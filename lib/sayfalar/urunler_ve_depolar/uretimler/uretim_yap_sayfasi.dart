import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../yardimcilar/ceviri/ceviri_servisi.dart';
import '../../../yardimcilar/mesaj_yardimcisi.dart';
import '../../../yardimcilar/format_yardimcisi.dart';
import '../../../servisler/uretimler_veritabani_servisi.dart';
import '../../../servisler/depolar_veritabani_servisi.dart';
import '../../../servisler/ayarlar_veritabani_servisi.dart';
import '../../ayarlar/genel_ayarlar/modeller/genel_ayarlar_model.dart';
import '../depolar/modeller/depo_model.dart';
import 'modeller/uretim_model.dart';
import '../../../bilesenler/tek_tarih_secici_dialog.dart';

class UretimYapSayfasi extends StatefulWidget {
  final UretimModel? initialModel;
  final int? editingTransactionId;
  final Map<String, dynamic>? initialData;

  const UretimYapSayfasi({
    super.key,
    this.initialModel,
    this.editingTransactionId,
    this.initialData,
  });

  @override
  State<UretimYapSayfasi> createState() => _UretimYapSayfasiState();
}

class _UretimYapSayfasiState extends State<UretimYapSayfasi> {
  final _formKey = GlobalKey<FormState>();

  // Style Constants
  static const Color _primaryColor = Color(0xFF2C3E50);
  static const Color _labelColor = Color(0xFF4A4A4A);
  static const Color _textColor = Color(0xFF202124);
  static const Color _hintColor = Color(0xFFBDC1C6);
  static const Color _borderColor = Color(0xFFE0E0E0);

  // Form alanları
  final _codeController = TextEditingController();
  final _nameController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  final _descriptionController = TextEditingController();
  final _tarihController = TextEditingController();

  // Durum
  GenelAyarlarModel _genelAyarlar = GenelAyarlarModel();
  List<DepoModel> _warehouses = [];
  int? _selectedOutputWarehouseId;
  DateTime _selectedDate = DateTime.now();
  String _productUnit = '';

  final List<_BomItem> _bomItems = [];
  bool _isLoading = true;
  bool _isSaving = false;

