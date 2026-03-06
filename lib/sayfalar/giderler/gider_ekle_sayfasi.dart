import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../yardimcilar/ceviri/ceviri_servisi.dart';
import '../../yardimcilar/mesaj_yardimcisi.dart';
import '../../yardimcilar/format_yardimcisi.dart';
import '../../servisler/ayarlar_veritabani_servisi.dart';
import '../../servisler/giderler_veritabani_servisi.dart';
import '../ayarlar/genel_ayarlar/modeller/genel_ayarlar_model.dart';
import '../../bilesenler/tek_tarih_secici_dialog.dart';
import '../../bilesenler/akilli_aciklama_input.dart';
import 'modeller/gider_model.dart';
import 'dart:io';
import 'package:file_selector/file_selector.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../../servisler/yapay_zeka_servisi.dart';

class GiderEkleSayfasi extends StatefulWidget {
  final GiderModel? gider;
  final bool autoStartAiScan;

  const GiderEkleSayfasi({super.key, this.gider, this.autoStartAiScan = false});

  @override
  State<GiderEkleSayfasi> createState() => _GiderEkleSayfasiState();
}

class _GiderEkleSayfasiState extends State<GiderEkleSayfasi> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  GenelAyarlarModel _genelAyarlar = GenelAyarlarModel();

  // Form Controllers
  final _kodController = TextEditingController();
  final _baslikController = TextEditingController();
  final _kategoriController = TextEditingController();
  final _tutarController = TextEditingController();
  final _aciklamaController = TextEditingController();

  // Focus Nodes
  late FocusNode _kodFocusNode;
  late FocusNode _baslikFocusNode;
  late FocusNode _tarihFocusNode;
  late FocusNode _tutarFocusNode;
  // late FocusNode _aciklamaFocusNode; // Removed as AkilliAciklamaInput handles it internally

  // Form State
  // String _selectedKategori = 'Market'; // Removed in favor of controller
  String _selectedParaBirimi = 'TRY';
  String _selectedOdemeDurumu = 'Beklemede';
  DateTime _selectedTarih = DateTime.now();
  bool _aktifMi = true;
  List<String> _resimler = [];
  int _selectedAiImageIndex = 0;

  // Sub-items
  final List<Map<String, dynamic>> _giderKalemleri = [];

  // Dropdown Data

  // AI State (Placeholder)
  bool _aiScanning = false;
  Map<String, dynamic>? _aiExtractedData;

  bool get _isEditing => widget.gider != null;

  @override
  void initState() {
    super.initState();
    _kodFocusNode = FocusNode();
    _baslikFocusNode = FocusNode();
    _tarihFocusNode = FocusNode();
    _tutarFocusNode = FocusNode();
    // _aciklamaFocusNode = FocusNode();

    _attachPriceFormatter(_tutarFocusNode, _tutarController);

    if (_isEditing) {
      _loadGiderData();
    } else {
      _generateKod();
      _addGiderKalemiRow(); // Default mandatory item
    }

    _initializeAndFocus();

    if (!_isEditing && widget.autoStartAiScan) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _handleAIScan();
      });
    }
  }

  @override
  void dispose() {
    for (final item in _giderKalemleri) {
      (item['aciklama'] as TextEditingController?)?.dispose();
      (item['tutar'] as TextEditingController?)?.dispose();
      (item['not'] as TextEditingController?)?.dispose();
      (item['focus'] as FocusNode?)?.dispose();
    }
    _kodController.dispose();
    _baslikController.dispose();
    _kategoriController.dispose();
    _tutarController.dispose();
    _aciklamaController.dispose();
    _kodFocusNode.dispose();
    _baslikFocusNode.dispose();
    _tarihFocusNode.dispose();
    _tutarFocusNode.dispose();
    // _aciklamaFocusNode.dispose();
    super.dispose();
  }

  void _addGiderKalemiRow() {
    setState(() {
      final aciklamaCtrl = TextEditingController();
      final tutarCtrl = TextEditingController();
      final notCtrl = TextEditingController();
      final focusNode = FocusNode();

      _attachPriceFormatter(focusNode, tutarCtrl, calculateTotal: true);

      _giderKalemleri.add({
        'aciklama': aciklamaCtrl,
        'tutar': tutarCtrl,
        'not': notCtrl,
        'focus': focusNode,
      });
    });
  }

  // Revised approach for `_addGiderKalemiRow` to handle standard controllers properly
  // We need to manage the focus nodes separately or change the type of _giderKalemleri.
  // Let's change `_giderKalemleri` to `List<Map<String, dynamic>>` in a separate step or just assume dynamic for now.
  // Actually, I can just use a helper to attach the formatter immediately.

  void _removeGiderKalemiRow(int index) {
    if (_giderKalemleri.length <= 1) return;
    setState(() {
      _giderKalemleri[index]['aciklama']?.dispose();
      _giderKalemleri[index]['tutar']?.dispose();
      _giderKalemleri[index]['not']?.dispose();
      _giderKalemleri[index]['focus']?.dispose();
      _giderKalemleri.removeAt(index);
      _calculateTotalFromItems();
    });
  }

  void _calculateTotalFromItems() {
    double total = 0;
    for (var item in _giderKalemleri) {
      final val = FormatYardimcisi.parseDouble(
        item['tutar']?.text ?? '0',
        binlik: _genelAyarlar.binlikAyiraci,
        ondalik: _genelAyarlar.ondalikAyiraci,
      );
      total += val;
    }
    _tutarController.text = FormatYardimcisi.sayiFormatlaOndalikli(
      total,
      binlik: _genelAyarlar.binlikAyiraci,
      ondalik: _genelAyarlar.ondalikAyiraci,
      decimalDigits: _genelAyarlar.fiyatOndalik,
    );
  }

  void _attachPriceFormatter(
    FocusNode focusNode,
    TextEditingController controller, {
    bool calculateTotal = false,
  }) {
    focusNode.addListener(() {
      if (!focusNode.hasFocus) {
        final text = controller.text.trim();
        if (text.isEmpty) return;
        final value = FormatYardimcisi.parseDouble(
          text,
          binlik: _genelAyarlar.binlikAyiraci,
          ondalik: _genelAyarlar.ondalikAyiraci,
        );
        final formatted = FormatYardimcisi.sayiFormatlaOndalikli(
          value,
          binlik: _genelAyarlar.binlikAyiraci,
          ondalik: _genelAyarlar.ondalikAyiraci,
          decimalDigits: _genelAyarlar.fiyatOndalik,
        );
        controller
          ..text = formatted
          ..selection = TextSelection.collapsed(offset: formatted.length);

        if (calculateTotal && mounted) {
          setState(() => _calculateTotalFromItems());
        }
      }
    });
  }

  Future<void> _initializeAndFocus() async {
    try {
      final settings = await AyarlarVeritabaniServisi().genelAyarlariGetir();

      if (!mounted) return;

      String currency = settings.varsayilanParaBirimi;
      if (currency == 'TL') currency = 'TRY';

      setState(() {
        _genelAyarlar = settings;
        _selectedParaBirimi = currency;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_kodController.text.isNotEmpty) {
          _baslikFocusNode.requestFocus();
        } else {
          _kodFocusNode.requestFocus();
        }
      });
    } catch (e) {
      debugPrint('Başlatma hatası: $e');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _kodFocusNode.requestFocus();
      });
    }
  }

  void _loadGiderData() {
    final gider = widget.gider!;
    _kodController.text = gider.kod;
    _baslikController.text = gider.baslik;
    _tutarController.text = gider.tutar > 0
        ? FormatYardimcisi.sayiFormatlaOndalikli(
            gider.tutar,
            binlik: _genelAyarlar.binlikAyiraci,
            ondalik: _genelAyarlar.ondalikAyiraci,
            decimalDigits: _genelAyarlar.fiyatOndalik,
          )
        : '';
    _aciklamaController.text = gider.aciklama;

    _kategoriController.text = gider.kategori;
    // _selectedKategori = gider.kategori;
    _selectedParaBirimi = gider.paraBirimi;
    _selectedOdemeDurumu = gider.odemeDurumu;
    _selectedTarih = gider.tarih;
    _aktifMi = gider.aktifMi;
    _resimler = List.from(gider.resimler);

    // Kalemleri yükle
    for (var kalem in gider.kalemler) {
      final aciklamaCtrl = TextEditingController(text: kalem.aciklama);
      final tutarCtrl = TextEditingController(
        text: FormatYardimcisi.sayiFormatlaOndalikli(
          kalem.tutar,
          binlik: _genelAyarlar.binlikAyiraci,
          ondalik: _genelAyarlar.ondalikAyiraci,
          decimalDigits: _genelAyarlar.fiyatOndalik,
        ),
      );
      final notCtrl = TextEditingController(text: kalem.not);
      final focusNode = FocusNode();
      _attachPriceFormatter(focusNode, tutarCtrl, calculateTotal: true);

      _giderKalemleri.add({
        'aciklama': aciklamaCtrl,
        'tutar': tutarCtrl,
        'not': notCtrl,
        'focus': focusNode,
      });
    }

    if (_giderKalemleri.isEmpty) {
      final aciklamaCtrl = TextEditingController();
      final tutarCtrl = TextEditingController();
      final notCtrl = TextEditingController();
      final focusNode = FocusNode();
      _attachPriceFormatter(focusNode, tutarCtrl, calculateTotal: true);
      _giderKalemleri.add({
        'aciklama': aciklamaCtrl,
        'tutar': tutarCtrl,
        'not': notCtrl,
        'focus': focusNode,
      });
    }
  }

  // REDEFINING THE LIST STRUCTURE IN A BETTER WAY BELOW (via replacement logic)

  void _generateKod() {
    final now = DateTime.now();
    _kodController.text =
        'GD-${now.millisecondsSinceEpoch.toString().substring(7)}';
  }

  Future<void> _handleAIScan() async {
    if (_aiScanning) return;

    if (_resimler.isEmpty) {
      await _pickImage();
      if (!mounted) return;
      if (_resimler.isEmpty) return;
    }

    setState(() => _aiScanning = true);

    try {
      final int index = _selectedAiImageIndex.clamp(0, _resimler.length - 1);
      final imageFile = File(_resimler[index]);
      if (!await imageFile.exists()) {
        throw Exception(tr('expenses.ai.image_file_not_found'));
      }

      final imageBytes = await imageFile.readAsBytes();
      final yapayZekaServisi = YapayZekaServisi();

      final extractedMap = await yapayZekaServisi.analizEtGiderFisi(imageBytes);

      if (mounted) {
        setState(() {
          _aiExtractedData = extractedMap;
          _aiScanning = false;
        });

        // Verileri otomatik uygula
        _applyAIData();

        MesajYardimcisi.basariGoster(context, tr('expenses.ai.scan_success'));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _aiScanning = false);
        MesajYardimcisi.hataGoster(
          context,
          tr('expenses.ai.scan_error_detail').replaceAll('{error}', '$e'),
        );
      }
    }
  }

  void _applyAIData() {
    if (_aiExtractedData == null) return;

    setState(() {
      if (_aiExtractedData!['baslik'] != null) {
        _baslikController.text = _aiExtractedData!['baslik'].toString();
      }

      if (_aiExtractedData!['tutar'] != null) {
        final val = _aiExtractedData!['tutar'];
        double dVal = 0.0;
        if (val is num) {
          dVal = val.toDouble();
        } else if (val is String) {
          dVal = double.tryParse(val) ?? 0.0;
        }

        _tutarController.text = FormatYardimcisi.sayiFormatlaOndalikli(
          dVal,
          binlik: _genelAyarlar.binlikAyiraci,
          ondalik: _genelAyarlar.ondalikAyiraci,
          decimalDigits: _genelAyarlar.fiyatOndalik,
        );
      }

      if (_aiExtractedData!['tarih'] != null) {
        try {
          _selectedTarih = DateTime.parse(_aiExtractedData!['tarih']);
        } catch (_) {}
      }

      if (_aiExtractedData!['kategori'] != null) {
        _kategoriController.text = _aiExtractedData!['kategori'].toString();
      }

      final rawKalemler = _aiExtractedData!['kalemler'];
      final List<dynamic> kalemler = rawKalemler is List
          ? rawKalemler
          : const [];
      if (kalemler.isNotEmpty) {
        // Dispose existing controllers properly
        for (var item in _giderKalemleri) {
          (item['aciklama'] as TextEditingController).dispose();
          (item['tutar'] as TextEditingController).dispose();
          (item['not'] as TextEditingController).dispose();
          (item['focus'] as FocusNode).dispose();
        }
        _giderKalemleri.clear();

        for (final k in kalemler) {
          if (k is! Map) continue;

          final aciklama = k['aciklama']?.toString() ?? '';
          final not = k['not']?.toString() ?? '';

          double kFiyat = 0;
          final kVal = k['tutar'];
          if (kVal is num) {
            kFiyat = kVal.toDouble();
          } else if (kVal is String) {
            kFiyat = double.tryParse(kVal) ?? 0.0;
          }

          final aciklamaCtrl = TextEditingController(text: aciklama);
          final tutarCtrl = TextEditingController(
            text: FormatYardimcisi.sayiFormatlaOndalikli(
              kFiyat,
              binlik: _genelAyarlar.binlikAyiraci,
              ondalik: _genelAyarlar.ondalikAyiraci,
              decimalDigits: _genelAyarlar.fiyatOndalik,
            ),
          );
          final notCtrl = TextEditingController(text: not);
          final focus = FocusNode();

          _attachPriceFormatter(focus, tutarCtrl, calculateTotal: true);

          _giderKalemleri.add({
            'aciklama': aciklamaCtrl,
            'tutar': tutarCtrl,
            'not': notCtrl,
            'focus': focus,
          });
        }
        // Trigger total calculation
        _calculateTotalFromItems();
      }
    });
  }

  Widget _buildHeader(ThemeData theme) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.receipt_long_rounded,
            color: theme.colorScheme.primary,
            size: 28,
          ),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isEditing
                  ? tr('expenses.form.edit.title')
                  : tr('expenses.form.add.title'),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
                fontSize: 23,
              ),
            ),
            Text(
              _isEditing
                  ? tr('expenses.form.edit.subtitle')
                  : tr('expenses.form.add.subtitle'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                fontSize: 16,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _selectDate() async {
    final picked = await showDialog<DateTime>(
      context: context,
      builder: (context) => TekTarihSeciciDialog(
        initialDate: _selectedTarih,
        firstDate: DateTime(2000),
        lastDate: DateTime(2100),
        title: tr('expenses.form.date.label'),
      ),
    );
    if (picked != null) {
      setState(() => _selectedTarih = picked);
    }
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.escape) {
        Navigator.of(context).pop();
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.enter ||
          event.logicalKey == LogicalKeyboardKey.numpadEnter) {
        final kodDolu = _kodController.text.trim().isNotEmpty;
        final baslikDolu = _baslikController.text.trim().isNotEmpty;
        final tutarDolu = _tutarController.text.trim().isNotEmpty;

        if (kodDolu && baslikDolu && tutarDolu) {
          _save();
          return KeyEventResult.handled;
        }
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool isMobileLayout = MediaQuery.sizeOf(context).width < 900;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.arrow_back, color: theme.colorScheme.onSurface),
              onPressed: () => Navigator.of(context).pop(),
            ),
            Text(
              tr('common.esc'),
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
            ),
          ],
        ),
        leadingWidth: 80,
        title: Text(
          _isEditing
              ? tr('expenses.form.edit.title')
              : tr('expenses.form.add.title'),
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
            fontSize: 21,
          ),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: tr('expenses.ai.scan_button'),
            onPressed: _aiScanning ? null : _handleAIScan,
            icon: Icon(Icons.auto_awesome, color: theme.colorScheme.primary),
          ),
        ],
      ),
      body: Stack(
        children: [
          FocusScope(
            onKeyEvent: _handleKeyEvent,
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1200),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildHeader(theme),
                              const SizedBox(height: 32),
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  if (constraints.maxWidth > 800) {
                                    return Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          flex: 2,
                                          child: FocusTraversalGroup(
                                            child: _buildLeftColumn(theme),
                                          ),
                                        ),
                                        const SizedBox(width: 24),
                                        Expanded(
                                          child: FocusTraversalGroup(
                                            child: _buildAIScanSection(theme),
                                          ),
                                        ),
                                      ],
                                    );
                                  } else {
                                    return Column(
                                      children: [
                                        FocusTraversalGroup(
                                          child: _buildAIScanSection(theme),
                                        ),
                                        const SizedBox(height: 24),
                                        FocusTraversalGroup(
                                          child: _buildLeftColumn(theme),
                                        ),
                                      ],
                                    );
                                  }
                                },
                              ),
                              const SizedBox(height: 40),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Container(
                  padding: isMobileLayout
                      ? const EdgeInsets.fromLTRB(16, 12, 16, 12)
                      : const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1200),
                      child: _buildActionButtons(
                        theme,
                        isCompact: isMobileLayout,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGiderKalemleriSection(ThemeData theme) {
    final color = Colors.red.shade700;
    double total = 0;
    for (var item in _giderKalemleri) {
      total += FormatYardimcisi.parseDouble(
        item['tutar']?.text ?? '0',
        binlik: _genelAyarlar.binlikAyiraci,
        ondalik: _genelAyarlar.ondalikAyiraci,
      );
    }

    return _buildSection(
      theme,
      title: tr('expenses.items.title'),
      icon: Icons.list_alt_rounded,
      color: color,
      child: Column(
        children: [
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _giderKalemleri.length,
            separatorBuilder: (context, index) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final item = _giderKalemleri[index];
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final bool isNarrow = constraints.maxWidth < 650;

                        final descField = _buildTextField(
                          controller: item['aciklama'] as TextEditingController,
                          label: tr('expenses.items.description'),
                          hint: tr('expenses.items.description_hint'),
                          color: color,
                        );

                        final amountField = _buildTextField(
                          controller: item['tutar'] as TextEditingController,
                          label: tr('expenses.form.amount.label'),
                          hint: '0.00',
                          isNumeric: true,
                          color: color,
                          prefix: _getParaBirimiSembol(_selectedParaBirimi),
                          focusNode: item['focus'] as FocusNode,
                          onChanged: (_) =>
                              setState(() => _calculateTotalFromItems()),
                        );

                        final currencyField = _buildDropdown<String>(
                          value: _selectedParaBirimi,
                          label: tr('expenses.form.currency.label'),
                          items:
                              _genelAyarlar.kullanilanParaBirimleri.isNotEmpty
                              ? _genelAyarlar.kullanilanParaBirimleri
                              : ['TRY', 'USD', 'EUR', 'GBP'],
                          onChanged: (val) {
                            setState(() => _selectedParaBirimi = val ?? 'TRY');
                          },
                          color: color,
                        );

                        if (isNarrow) {
                          return Column(
                            children: [
                              descField,
                              const SizedBox(height: 12),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(flex: 2, child: amountField),
                                  const SizedBox(width: 12),
                                  Expanded(child: currencyField),
                                  if (_giderKalemleri.length > 1) ...[
                                    const SizedBox(width: 4),
                                    Padding(
                                      padding: const EdgeInsets.only(top: 22),
                                      child: IconButton(
                                        icon: const Icon(
                                          Icons.delete_outline,
                                          color: Colors.red,
                                        ),
                                        onPressed: () =>
                                            _removeGiderKalemiRow(index),
                                        tooltip: tr('common.delete'),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          );
                        }

                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 3, child: descField),
                            const SizedBox(width: 16),
                            Expanded(flex: 2, child: amountField),
                            const SizedBox(width: 16),
                            Expanded(flex: 1, child: currencyField),
                            if (_giderKalemleri.length > 1) ...[
                              const SizedBox(width: 8),
                              Padding(
                                padding: const EdgeInsets.only(top: 24),
                                child: IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: Colors.red,
                                  ),
                                  onPressed: () => _removeGiderKalemiRow(index),
                                  tooltip: tr('common.delete'),
                                ),
                              ),
                            ],
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    AkilliAciklamaInput(
                      controller: item['not'] as TextEditingController,
                      label: tr('expenses.form.description.label'),
                      category: 'expense_item_note',
                      color: color,
                      defaultItems: [
                        tr('expenses.items.default_note.part'),
                        tr('expenses.items.default_note.labor'),
                        tr('expenses.items.default_note.shipping'),
                        tr('expenses.items.default_note.tax'),
                        tr('common.other'),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                '${tr('common.total')}: ',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              Text(
                '${FormatYardimcisi.sayiFormatlaOndalikli(total, binlik: _genelAyarlar.binlikAyiraci, ondalik: _genelAyarlar.ondalikAyiraci, decimalDigits: _genelAyarlar.fiyatOndalik)} $_selectedParaBirimi',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _addGiderKalemiRow,
              icon: const Icon(Icons.add_circle_outline),
              label: Text(tr('expenses.items.add')),
              style: OutlinedButton.styleFrom(
                foregroundColor: color,
                side: BorderSide(color: color.withValues(alpha: 0.5)),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeftColumn(ThemeData theme) {
    return Column(
      children: [
        _buildSection(
          theme,
          title: tr('expenses.form.section.general'),
          child: _buildGeneralInfoSection(theme),
          icon: Icons.info_rounded,
          color: Colors.blue.shade700,
        ),
        const SizedBox(height: 24),
        _buildGiderKalemleriSection(theme),
        const SizedBox(height: 24),
        _buildSection(
          theme,
          title: tr('expenses.form.section.status_info'),
          child: _buildAmountSection(theme),
          icon: Icons.info_outline,
          color: Colors.green.shade700,
        ),
        const SizedBox(height: 24),
        _buildSection(
          theme,
          title: tr('expenses.form.section.notes'),
          child: _buildNotesSection(theme),
          icon: Icons.note_alt_rounded,
          color: Colors.purple.shade700,
        ),
      ],
    );
  }

  Widget _buildSection(
    ThemeData theme, {
    required String title,
    required Widget child,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 16),
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                  fontSize: 21,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          child,
        ],
      ),
    );
  }

  Widget _buildGeneralInfoSection(ThemeData theme) {
    final requiredColor = Colors.red.shade700;
    final optionalColor = Colors.blue.shade700;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildTextField(
                controller: _kodController,
                label: tr('expenses.form.code.label'),
                hint: tr('expenses.form.code.hint'),
                isRequired: true,
                color: requiredColor,
                focusNode: _kodFocusNode,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildDateField(
                label: tr('expenses.form.date.label'),
                value: _selectedTarih,
                onTap: _selectDate,
                color: requiredColor,
                focusNode: _tarihFocusNode,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _baslikController,
          label: tr('expenses.form.title.label'),
          hint: tr('expenses.form.title.hint'),
          isRequired: true,
          color: requiredColor,
          focusNode: _baslikFocusNode,
        ),
        const SizedBox(height: 16),
        AkilliAciklamaInput(
          controller: _kategoriController,
          label: tr('expenses.form.category.label'),
          category: 'expense_category',
          color: optionalColor,
          defaultItems: GiderModel.varsayilanKategoriler(),
        ),
      ],
    );
  }

  Widget _buildAmountSection(ThemeData theme) {
    final optionalColor = Colors.green.shade700;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildDropdown<String>(
                value: _selectedOdemeDurumu,
                label: tr('expenses.form.payment_status.label'),
                items: ['Beklemede', 'Ödendi'],
                onChanged: (val) =>
                    setState(() => _selectedOdemeDurumu = val ?? 'Beklemede'),
                itemLabelBuilder: (item) => item == 'Beklemede'
                    ? tr('expenses.payment.pending')
                    : tr('expenses.payment.paid'),
                color: optionalColor,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildDropdown<String>(
                value: _aktifMi ? 'Aktif' : 'Pasif',
                label: tr('common.status'),
                items: ['Aktif', 'Pasif'],
                onChanged: (val) => setState(() => _aktifMi = val == 'Aktif'),
                itemLabelBuilder: (item) => item == 'Aktif'
                    ? tr('common.active')
                    : tr('common.passive'),
                color: optionalColor,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNotesSection(ThemeData theme) {
    final color = Colors.purple.shade700;

    return Column(
      children: [
        AkilliAciklamaInput(
          controller: _aciklamaController,
          label: tr('expenses.form.description.label'),
          category: 'expense_note',
          color: color,
          defaultItems: [
            tr('expenses.notes.suggestion.monthly_routine'),
            tr('expenses.notes.suggestion.credit_card'),
            tr('expenses.notes.suggestion.cash'),
            tr('expenses.notes.suggestion.company_expense'),
            tr('expenses.notes.suggestion.installment'),
          ],
        ),
      ],
    );
  }

  Widget _buildAIScanSection(ThemeData theme) {
    final color = Colors.teal.shade700;

    return _buildSection(
      theme,
      title: tr('expenses.form.section.ai_scan'),
      icon: Icons.auto_awesome,
      color: color,
      child: Column(
        children: [
          Container(
            height: 180,
            width: double.infinity,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
            ),
            child: _resimler.isEmpty
                ? InkWell(
                    mouseCursor: WidgetStateMouseCursor.clickable,
                    onTap: _pickImage,
                    borderRadius: BorderRadius.circular(12),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.cloud_upload_outlined,
                          size: 48,
                          color: color.withValues(alpha: 0.6),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          tr('expenses.form.images.add'),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: color.withValues(alpha: 0.8),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          tr('expenses.form.images.upload_prompt'),
                          style: TextStyle(
                            fontSize: 12,
                            color: color.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    children: [
                      ..._resimler.asMap().entries.map((entry) {
                        final index = entry.key;
                        final path = entry.value;
                        final bool isSelected = index == _selectedAiImageIndex;

                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            mouseCursor: WidgetStateMouseCursor.clickable,
                            onTap: () {
                              setState(() {
                                _selectedAiImageIndex = index;
                              });
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              width: 120,
                              margin: const EdgeInsets.only(right: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isSelected
                                      ? color
                                      : Colors.grey.shade300,
                                  width: isSelected ? 2 : 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.05),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Stack(
                                children: [
                                  Positioned.fill(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Container(
                                        color: Colors.grey.shade50, // Arka plan
                                        child: Image.file(
                                          File(path),
                                          fit: BoxFit.contain, // Tam görünüm
                                          errorBuilder: (_, _, _) => Container(
                                            color: Colors.grey.shade200,
                                            child: const Icon(
                                              Icons.broken_image,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (isSelected)
                                    Positioned(
                                      left: 6,
                                      bottom: 6,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: color.withValues(alpha: 0.9),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: const Text(
                                          'AI',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                  Positioned(
                                    top: 4,
                                    right: 4,
                                    child: InkWell(
                                      mouseCursor: WidgetStateMouseCursor.clickable,
                                      onTap: () {
                                        setState(() {
                                          _resimler.removeAt(index);
                                          if (_resimler.isEmpty) {
                                            _aiExtractedData = null;
                                            _selectedAiImageIndex = 0;
                                            return;
                                          }
                                          if (_selectedAiImageIndex >=
                                              _resimler.length) {
                                            _selectedAiImageIndex =
                                                _resimler.length - 1;
                                          } else if (index <
                                              _selectedAiImageIndex) {
                                            _selectedAiImageIndex =
                                                (_selectedAiImageIndex - 1)
                                                    .clamp(
                                                      0,
                                                      _resimler.length - 1,
                                                    )
                                                    .toInt();
                                          }
                                        });
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withValues(
                                            alpha: 0.6,
                                          ),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.close,
                                          size: 16,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                      if (_resimler.length < 5)
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            mouseCursor: WidgetStateMouseCursor.clickable,
                            onTap: _pickImage,
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              width: 100,
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: color.withValues(alpha: 0.3),
                                  style: BorderStyle.solid,
                                  width: 1.5,
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.add_a_photo,
                                    color: color.withValues(alpha: 0.7),
                                    size: 28,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    tr('common.add'), // "Ekle" yerine çeviri
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: color.withValues(alpha: 0.8),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
          if (_resimler.isNotEmpty) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Analiz edilecek resim: ${_selectedAiImageIndex + 1}/${_resimler.length} (dokunup seçebilirsiniz)',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _aiScanning ? null : _handleAIScan,
              icon: _aiScanning
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.auto_awesome, size: 18),
              label: Text(
                _aiScanning
                    ? tr('expenses.ai.scanning')
                    : tr('expenses.ai.scan_button'),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade300,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_aiExtractedData != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: Colors.green.shade600,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        tr('expenses.ai.extracted_data'),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 16, color: Colors.green),
                  _buildAIDataRow(
                    tr('expenses.table.title'),
                    _aiExtractedData!['baslik']?.toString() ?? '-',
                  ),
                  _buildAIDataRow(
                    tr('expenses.ai.store'),
                    _aiExtractedData!['magaza']?.toString() ?? '-',
                  ),
                  _buildAIDataRow(
                    tr('common.date'),
                    _aiExtractedData!['tarih']?.toString() ?? '-',
                  ),
                  _buildAIDataRow(
                    tr('common.amount'),
                    '${_aiExtractedData!['tutar']} ${tr('common.currency.try')}',
                    isBold: true,
                  ),
                  if (_aiExtractedData!['kalemler'] != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      tr('expenses.ai.items'),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.green.shade800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    ...(_aiExtractedData!['kalemler'] as List).map((item) {
                      final itemDesc = item['aciklama']?.toString() ?? '';
                      final itemPrice = item['tutar']?.toString() ?? '';
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Text(
                          '• $itemDesc ($itemPrice)',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.green.shade900,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }),
                  ],
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _applyAIData,
                      icon: const Icon(Icons.download_done, size: 16),
                      label: Text(tr('expenses.ai.apply_data')),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.green.shade700,
                        side: BorderSide(color: Colors.green.shade400),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        textStyle: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.blue.shade600,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      tr('expenses.ai.helper_text'),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          Text(
            tr('expenses.form.images.limit'),
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Future<void> _pickImage() async {
    // Limit kontrolü manual yapılmalı çünkü çoklu seçimde kalan hakkı hesaplamalıyız
    if (_resimler.length >= 5) {
      if (mounted) {
        MesajYardimcisi.bilgiGoster(context, tr('expenses.form.images.limit'));
      }
      return;
    }

    try {
      final typeGroup = XTypeGroup(
        label: tr('common.images'),
        extensions: <String>['jpg', 'jpeg', 'png', 'webp', 'heic', 'heif'],
        uniformTypeIdentifiers: <String>['public.image'],
      );

      // Kullanıcıya seçtir
      final List<XFile> files = await openFiles(
        acceptedTypeGroups: <XTypeGroup>[typeGroup],
      );

      if (files.isEmpty) return;

      final bool wasEmpty = _resimler.isEmpty;

      setState(() {
        // Kalan hak kadar ekle
        final remaining = 5 - _resimler.length;
        final toAdd = files.take(remaining).map((f) => f.path).toList();
        _resimler.addAll(toAdd);

        if (_resimler.isEmpty) {
          _selectedAiImageIndex = 0;
        } else if (wasEmpty) {
          _selectedAiImageIndex = 0;
        } else if (_selectedAiImageIndex >= _resimler.length) {
          _selectedAiImageIndex = _resimler.length - 1;
        }

        if (files.length > remaining) {
          MesajYardimcisi.bilgiGoster(
            context,
            tr(
              'expenses.form.images.limit_exceeded',
            ).replaceAll('{max}', '5').replaceAll('{count}', '$remaining'),
          );
        }
      });
    } catch (e) {
      debugPrint('Resim seçme hatası: $e');
      if (mounted) {
        MesajYardimcisi.hataGoster(context, '${tr('common.error')}: $e');
      }
    }
  }

  Future<String> _saveImageToAppDir(String sourcePath) async {
    try {
      final sourceFile = File(sourcePath);
      if (!await sourceFile.exists()) {
        return sourcePath;
      } // Dosya yoksa olduğu gibi bırak (belki http url?)

      final appDir = await getApplicationDocumentsDirectory();
      final expensesDir = Directory(
        p.join(appDir.path, 'patisyov10', 'expenses_images'),
      );

      if (!await expensesDir.exists()) {
        await expensesDir.create(recursive: true);
      }

      final fileName = p.basename(sourcePath);
      // Benzersiz isim oluştur: timestamp_filename
      final newName = '${DateTime.now().millisecondsSinceEpoch}_$fileName';
      final newPath = p.join(expensesDir.path, newName);

      await sourceFile.copy(newPath);
      return newPath;
    } catch (e) {
      debugPrint('Resim kopyalama hatası: $e');
      return sourcePath; // Hata olursa eski path'i kullan
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Resimleri kalıcı klasöre taşı
      final List<String> permanentImages = [];
      for (final imgPath in _resimler) {
        // Eğer zaten expenses_images klasöründeyse kopyalama
        if (imgPath.contains('expenses_images')) {
          permanentImages.add(imgPath);
        } else {
          final newPath = await _saveImageToAppDir(imgPath);
          permanentImages.add(newPath);
        }
      }

      // _resimler listesini güncelle (State'i güncellemeye gerek yok, save işlemi bitince çıkıcaz zaten)
      // Ancak _saveImageToAppDir asenkron olduğu için yerel değişken kullanabiliriz.
      // Ama model oluştururken permanentImages kullanacağız.

      final prefs = await SharedPreferences.getInstance();
      final currentUserRaw = (prefs.getString('current_username') ?? '').trim();
      final currentUser = currentUserRaw.isNotEmpty ? currentUserRaw : 'Sistem';

      final kalemler = _giderKalemleri.map((e) {
        return GiderKalemi(
          aciklama: (e['aciklama'] as TextEditingController).text,
          tutar: FormatYardimcisi.parseDouble(
            (e['tutar'] as TextEditingController).text,
            binlik: _genelAyarlar.binlikAyiraci,
            ondalik: _genelAyarlar.ondalikAyiraci,
          ),
          not: (e['not'] as TextEditingController).text,
        );
      }).toList();

      final toplamTutar = kalemler.isNotEmpty
          ? kalemler.fold(0.0, (sum, k) => sum + k.tutar)
          : FormatYardimcisi.parseDouble(
              _tutarController.text,
              binlik: _genelAyarlar.binlikAyiraci,
              ondalik: _genelAyarlar.ondalikAyiraci,
            );

      final gider = GiderModel(
        id: widget.gider?.id ?? 0,
        kod: _kodController.text,
        baslik: _baslikController.text,
        tutar: toplamTutar,
        paraBirimi: _selectedParaBirimi,
        tarih: _selectedTarih,
        odemeDurumu: _selectedOdemeDurumu,
        kategori: _kategoriController.text,
        aciklama: _aciklamaController.text,

        resimler: permanentImages, // Güncellenmiş kalıcı yollar
        kalemler: kalemler,
        aiIslenmisMi: _aiExtractedData != null,
        aiVerileri: _aiExtractedData,
        aktifMi: _aktifMi,
        olusturmaTarihi: widget.gider?.olusturmaTarihi ?? DateTime.now(),
        guncellemeTarihi: DateTime.now(),
        kullanici: currentUser,
      );

      if (_isEditing) {
        await GiderlerVeritabaniServisi().giderGuncelle(
          gider.copyWith(id: widget.gider!.id),
          updatedBy: currentUser,
        );
      } else {
        await GiderlerVeritabaniServisi().giderEkle(
          gider,
          createdBy: currentUser,
        );
      }

      if (mounted) {
        MesajYardimcisi.basariGoster(
          context,
          _isEditing
              ? tr('common.updated_successfully')
              : tr('common.saved_successfully'),
        );

        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        MesajYardimcisi.hataGoster(context, '${tr('common.error')}: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _handleClear() {
    _formKey.currentState?.reset();
    _generateKod();
    _baslikController.clear();
    _tutarController.clear();
    _aciklamaController.clear();

    _resimler.clear();
    _selectedAiImageIndex = 0;
    _aiExtractedData = null;
    _aiScanning = false;

    // Clear items
    for (var item in _giderKalemleri) {
      (item['aciklama'] as TextEditingController).dispose();
      (item['tutar'] as TextEditingController).dispose();
      (item['not'] as TextEditingController?)?.dispose();
      (item['focus'] as FocusNode?)?.dispose();
      // focus node handling?
    }
    _giderKalemleri.clear();
    _addGiderKalemiRow(); // Default mandatory item

    setState(() {
      _kategoriController.text = 'Market';
      _selectedOdemeDurumu = 'Beklemede';
      _selectedTarih = DateTime.now();
      _aktifMi = true;
    });
  }

  Widget _buildActionButtons(ThemeData theme, {bool isCompact = false}) {
    if (isCompact) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final double maxRowWidth = constraints.maxWidth > 320
              ? 320
              : constraints.maxWidth;
          const double gap = 10;
          final double buttonWidth = (maxRowWidth - gap) / 2;

          return Align(
            alignment: Alignment.center,
            child: SizedBox(
              width: maxRowWidth,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: buttonWidth,
                    child: OutlinedButton.icon(
                      onPressed: _handleClear,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: theme.colorScheme.primary,
                        side: BorderSide(color: Colors.grey.shade300),
                        minimumSize: const Size(0, 40),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                      icon: const Icon(Icons.refresh, size: 15),
                      label: Text(
                        tr('common.clear'),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: gap),
                  SizedBox(
                    width: buttonWidth,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(0, 40),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                        visualDensity: VisualDensity.compact,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              tr('common.save'),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    }

    final clearButton = TextButton(
      onPressed: _handleClear,
      style: TextButton.styleFrom(
        foregroundColor: theme.colorScheme.primary,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.refresh, size: 20),
          const SizedBox(width: 8),
          Text(
            tr('common.clear'),
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
        ],
      ),
    );

    final saveButton = ElevatedButton(
      onPressed: _isLoading ? null : _save,
      style: ElevatedButton.styleFrom(
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        elevation: 0,
      ),
      child: _isLoading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Text(
              tr('common.save'),
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isNarrow = constraints.maxWidth < 520;

        if (isNarrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OutlinedButton.icon(
                onPressed: _handleClear,
                icon: const Icon(Icons.refresh, size: 20),
                label: Text(
                  tr('common.clear'),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: theme.colorScheme.primary,
                  side: BorderSide(
                    color: theme.colorScheme.primary.withValues(alpha: 0.3),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(width: double.infinity, child: saveButton),
            ],
          );
        }

        return Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [clearButton, const SizedBox(width: 16), saveButton],
        );
      },
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    bool isNumeric = false,
    bool isRequired = false,
    Color? color,
    String? hint,
    FocusNode? focusNode,
    ValueChanged<String>? onChanged,
    String? errorText,
    String? prefix,
    String? suffix,
    int maxLines = 1,
    bool readOnly = false,
  }) {
    final theme = Theme.of(context);
    final effectiveColor = color ?? theme.colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty)
          Text(
            isRequired ? '$label *' : label,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: effectiveColor,
              fontSize: 14,
            ),
          ),
        if (label.isNotEmpty) const SizedBox(height: 4),
        TextFormField(
          controller: controller,
          focusNode: focusNode,
          onChanged: onChanged,
          readOnly: readOnly,
          keyboardType: isNumeric
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.text,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontSize: 17,
            color: readOnly ? Colors.grey.shade600 : null,
          ),
          maxLines: maxLines,
          inputFormatters: isNumeric
              ? [
                  CurrencyInputFormatter(
                    binlik: _genelAyarlar.binlikAyiraci,
                    ondalik: _genelAyarlar.ondalikAyiraci,
                    maxDecimalDigits: _genelAyarlar.fiyatOndalik,
                  ),
                  LengthLimitingTextInputFormatter(20),
                ]
              : null,
          onFieldSubmitted: (value) {
            FocusScope.of(context).nextFocus();
          },
          textInputAction: TextInputAction.next,
          validator: (value) {
            if (isRequired && (value == null || value.isEmpty)) {
              return tr('validation.required');
            }
            return null;
          },
          decoration: InputDecoration(
            errorText: errorText,
            hintText: hint,
            prefixText: prefix,
            suffixText: suffix,
            isDense: maxLines > 1,
            filled: readOnly,
            fillColor: readOnly ? Colors.grey.shade100 : null,
            hintStyle: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.grey.withValues(alpha: 0.3),
              fontSize: 16,
            ),
            border: UnderlineInputBorder(
              borderSide: BorderSide(
                color: effectiveColor.withValues(alpha: 0.3),
              ),
            ),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(
                color: effectiveColor.withValues(alpha: 0.3),
              ),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: effectiveColor, width: 2),
            ),
            contentPadding: EdgeInsets.only(
              top: maxLines > 1 ? 8 : 10,
              bottom: maxLines > 1
                  ? 4
                  : 10, // Reduced bottom padding for multiline
              left: readOnly ? 8 : 0,
              right: readOnly ? 8 : 0,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDateField({
    required String label,
    required DateTime value,
    required VoidCallback onTap,
    Color? color,
    FocusNode? focusNode,
  }) {
    final theme = Theme.of(context);
    final effectiveColor = color ?? theme.colorScheme.primary;

    return FormField<DateTime>(
      initialValue: value,
      validator: (val) {
        if (val == null) return tr('validation.required');
        return null; // Date is mandatory
      },
      builder: (FormFieldState<DateTime> state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$label *',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: effectiveColor,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            InkWell(
              mouseCursor: WidgetStateMouseCursor.clickable,
              onTap: () {
                focusNode?.requestFocus();
                onTap();
              },
              focusNode: focusNode,
              child: InputDecorator(
                decoration: InputDecoration(
                  errorText: state.errorText,
                  suffixIcon: Icon(
                    Icons.calendar_today,
                    size: 18,
                    color: effectiveColor,
                  ),
                  border: UnderlineInputBorder(
                    borderSide: BorderSide(
                      color: effectiveColor.withValues(alpha: 0.3),
                    ),
                  ),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(
                      color: effectiveColor.withValues(alpha: 0.3),
                    ),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: effectiveColor, width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
                child: Text(
                  DateFormat('dd.MM.yyyy').format(value),
                  style: theme.textTheme.bodyLarge?.copyWith(fontSize: 17),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDropdown<T>({
    required T? value,
    required String label,
    required List<T> items,
    required ValueChanged<T?> onChanged,
    String Function(T item)? itemLabelBuilder,
    Color? color,
    FocusNode? focusNode,
  }) {
    final theme = Theme.of(context);
    final effectiveColor = color ?? theme.colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: effectiveColor,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 4),
        DropdownButtonFormField<T>(
          mouseCursor: WidgetStateMouseCursor.clickable,
          dropdownMenuItemMouseCursor: WidgetStateMouseCursor.clickable,
          focusNode: focusNode,
          initialValue: items.contains(value) ? value : null,
          onChanged: (val) {
            onChanged(val);
            FocusScope.of(context).nextFocus();
          },
          decoration: InputDecoration(
            hintStyle: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.grey.withValues(alpha: 0.3),
              fontSize: 16,
            ),
            border: UnderlineInputBorder(
              borderSide: BorderSide(
                color: effectiveColor.withValues(alpha: 0.3),
              ),
            ),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(
                color: effectiveColor.withValues(alpha: 0.3),
              ),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: effectiveColor, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
          ),
          items: items
              .map(
                (item) => DropdownMenuItem<T>(
                  value: item,
                  child: Text(
                    itemLabelBuilder?.call(item) ?? item.toString(),
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              )
              .toList(),
          icon: Icon(Icons.arrow_drop_down, color: effectiveColor),
        ),
      ],
    );
  }

  Widget _buildAIDataRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
                color: isBold ? Colors.black : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getParaBirimiSembol(String paraBirimi) {
    switch (paraBirimi) {
      case 'TRY':
        return '₺ ';
      case 'USD':
        return '\$ ';
      case 'EUR':
        return '€ ';
      case 'GBP':
        return '£ ';
      default:
        return '';
    }
  }
}
