import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';

import 'package:intl/intl.dart';
import '../../../bilesenler/tek_tarih_secici_dialog.dart';
import '../../../yardimcilar/ceviri/ceviri_servisi.dart';
import '../../../servisler/depolar_veritabani_servisi.dart';
import '../../../servisler/urunler_veritabani_servisi.dart';
import '../urunler/modeller/urun_model.dart';
import 'modeller/depo_model.dart';
import '../../../yardimcilar/mesaj_yardimcisi.dart';
import '../../../servisler/ayarlar_veritabani_servisi.dart';
import '../../ayarlar/genel_ayarlar/modeller/genel_ayarlar_model.dart';
import '../../../yardimcilar/format_yardimcisi.dart';

// Helper class for shipment items
class ShipmentItem {
  final String code;
  final String name;
  final String unit;
  final double quantity;
  final double? unitCost;

  ShipmentItem({
    required this.code,
    required this.name,
    required this.unit,
    required this.quantity,
    this.unitCost,
    this.devices,
  });

  final List<dynamic>? devices;
}

class SevkiyatOlusturSayfasi extends StatefulWidget {
  final List<DepoModel> depolar;
  final DepoModel? varsayilanDepo;
  final int? editingShipmentId;
  final Map<String, dynamic>? initialData;

  const SevkiyatOlusturSayfasi({
    super.key,
    required this.depolar,
    this.varsayilanDepo,
    this.editingShipmentId,
    this.initialData,
  });

  @override
  State<SevkiyatOlusturSayfasi> createState() => _SevkiyatOlusturSayfasiState();
}

class _SevkiyatOlusturSayfasiState extends State<SevkiyatOlusturSayfasi> {
  final _formKey = GlobalKey<FormState>();
  final _itemFormKey = GlobalKey<FormState>();

  // Header Controllers
  int? _selectedSourceWarehouseId;
  int? _selectedDestWarehouseId;
  final _dateController = TextEditingController();
  final _descriptionController = TextEditingController();
  DateTime _selectedDate = DateTime.now();

  // Product Entry Controllers
  final _productCodeController = TextEditingController();
  final _productNameController = TextEditingController();
  final _productUnitController = TextEditingController();
  final _quantityController = TextEditingController();

  // Inline Editing State
  int? _editingIndex;
  String? _editingField; // 'quantity'

  // State Data
  final List<ShipmentItem> _tempItems = [];
  final Set<int> _selectedItemIndices = {};
  bool _isLoading = false;
  List<DepoModel> _allWarehouses = [];
  bool _isLoadingWarehouses = true;

  // Focus helpers
  final _quantityFocusNode = FocusNode();
  final _productCodeFocusNode = FocusNode();
  final _productNameFocusNode = FocusNode();
  Timer? _searchDebounce;

  // Style Constants from DepoEkleDialog & Project Theme
  static const Color _primaryColor = Color(0xFF2C3E50);
  static const Color _labelColor = Color(0xFF4A4A4A);
  static const Color _textColor = Color(0xFF202124);
  static const Color _hintColor = Color(0xFFBDC1C6);
  static const Color _borderColor = Color(0xFFE0E0E0);

  // No longer using text controllers for warehouses as we switch to Dropdown
  Timer? _debounce;
  GenelAyarlarModel _genelAyarlar = GenelAyarlarModel();

  @override
  void initState() {
    super.initState();
    _dateController.text = DateFormat('dd.MM.yyyy').format(_selectedDate);
    _loadSettings();
    _attachQuantityFormatter();
    _loadWarehouses();
  }

  Future<void> _loadSettings() async {
    try {
      final settings = await AyarlarVeritabaniServisi().genelAyarlariGetir();
      if (mounted) {
        setState(() {
          _genelAyarlar = settings;
        });
      }
    } catch (e) {
      debugPrint('Ayarlar yüklenirken hata: $e');
    }
  }

  void _attachQuantityFormatter() {
    _quantityFocusNode.addListener(() {
      if (!_quantityFocusNode.hasFocus) {
        final text = _quantityController.text.trim();
        if (text.isEmpty) return;

        final value = FormatYardimcisi.parseDouble(
          text,
          binlik: _genelAyarlar.binlikAyiraci,
          ondalik: _genelAyarlar.ondalikAyiraci,
        );

        final formatted = FormatYardimcisi.sayiFormatla(
          value,
          binlik: _genelAyarlar.binlikAyiraci,
          ondalik: _genelAyarlar.ondalikAyiraci,
          decimalDigits: _genelAyarlar.miktarOndalik,
        );

        _quantityController
          ..text = formatted
          ..selection = TextSelection.collapsed(offset: formatted.length);
      }
    });
  }