  // Focus helpers
  final _codeFocusNode = FocusNode();
  final _nameFocusNode = FocusNode();
  final _quantityFocusNode = FocusNode();
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    try {
      final settings = await AyarlarVeritabaniServisi().genelAyarlariGetir();
      final warehouses = await DepolarVeritabaniServisi().tumDepolariGetir();

      int? defaultWarehouseId;
      if (warehouses.isNotEmpty) {
        defaultWarehouseId = warehouses.first.id;
      }

      if (!mounted) return;
      if (!mounted) return;

      // EDIT MODE INITIALIZATION (Async logic outside setState)
      if (widget.initialModel != null) {
        _codeController.text = widget.initialModel!.kod;
        await _loadProduction(widget.initialModel!.kod);
      }

      setState(() {
        _genelAyarlar = settings;
        _warehouses = warehouses;
        _selectedOutputWarehouseId ??= defaultWarehouseId;
        _isLoading = false;

        if (widget.initialData != null) {
          final data = widget.initialData!;
          // Date
          if (data['date'] != null) {
            final d = data['date'] is DateTime
                ? data['date']
                : DateTime.tryParse(data['date'].toString());
            if (d != null) {
              _selectedDate = d;
            }
          }
          // Warehouse
          if (data['dest_warehouse_id'] != null) {
            _selectedOutputWarehouseId = data['dest_warehouse_id'] as int;
          } else if (data['source_warehouse_id'] != null) {
            _selectedOutputWarehouseId = data['source_warehouse_id'] as int;
          }

          // Description
          if (data['description'] != null) {
            _descriptionController.text = data['description'].toString();
          }

          // Quantity
          if (data['quantity'] != null) {
            _quantityController.text = data['quantity'].toString();
          } else if (data['amount'] != null) {
            final parts = data['amount'].toString().split(' ');
            if (parts.isNotEmpty) {
              _quantityController.text = parts[0];
            }
          }
        }
        _tarihController.text = DateFormat('dd.MM.yyyy').format(_selectedDate);
      });
    } catch (e) {
      debugPrint('Üretim verileri yüklenirken hata: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    _quantityController.dispose();
    _descriptionController.dispose();
    _codeFocusNode.dispose();
    _nameFocusNode.dispose();
    _quantityFocusNode.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  Future<void> _loadProduction(String code) async {
    try {
      // Üretimi bul
      final uretimler = await UretimlerVeritabaniServisi().uretimleriGetir(
        aramaTerimi: code,
        sayfaBasinaKayit: 1,
      );

      if (uretimler.isEmpty) {
        if (!mounted) return;
        setState(() {
          _nameController.clear();
          _productUnit = '';
          _bomItems.clear();
        });
        MesajYardimcisi.hataGoster(context, tr('productions.make.not_found'));
        return;
      }

      final uretim = uretimler.first;

      // Reçeteyi getir
      final recipeItems = await UretimlerVeritabaniServisi().receteGetir(
        uretim.id,
      );

      final defaultRowWarehouseId =
          _selectedOutputWarehouseId ??
          (_warehouses.isNotEmpty ? _warehouses.first.id : null);

      final items = recipeItems.map((r) {
        return _BomItem(
          code: r['product_code']?.toString() ?? '',
          name: r['product_name']?.toString() ?? '',
          unit: r['unit']?.toString() ?? '',
          baseQuantity: (r['quantity'] as num?)?.toDouble() ?? 0.0,
          warehouseId: defaultRowWarehouseId,
        );
      }).toList();

      if (!mounted) return;
      setState(() {
        _codeController.text = uretim.kod;
        _nameController.text = uretim.ad;
        _productUnit = uretim.birim;
        _bomItems
          ..clear()
          ..addAll(items);
      });
    } catch (e) {
      debugPrint('Üretim yüklenirken hata: $e');
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDialog<DateTime>(
      context: context,
      builder: (context) => TekTarihSeciciDialog(
        initialDate: _selectedDate,
        title: tr('productions.make.field.date'),
      ),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _tarihController.text = DateFormat('dd.MM.yyyy').format(picked);
      });
    }
  }

  double _parseQuantity(String text) {
    return FormatYardimcisi.parseDouble(
      text,
      binlik: _genelAyarlar.binlikAyiraci,
      ondalik: _genelAyarlar.ondalikAyiraci,
    );
  }

  String _formatQuantity(num value) {
    return FormatYardimcisi.sayiFormatla(
      value,
      binlik: _genelAyarlar.binlikAyiraci,
      ondalik: _genelAyarlar.ondalikAyiraci,
      decimalDigits: _genelAyarlar.miktarOndalik,
    );
  }

  Future<void> _handleSave() async {
    if (_isSaving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final code = _codeController.text.trim();
    if (code.isEmpty) {
      MesajYardimcisi.uyariGoster(context, tr('productions.make.enter_code'));
      return;
    }

    if (_selectedOutputWarehouseId == null) {
      MesajYardimcisi.uyariGoster(
        context,
        tr('productions.make.select_warehouse'),
      );
      return;
    }

    if (_bomItems.isEmpty) {
      MesajYardimcisi.uyariGoster(context, tr('productions.make.no_recipe'));
      return;
    }

    if (_bomItems.any((b) => b.warehouseId == null)) {
      MesajYardimcisi.uyariGoster(
        context,
        tr('productions.make.select_all_warehouses'),
      );
      return;
    }

    final quantity = _parseQuantity(_quantityController.text);
    if (quantity <= 0) {
      MesajYardimcisi.uyariGoster(
        context,
        tr('productions.make.enter_quantity'),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      // Tüketilen malzemeleri hazırla
      final consumedItemsList = <Map<String, dynamic>>[];
      for (final bom in _bomItems) {
        final consumed = bom.baseQuantity * quantity;
        if (consumed == 0) continue;
        consumedItemsList.add({
          'product_code': bom.code,
          'product_name': bom.name,
          'quantity': consumed,
          'unit': bom.unit,
          'warehouse_id': bom.warehouseId,
        });
      }

      debugPrint('🚀 Üretim Kaydetme İşlemi Başlatılıyor...');
      debugPrint(
        '📝 Parametreler: Code=$code, Qty=$quantity, Date=$_selectedDate, Warehouse=$_selectedOutputWarehouseId',
      );

      if (widget.editingTransactionId != null) {
        debugPrint('🔄 Güncelleme Modu: ID=${widget.editingTransactionId}');
        await UretimlerVeritabaniServisi().uretimHareketiGuncelle(
          widget.editingTransactionId!,
          productCode: code,
          productName: _nameController.text.trim(),
          quantity: quantity,
          unit: _productUnit,
          date: _selectedDate,
          warehouseId: _selectedOutputWarehouseId!,
          description: _descriptionController.text.trim(),
          consumedItems: consumedItemsList,
        );
      } else {
        debugPrint('✨ Yeni Kayıt Modu: uretimHareketiEkle çağrılıyor...');
        await UretimlerVeritabaniServisi().uretimHareketiEkle(
          productCode: code,
          productName: _nameController.text.trim(),
          quantity: quantity,
          unit: _productUnit,
          date: _selectedDate,
          warehouseId: _selectedOutputWarehouseId!,
          description: _descriptionController.text.trim(),
          consumedItems: consumedItemsList,
        );
        debugPrint('✅ uretimHareketiEkle tamamlandı.');
      }

      if (!mounted) return;
      MesajYardimcisi.basariGoster(context, tr('productions.make.success'));
      await Future.delayed(const Duration(milliseconds: 400));
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      debugPrint('Üretim kaydedilirken hata: $e');
      if (!mounted) return;
      MesajYardimcisi.hataGoster(context, '${tr('common.error')}: $e');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _openProductionFinder() async {
    final selected = await showDialog<UretimModel>(
      context: context,
      builder: (context) => const _ProductionSelectionDialog(),
    );

    if (selected != null) {
      setState(() {
        _codeController.text = selected.kod;
      });
      await _loadProduction(selected.kod);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final media = MediaQuery.of(context);
    final bool isMobile = media.size.width < 760;

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            Navigator.of(context).pop(),
        const SingleActivator(LogicalKeyboardKey.f3): _openProductionFinder,
        const SingleActivator(LogicalKeyboardKey.enter): () {
          if (!_isSaving) _handleSave();
        },
        const SingleActivator(LogicalKeyboardKey.numpadEnter): () {
          if (!_isSaving) _handleSave();
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
                    fontSize: 10,
                  ),
                ),
              ],
            ),
            leadingWidth: 80,
            title: Text(
              widget.editingTransactionId != null
                  ? tr('productions.transaction.edit')
                  : tr('productions.make.title'),
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            centerTitle: false,
          ),
          body: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(isMobile ? 12 : 16),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: isMobile ? double.infinity : 850,
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildHeader(theme),
                            SizedBox(height: isMobile ? 20 : 32),
                            _buildSection(
                              theme,
                              title: tr('productions.make.info_section'),
                              icon: Icons.precision_manufacturing_rounded,
                              color: Colors.blue.shade700,
                              child: _buildProductionInfoSection(theme),
                            ),
                            SizedBox(height: isMobile ? 16 : 24),
                            _buildSection(
                              theme,
                              title: tr('productions.make.bom_section'),
                              icon: Icons.list_alt_rounded,
                              color: Colors.orange.shade700,
                              child: _buildBomSection(theme),
                            ),
                            SizedBox(height: isMobile ? 20 : 40),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.all(isMobile ? 12 : 16),
                decoration: BoxDecoration(
                  color: theme.scaffoldBackgroundColor,
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
                    constraints: BoxConstraints(
                      maxWidth: isMobile ? double.infinity : 850,
                    ),
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
    final bool isMobile = MediaQuery.of(context).size.width < 760;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.all(isMobile ? 10 : 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.precision_manufacturing_rounded,
            color: theme.colorScheme.primary,
            size: isMobile ? 26 : 32,
          ),
        ),
        SizedBox(width: isMobile ? 12 : 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.editingTransactionId != null
                    ? tr('productions.transaction.edit')
                    : tr('productions.make.header_title'),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                  fontSize: isMobile ? 20 : null,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                tr('productions.make.header_subtitle'),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  fontSize: isMobile ? 13 : null,
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
    final bool isMobile = MediaQuery.of(context).size.width < 760;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isMobile ? 12 : 16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.05),
            blurRadius: isMobile ? 12 : 20,
            offset: Offset(0, isMobile ? 4 : 8),
          ),
        ],
      ),
      padding: EdgeInsets.all(isMobile ? 14 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: EdgeInsets.all(isMobile ? 8 : 10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: isMobile ? 20 : 24),
              ),
              SizedBox(width: isMobile ? 10 : 16),
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                    fontSize: isMobile ? 16 : 18,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: isMobile ? 14 : 24),
          child,
        ],
      ),
    );
  }

  Widget _buildProductionInfoSection(ThemeData theme) {
    final requiredColor = Colors.red.shade700;
    final optionalColor = Colors.blue.shade700;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 600;
        return Column(
          children: [
            _buildRow(isWide, [
              _buildProductionAutocompleteField(
                controller: _codeController,
                focusNode: _codeFocusNode,
                label: tr('productions.field.find_production'),
                isRequired: true,
                isCodeField: true,
                searchHint: 'Kod barkod veya isim ile arayın',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: _openProductionFinder,
                  color: requiredColor,
                ),
              ),
              _buildProductionAutocompleteField(
                controller: _nameController,
                focusNode: _nameFocusNode,
                label: tr('productions.field.production_name'),
                isRequired: true,
                isCodeField: false,
                searchHint: 'İsme göre arayın',
                suffixIcon: const Icon(Icons.search),
              ),
            ]),
            const SizedBox(height: 16),
            _buildRow(isWide, [
              _buildTextField(
                controller: _quantityController,
                label: tr('productions.make.field.quantity'),
                isNumeric: true,
                isRequired: true,
                focusNode: _quantityFocusNode,
                color: requiredColor,
                onChanged: (_) => setState(() {}),
                maxDecimalDigits: _genelAyarlar.miktarOndalik,
              ),
              _buildDropdown(
                value: _selectedOutputWarehouseId,
                label: tr('productions.make.field.output_warehouse'),
                items: _warehouses.map((w) => w.id).toList(),
                itemLabels: Map.fromEntries(
                  _warehouses.map((w) => MapEntry(w.id, w.ad)),
                ),
                onChanged: (val) =>
                    setState(() => _selectedOutputWarehouseId = val),
                isRequired: true,
                color: requiredColor,
              ),
            ]),
            const SizedBox(height: 16),
            _buildRow(isWide, [
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _selectDate(context),
                      mouseCursor: SystemMouseCursors.click,
                      child: IgnorePointer(
                        child: _buildTextField(
                          controller: _tarihController,
                          label: tr('productions.make.field.date'),
                          color: requiredColor,
                          isRequired: true,
                        ),
                      ),
                    ),
                  ),
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
                          _selectedDate = DateTime.now();
                          _tarihController.text = DateFormat(
                            'dd.MM.yyyy',
                          ).format(_selectedDate);
                        });
                      },
                      tooltip: tr('common.clear'),
                    ),
                  ),
                ],
              ),
              _buildTextField(
                controller: _descriptionController,
                label: tr('productions.make.field.description'),
                hint: tr('productions.make.field.description_hint'),
                color: optionalColor,
              ),
            ]),
          ],
        );
      },
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

  Widget _buildProductionAutocompleteField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String label,
    required bool isRequired,
    required bool isCodeField,
    String? searchHint,
    Widget? suffixIcon,
  }) {
    final effectiveColor = isRequired ? Colors.red.shade700 : _labelColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 2,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              isRequired && !label.endsWith('*') ? '$label *' : label,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: effectiveColor,
                fontSize: 14,
              ),
            ),
            if (searchHint != null)
              Text(
                searchHint,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey.shade400,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            return RawAutocomplete<UretimModel>(
              focusNode: focusNode,
              textEditingController: controller,
              optionsBuilder: (TextEditingValue textEditingValue) async {
                if (textEditingValue.text.isEmpty) {
                  return const Iterable<UretimModel>.empty();
                }

                if (_searchDebounce?.isActive ?? false) {
                  _searchDebounce!.cancel();
                }

                final completer = Completer<Iterable<UretimModel>>();

                _searchDebounce = Timer(
                  const Duration(milliseconds: 250),
                  () async {
                    try {
                      final results = await UretimlerVeritabaniServisi()
                          .uretimleriGetir(
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
              displayStringForOption: (UretimModel option) =>
                  isCodeField ? option.kod : option.ad,
              onSelected: (UretimModel selection) {
                // Populate fields
                setState(() {
                  _codeController.text = selection.kod;
                  // _loadProduction already handles everything given the code
                  _loadProduction(selection.kod);
                });
              },
              optionsViewBuilder:
                  (
                    BuildContext context,
                    AutocompleteOnSelected<UretimModel> onSelected,
                    Iterable<UretimModel> options,
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

                              // Use 'ad' for title, 'kod' for subtitle
                              final title = option.ad;
                              String subtitle = 'Kod: ${option.kod}';

                              final term = controller.text.toLowerCase();
                              if (option.barkod.isNotEmpty &&
                                  option.barkod.contains(term)) {
                                subtitle += ' • Barkod: ${option.barkod}';
                              }

                              // Stock styling (Production Stock)
                              final bool hasStock = option.stok > 0;
                              final Color stockBgColor = hasStock
                                  ? const Color(0xFFE8F5E9)
                                  : const Color(0xFFFFEBEE);
                              final Color stockTextColor = hasStock
                                  ? const Color(0xFF2E7D32)
                                  : const Color(0xFFC62828);

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
                      height: 52,
                      child: TextFormField(
                        controller: textEditingController,
                        focusNode: focusNode,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: _textColor,
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
                            fontSize: 16,
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
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 16,
                            horizontal: 12,
                          ),
                        ),
                      ),
                    );
                  },
            );
          },
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    bool isNumeric = false,
    bool isRequired = false,
    Color? color,
    String? hint,
    Widget? suffix,
    bool readOnly = false,
    FocusNode? focusNode,
    ValueChanged<String>? onChanged,
    int? maxDecimalDigits,
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
          onChanged: onChanged,
          keyboardType: isNumeric
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.text,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: readOnly ? Colors.grey : null,
            fontSize: 17,
          ),
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
            suffixIcon: suffix,
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
        ),
      ],
    );
  }

  Widget _buildDropdown({
    required int? value,
    required String label,
    required List<int> items,
    required ValueChanged<int?> onChanged,
    Map<int, String>? itemLabels,
    bool isRequired = false,
    Color? color,
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
        DropdownButtonFormField<int>(
          key: ValueKey(value),
          initialValue: value,
          items: items.map((item) {
            return DropdownMenuItem<int>(
              value: item,
              child: Text(
                itemLabels?[item] ?? item.toString(),
                style: theme.textTheme.bodyLarge?.copyWith(fontSize: 17),
              ),
            );
          }).toList(),
          onChanged: onChanged,
          isExpanded: true,
          icon: Icon(Icons.arrow_drop_down, color: effectiveColor),
          decoration: InputDecoration(
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
          validator: isRequired
              ? (value) {
                  if (value == null) {
                    return tr('validation.required');
                  }
                  return null;
                }
              : null,
        ),
      ],
    );
  }

  Widget _buildBomSection(ThemeData theme) {
    final color = Colors.orange.shade700;
    final factor = _parseQuantity(_quantityController.text);
    final bool isMobile = MediaQuery.of(context).size.width < 760;

    if (isMobile) {
      if (_bomItems.isEmpty) {
        return Padding(
          padding: const EdgeInsets.all(12.0),
          child: Center(
            child: Text(
              tr('productions.make.empty_bom'),
              style: TextStyle(
                color: Colors.grey.withValues(alpha: 0.6),
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        );
      }

      return Column(
        children: _bomItems.map((item) {
          final consumed = item.baseQuantity * factor;
          return _buildMobileBomCard(item, color, consumed);
        }).toList(),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: SizedBox(
            width: double.infinity,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(
                color.withValues(alpha: 0.05),
              ),
              columnSpacing: 24,
              horizontalMargin: 16,
              columns: [
                DataColumn(
                  label: Text(
                    tr('productions.make.table.code'),
                    style: TextStyle(color: color, fontWeight: FontWeight.bold),
                  ),
                ),
                DataColumn(
                  label: Text(
                    tr('productions.make.table.name'),
                    style: TextStyle(color: color, fontWeight: FontWeight.bold),
                  ),
                ),
                DataColumn(
                  label: Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      tr('productions.make.table.quantity'),
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  numeric: true,
                ),
                DataColumn(
                  label: Text(
                    tr('productions.make.table.unit'),
                    style: TextStyle(color: color, fontWeight: FontWeight.bold),
                  ),
                ),
                DataColumn(
                  label: Text(
                    tr('productions.make.table.output_warehouse'),
                    style: TextStyle(color: color, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
              rows: _bomItems.isEmpty
                  ? []
                  : _bomItems.map((item) {
                      final consumed = item.baseQuantity * factor;
                      return DataRow(
                        cells: [
                          DataCell(
                            Text(
                              item.code,
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          DataCell(
                            Text(
                              item.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 2,
                            ),
                          ),
                          DataCell(
                            Align(
                              alignment: Alignment.centerRight,
                              child: Text(
                                _formatQuantity(consumed),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                          ),
                          DataCell(
                            Text(
                              item.unit,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          DataCell(_buildWarehouseCellDropdown(item, color)),
                        ],
                      );
                    }).toList(),
            ),
          ),
        ),
        if (_bomItems.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Center(
              child: Text(
                tr('productions.make.empty_bom'),
                style: TextStyle(
                  color: Colors.grey.withValues(alpha: 0.5),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMobileBomCard(_BomItem item, Color color, double consumed) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF202124),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            item.code,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF606368),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr('productions.make.table.quantity'),
                        style: TextStyle(
                          fontSize: 10,
                          color: color.withValues(alpha: 0.9),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_formatQuantity(consumed)} ${item.unit}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF202124),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            tr('productions.make.table.output_warehouse'),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              border: Border.all(color: color.withValues(alpha: 0.25)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: _buildWarehouseCellDropdown(item, color),
          ),
        ],
      ),
    );
  }

  Widget _buildWarehouseCellDropdown(_BomItem item, Color color) {
    if (_warehouses.isEmpty) {
      return const Text('-');
    }

    final theme = Theme.of(context);
    final value =
        item.warehouseId ?? _selectedOutputWarehouseId ?? _warehouses.first.id;

    return DropdownButtonHideUnderline(
      child: DropdownButton<int>(
        value: value,
        items: _warehouses
            .map(
              (w) => DropdownMenuItem(
                value: w.id,
                child: Text(w.ad, style: theme.textTheme.bodyMedium),
              ),
            )
            .toList(),
        onChanged: (val) {
          setState(() {
            item.warehouseId = val;
          });
        },
        icon: Icon(Icons.arrow_drop_down, color: color),
      ),
    );
  }

  Widget _buildActionButtons(ThemeData theme) {
    final bool isMobile = MediaQuery.of(context).size.width < 760;

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Expanded(
          child: FilledButton(
            onPressed: _isSaving ? null : _handleSave,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFEA4335),
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 20 : 32,
                vertical: isMobile ? 14 : 16,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    tr('common.save'),
                    style: TextStyle(
                      fontSize: isMobile ? 14 : 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

class _BomItem {
  final String code;
  final String name;
  final String unit;
  final double baseQuantity;
  int? warehouseId;

  _BomItem({
    required this.code,
    required this.name,
    required this.unit,
    required this.baseQuantity,
    this.warehouseId,
  });
}

/// Üretim Seçim Dialog'u
class _ProductionSelectionDialog extends StatefulWidget {
  const _ProductionSelectionDialog();

  @override
  State<_ProductionSelectionDialog> createState() =>
      _ProductionSelectionDialogState();
}

class _ProductionSelectionDialogState
    extends State<_ProductionSelectionDialog> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<UretimModel> _productions = [];
  bool _isLoading = false;
  Timer? _debounce;
  static const Color _primaryColor = Color(0xFF2C3E50);

  @override
  void initState() {
    super.initState();
    _searchProductions('');
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
      _searchProductions(query);
    });
  }

  Future<void> _searchProductions(String query) async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final results = await UretimlerVeritabaniServisi().uretimleriGetir(
        aramaTerimi: query,
        sayfaBasinaKayit: 50,
        sortAscending: true,
        sortBy: 'ad',
        aktifMi: true,
      );
      if (mounted) {
        setState(() {
          _productions = results;
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
    final media = MediaQuery.of(context);
    final bool isMobile = media.size.width < 760;

    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 32,
        vertical: isMobile ? 16 : 24,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(dialogRadius),
      ),
      child: Container(
        width: isMobile ? double.infinity : 720,
        constraints: BoxConstraints(
          maxHeight: isMobile ? media.size.height * 0.88 : 680,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(dialogRadius),
        ),
        padding: EdgeInsets.fromLTRB(
          isMobile ? 16 : 28,
          isMobile ? 16 : 24,
          isMobile ? 16 : 28,
          isMobile ? 16 : 22,
        ),
        child: Column(
          children: [
            // Header
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr('productions.make.find_production'),
                        style: TextStyle(
                          fontSize: isMobile ? 19 : 22,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF202124),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        tr('productions.make.find_production_subtitle'),
                        maxLines: isMobile ? 3 : 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: isMobile ? 13 : 14,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF606368),
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isMobile)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(
                      tr('common.esc'),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF9AA0A6),
                      ),
                    ),
                  ),
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                    icon: Icon(
                      Icons.close,
                      size: isMobile ? 20 : 22,
                      color: const Color(0xFF3C4043),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: tr('common.close'),
                  ),
                ),
              ],
            ),
            SizedBox(height: isMobile ? 16 : 24),

            // Search Input
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr('common.search'),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF4A4A4A),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  onChanged: _onSearchChanged,
                  style: TextStyle(
                    fontSize: isMobile ? 15 : 16,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF202124),
                  ),
                  decoration: InputDecoration(
                    hintText: tr('productions.search_placeholder'),
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
            SizedBox(height: isMobile ? 14 : 20),

            // Productions List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _productions.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.precision_manufacturing_outlined,
                            size: 48,
                            color: Color(0xFFE0E0E0),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            tr('productions.no_productions_found'),
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
                      itemCount: _productions.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1, color: Color(0xFFEEEEEE)),
                      itemBuilder: (context, index) {
                        final production = _productions[index];
                        return InkWell(
                          onTap: () => Navigator.pop(context, production),
                          hoverColor: const Color(0xFFF5F7FA),
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              vertical: isMobile ? 10 : 12,
                              horizontal: isMobile ? 4 : 8,
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: isMobile ? 36 : 40,
                                  height: isMobile ? 36 : 40,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE3F2FD),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.precision_manufacturing,
                                    color: _primaryColor,
                                    size: isMobile ? 18 : 20,
                                  ),
                                ),
                                SizedBox(width: isMobile ? 10 : 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        production.ad,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: isMobile ? 14 : 15,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFF202124),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 6,
                                        crossAxisAlignment:
                                            WrapCrossAlignment.center,
                                        children: [
                                          Text(
                                            '${tr('productions.make.table.code')}: ${production.kod}',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFF606368),
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 3,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF1F3F4),
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            child: Text(
                                              production.birim,
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFF4A4A4A),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
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
