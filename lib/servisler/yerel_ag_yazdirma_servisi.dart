import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:postgres/postgres.dart';
import 'package:printing/printing.dart';

import '../sayfalar/ayarlar/genel_ayarlar/modeller/genel_ayarlar_model.dart';
import 'ayarlar_veritabani_servisi.dart';
import 'veritabani_havuzu.dart';
import 'veritabani_yapilandirma.dart';

class YerelAgYazdirmaIsi {
  final String id;
  final String title;
  final String status;
  final String pdfBase64;
  final String? printerJson;
  final String? printerName;
  final int copies;
  final DateTime? createdAt;

  const YerelAgYazdirmaIsi({
    required this.id,
    required this.title,
    required this.status,
    required this.pdfBase64,
    required this.printerJson,
    required this.printerName,
    required this.copies,
    required this.createdAt,
  });

  factory YerelAgYazdirmaIsi.fromMap(Map<String, dynamic> map) {
    return YerelAgYazdirmaIsi(
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      status: map['status']?.toString() ?? 'pending',
      pdfBase64: map['pdf_base64']?.toString() ?? '',
      printerJson: map['printer_json']?.toString(),
      printerName: map['printer_name']?.toString(),
      copies: (map['copies'] as num?)?.toInt() ?? 1,
      createdAt: map['created_at'] is DateTime
          ? map['created_at'] as DateTime
          : DateTime.tryParse(map['created_at']?.toString() ?? ''),
    );
  }
}

class YerelAgYazdirmaServisi {
  static final YerelAgYazdirmaServisi _instance =
      YerelAgYazdirmaServisi._internal();
  factory YerelAgYazdirmaServisi() => _instance;
  YerelAgYazdirmaServisi._internal();

  Pool? _pool;
  bool _kuyrukBaslatildi = false;
  bool _kuyrukIsleniyor = false;
  Timer? _kuyrukTimer;

  bool get _masaustuPlatformu =>
      !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

  bool get _mobilPlatformu => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  bool get _yerelModAktif {
    final mode = VeritabaniYapilandirma.connectionMode;
    return mode == 'local' || mode == 'hybrid';
  }

  Future<void> _poolGuncelle() async {
    await AyarlarVeritabaniServisi().baslat();
    if (_pool == null || !(_pool?.isOpen ?? false)) {
      _pool = await VeritabaniHavuzu().havuzAl(
        database: VeritabaniYapilandirma().database,
      );
    }
    await _tabloyuHazirla();
  }

  Future<void> _tabloyuHazirla() async {
    if (_pool == null) return;

    await _pool!.execute('''
      CREATE TABLE IF NOT EXISTS local_print_jobs (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'pending',
        pdf_base64 TEXT NOT NULL,
        printer_json TEXT,
        printer_name TEXT,
        copies INTEGER NOT NULL DEFAULT 1,
        requested_platform TEXT,
        requested_device TEXT,
        created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        started_at TIMESTAMP,
        completed_at TIMESTAMP,
        error_message TEXT
      )
    ''');

    await _pool!.execute(
      'CREATE INDEX IF NOT EXISTS idx_local_print_jobs_status_created_at ON local_print_jobs (status, created_at)',
    );
  }

  String _printerIdentity(Printer printer) {
    final url = printer.url.trim();
    if (url.isNotEmpty) return url;
    return printer.name.trim();
  }

  Printer? _decodePrinter(String? raw) {
    final value = (raw ?? '').trim();
    if (value.isEmpty) return null;

    try {
      final decoded = jsonDecode(value);
      if (decoded is Map) {
        return Printer.fromMap(decoded.cast<String, dynamic>());
      }
    } catch (_) {}

    return Printer(url: value, name: value);
  }

  Printer? _selectPrinterFromSettings(GenelAyarlarModel ayarlar) {
    return _decodePrinter(ayarlar.yaziciSecimi);
  }

  Printer? _findMatchingPrinter(List<Printer> printers, Printer candidate) {
    final candidateIdentity = _printerIdentity(candidate);
    for (final printer in printers) {
      if (_printerIdentity(printer) == candidateIdentity) {
        return printer;
      }
      if (printer.name.trim() == candidate.name.trim()) {
        return printer;
      }
    }
    return null;
  }

  Future<List<Printer>> mobilTabletYazicilariniGetir() async {
    await _poolGuncelle();
    final ayarlar = await AyarlarVeritabaniServisi().genelAyarlariGetir();
    final printer = _selectPrinterFromSettings(ayarlar);
    if (printer == null) return const [];
    return <Printer>[printer];
  }

  Future<String?> mobilTabletYaziciAdiGetir() async {
    final printers = await mobilTabletYazicilariniGetir();
    if (printers.isEmpty) return null;
    return printers.first.name.trim().isEmpty ? null : printers.first.name;
  }