  Future<void> _loadWarehouses() async {
    try {
      final warehouses = await DepolarVeritabaniServisi().tumDepolariGetir();
      if (mounted) {
        setState(() {
          _allWarehouses = warehouses;
          _isLoadingWarehouses = false;

          // Set defaults logic
          if (widget.initialData != null) {
            final data = widget.initialData!;
            _selectedSourceWarehouseId = data['source_warehouse_id'];
            _selectedDestWarehouseId = data['dest_warehouse_id'];

            if (data['date'] != null) {
              if (data['date'] is DateTime) {
                _selectedDate = data['date'];
              } else {
                _selectedDate =
                    DateTime.tryParse(data['date'].toString()) ??
                    DateTime.now();
              }
              _dateController.text = DateFormat(
                'dd.MM.yyyy',
              ).format(_selectedDate);
            }

            _descriptionController.text = data['description']?.toString() ?? '';

            if (data['items'] != null) {
              final itemsList = (data['items'] as List).map((i) {
                return ShipmentItem(
                  code: i['code'],
                  name: i['name'],
                  unit: i['unit'],
                  quantity: (i['quantity'] as num).toDouble(),
                  unitCost: i['unitCost'] != null
                      ? (i['unitCost'] as num).toDouble()
                      : null,
                );
              }).toList();

              _tempItems.clear();
              _tempItems.addAll(itemsList);
            }
          } else if (_selectedSourceWarehouseId == null) {
            // Only set defaults if not editing and not already set
            if (widget.varsayilanDepo != null) {
              _selectedSourceWarehouseId = widget.varsayilanDepo!.id;
            } else if (_allWarehouses.isNotEmpty) {
              _selectedSourceWarehouseId = _allWarehouses.first.id;
            }

            if (_allWarehouses.length > 1) {
              final dest = _allWarehouses.firstWhere(
                (d) => d.id != _selectedSourceWarehouseId,
                orElse: () => _allWarehouses.last,
              );
              _selectedDestWarehouseId = dest.id;
            }
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingWarehouses = false);
        MesajYardimcisi.hataGoster(context, tr('common.error'));
      }
    }
  }

  @override
  void dispose() {
    _dateController.dispose();
    _descriptionController.dispose();
    _productCodeController.dispose();
    _productNameController.dispose();
    _productUnitController.dispose();
    _quantityController.dispose();
    _quantityFocusNode.dispose();
    _productCodeFocusNode.dispose();
    _productNameFocusNode.dispose();
    _searchDebounce?.cancel();
    _debounce?.cancel();
    super.dispose();
  }

  void _fillProductFields(UrunModel product) {
    setState(() {
      _productCodeController.text = product.kod;
      _productNameController.text = product.ad;
      _productUnitController.text = product.birim;
      _quantityFocusNode.requestFocus();
    });
  }

  // ... (rest of the file)

  Widget _buildGeneralInfoFields() {
    return Column(
      children: [
        if (_isLoadingWarehouses)
          const Center(child: LinearProgressIndicator())
        else ...[
          _buildWarehouseDropdown(
            label: tr('shipment.form.source'),
            value: _selectedSourceWarehouseId,
            icon: Icons.upload_rounded,
            onChanged: (val) =>
                setState(() => _selectedSourceWarehouseId = val),
            isRequired: true,
          ),
          const SizedBox(height: 24),
          _buildWarehouseDropdown(
            label: tr('shipment.form.destination'),
            value: _selectedDestWarehouseId,
            icon: Icons.download_rounded,
            onChanged: (val) => setState(() => _selectedDestWarehouseId = val),
            isRequired: true,
          ),
        ],
        const SizedBox(height: 24),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: _buildStyledTextField(
                      controller: _dateController,
                      label: tr('shipment.field.date'),
                      icon: Icons.calendar_today_outlined,
                      readOnly: true,
                      onTap: () => _selectDate(context),
                    ),
                  ),
                  if (_dateController.text.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 24),
                      child: IconButton(
                        icon: const Icon(
                          Icons.clear,
                          size: 20,
                          color: Colors.red,
                        ),
                        onPressed: () {
                          setState(() {
                            _dateController.clear();
                            _selectedDate = DateTime.now();
                          });
                        },
                        tooltip: tr('common.clear'),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: _buildStyledTextField(
                controller: _descriptionController,
                label: tr('shipment.field.description'),
                icon: Icons.description_outlined,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildWarehouseDropdown({
    required String label,
    required int? value,
    required ValueChanged<int?> onChanged,
    required IconData icon,
    bool isRequired = false,
  }) {
    // Dropdown items
    final items = _allWarehouses.map((depo) {
      return DropdownMenuItem<int>(
        value: depo.id,
        child: Text(
          depo.ad,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: _textColor,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      );
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: _labelColor,
              ),
            ),
            if (isRequired)
              const Text(
                ' *',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<int>(
          key: ValueKey(value),
          initialValue: value,
          items: items,
          onChanged: onChanged,
          icon: const Icon(Icons.arrow_drop_down, color: _hintColor),
          isExpanded: true,
          hint: Text(
            tr('common.select'),
            style: const TextStyle(
              color: _hintColor,
              fontSize: 16,
              fontWeight: FontWeight.w400,
            ),
          ),
          dropdownColor: Colors.white,
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
            prefixIcon: Icon(icon, size: 20, color: _hintColor),
            enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: _borderColor),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: _primaryColor, width: 2),
            ),
            errorBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.red),
            ),
          ),
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: _textColor,
          ),
        ),
      ],
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDialog<DateTime>(
      context: context,
      builder: (context) => TekTarihSeciciDialog(
        initialDate: _selectedDate,
        title: tr('shipment.field.date'),
      ),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _dateController.text = DateFormat('dd.MM.yyyy').format(picked);
      });
    }
  }

  // Professional, Modern, Fast Product Search Modal
  Future<void> _openProductSearchModal() async {
    // Mod B implementation: Dialog style matching DepoEkleDialog
    final UrunModel? selected = await showDialog<UrunModel>(
      context: context,
      builder: (context) =>
          _ProductSearchDialog(sourceWarehouseId: _selectedSourceWarehouseId),
    );

    if (selected != null) {
      setState(() {
        _productCodeController.text = selected.kod;
        _productNameController.text = selected.ad;
        _productUnitController.text = selected.birim;
        _quantityFocusNode.requestFocus();
      });
    }
  }

  // Legacy fast find method (kept for checking code validity if typed manually)
  Future<void> _findProduct() async {
    // If empty, open modal!
    if (_productCodeController.text.isEmpty) {
      _openProductSearchModal();
      return;
    }

    // ... existing logic but optimized ...
    // Since DepolarVeritabaniServisi doesn't have urunAra, switch to UrunlerVeritabaniServisi
    try {
      setState(() => _isLoading = true);
      final results = await UrunlerVeritabaniServisi().urunleriGetir(
        aramaTerimi: _productCodeController.text.trim(),
        sayfaBasinaKayit: 1,
      );

      if (mounted) {
        setState(() => _isLoading = false);
        if (results.isNotEmpty) {
          final p = results.first;
          _productNameController.text = p.ad;
          _productUnitController.text = p.birim;
          _quantityFocusNode.requestFocus();
        } else {
          MesajYardimcisi.hataGoster(
            context,
            tr('shipment.form.error.product_not_found'),
          );
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _addItem() async {
    if (_itemFormKey.currentState?.validate() ?? false) {
      // code ve unit değişkenleri aşağıda güncel haliyle controller'dan alındığı için
      // burada tanımlamaya gerek yok, sadece quantity parse ediliyor.
      final rawQuantityText = _quantityController.text.trim();

      double quantity =
          double.tryParse(rawQuantityText.replaceAll(',', '.')) ?? 0;

      if (_productNameController.text.trim().isEmpty) {
        await _findProduct();
        if (_productNameController.text.isEmpty) {
          // Ürün bulunamadıysa hata zaten _findProduct içinde gösterildi
          return;
        }
      }
      // Değerler güncellendi, tekrar al
      // _findProduct setState yaptığı için build tekrar çalışır ama
      // yerel değişkenler güncellenmez.
      // Ancak _tempItems.add kısmında controller.text kullanıyoruz, o yüzden sorun yok.

      // Tekrar kontrol (async işlem sonrası)
      if (_productNameController.text.isEmpty) return;

      setState(() {
        final code = _productCodeController.text.trim();
        final name = _productNameController.text.trim();
        final unit = _productUnitController.text.trim();

        final existingIndex = _tempItems.indexWhere(
          (item) => item.code == code,
        );

        if (existingIndex != -1) {
          // Update existing item
          final existingItem = _tempItems[existingIndex];
          _tempItems[existingIndex] = ShipmentItem(
            code: existingItem.code,
            name: existingItem.name,
            unit: existingItem.unit,
            quantity: existingItem.quantity + quantity,
            unitCost: existingItem.unitCost,
          );
        } else {
          // Add new item
          _tempItems.add(
            ShipmentItem(
              code: code,
              name: name,
              unit: unit,
              quantity: quantity,
            ),
          );
        }

        _productCodeController.clear();
        _productNameController.clear();
        _productUnitController.clear();
        _quantityController.clear();
        _quantityFocusNode.requestFocus(); // Keep focus for fast entry
      });
    }
  }

  void _deleteSelected() {
    setState(() {
      final indices = _selectedItemIndices.toList()
        ..sort((a, b) => b.compareTo(a));
      for (final index in indices) {
        if (index < _tempItems.length) {
          _tempItems.removeAt(index);
        }
      }
      _selectedItemIndices.clear();
    });
  }

  Future<void> _saveShipment() async {
    if (!_formKey.currentState!.validate()) return;

    if (_tempItems.isEmpty) {
      MesajYardimcisi.uyariGoster(
        context,
        tr('shipment.form.error.items_required'),
      );
      return;
    }

    if (_selectedSourceWarehouseId == null ||
        _selectedDestWarehouseId == null) {
      MesajYardimcisi.uyariGoster(
        context,
        tr('shipment.form.error.warehouses_required'),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      if (widget.editingShipmentId != null) {
        await DepolarVeritabaniServisi().sevkiyatGuncelle(
          id: widget.editingShipmentId!,
          sourceId: _selectedSourceWarehouseId,
          destId: _selectedDestWarehouseId,
          date: _selectedDate,
          description: _descriptionController.text.trim(),
          items: _tempItems,
        );
        if (!mounted) return;
        MesajYardimcisi.basariGoster(context, tr('shipment.success.update'));
      } else {
        await DepolarVeritabaniServisi().sevkiyatEkle(
          sourceId: _selectedSourceWarehouseId,
          destId: _selectedDestWarehouseId,
          date: _selectedDate,
          description: _descriptionController.text.trim(),
          items: _tempItems,
        );
        if (!mounted) return;
        MesajYardimcisi.basariGoster(context, tr('shipment.save.success'));
      }
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      MesajYardimcisi.hataGoster(context, '${tr('common.error')}: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final bool isCompact = mediaQuery.size.width < 700;
    final double pagePadding = isCompact ? 12 : 24;
    final double sectionGap = isCompact ? 16 : 24;
    final double actionVerticalPadding = isCompact ? 14 : 20;

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            Navigator.of(context).pop(),
        const SingleActivator(LogicalKeyboardKey.enter): _saveShipment,
        const SingleActivator(LogicalKeyboardKey.numpadEnter): _saveShipment,
        const SingleActivator(LogicalKeyboardKey.f3): _openProductSearchModal,
        const SingleActivator(LogicalKeyboardKey.f8): _deleteSelected,
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: const Color(0xFFF5F7FA),
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 1,
            shadowColor: Colors.black.withValues(alpha: 0.05),
            leadingWidth: isCompact ? 72 : 80,
            leading: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Color(0xFF3C4043)),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                Text(
                  tr('common.esc'),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF9AA0A6),
                  ),
                ),
              ],
            ),
            title: Text(
              widget.editingShipmentId != null
                  ? tr('shipment.edit_title')
                  : tr('shipment.title'),
              style: TextStyle(
                color: Color(0xFF202124),
                fontWeight: FontWeight.w800,
                fontSize: isCompact ? 18 : 20,
              ),
            ),
            centerTitle: false,
          ),
          body: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: _primaryColor),
                )
              : Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.all(pagePadding),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1100),
                            child: Form(
                              key: _formKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Top Section: General Info & Product Entry Side-by-Side on Wide Screens
                                  LayoutBuilder(
                                    builder: (context, constraints) {
                                      if (constraints.maxWidth > 900) {
                                        return Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              child: _buildSection(
                                                title: tr(
                                                  'products.details.general_info',
                                                ),
                                                icon:
                                                    Icons.info_outline_rounded,
                                                child:
                                                    _buildGeneralInfoFields(),
                                                compact: isCompact,
                                                padding: EdgeInsets.all(
                                                  isCompact ? 16 : 24,
                                                ),
                                              ),
                                            ),
                                            SizedBox(width: sectionGap),
                                            Expanded(
                                              child: _buildSection(
                                                title: tr(
                                                  'shipment.form.product.add',
                                                ),
                                                icon: Icons.add_box_outlined,
                                                child:
                                                    _buildProductEntryFields(),
                                                compact: isCompact,
                                                padding: EdgeInsets.all(
                                                  isCompact ? 16 : 24,
                                                ),
                                              ),
                                            ),
                                          ],
                                        );
                                      } else {
                                        return Column(
                                          children: [
                                            _buildSection(
                                              title: tr(
                                                'products.details.general_info',
                                              ),
                                              icon: Icons.info_outline_rounded,
                                              child: _buildGeneralInfoFields(),
                                              compact: isCompact,
                                              padding: EdgeInsets.all(
                                                isCompact ? 16 : 24,
                                              ),
                                            ),
                                            SizedBox(height: sectionGap),
                                            _buildSection(
                                              title: tr(
                                                'shipment.form.product.add',
                                              ),
                                              icon: Icons.add_box_outlined,
                                              child: _buildProductEntryFields(),
                                              compact: isCompact,
                                              padding: EdgeInsets.all(
                                                isCompact ? 16 : 24,
                                              ),
                                            ),
                                          ],
                                        );
                                      }
                                    },
                                  ),

                                  SizedBox(height: sectionGap),

                                  // Bottom Section: Items List
                                  _buildSection(
                                    title:
                                        '${tr('shipment.section.transaction')} (${_tempItems.length})',
                                    icon: Icons.list_alt_rounded,
                                    child: _buildItemsTable(),
                                    padding: EdgeInsets
                                        .zero, // Table needs full width
                                    compact: isCompact,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Bottom Actions
                    Container(
                      padding: isCompact
                          ? const EdgeInsets.fromLTRB(16, 12, 16, 12)
                          : EdgeInsets.all(pagePadding),
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
                          constraints: const BoxConstraints(maxWidth: 1100),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              void handleClear() {
                                _formKey.currentState!.reset();
                                _descriptionController.clear();
                                setState(() {
                                  _tempItems.clear();
                                  _selectedItemIndices.clear();
                                });
                              }

                              if (isCompact) {
                                final double maxRowWidth =
                                    constraints.maxWidth > 320
                                    ? 320
                                    : constraints.maxWidth;
                                const double gap = 10;
                                final double buttonWidth =
                                    (maxRowWidth - gap) / 2;

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
                                            onPressed: handleClear,
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: _primaryColor,
                                              side: BorderSide(
                                                color: Colors.grey.shade300,
                                              ),
                                              minimumSize: const Size(0, 40),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                  ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              visualDensity:
                                                  VisualDensity.compact,
                                            ),
                                            icon: const Icon(
                                              Icons.refresh,
                                              size: 15,
                                            ),
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
                                            onPressed: _isLoading
                                                ? null
                                                : _saveShipment,
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: _primaryColor,
                                              foregroundColor: Colors.white,
                                              minimumSize: const Size(0, 40),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                  ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              elevation: 0,
                                              visualDensity:
                                                  VisualDensity.compact,
                                            ),
                                            child: _isLoading
                                                ? const SizedBox(
                                                    width: 16,
                                                    height: 16,
                                                    child:
                                                        CircularProgressIndicator(
                                                          strokeWidth: 2,
                                                          color: Colors.white,
                                                        ),
                                                  )
                                                : Text(
                                                    tr('common.save'),
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }

                              final bool stackActions =
                                  constraints.maxWidth < 520;
                              final clearButton = TextButton(
                                onPressed: handleClear,
                                style: TextButton.styleFrom(
                                  foregroundColor: _primaryColor,
                                  padding: EdgeInsets.symmetric(
                                    horizontal: isCompact ? 18 : 24,
                                    vertical: actionVerticalPadding,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.refresh,
                                      size: isCompact ? 18 : 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      tr('common.clear'),
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: isCompact ? 14 : 15,
                                      ),
                                    ),
                                  ],
                                ),
                              );

                              final saveButton = ElevatedButton(
                                onPressed: _isLoading ? null : _saveShipment,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _primaryColor,
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.symmetric(
                                    horizontal: stackActions
                                        ? 24
                                        : (isCompact ? 30 : 40),
                                    vertical: actionVerticalPadding,
                                  ),
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
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: isCompact ? 14 : 15,
                                        ),
                                      ),
                              );

                              if (stackActions) {
                                return Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    SizedBox(
                                      width: double.infinity,
                                      child: clearButton,
                                    ),
                                    const SizedBox(height: 8),
                                    SizedBox(
                                      width: double.infinity,
                                      child: saveButton,
                                    ),
                                  ],
                                );
                              }

                              return Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  clearButton,
                                  const SizedBox(width: 12),
                                  saveButton,
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(24),
    bool compact = false,
  }) {
    final double radius = compact ? 12 : 16;
    final double iconSize = compact ? 18 : 22;
    final double headerFontSize = compact ? 15 : 17;
    final EdgeInsets headerPadding = compact
        ? const EdgeInsets.fromLTRB(16, 14, 16, 0)
        : const EdgeInsets.fromLTRB(24, 20, 24, 0);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: _borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: headerPadding,
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(compact ? 7 : 8),
                  decoration: BoxDecoration(
                    color: _primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: _primaryColor, size: iconSize),
                ),
                SizedBox(width: compact ? 12 : 16),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: headerFontSize,
                    fontWeight: FontWeight.w700,
                    color: _textColor,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: compact ? 12 : 16),
          const Divider(height: 1, color: _borderColor),
          Padding(padding: padding, child: child),
        ],
      ),
    );
  }

  Widget _buildProductEntryFields() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool compact = constraints.maxWidth < 700;
        final bool veryCompact = constraints.maxWidth < 520;

        return Form(
          key: _itemFormKey,
          child: Column(
            children: [
              if (!compact)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: _buildProductAutocompleteField(
                        controller: _productCodeController,
                        focusNode: _productCodeFocusNode,
                        label: tr('shipment.field.product_code'),
                        searchHint: tr(
                          'common.search_fields.code_name_barcode',
                        ),
                        isRequired: true,
                        isCodeField: true,
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.search),
                          onPressed: _findProduct,
                        ),
                        onExternalSubmit: _findProduct,
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      flex: 3,
                      child: _buildProductAutocompleteField(
                        controller: _productNameController,
                        focusNode: _productNameFocusNode,
                        label: tr('shipment.field.name'),
                        searchHint: tr('common.search_fields.name_code'),
                        isRequired: true,
                        isCodeField: false,
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.search),
                          onPressed: _findProduct,
                        ),
                        onExternalSubmit: _findProduct,
                      ),
                    ),
                  ],
                )
              else
                Column(
                  children: [
                    _buildProductAutocompleteField(
                      controller: _productCodeController,
                      focusNode: _productCodeFocusNode,
                      label: tr('shipment.field.product_code'),
                      searchHint: tr('common.search_fields.code_name_barcode'),
                      isRequired: true,
                      isCodeField: true,
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.search),
                        onPressed: _findProduct,
                      ),
                      onExternalSubmit: _findProduct,
                    ),
                    const SizedBox(height: 18),
                    _buildProductAutocompleteField(
                      controller: _productNameController,
                      focusNode: _productNameFocusNode,
                      label: tr('shipment.field.name'),
                      searchHint: tr('common.search_fields.name_code'),
                      isRequired: true,
                      isCodeField: false,
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.search),
                        onPressed: _findProduct,
                      ),
                      onExternalSubmit: _findProduct,
                    ),
                  ],
                ),
              const SizedBox(height: 20),
              if (!veryCompact)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _buildStyledTextField(
                        controller: _quantityController,
                        label: tr('shipment.field.quantity'),
                        isNumeric: true,
                        focusNode: _quantityFocusNode,
                        onSubmitted: (_) => _addItem(),
                        isRequired: true,
                        icon: Icons.format_list_numbered_rounded,
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: _buildStyledTextField(
                        controller: _productUnitController,
                        label: tr('shipment.field.unit'),
                        readOnly: true,
                        icon: Icons.straighten_rounded,
                      ),
                    ),
                  ],
                )
              else
                Column(
                  children: [
                    _buildStyledTextField(
                      controller: _quantityController,
                      label: tr('shipment.field.quantity'),
                      isNumeric: true,
                      focusNode: _quantityFocusNode,
                      onSubmitted: (_) => _addItem(),
                      isRequired: true,
                      icon: Icons.format_list_numbered_rounded,
                    ),
                    const SizedBox(height: 16),
                    _buildStyledTextField(
                      controller: _productUnitController,
                      label: tr('shipment.field.unit'),
                      readOnly: true,
                      icon: Icons.straighten_rounded,
                    ),
                  ],
                ),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  onPressed: _addItem,
                  icon: const Icon(Icons.add_circle_outline, size: 18),
                  label: Text(
                    compact
                        ? tr('common.add')
                        : tr('shipment.form.product.add').toUpperCase(),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: EdgeInsets.symmetric(
                      horizontal: compact ? 18 : 32,
                      vertical: compact ? 12 : 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    textStyle: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: compact ? 13 : 14,
                      letterSpacing: compact ? 0.1 : 0.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProductAutocompleteField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String label,
    required bool isRequired,
    required bool isCodeField,
    String? searchHint,
    Widget? suffixIcon,
    VoidCallback? onExternalSubmit,
  }) {
    final bool compact = MediaQuery.of(context).size.width < 700;
    final effectiveColor = isRequired
        ? Colors.red.shade700
        : _labelColor; // sevkiyat's styling

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              isRequired
                  ? 'Ürün Bul *'
                  : label, // Use direct string if changing from Key
              style: TextStyle(
                fontWeight: FontWeight.w700, // matches sevkiyat header
                color: effectiveColor,
                fontSize: compact ? 13 : 14,
              ),
            ),
            if (searchHint != null) ...[
              const SizedBox(width: 6),
              Text(
                searchHint,
                style: TextStyle(
                  fontSize: compact ? 9 : 10,
                  color: Colors.grey.shade400,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
        SizedBox(height: compact ? 8 : 10),
        LayoutBuilder(
          builder: (context, constraints) {
            return RawAutocomplete<UrunModel>(
              focusNode: focusNode,
              textEditingController: controller,
              optionsBuilder: (TextEditingValue textEditingValue) async {
                if (textEditingValue.text.isEmpty) {
                  return const Iterable<UrunModel>.empty();
                }

                if (_searchDebounce?.isActive ?? false) {
                  _searchDebounce!.cancel();
                }

                final completer = Completer<Iterable<UrunModel>>();

                _searchDebounce = Timer(
                  const Duration(milliseconds: 500),
                  () async {
                    try {
                      final results = await UrunlerVeritabaniServisi()
                          .urunleriGetir(
                            aramaTerimi: textEditingValue.text,
                            sayfaBasinaKayit: 10,
                          );
                      if (!completer.isCompleted) completer.complete(results);
                    } catch (e) {
                      if (!completer.isCompleted) completer.complete([]);
                    }
                  },
                );

                return completer.future;
              },
              displayStringForOption: (UrunModel option) =>
                  isCodeField ? option.kod : option.ad,
              onSelected: (UrunModel selection) {
                _fillProductFields(selection);
              },
              optionsViewBuilder:
                  (
                    BuildContext context,
                    AutocompleteOnSelected<UrunModel> onSelected,
                    Iterable<UrunModel> options,
                  ) {
                    return Align(
                      alignment: Alignment.topLeft,
                      child: Material(
                        elevation: 4.0,
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.white,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxHeight: 300,
                            maxWidth: constraints.maxWidth,
                          ),
                          child: ListView.separated(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shrinkWrap: true,
                            itemCount: options.length,
                            separatorBuilder: (context, index) =>
                                const Divider(height: 1),
                            itemBuilder: (BuildContext context, int index) {
                              final option = options.elementAt(index);

                              // User Request: "Ürün adı üstte, kodu altta olsun" for both fields.
                              final title = option.ad;
                              String subtitle = 'Kod: ${option.kod}';

                              final term = controller.text.toLowerCase();
                              if (option.barkod.isNotEmpty &&
                                  option.barkod.contains(term)) {
                                subtitle += ' • Barkod: ${option.barkod}';
                              }

                              // Stock styling
                              final bool hasStock = option.stok > 0;
                              final Color stockBgColor = hasStock
                                  ? const Color(0xFFE8F5E9) // Green shade
                                  : const Color(0xFFFFEBEE); // Red shade
                              final Color stockTextColor = hasStock
                                  ? const Color(0xFF2E7D32) // Green text
                                  : const Color(0xFFC62828); // Red text

                              return InkWell(
                                onTap: () => onSelected(option),
                                hoverColor: const Color(0xFFF5F7FA),
                                child: Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        title,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 15,
                                          color: Color(0xFF202124),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              subtitle,
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: Colors.grey[600],
                                                fontWeight: FontWeight.w500,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 1,
                                            ),
                                            decoration: BoxDecoration(
                                              color: stockBgColor,
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                              border: Border.all(
                                                color: stockTextColor
                                                    .withValues(alpha: 0.2),
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  hasStock
                                                      ? Icons
                                                            .check_circle_outline
                                                      : Icons.error_outline,
                                                  size: 14,
                                                  color: stockTextColor,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  '${FormatYardimcisi.sayiFormatla(option.stok)} ${option.birim}',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                    color: stockTextColor,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  },
              fieldViewBuilder:
                  (
                    BuildContext context,
                    TextEditingController textEditingController,
                    FocusNode focusNode,
                    VoidCallback onFieldSubmitted,
                  ) {
                    return SizedBox(
                      height: compact ? 46 : 52,
                      child: TextFormField(
                        controller: textEditingController,
                        focusNode: focusNode,
                        style: TextStyle(
                          fontSize: compact ? 15 : 16,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF202124),
                        ),
                        decoration: InputDecoration(
                          suffixIcon: suffixIcon,
                          prefixIcon: isCodeField
                              ? const Icon(
                                  Icons.qr_code,
                                  size: 20,
                                  color: _hintColor,
                                )
                              : const Icon(
                                  Icons.inventory_2_outlined,
                                  size: 20,
                                  color: _hintColor,
                                ),
                          hintStyle: TextStyle(
                            color: Colors.grey.withValues(alpha: 0.3),
                            fontSize: compact ? 15 : 16,
                          ),
                          border: UnderlineInputBorder(
                            borderSide: BorderSide(
                              color: isRequired
                                  ? Colors.red.withValues(alpha: 0.3)
                                  : _borderColor,
                            ),
                          ),
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(
                              color: isRequired
                                  ? Colors.red.withValues(alpha: 0.3)
                                  : _borderColor,
                            ),
                          ),
                          focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(
                              color: isRequired ? Colors.red : _primaryColor,
                              width: 2,
                            ),
                          ),
                          errorBorder: const UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.red),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 12,
                          ),
                        ),
                        onFieldSubmitted: (String value) {
                          onFieldSubmitted();
                          if (onExternalSubmit != null) {
                            onExternalSubmit();
                          }
                        },
                      ),
                    );
                  },
            );
          },
        ),
      ],
    );
  }

  Widget _buildItemsTable() {
    return Column(
      children: [
        if (_selectedItemIndices.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            color: Colors.red.shade50,
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 20, color: Colors.red.shade700),
                const SizedBox(width: 12),
                Text(
                  tr('common.delete_selected').replaceAll(
                    '{count}',
                    _selectedItemIndices.length.toString(),
                  ),
                  style: TextStyle(
                    color: Colors.red.shade700,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _deleteSelected,
                  icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                  label: Text(
                    tr('common.delete'),
                    style: const TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                ),
              ],
            ),
          ),
        if (_tempItems.isEmpty)
          Padding(
            padding: const EdgeInsets.all(48.0),
            child: Center(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.inventory_2_outlined,
                      size: 48,
                      color: _hintColor,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    tr('common.no_records_found'),
                    style: const TextStyle(
                      color: _hintColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: constraints.maxWidth),
                  child: DataTable(
                    headingRowHeight: 56,
                    dataRowMinHeight: 60,
                    dataRowMaxHeight: 60,
                    columnSpacing: 32,
                    horizontalMargin: 24,
                    headingTextStyle: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: _labelColor,
                      fontSize: 14,
                    ),
                    columns: [
                      DataColumn(label: Text(tr('shipment.field.code'))),
                      DataColumn(label: Text(tr('shipment.field.name'))),
                      DataColumn(
                        label: Text(
                          tr('shipment.field.quantity'),
                          textAlign: TextAlign.right,
                        ),
                        numeric: true,
                      ),
                      DataColumn(label: Text(tr('shipment.field.unit'))),
                    ],
                    rows: List.generate(_tempItems.length, (index) {
                      final item = _tempItems[index];
                      final isSelected = _selectedItemIndices.contains(index);
                      return DataRow(
                        selected: isSelected,
                        onSelectChanged: (val) {
                          setState(() {
                            if (val == true) {
                              _selectedItemIndices.add(index);
                            } else {
                              _selectedItemIndices.remove(index);
                            }
                          });
                        },
                        cells: [
                          DataCell(
                            Text(
                              item.code,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: _textColor,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          DataCell(
                            Text(
                              item.name,
                              style: const TextStyle(
                                color: _textColor,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          DataCell(
                            Align(
                              alignment: Alignment.centerRight,
                              child: _buildEditableCell(
                                index: index,
                                field: 'quantity',
                                value: item.quantity,
                                onSubmitted: (val) {
                                  setState(() {
                                    _tempItems[index] = ShipmentItem(
                                      code: item.code,
                                      name: item.name,
                                      unit: item.unit,
                                      quantity: val,
                                      unitCost: item.unitCost,
                                    );
                                  });
                                },
                              ),
                            ),
                          ),
                          DataCell(
                            Text(
                              item.unit,
                              style: const TextStyle(
                                color: _textColor,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ],
                      );
                    }),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildEditableCell({
    required int index,
    required String field,
    required double value,
    required void Function(double) onSubmitted,
    String prefix = '',
  }) {
    final isEditing = _editingIndex == index && _editingField == field;

    int decimals = 2;
    // shipment creation also has quantity that needs general settings
    if (field == 'quantity') {
      decimals = _genelAyarlar.miktarOndalik;
    }

    if (isEditing) {
      return _InlineNumberEditor(
        value: value,
        binlik: _genelAyarlar.binlikAyiraci,
        ondalik: _genelAyarlar.ondalikAyiraci,
        decimalDigits: decimals,
        onSubmitted: (val) {
          onSubmitted(val);
          setState(() {
            _editingIndex = null;
            _editingField = null;
          });
        },
      );
    }

    return InkWell(
      onTap: () {
        setState(() {
          _editingIndex = index;
          _editingField = field;
        });
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.edit, size: 12, color: Colors.grey.withValues(alpha: 0.5)),
          const SizedBox(width: 4),
          Text(
            '$prefix${FormatYardimcisi.sayiFormatla(value, binlik: _genelAyarlar.binlikAyiraci, ondalik: _genelAyarlar.ondalikAyiraci, decimalDigits: _genelAyarlar.miktarOndalik)}',
            style: const TextStyle(
              fontSize: 15, // Matched previous cell style
              fontWeight: FontWeight.w700,
              color: _textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStyledTextField({
    required TextEditingController controller,
    required String label,
    IconData? icon,
    bool isNumeric = false,
    bool readOnly = false,
    bool autoFocus = false,
    bool isRequired = false,
    Widget? suffix,
    FocusNode? focusNode,
    VoidCallback? onTap,
    ValueChanged<String>? onSubmitted,
  }) {
    final bool compact = MediaQuery.of(context).size.width < 700;
    final labelColor = isRequired ? Colors.red : _labelColor;
    final borderColor = isRequired ? Colors.red : _borderColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: compact ? 13 : 14,
                fontWeight: FontWeight.w700,
                color: labelColor,
              ),
            ),
            if (isRequired)
              const Text(
                ' *',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
        SizedBox(height: compact ? 8 : 10),
        SizedBox(
          height: compact ? 46 : 52,
          child: MouseRegion(
            cursor: onTap != null
                ? SystemMouseCursors.click
                : SystemMouseCursors.basic,
            child: TextFormField(
              controller: controller,
              focusNode: focusNode,
              autofocus: autoFocus,
              readOnly: readOnly,
              onTap: onTap,
              onFieldSubmitted: onSubmitted,
              keyboardType: isNumeric
                  ? const TextInputType.numberWithOptions(decimal: true)
                  : TextInputType.text,
              style: TextStyle(
                fontSize: compact ? 15 : 16,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF202124),
              ),
              decoration: InputDecoration(
                prefixIcon: icon != null
                    ? Icon(icon, size: 20, color: _hintColor)
                    : null,
                suffixIcon: suffix,
                contentPadding: EdgeInsets.symmetric(
                  vertical: compact ? 12 : 14,
                  horizontal: 12,
                ),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: borderColor),
                ),
                focusedBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: _primaryColor, width: 2),
                ),
                errorBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.red),
                ),
                focusedErrorBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.red, width: 2),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// --- PROFESSIONAL PRODUCT SEARCH DIALOG (Matching DepoEkleDialog) ---
class _ProductSearchDialog extends StatefulWidget {
  final int? sourceWarehouseId;

  const _ProductSearchDialog({this.sourceWarehouseId});

  @override
  State<_ProductSearchDialog> createState() => _ProductSearchDialogState();
}

class _InlineNumberEditor extends StatefulWidget {
  final double value;
  final void Function(double) onSubmitted;
  final String binlik;
  final String ondalik;
  final int decimalDigits;

  const _InlineNumberEditor({
    required this.value,
    required this.onSubmitted,
    required this.binlik,
    required this.ondalik,
    required this.decimalDigits,
  });

  @override
  State<_InlineNumberEditor> createState() => _InlineNumberEditorState();
}

class _InlineNumberEditorState extends State<_InlineNumberEditor> {
  late TextEditingController _controller;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: FormatYardimcisi.sayiFormatlaOndalikli(
        widget.value,
        binlik: widget.binlik,
        ondalik: widget.ondalik,
        decimalDigits: widget.decimalDigits,
      ),
    );
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChanged);
    _focusNode.requestFocus();
  }

  void _onFocusChanged() {
    if (!_focusNode.hasFocus) {
      _save();
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    // Unfocus to prevent "Enter" from bubbling to DataTable row selection
    FocusScope.of(context).unfocus();

    final newValue = FormatYardimcisi.parseDouble(
      _controller.text,
      binlik: widget.binlik,
      ondalik: widget.ondalik,
    );
    widget.onSubmitted(newValue);
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF2C3E50);
    return Focus(
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.enter ||
                event.logicalKey == LogicalKeyboardKey.numpadEnter)) {
          _save();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: SizedBox(
        width: 80,
        height: 40,
        child: TextFormField(
          controller: _controller,
          focusNode: _focusNode,
          // CRITICAL: Disable default "Done/Next" action to prevent bubbling
          textInputAction: TextInputAction.none,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textAlign: TextAlign.right,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: primaryColor,
          ),
          decoration: const InputDecoration(
            isDense: true,
            contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            border: UnderlineInputBorder(
              borderSide: BorderSide(color: primaryColor),
            ),
          ),
          inputFormatters: [
            CurrencyInputFormatter(
              // Using generic formatter but passed quantity decimal digits
              binlik: widget.binlik,
              ondalik: widget.ondalik,
              maxDecimalDigits: widget.decimalDigits,
            ),
            LengthLimitingTextInputFormatter(20),
          ],
          onTapOutside: (_) => _save(),
          // onFieldSubmitted is still useful for some soft keyboards, but
          // key event handler above takes precedence for hardware Enter.
          onFieldSubmitted: (_) => _save(),
        ),
      ),
    );
  }
}

class _ProductSearchDialogState extends State<_ProductSearchDialog> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<UrunModel> _products = [];
  bool _isLoading = false;
  Timer? _debounce;
  static const Color _primaryColor = Color(0xFF2C3E50);

  @override
  void initState() {
    super.initState();
    // Auto-search initially
    _searchProducts('');
    // Auto-focus after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _searchProducts(query);
    });
  }

  Future<void> _searchProducts(String query) async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final results = await UrunlerVeritabaniServisi().urunleriGetir(
        aramaTerimi: query,
        sayfaBasinaKayit: 50,
        sortAscending: true,
        sortBy: 'ad',
        aktifMi: true, // Only active products
        depoIds: widget.sourceWarehouseId != null
            ? [widget.sourceWarehouseId!]
            : null, // Filter by source warehouse
      );
      if (mounted) {
        setState(() {
          _products = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const double dialogRadius = 14;

    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(dialogRadius),
      ),
      child: Container(
        width: 720,
        constraints: const BoxConstraints(maxHeight: 680),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(dialogRadius),
        ),
        padding: const EdgeInsets.fromLTRB(28, 24, 28, 22),
        child: Column(
          children: [
            // Header: Title + ESC + Close Button
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr(
                          'shipment.form.product.search_title',
                        ), // Need key or use 'Ürün Bul' fallback
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF202124),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        tr('shipment.form.product.search_subtitle'),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF606368),
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      tr('common.esc'),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF9AA0A6),
                      ),
                    ),
                    const SizedBox(width: 8),
                    MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                        icon: const Icon(
                          Icons.close,
                          size: 22,
                          color: Color(0xFF3C4043),
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                        tooltip: tr('common.close'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Search Input (Underline Style like DepoEkleDialog)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr('common.search'),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF4A4A4A), // _labelColor
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  onChanged: _onSearchChanged,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF202124),
                  ),
                  decoration: InputDecoration(
                    hintText: tr('products.search_placeholder'),
                    prefixIcon: const Icon(
                      Icons.search,
                      size: 20,
                      color: Color(0xFFBDC1C6),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    enabledBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFFE0E0E0)),
                    ),
                    focusedBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(color: _primaryColor, width: 2),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Product List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _products.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.inventory_2_outlined,
                            size: 48,
                            color: Color(0xFFE0E0E0),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            tr('products.no_products_found'),
                            style: const TextStyle(
                              fontSize: 16,
                              color: Color(0xFF606368),
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: EdgeInsets.zero,
                      itemCount: _products.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1, color: Color(0xFFEEEEEE)),
                      itemBuilder: (context, index) {
                        final product = _products[index];
                        return InkWell(
                          onTap: () => Navigator.pop(context, product),
                          hoverColor: const Color(0xFFF5F7FA),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 12,
                              horizontal: 8,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE3F2FD),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.inventory_2,
                                    color: _primaryColor,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        product.ad,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF202124),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        product.kod,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: Color(0xFF606368),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Stok Göstergesi (Yeni Özellik)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  margin: const EdgeInsets.only(right: 8),
                                  decoration: BoxDecoration(
                                    color: product.stok > 0
                                        ? const Color(0xFFE6F4EA)
                                        : const Color(0xFFFCE8E6),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '${product.stok.toStringAsFixed(0)} ${product.birim}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: product.stok > 0
                                          ? const Color(0xFF1E7E34)
                                          : const Color(0xFFC5221F),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(
                                  Icons.chevron_right,
                                  size: 20,
                                  color: Color(0xFFBDC1C6),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
