import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart' as crypto;
import 'package:cryptography/cryptography.dart' as cryptography;
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class LisansKasasiKaydi {
  final int version;
  final String hardwareId;

  final String? licenseKey;
  final DateTime? licenseEndDateUtc; // Date-only (UTC)

  final DateTime lastSeenUtc;
  final DateTime maxSeenUtc;

  const LisansKasasiKaydi({
    required this.version,
    required this.hardwareId,
    required this.licenseKey,
    required this.licenseEndDateUtc,
    required this.lastSeenUtc,
    required this.maxSeenUtc,
  });

  Map<String, dynamic> toJson() => {
        'v': version,
        'hardware_id': hardwareId,
        'license_key': licenseKey,
        'license_end_date': licenseEndDateUtc != null
            ? _dateOnlyIsoUtc(licenseEndDateUtc!)
            : null,
        'last_seen_utc': lastSeenUtc.toUtc().toIso8601String(),
        'max_seen_utc': maxSeenUtc.toUtc().toIso8601String(),
      };

  static LisansKasasiKaydi? fromJson(Map<String, dynamic> json) {
    try {
      final vRaw = json['v'];
      final version = vRaw is int ? vRaw : int.tryParse(vRaw?.toString() ?? '');
      if (version == null || version < 1) return null;

      final hardwareId = json['hardware_id']?.toString();
      if (hardwareId == null || hardwareId.trim().isEmpty) return null;

      final lastSeenIso = json['last_seen_utc']?.toString();
      final lastSeenUtc =
          lastSeenIso != null ? DateTime.tryParse(lastSeenIso) : null;

      final maxSeenIso = json['max_seen_utc']?.toString();
      final maxSeenUtc =
          maxSeenIso != null ? DateTime.tryParse(maxSeenIso) : null;

      if (lastSeenUtc == null || maxSeenUtc == null) {
        return null;
      }

      final licenseKey = json['license_key']?.toString();
      final endDateIso = json['license_end_date']?.toString();
      final licenseEndDateUtc =
          endDateIso != null ? _parseDateOnlyIsoUtc(endDateIso) : null;

      return LisansKasasiKaydi(
        version: version,
        hardwareId: hardwareId,
        licenseKey: (licenseKey != null && licenseKey.trim().isNotEmpty)
            ? licenseKey
            : null,
        licenseEndDateUtc: licenseEndDateUtc,
        lastSeenUtc: lastSeenUtc.toUtc(),
        maxSeenUtc: maxSeenUtc.toUtc(),
      );
    } catch (_) {
      return null;
    }
  }

  static String _dateOnlyIsoUtc(DateTime dt) {
    final d = dt.toUtc();
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  static DateTime? _parseDateOnlyIsoUtc(String iso) {
    final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(iso.trim());
    if (m == null) return null;
    final y = int.tryParse(m.group(1)!);
    final mo = int.tryParse(m.group(2)!);
    final d = int.tryParse(m.group(3)!);
    if (y == null || mo == null || d == null) return null;
    return DateTime.utc(y, mo, d);
  }
}

class LisansKasasi {
  static const int _containerVersion = 1;
  static const String _alg = 'A256GCM';

  final cryptography.AesGcm _cipher = cryptography.AesGcm.with256bits();

  Future<bool> dosyaVarMi({required String hardwareId}) async {
    if (kIsWeb) return false;
    final file = await _vaultFile(hardwareId);
    return file.exists();
  }

  Future<void> sil({required String hardwareId}) async {
    if (kIsWeb) return;
    try {
      final file = await _vaultFile(hardwareId);
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  Future<LisansKasasiKaydi?> oku({
    required String hardwareId,
    required String secret,
  }) async {
    if (kIsWeb) return null;
    final file = await _vaultFile(hardwareId);
    if (!await file.exists()) return null;

    try {
      final raw = await file.readAsString();
      final decoded = json.decode(raw);
      if (decoded is! Map) return null;
      final container = Map<String, dynamic>.from(decoded);

      final vRaw = container['v'];
      final v = vRaw is int ? vRaw : int.tryParse(vRaw?.toString() ?? '');
      if (v != _containerVersion) return null;

      final alg = container['alg']?.toString();
      if (alg != _alg) return null;

      final nonceB64 = container['nonce']?.toString();
      final cipherB64 = container['ciphertext']?.toString();
      final macB64 = container['mac']?.toString();
      final sigB64 = container['sig']?.toString();
      if (nonceB64 == null ||
          cipherB64 == null ||
          macB64 == null ||
          sigB64 == null) {
        return null;
      }

      final nonce = base64.decode(nonceB64);
      final ciphertext = base64.decode(cipherB64);
      final macBytes = base64.decode(macB64);
      final sig = base64.decode(sigB64);

      final encKey = _deriveKeyBytes(
        hardwareId: hardwareId,
        secret: secret,
        purpose: 'enc-v1',
      );
      final signKey = _deriveKeyBytes(
        hardwareId: hardwareId,
        secret: secret,
        purpose: 'sig-v1',
      );

      final expectedSig = _hmacSha256(
        keyBytes: signKey,
        dataBytes: _signatureBytes(
          nonce: nonce,
          ciphertext: ciphertext,
          mac: macBytes,
        ),
      );

      if (!_constantTimeEquals(sig, expectedSig)) return null;

      final clearBytes = await _cipher.decrypt(
        cryptography.SecretBox(
          ciphertext,
          nonce: nonce,
          mac: cryptography.Mac(macBytes),
        ),
        secretKey: cryptography.SecretKey(encKey),
      );

      final clear = utf8.decode(clearBytes);
      final payloadDecoded = json.decode(clear);
      if (payloadDecoded is! Map) return null;

      final record = LisansKasasiKaydi.fromJson(
        Map<String, dynamic>.from(payloadDecoded),
      );

      if (record == null) return null;
      if (record.hardwareId.toUpperCase() != hardwareId.toUpperCase()) {
        return null;
      }

      return record;
    } catch (_) {
      return null;
    }
  }

  Future<void> yaz({
    required String hardwareId,
    required String secret,
    required LisansKasasiKaydi record,
  }) async {
    if (kIsWeb) return;

    final file = await _vaultFile(hardwareId);
    await file.parent.create(recursive: true);

    final encKey = _deriveKeyBytes(
      hardwareId: hardwareId,
      secret: secret,
      purpose: 'enc-v1',
    );
    final signKey = _deriveKeyBytes(
      hardwareId: hardwareId,
      secret: secret,
      purpose: 'sig-v1',
    );

    final payload = json.encode(record.toJson());
    final payloadBytes = utf8.encode(payload);

    final nonce = _randomBytes(12);
    final box = await _cipher.encrypt(
      payloadBytes,
      secretKey: cryptography.SecretKey(encKey),
      nonce: nonce,
    );

    final sig = _hmacSha256(
      keyBytes: signKey,
      dataBytes: _signatureBytes(
        nonce: box.nonce,
        ciphertext: box.cipherText,
        mac: box.mac.bytes,
      ),
    );

    final container = <String, dynamic>{
      'v': _containerVersion,
      'alg': _alg,
      'nonce': base64.encode(box.nonce),
      'ciphertext': base64.encode(box.cipherText),
      'mac': base64.encode(box.mac.bytes),
      'sig': base64.encode(sig),
    };

    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(json.encode(container), flush: true);

    try {
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}

    await tmp.rename(file.path);
  }

  Future<File> _vaultFile(String hardwareId) async {
    final dir = await getApplicationSupportDirectory();
    final folder = Directory(p.join(dir.path, 'lotyazilim'));
    return File(p.join(folder.path, 'license_${hardwareId.toUpperCase()}.vault'));
  }

  static List<int> _deriveKeyBytes({
    required String hardwareId,
    required String secret,
    required String purpose,
  }) {
    final material = 'LOT|$purpose|${hardwareId.toUpperCase()}|$secret';
    return crypto.sha256.convert(utf8.encode(material)).bytes;
  }

  static List<int> _signatureBytes({
    required List<int> nonce,
    required List<int> ciphertext,
    required List<int> mac,
  }) {
    final prefix = utf8.encode('v$_containerVersion|$_alg|');
    return <int>[...prefix, ...nonce, ...ciphertext, ...mac];
  }

  static List<int> _hmacSha256({
    required List<int> keyBytes,
    required List<int> dataBytes,
  }) {
    final hmac = crypto.Hmac(crypto.sha256, keyBytes);
    return hmac.convert(dataBytes).bytes;
  }

  static bool _constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }

  static List<int> _randomBytes(int length) {
    final rand = Random.secure();
    return List<int>.generate(length, (_) => rand.nextInt(256));
  }
}