  Future<String> yazdirmaIstegiGonder({
    required String title,
    required Uint8List pdfBytes,
    required Printer printer,
    required int copies,
  }) async {
    if (!_mobilPlatformu || !_yerelModAktif) {
      throw Exception(
        'Yerel ag yazdirma yalnizca mobil/tablet yerel modda kullanilir.',
      );
    }

    await _poolGuncelle();
    if (_pool == null) {
      throw Exception('Yazdirma kuyrugu baglantisi kurulamadı.');
    }

    final id = _generateJobId();
    final requestedDevice = Platform.operatingSystem;

    await _pool!.execute(
      Sql.named('''
        INSERT INTO local_print_jobs (
          id, title, status, pdf_base64, printer_json, printer_name,
          copies, requested_platform, requested_device
        ) VALUES (
          @id, @title, 'pending', @pdf_base64, @printer_json, @printer_name,
          @copies, @requested_platform, @requested_device
        )
      '''),
      parameters: {
        'id': id,
        'title': title,
        'pdf_base64': base64Encode(pdfBytes),
        'printer_json': jsonEncode(printer.toMap()),
        'printer_name': printer.name,
        'copies': math.max(1, copies),
        'requested_platform': requestedDevice,
        'requested_device': requestedDevice,
      },
    );

    return id;
  }

  Future<void> masaustuKuyrugunuBaslat() async {
    if (!_masaustuPlatformu || _kuyrukBaslatildi) return;
    _kuyrukBaslatildi = true;
    await _poolGuncelle();
    _kuyrukTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      unawaited(_bekleyenIsleriIsle());
    });
    unawaited(_bekleyenIsleriIsle());
  }

  Future<void> masaustuKuyrugunuDurdur() async {
    _kuyrukTimer?.cancel();
    _kuyrukTimer = null;
    _kuyrukBaslatildi = false;
  }

  Future<void> _bekleyenIsleriIsle() async {
    if (_kuyrukIsleniyor) return;
    if (!_masaustuPlatformu || !_yerelModAktif) return;

    _kuyrukIsleniyor = true;
    try {
      await _poolGuncelle();
      if (_pool == null) return;

      final ayarlar = await AyarlarVeritabaniServisi().genelAyarlariGetir();
      if (ayarlar.sunucuModu != 'server') return;

      final rows = await _pool!.execute(
        Sql.named('''
          SELECT id, title, status, pdf_base64, printer_json, printer_name, copies, created_at
          FROM local_print_jobs
          WHERE status = 'pending'
          ORDER BY created_at ASC
          LIMIT 5
        '''),
      );

      final jobs = rows
          .map((row) => YerelAgYazdirmaIsi.fromMap(row.toColumnMap()))
          .toList();

      if (jobs.isEmpty) return;

      final printers = await Printing.listPrinters();
      for (final job in jobs) {
        await _processJob(job, printers, ayarlar);
      }

      await _cleanupOldJobs();
    } catch (e) {
      debugPrint('YerelAgYazdirmaServisi kuyruk hatasi: $e');
    } finally {
      _kuyrukIsleniyor = false;
    }
  }

  Future<void> _processJob(
    YerelAgYazdirmaIsi job,
    List<Printer> printers,
    GenelAyarlarModel ayarlar,
  ) async {
    final claimed = await _claimJob(job.id);
    if (!claimed) return;

    try {
      final fallbackPrinter = _selectPrinterFromSettings(ayarlar);
      final requestedPrinter = _decodePrinter(job.printerJson);
      final candidate = requestedPrinter ?? fallbackPrinter;
      if (candidate == null) {
        throw Exception('Hedef yazıcı bulunamadı.');
      }

      final printer = _findMatchingPrinter(printers, candidate);
      if (printer == null) {
        throw Exception('Secilen yazici masaustunde yüklü değil.');
      }

      final bytes = base64Decode(job.pdfBase64);
      final copies = math.max(1, job.copies);
      for (var i = 0; i < copies; i++) {
        await Printing.directPrintPdf(
          printer: printer,
          onLayout: (_) async => bytes,
          name: job.title,
        );
      }

      await _markCompleted(job.id);
    } catch (e) {
      await _markFailed(job.id, '$e');
    }
  }

  Future<bool> _claimJob(String id) async {
    if (_pool == null) return false;

    final result = await _pool!.execute(
      Sql.named('''
        UPDATE local_print_jobs
        SET status = 'processing',
            started_at = CURRENT_TIMESTAMP,
            error_message = NULL
        WHERE id = @id
          AND status = 'pending'
        RETURNING id
      '''),
      parameters: {'id': id},
    );

    return result.isNotEmpty;
  }

  Future<void> _markCompleted(String id) async {
    if (_pool == null) return;
    await _pool!.execute(
      Sql.named('''
        UPDATE local_print_jobs
        SET status = 'completed',
            completed_at = CURRENT_TIMESTAMP,
            error_message = NULL
        WHERE id = @id
      '''),
      parameters: {'id': id},
    );
  }

  Future<void> _markFailed(String id, String error) async {
    if (_pool == null) return;
    await _pool!.execute(
      Sql.named('''
        UPDATE local_print_jobs
        SET status = 'failed',
            completed_at = CURRENT_TIMESTAMP,
            error_message = @error
        WHERE id = @id
      '''),
      parameters: {'id': id, 'error': error},
    );
  }

  Future<void> _cleanupOldJobs() async {
    if (_pool == null) return;

    await _pool!.execute(
      Sql.named('''
        DELETE FROM local_print_jobs
        WHERE status IN ('completed', 'failed')
          AND completed_at IS NOT NULL
          AND completed_at < CURRENT_TIMESTAMP - INTERVAL '2 days'
      '''),
    );
  }

  String _generateJobId() {
    final random = math.Random.secure().nextInt(1 << 32);
    return '${DateTime.now().microsecondsSinceEpoch}_$random';
  }
}
