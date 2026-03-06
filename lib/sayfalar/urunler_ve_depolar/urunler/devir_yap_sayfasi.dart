import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../yardimcilar/ceviri/ceviri_servisi.dart';
import '../../../yardimcilar/mesaj_yardimcisi.dart';
import '../../../yardimcilar/format_yardimcisi.dart';

import 'modeller/urun_model.dart';
import 'modeller/cihaz_model.dart';
import '../depolar/modeller/depo_model.dart';
import '../../../servisler/depolar_veritabani_servisi.dart';
import '../../../servisler/ayarlar_veritabani_servisi.dart';
import '../../ayarlar/genel_ayarlar/modeller/genel_ayarlar_model.dart';
import '../depolar/sevkiyat_olustur_sayfasi.dart'; // For ShipmentItem
import '../../../bilesenler/akilli_aciklama_input.dart';
import '../../../bilesenler/tek_tarih_secici_dialog.dart';

class DevirYapSayfasi extends StatefulWidget {
  final UrunModel urun;
  final int? editingShipmentId;
  final Map<String, dynamic>? initialData;

  const DevirYapSayfasi({
    super.key,
    required this.urun,
    this.editingShipmentId,
    this.initialData,
  });

  @override
  State<DevirYapSayfasi> createState() => _DevirYapSayfasiState();
}

class _DevirYapSayfasiState extends State<DevirYapSayfasi> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  GenelAyarlarModel _genelAyarlar = GenelAyarlarModel();

  // General Info Controllers
  final _productCodeController = TextEditingController();
  final _productNameController = TextEditingController();
  final _dateController = TextEditingController();

  String? _selectedTransactionType;
  int? _selectedWarehouseId;
  List<DepoModel> _warehouses = [];
  DateTime? _selectedDate;

  // Movement Details Controllers
  final _quantityController = TextEditingController();
  final _unitPriceController = TextEditingController();

  String? _selectedUnit;
  String _currency = 'TL';
  String _vatStatus = 'excluded';

  // Description Controller
  final _descriptionController = TextEditingController();

  // Devices (Cihaz Listesi)
  final List<CihazModel> _devices = [];
  String _deviceIdentityType = 'IMEI';
  String _deviceCondition = 'Sıfır';
  final _deviceColorController = TextEditingController();
  final _deviceCapacityController = TextEditingController();
  final _deviceIdentityValueController = TextEditingController();
  DateTime? _deviceWarrantyEndDate;
  bool _deviceHasBox = false;
  bool _deviceHasInvoice = false;
  bool _deviceHasOriginalCharger = false;

  late FocusNode _productCodeFocusNode;
  late FocusNode _productNameFocusNode;
  late FocusNode _quantityFocusNode;
  late FocusNode _unitPriceFocusNode;
  late FocusNode _descriptionFocusNode;

  @override
  void initState() {
    super.initState();
    _productCodeFocusNode = FocusNode();
    _productNameFocusNode = FocusNode();
    _quantityFocusNode = FocusNode();
    _unitPriceFocusNode = FocusNode();
    _descriptionFocusNode = FocusNode();

    // Pre-fill product info
    _productCodeController.text = widget.urun.kod;
    _productNameController.text = widget.urun.ad;
    _selectedUnit = widget.urun.birim;
    _selectedTransactionType = 'Girdi';

    // Set default date to today
    _selectedDate = DateTime.now();
    _dateController.text = DateFormat('dd.MM.yyyy').format(_selectedDate!);

    _loadSettings();
    _fetchWarehouses();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.editingShipmentId == null) {
        _focusFirstEmptyField();
      }
    });
  }

  Future<void> _loadSettings() async {
    try {
      final settings = await AyarlarVeritabaniServisi().genelAyarlariGetir();
      if (mounted) {
        setState(() {
          _genelAyarlar = settings;

          // Para birimini güncelle - kullanilanParaBirimleri listesinde olduğundan emin ol
          String currency = settings.varsayilanParaBirimi;
          if (!settings.kullanilanParaBirimleri.contains(currency)) {
            currency = settings.kullanilanParaBirimleri.isNotEmpty
                ? settings.kullanilanParaBirimleri.first
                : 'TRY';
          }
          _currency = currency;

          // Varsayılan KDV durumunu uygula
          _vatStatus = settings.varsayilanKdvDurumu;
        });
      }
    } catch (e) {
      debugPrint('Genel ayarlar yüklenemedi: $e');
    }
  }

  Future<void> _fetchWarehouses() async {
    try {
      final depots = await DepolarVeritabaniServisi().tumDepolariGetir();
      if (mounted) {
        setState(() {
          _warehouses = depots;
          // Eğer düzenleme modundaysak ve halihazırda seçili bir depo varsa dokunma
          // Yeni kayıtsa varsayılanı seç
          if (_selectedWarehouseId == null && _warehouses.isNotEmpty) {
            _selectedWarehouseId = _warehouses.first.id;
          }

          // Düzenleme Modu Verilerini Doldur
          if (widget.editingShipmentId != null && widget.initialData != null) {
            final data = widget.initialData!;
            final sourceId = data['source_warehouse_id'] as int?;
            final destId = data['dest_warehouse_id'] as int?;

            // Tip Belirle
            if (sourceId == null && destId != null) {
              _selectedTransactionType = 'Girdi';
              _selectedWarehouseId = destId;
            } else if (sourceId != null && destId == null) {
              _selectedTransactionType = 'Çıktı';
              _selectedWarehouseId = sourceId;
            }

            // Tarih
            if (data['date'] != null) {
              final d = data['date'] is DateTime
                  ? data['date']
                  : DateTime.tryParse(data['date'].toString());
              if (d != null) {
                _selectedDate = d;
                _dateController.text = DateFormat('dd.MM.yyyy').format(d);
              }
            }

            // Açıklama
            _descriptionController.text = data['description'] ?? '';

            // Item Detayları
            final items = data['items'] as List<dynamic>;
            // Mevcut ürün koduna ait olanı bul
            final currentItem = items.firstWhere(
              (element) => element['code'] == widget.urun.kod,
              orElse: () => items.isNotEmpty ? items.first : null,
            );

            if (currentItem != null) {
              final q = currentItem['quantity'];
              final u = currentItem['unit'];
              final c = currentItem['unitCost'];
              // final name = currentItem['name']; // İsim zaten üründen geliyor

              _quantityController.text = FormatYardimcisi.sayiFormatla(
                q,
                binlik: _genelAyarlar.binlikAyiraci,
                ondalik: _genelAyarlar.ondalikAyiraci,
                decimalDigits: _genelAyarlar.miktarOndalik,
              );
              _unitPriceController.text = FormatYardimcisi.sayiFormatla(
                c,
                binlik: _genelAyarlar.binlikAyiraci,
                ondalik: _genelAyarlar.ondalikAyiraci,
                decimalDigits: _genelAyarlar.fiyatOndalik,
              );
              if (u != null) _selectedUnit = u.toString();

              // Load Devices if present
              if (currentItem['devices'] != null) {
                final devs = currentItem['devices'] as List<dynamic>;
                _devices.clear();
                _devices.addAll(devs.map((d) => CihazModel.fromMap(d)));
              }
            }
          }
        });
      }
    } catch (e) {
      debugPrint('Error fetching warehouses: $e');
    }
  }

  void _focusFirstEmptyField() {
    if (_productCodeController.text.isEmpty) {
      _productCodeFocusNode.requestFocus();
    } else if (_productNameController.text.isEmpty) {
      _productNameFocusNode.requestFocus();
    } else if (_quantityController.text.isEmpty) {
      _quantityFocusNode.requestFocus();
    } else if (_unitPriceController.text.isEmpty) {
      _unitPriceFocusNode.requestFocus();
    }
  }

  @override
  void dispose() {
    _productCodeFocusNode.dispose();
    _productNameFocusNode.dispose();
    _quantityFocusNode.dispose();
    _unitPriceFocusNode.dispose();
    _descriptionFocusNode.dispose();

    _productCodeController.dispose();
    _productNameController.dispose();
    _dateController.dispose();
    _quantityController.dispose();
    _unitPriceController.dispose();
    _descriptionController.dispose();

    _deviceColorController.dispose();
    _deviceCapacityController.dispose();
    _deviceIdentityValueController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDialog<DateTime>(
      context: context,
      builder: (context) => TekTarihSeciciDialog(
        initialDate: _selectedDate ?? DateTime.now(),
        title: tr('products.transaction.date'),
      ),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _dateController.text = DateFormat('dd.MM.yyyy').format(picked);
      });
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedTransactionType == null) {
      MesajYardimcisi.hataGoster(context, tr('validation.required'));
      return;
    }

    setState(() => _isLoading = true);

    try {
      int? sourceId;
      int? destId;

      if (_selectedTransactionType == 'Girdi') {
        // Devir Girdi: Source is NULL, Dest is Selected Warehouse
        sourceId = null;
        destId = _selectedWarehouseId;
      } else {
        // Devir Çıktı: Source is Selected Warehouse, Dest is NULL
        sourceId = _selectedWarehouseId;
        destId = null;
      }

      final quantity = FormatYardimcisi.parseDouble(
        _quantityController.text,
        binlik: _genelAyarlar.binlikAyiraci,
        ondalik: _genelAyarlar.ondalikAyiraci,
      );
      final unitPrice = FormatYardimcisi.parseDouble(
        _unitPriceController.text,
        binlik: _genelAyarlar.binlikAyiraci,
        ondalik: _genelAyarlar.ondalikAyiraci,
      );

      final item = ShipmentItem(
        code: widget.urun.kod,
        name: widget.urun.ad,
        unit: _selectedUnit ?? widget.urun.birim,
        quantity: quantity,
        unitCost: unitPrice,
        devices: _devices.map((d) => d.toMap()).toList(),
      );

      final prefs = await SharedPreferences.getInstance();
      final currentUser = prefs.getString('current_username') ?? 'Sistem';

      if (widget.editingShipmentId != null) {
        // GÜNCELLEME
        await DepolarVeritabaniServisi().sevkiyatGuncelle(
          id: widget.editingShipmentId!,
          sourceId: sourceId,
          destId: destId,
          date: _selectedDate!,
          description: _descriptionController.text,
          items: [item],
          createdBy: currentUser,
        );
      } else {
        // YENİ EKLEME
        await DepolarVeritabaniServisi().sevkiyatEkle(
          sourceId: sourceId,
          destId: destId,
          date: _selectedDate!,
          description: _descriptionController.text,
          items: [item],
          createdBy: currentUser,
        );
      }

      if (!mounted) return;

      MesajYardimcisi.basariGoster(context, tr('common.saved_successfully'));

      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      MesajYardimcisi.hataGoster(context, '${tr('common.error')}: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            Navigator.of(context).pop(),
        const SingleActivator(LogicalKeyboardKey.enter): () {
          if (!_isLoading) _handleSave();
        },
        const SingleActivator(LogicalKeyboardKey.numpadEnter): () {
          if (!_isLoading) _handleSave();
        },
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            leading: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(
                    Icons.arrow_back,
                    color: theme.colorScheme.onSurface,
                  ),
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
              widget.editingShipmentId != null
                  ? tr('products.actions.transfer_edit')
                  : tr('products.actions.transfer'),
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 21,
              ),
            ),
            centerTitle: false,
          ),
          body: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 850),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildHeader(theme),
                            const SizedBox(height: 32),
                            _buildSection(
                              theme,
                              title: tr(
                                'products.form.section.general',
                              ), // General Info
                              child: _buildGeneralInfoSection(theme),
                              icon: Icons.info_rounded,
                              color: Colors.blue.shade700,
                            ),
                            const SizedBox(height: 24),
                            _buildSection(
                              theme,
                              title: tr(
                                'products.detail.transactions',
                              ), // Movement Details
                              child: _buildMovementDetailsSection(theme),
                              icon: Icons.swap_horiz_rounded,
                              color: Colors.orange.shade700,
                            ),
                            const SizedBox(height: 24),
                            // Device List Section
                            if (_genelAyarlar.cihazListesiModuluAktif)
                              _buildDeviceListSection(theme),
                            const SizedBox(height: 24),
                            _buildSection(
                              theme,
                              title: tr(
                                'shipment.field.description',
                              ), // Description
                              child: _buildDescriptionSection(theme),
                              icon: Icons.description_rounded,
                              color: Colors.teal.shade700,
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
                padding: const EdgeInsets.all(16.0),
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
                    constraints: const BoxConstraints(maxWidth: 850),
                    child: _buildActionButtons(theme),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
            Icons.swap_horiz_rounded,
            color: theme.colorScheme.primary,
            size: 28,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.editingShipmentId != null
                    ? tr('products.actions.transfer_edit')
                    : tr('products.actions.transfer'),
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                  fontSize: 23,
                ),
              ),
              Text(
                tr(
                  'shipment.subtitle',
                ), // "Manage product input/output operations here."
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  fontSize: 16,
                ),
              ),
            ],
          ),
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
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                    fontSize: 21,
                  ),
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
    const requiredColor = Colors.red;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 600;
        return Column(
          children: [
            _buildRow(isWide, [
              _buildTextField(
                controller: _productCodeController,
                label: tr('products.form.code.label'),
                hint: tr('products.form.code.hint'),
                isRequired: true,
                color: requiredColor,
                focusNode: _productCodeFocusNode,
                readOnly: true, // Read-only
              ),
              _buildTextField(
                controller: _productNameController,
                label: tr('products.form.name.label'),
                hint: tr('products.form.name.hint'),
                isRequired: true,
                color: requiredColor,
                focusNode: _productNameFocusNode,
                readOnly: true, // Read-only
              ),
            ]),
            const SizedBox(height: 16),
            _buildRow(isWide, [
              _buildDropdown(
                value: _selectedTransactionType,
                label: tr('products.transaction.type'),
                items: ['Girdi', 'Çıktı'],
                onChanged: (val) =>
                    setState(() => _selectedTransactionType = val as String?),
                isRequired: true,
                color: requiredColor,
                itemLabels: {
                  'Girdi': tr('products.transaction.type.input'),
                  'Çıktı': tr('products.transaction.type.output'),
                },
              ),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _selectDate(context),
                      mouseCursor: SystemMouseCursors.click,
                      child: IgnorePointer(
                        child: _buildTextField(
                          controller: _dateController,
                          label: tr('products.transaction.date'),
                          hint: tr('common.placeholder.date'),
                          isRequired: true,
                          color: requiredColor,
                        ),
                      ),
                    ),
                  ),
                  if (_dateController.text.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 20),
                      child: IconButton(
                        icon: const Icon(
                          Icons.clear,
                          size: 20,
                          color: Colors.red,
                        ),
                        onPressed: () {
                          setState(() {
                            _dateController.clear();
                          });
                        },
                        tooltip: tr('common.clear'),
                      ),
                    )
                  else
                    const Padding(
                      padding: EdgeInsets.only(top: 20, right: 12),
                      child: Icon(
                        Icons.calendar_today,
                        size: 20,
                        color: Colors.grey,
                      ),
                    ),
                ],
              ),
            ]),
          ],
        );
      },
    );
  }

  Widget _buildMovementDetailsSection(ThemeData theme) {
    const requiredColor = Colors.red;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 600;
        return Column(
          children: [
            _buildRow(isWide, [
              _buildTextField(
                controller: _quantityController,
                label: tr('products.transaction.quantity'),
                isNumeric: true,
                isRequired: true,
                color: requiredColor,
                focusNode: _quantityFocusNode,
                maxDecimalDigits: _genelAyarlar.miktarOndalik,
              ),
              _buildDropdown(
                value: _selectedUnit,
                label: tr('products.form.unit.label'),
                items: ['Adet', 'Kg', 'Lt', 'M', 'Paket', 'Koli'],
                onChanged: (val) =>
                    setState(() => _selectedUnit = val as String?),
                isRequired: true,
                color: requiredColor,
              ), // Unit is usually required if quantity is
            ]),
            const SizedBox(height: 16),
            _buildPriceRow(
              controller: _unitPriceController,
              currency: _currency,
              vatStatus: _vatStatus,
              onCurrencyChanged: (val) => setState(() => _currency = val!),
              onVatStatusChanged: (val) => setState(() => _vatStatus = val!),
              color: requiredColor,
              labelOverride: tr('products.transaction.unit_price'),
              focusNode: _unitPriceFocusNode,
              isRequired: true,
            ),
            const SizedBox(height: 16),
            _buildDropdown(
              value: _selectedWarehouseId,
              label: tr('products.transaction.warehouse'),
              items: _warehouses.map((e) => e.id).toList(),
              onChanged: (val) =>
                  setState(() => _selectedWarehouseId = val as int?),
              isRequired: true,
              color: requiredColor,
              itemLabels: {for (var w in _warehouses) w.id: w.ad},
            ),
          ],
        );
      },
    );
  }

  Widget _buildDescriptionSection(ThemeData theme) {
    final color = Colors.teal.shade700;

    return AkilliAciklamaInput(
      controller: _descriptionController,
      label: tr('shipment.field.description'),
      category: 'stock_transfer_description',
      color: color,
      maxLines: 3,
      minLines: 1,
      focusNode: _descriptionFocusNode,
      defaultItems: [
        tr('smart_select.stock_transfer.desc.1'),
        tr('smart_select.stock_transfer.desc.2'),
        tr('smart_select.stock_transfer.desc.3'),
        tr('smart_select.stock_transfer.desc.4'),
        tr('smart_select.stock_transfer.desc.5'),
      ],
    );
  }

  Widget _buildActionButtons(ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        ElevatedButton(
          onPressed: _isLoading ? null : _handleSave,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFEA4335),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
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
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
        ),
      ],
    );
  }

  // Helper Widgets (Copied from UrunEkleSayfasi)

  Widget _buildDeviceListSection(ThemeData theme) {
    const color = Color(0xFFFF8C42); // Orange from image

    String identityTypeLabel(String raw) {
      switch (raw) {
        case 'IMEI':
          return tr('common.identity.imei');
        case 'Seri No':
          return tr('common.identity.serial');
        case 'Diğer':
          return tr('common.identity.other');
        default:
          return raw;
      }
    }

    String conditionLabel(String raw) {
      switch (raw) {
        case 'Sıfır':
          return tr('common.condition.new');
        case 'İkinci El':
          return tr('common.condition.used');
        case 'Yenilenmiş':
          return tr('common.condition.refurbished');
        case 'Arızalı':
          return tr('common.condition.broken');
        default:
          return raw;
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 600;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F9FA), // Off-white/slate-ish background
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.blue.shade100.withValues(alpha: 0.5),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.phone_android_rounded,
                        color: color,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        tr('products.devices.list_title'),
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      tr(
                        'products.devices.count',
                        args: {'count': _devices.length.toString()},
                      ),
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Input Grid
              _buildRow(isWide, [
                _buildDropdown(
                  value: _deviceIdentityType,
                  label: tr('products.devices.identity_type'),
                  items: ['IMEI', 'Seri No', 'Diğer'],
                  itemLabels: {
                    'IMEI': tr('common.identity.imei'),
                    'Seri No': tr('common.identity.serial'),
                    'Diğer': tr('common.identity.other'),
                  },
                  onChanged: (val) =>
                      setState(() => _deviceIdentityType = val!),
                  color: Colors.blue.shade700,
                ),
                _buildDropdown(
                  value: _deviceCondition,
                  label: tr('products.devices.condition'),
                  items: ['Sıfır', 'İkinci El', 'Yenilenmiş', 'Arızalı'],
                  itemLabels: {
                    'Sıfır': tr('common.condition.new'),
                    'İkinci El': tr('common.condition.used'),
                    'Yenilenmiş': tr('common.condition.refurbished'),
                    'Arızalı': tr('common.condition.broken'),
                  },
                  onChanged: (val) => setState(() => _deviceCondition = val!),
                  color: Colors.blue.shade700,
                ),
                _buildTextField(
                  controller: _deviceColorController,
                  label: tr('products.field.color'),
                  color: Colors.blue.shade700,
                ),
                _buildTextField(
                  controller: _deviceCapacityController,
                  label: tr('products.field.capacity'),
                  color: Colors.blue.shade700,
                ),
              ]),
              const SizedBox(height: 12),
              InkWell(
                mouseCursor: WidgetStateMouseCursor.clickable,
                onTap: _openWarrantyDatePicker,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tr('products.devices.warranty_end_date'),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue.shade700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _deviceWarrantyEndDate != null
                                ? DateFormat(
                                    'dd.MM.yyyy',
                                  ).format(_deviceWarrantyEndDate!)
                                : tr('common.select'),
                            style: const TextStyle(fontSize: 15),
                          ),
                        ],
                      ),
                      Icon(
                        Icons.calendar_today,
                        size: 16,
                        color: Colors.grey.shade600,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildGadgetToggle(
                    label: tr('common.gadget.box'),
                    value: _deviceHasBox,
                    onChanged: (val) => setState(() => _deviceHasBox = val),
                  ),
                  _buildGadgetToggle(
                    label: tr('common.gadget.invoice'),
                    value: _deviceHasInvoice,
                    onChanged: (val) => setState(() => _deviceHasInvoice = val),
                  ),
                  _buildGadgetToggle(
                    label: tr('common.gadget.charger'),
                    value: _deviceHasOriginalCharger,
                    onChanged: (val) =>
                        setState(() => _deviceHasOriginalCharger = val),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (isWide)
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        controller: _deviceIdentityValueController,
                        label: tr('products.devices.identity'),
                        color: Colors.blue.shade700,
                        onSubmitted: (_) => _addDevice(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _addDevice,
                      icon: const Icon(Icons.add, size: 18),
                      label: Text(tr('common.add')),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade50,
                        foregroundColor: Colors.blue.shade700,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: _openBulkAddDialog,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.blue.shade700,
                        side: BorderSide(color: Colors.blue.shade200),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                      ),
                      child: Text(tr('products.quick_add.bulk_add')),
                    ),
                  ],
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildTextField(
                      controller: _deviceIdentityValueController,
                      label: tr('products.devices.identity'),
                      color: Colors.blue.shade700,
                      onSubmitted: (_) => _addDevice(),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _addDevice,
                            icon: const Icon(Icons.add, size: 18),
                            label: Text(tr('common.add')),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue.shade50,
                              foregroundColor: Colors.blue.shade700,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _openBulkAddDialog,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.blue.shade700,
                              side: BorderSide(color: Colors.blue.shade200),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: Text(tr('products.quick_add.bulk_add')),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              const SizedBox(height: 16),
              if (_devices.isEmpty)
                Text(
                  tr('products.quick_add.no_device_added'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade500,
                    fontStyle: FontStyle.italic,
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _devices.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final device = _devices[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        '${identityTypeLabel(device.identityType)}: ${device.identityValue}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        '${conditionLabel(device.condition)} | ${device.color ?? "-"} | ${device.capacity ?? "-"}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: IconButton(
                        icon: const Icon(
                          Icons.remove_circle_outline,
                          color: Colors.red,
                        ),
                        onPressed: () => _removeDevice(index),
                      ),
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGadgetToggle({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return InkWell(
      mouseCursor: WidgetStateMouseCursor.clickable,
      onTap: () => onChanged(!value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: value ? Colors.blue.shade50 : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: value ? Colors.blue.shade300 : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: value ? FontWeight.bold : FontWeight.normal,
            color: value ? Colors.blue.shade700 : Colors.grey.shade700,
          ),
        ),
      ),
    );
  }

  void _addDevice() {
    final value = _deviceIdentityValueController.text.trim();
    if (value.isEmpty) return;

    if (_devices.any((d) => d.identityValue == value)) {
      MesajYardimcisi.hataGoster(context, tr('validation.exists'));
      return;
    }

    setState(() {
      _devices.add(
        CihazModel(
          id: 0,
          productId: 0,
          identityType: _deviceIdentityType,
          identityValue: value,
          condition: _deviceCondition,
          color: _deviceColorController.text.trim(),
          capacity: _deviceCapacityController.text.trim(),
          warrantyEndDate: _deviceWarrantyEndDate,
          hasBox: _deviceHasBox,
          hasInvoice: _deviceHasInvoice,
          hasOriginalCharger: _deviceHasOriginalCharger,
        ),
      );

      // Update stock quantity
      int currentStock = int.tryParse(_quantityController.text) ?? 0;
      _quantityController.text = (currentStock + 1).toString();

      _deviceIdentityValueController.clear();
      // Keep other fields for easier batch entry
    });
  }

  void _removeDevice(int index) {
    setState(() {
      _devices.removeAt(index);
      // Update stock quantity
      int currentStock = int.tryParse(_quantityController.text) ?? 0;
      if (currentStock > 0) {
        _quantityController.text = (currentStock - 1).toString();
      }
    });
  }

  Future<void> _openWarrantyDatePicker() async {
    final picked = await showDialog<DateTime>(
      context: context,
      builder: (context) => TekTarihSeciciDialog(
        initialDate: _deviceWarrantyEndDate ?? DateTime.now(),
        title: tr('products.devices.warranty_end_date'),
      ),
    );
    if (picked != null) {
      setState(() => _deviceWarrantyEndDate = picked);
    }
  }

  void _openBulkAddDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('products.quick_add.bulk_add')),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(tr('products.imei_input_hint')),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                maxLines: 10,
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: tr('products.quick_add.bulk_add_hint_example'),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF2C3E50),
            ),
            child: Text(tr('common.cancel')),
          ),
          ElevatedButton(
            onPressed: () {
              final lines = controller.text.split('\n');
              int addedCount = 0;

              for (var line in lines) {
                final val = line.trim();
                if (val.isNotEmpty &&
                    !_devices.any((d) => d.identityValue == val)) {
                  _devices.add(
                    CihazModel(
                      id: 0,
                      productId: 0,
                      identityType: _deviceIdentityType,
                      identityValue: val,
                      condition: _deviceCondition,
                      color: _deviceColorController.text.trim(),
                      capacity: _deviceCapacityController.text.trim(),
                      warrantyEndDate: _deviceWarrantyEndDate,
                      hasBox: _deviceHasBox,
                      hasInvoice: _deviceHasInvoice,
                      hasOriginalCharger: _deviceHasOriginalCharger,
                    ),
                  );
                  addedCount++;
                }
              }

              if (addedCount > 0) {
                setState(() {
                  int currentStock =
                      int.tryParse(_quantityController.text) ?? 0;
                  _quantityController.text = (currentStock + addedCount)
                      .toString();
                });
              }

              Navigator.pop(context);
            },
            child: Text(tr('common.add')),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(bool isWide, List<Widget> children) {
    if (isWide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children:
            children
                .map(
                  (c) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: c,
                    ),
                  ),
                )
                .toList()
              ..last = Expanded(child: children.last),
      );
    } else {
      return Column(
        children: children
            .map(
              (c) =>
                  Padding(padding: const EdgeInsets.only(bottom: 16), child: c),
            )
            .toList(),
      );
    }
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    bool isNumeric = false,
    bool isRequired = false,
    Color? color,
    String? hint,
    FocusNode? focusNode,
    int? maxLines = 1,
    int? minLines,
    bool readOnly = false,
    int? maxDecimalDigits,
    ValueChanged<String>? onSubmitted,
  }) {
    final theme = Theme.of(context);
    final effectiveColor = color ?? theme.colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isRequired ? '$label *' : label,
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: effectiveColor,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 4),
        TextFormField(
          controller: controller,
          focusNode: focusNode,
          readOnly: readOnly,
          onFieldSubmitted: onSubmitted,
          keyboardType: isNumeric
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.text,
          maxLines: maxLines,
          minLines: minLines,
          style: theme.textTheme.bodyLarge?.copyWith(fontSize: 17),
          inputFormatters: isNumeric
              ? [
                  CurrencyInputFormatter(
                    binlik: _genelAyarlar.binlikAyiraci,
                    ondalik: _genelAyarlar.ondalikAyiraci,
                    maxDecimalDigits: maxDecimalDigits,
                  ),
                  LengthLimitingTextInputFormatter(20),
                ]
              : null,
          validator: (value) {
            if (isRequired && (value == null || value.isEmpty)) {
              return tr('validation.required');
            }
            return null;
          },
          decoration: InputDecoration(
            hintText: hint,
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
            isDense: true,
            contentPadding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown({
    required dynamic value,
    required String label,
    required List<dynamic> items,
    required ValueChanged<dynamic> onChanged,
    bool isRequired = false,
    String? hint,
    Color? color,
    Map<dynamic, String>? itemLabels,
  }) {
    final theme = Theme.of(context);
    final effectiveColor = color ?? theme.colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isRequired ? '$label *' : label,
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: effectiveColor,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 4),
        DropdownButtonFormField<dynamic>(
          mouseCursor: WidgetStateMouseCursor.clickable,
          dropdownMenuItemMouseCursor: WidgetStateMouseCursor.clickable,
          // Changed type to dynamic
          key: ValueKey(value),
          initialValue: value,
          decoration: InputDecoration(
            hintText: hint,
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
            isDense: true,
            contentPadding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
          ),
          items: items
              .map(
                (item) => DropdownMenuItem(
                  value: item,
                  child: Text(
                    itemLabels?[item] ?? item.toString(),
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              )
              .toList(),
          onChanged: onChanged,
          icon: Icon(Icons.arrow_drop_down, color: effectiveColor),
          validator: isRequired
              ? (value) {
                  if (value == null || (value is String && value.isEmpty)) {
                    return tr('validation.required');
                  }
                  return null;
                }
              : null,
        ),
      ],
    );
  }

  Widget _buildPriceRow({
    required TextEditingController controller,
    required String currency,
    required String vatStatus,
    required ValueChanged<String?> onCurrencyChanged,
    required ValueChanged<String?> onVatStatusChanged,
    Color? color,
    String? labelOverride,
    FocusNode? focusNode,
    bool isRequired = false,
  }) {
    final vatLabels = {
      'excluded': tr('products.vat.excluded'),
      'included': tr('products.vat.included'),
    };
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 500) {
          return Column(
            children: [
              _buildTextField(
                controller: controller,
                label:
                    labelOverride ?? tr('products.form.purchase_price.label'),
                isNumeric: true,
                color: color,
                focusNode: focusNode,
                isRequired: isRequired,
                maxDecimalDigits: _genelAyarlar.fiyatOndalik,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildDropdown(
                      value:
                          _genelAyarlar.kullanilanParaBirimleri.contains(
                            currency,
                          )
                          ? currency
                          : (_genelAyarlar.kullanilanParaBirimleri.isNotEmpty
                                ? _genelAyarlar.kullanilanParaBirimleri.first
                                : 'TRY'),
                      label: tr('common.currency'),
                      items: _genelAyarlar.kullanilanParaBirimleri.isNotEmpty
                          ? _genelAyarlar.kullanilanParaBirimleri
                          : ['TRY', 'USD', 'EUR'],
                      onChanged: (val) => onCurrencyChanged(val as String?),
                      color: color,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildDropdown(
                      value: vatStatus,
                      label: tr('products.table.vat'),
                      items: ['excluded', 'included'],
                      onChanged: (val) => onVatStatusChanged(val as String?),
                      color: color,
                      itemLabels: vatLabels,
                    ),
                  ),
                ],
              ),
            ],
          );
        } else {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                flex: 2,
                child: _buildTextField(
                  controller: controller,
                  label:
                      labelOverride ?? tr('products.form.purchase_price.label'),
                  isNumeric: true,
                  color: color,
                  focusNode: focusNode,
                  isRequired: isRequired,
                  maxDecimalDigits: _genelAyarlar.fiyatOndalik,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 1,
                child: _buildDropdown(
                  value:
                      _genelAyarlar.kullanilanParaBirimleri.contains(currency)
                      ? currency
                      : (_genelAyarlar.kullanilanParaBirimleri.isNotEmpty
                            ? _genelAyarlar.kullanilanParaBirimleri.first
                            : 'TRY'),
                  label: tr('common.currency'),
                  items: _genelAyarlar.kullanilanParaBirimleri.isNotEmpty
                      ? _genelAyarlar.kullanilanParaBirimleri
                      : ['TRY', 'USD', 'EUR'],
                  onChanged: (val) => onCurrencyChanged(val as String?),
                  color: color,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 1,
                child: _buildDropdown(
                  value: vatStatus,
                  label: tr('products.table.vat'),
                  items: ['excluded', 'included'],
                  onChanged: (val) => onVatStatusChanged(val as String?),
                  color: color,
                  itemLabels: vatLabels,
                ),
              ),
            ],
          );
        }
      },
    );
  }
}
