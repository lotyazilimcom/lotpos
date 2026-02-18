import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:patisyov10/bilesenler/standart_alt_aksiyon_bar.dart';
import 'package:patisyov10/yardimcilar/ceviri/ceviri_servisi.dart';
import 'package:patisyov10/servisler/ayarlar_veritabani_servisi.dart';
import 'package:patisyov10/sayfalar/ayarlar/genel_ayarlar/modeller/genel_ayarlar_model.dart';
import 'package:patisyov10/servisler/sayfa_senkronizasyon_servisi.dart';

class ModullerSayfasi extends StatefulWidget {
  const ModullerSayfasi({super.key});

  @override
  State<ModullerSayfasi> createState() => _ModullerSayfasiState();
}

class _ModullerSayfasiState extends State<ModullerSayfasi> {
  late GenelAyarlarModel _ayarlar;
  GenelAyarlarModel? _kayitliAyarlar;
  bool _yukleniyor = true;

  final List<Map<String, dynamic>> _sidebarModulleri = [
    {
      'id': 'trading_operations',
      'icon': Icons.shopping_bag_rounded,
      'children': [
        'trading_operations.fast_sale',
        'trading_operations.make_purchase',
        'trading_operations.make_sale',
        'trading_operations.retail_sale',
      ],
    },
    {
      'id': 'orders_quotes',
      'icon': Icons.assignment_rounded,
      'children': ['orders_quotes.orders', 'orders_quotes.quotes'],
    },
    {
      'id': 'products_warehouses',
      'icon': Icons.inventory_2_rounded,
      'children': [
        'products_warehouses.products',
        'products_warehouses.productions',
        'products_warehouses.warehouses',
      ],
    },
    {'id': 'accounts', 'icon': Icons.account_balance_wallet_rounded},
    {
      'id': 'cash_bank',
      'icon': Icons.account_balance_rounded,
      'children': [
        'cash_bank.cash',
        'cash_bank.banks',
        'cash_bank.credit_cards',
      ],
    },
    {
      'id': 'checks_notes',
      'icon': Icons.receipt_long_rounded,
      'children': ['checks_notes.checks', 'checks_notes.notes'],
    },
    {'id': 'personnel_user', 'icon': Icons.people_alt_rounded},
    {'id': 'expenses', 'icon': Icons.money_off_rounded},
  ];

  @override
  void initState() {
    super.initState();
    _ayarlariYukle();
  }

  Future<void> _ayarlariYukle() async {
    final ayarlar = await AyarlarVeritabaniServisi().genelAyarlariGetir();
    if (mounted) {
      setState(() {
        _ayarlar = ayarlar;
        _kayitliAyarlar = _cloneAyarlar(ayarlar);
        _yukleniyor = false;
      });
    }
  }

  GenelAyarlarModel _cloneAyarlar(GenelAyarlarModel source) {
    final jsonMap =
        jsonDecode(jsonEncode(source.toMap())) as Map<String, dynamic>;
    return GenelAyarlarModel.fromMap(jsonMap);
  }

  void _iptalEt() {
    final kayitli = _kayitliAyarlar;
    if (kayitli == null) return;

    setState(() => _ayarlar = _cloneAyarlar(kayitli));
  }

  Future<void> _kaydet() async {
    await AyarlarVeritabaniServisi().genelAyarlariKaydet(_ayarlar);
    _kayitliAyarlar = _cloneAyarlar(_ayarlar);

    // Yan menüyü tetikle
    SayfaSenkronizasyonServisi().veriDegisti('moduller');

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('settings.general.actions.saveSuccess')),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_yukleniyor) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF2C3E50)),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isMobile = constraints.maxWidth < 860;

        return DefaultTabController(
          length: 1,
          child: Scaffold(
            backgroundColor: Colors.white,
            body: SafeArea(
              child: Column(
                children: [
                  _buildHeader(isMobile: isMobile),
                  Expanded(
                    child: Container(
                      color: const Color(0xFFF8FAFC),
                      child: TabBarView(
                        children: [_buildModullerTab(isMobile: isMobile)],
                      ),
                    ),
                  ),
                  StandartAltAksiyonBar(
                    isCompact: isMobile,
                    secondaryText: tr('common.cancel'),
                    onSecondaryPressed: _iptalEt,
                    primaryText: tr('common.save'),
                    onPrimaryPressed: _kaydet,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader({required bool isMobile}) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        isMobile ? 16 : 32,
        isMobile ? 16 : 32,
        isMobile ? 16 : 32,
        0,
      ),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr('settings.modules.title'),
            style: TextStyle(
              fontSize: isMobile ? 22 : 28,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1E293B),
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            tr('settings.modules.subtitle'),
            style: const TextStyle(fontSize: 14, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 24),
          TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: const Color(0xFF2C3E50),
            unselectedLabelColor: const Color(0xFF64748B),
            indicatorColor: const Color(0xFF2C3E50),
            indicatorWeight: 3,
            labelStyle: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
            unselectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 15,
            ),
            dividerColor: const Color(0xFFE2E8F0),
            tabs: [Tab(text: tr('settings.modules.title'))],
          ),
        ],
      ),
    );
  }

  Widget _buildModullerTab({required bool isMobile}) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16 : 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildModuleCard(
            title: tr('settings.modules.device_list.title'),
            description: tr('settings.modules.device_list.description'),
            info: tr('settings.modules.device_list.info'),
            icon: Icons.phonelink_setup_rounded,
            value: _ayarlar.cihazListesiModuluAktif,
            onChanged: (val) {
              setState(() {
                _ayarlar.cihazListesiModuluAktif = val;
              });
            },
          ),
          _buildSidebarModuleGrid(isMobile: isMobile),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSidebarModuleGrid({required bool isMobile}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: isMobile ? 28 : 64),
        Row(
          children: [
            Container(
              width: 4,
              height: 24,
              decoration: BoxDecoration(
                color: const Color(0xFF2C3E50),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              tr('nav.settings.modules'),
              style: TextStyle(
                fontSize: isMobile ? 18 : 22,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF1E293B),
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          tr('settings.modules.subtitle'),
          style: const TextStyle(fontSize: 14, color: Color(0xFF64748B)),
        ),
        SizedBox(height: isMobile ? 16 : 32),
        LayoutBuilder(
          builder: (context, constraints) {
            final double width = constraints.maxWidth;
            int crossAxisCount;
            if (width < 640) {
              crossAxisCount = 1;
            } else if (width < 1024) {
              crossAxisCount = 2;
            } else {
              crossAxisCount = 3;
            }

            final double spacing = isMobile ? 14 : 24;
            final double extent = width < 640 ? 360 : 340;

            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: spacing,
                mainAxisSpacing: spacing,
                mainAxisExtent: extent,
              ),
              itemCount: _sidebarModulleri.length,
              itemBuilder: (context, index) {
                final module = _sidebarModulleri[index];
                return _buildMiniModuleCard(
                  id: module['id'] as String,
                  icon: module['icon'] as IconData,
                  children: (module['children'] as List<String>?) ?? [],
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildMiniModuleCard({
    required String id,
    required IconData icon,
    List<String> children = const [],
  }) {
    final bool isMainActive = _ayarlar.aktifModuller[id] ?? true;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2C3E50).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        icon,
                        color: const Color(0xFF2C3E50),
                        size: 28,
                      ),
                    ),
                    const Spacer(),
                    _buildSwitch(
                      value: isMainActive,
                      onChanged: (val) {
                        setState(() {
                          _ayarlar.aktifModuller[id] = val;
                          // Ana menü kapanırsa alt menüleri de kapat
                          if (!val) {
                            for (final childId in children) {
                              _ayarlar.aktifModuller[childId] = false;
                            }
                          }
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  tr('settings.modules.items.$id.title'),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  tr('settings.modules.items.$id.description'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),

          if (children.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Divider(height: 1, color: Color(0xFFF1F5F9)),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: children.length,
                itemBuilder: (context, index) {
                  final childId = children[index];
                  final bool isChildActive =
                      _ayarlar.aktifModuller[childId] ?? true;
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 6,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.subdirectory_arrow_right_rounded,
                          size: 14,
                          color: Color(0xFF94A3B8),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            tr('settings.modules.items.$childId.title'),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: isMainActive
                                  ? const Color(0xFF475569)
                                  : const Color(0xFF94A3B8),
                            ),
                          ),
                        ),
                        IgnorePointer(
                          ignoring: !isMainActive,
                          child: Opacity(
                            opacity: isMainActive ? 1.0 : 0.5,
                            child: _buildSwitch(
                              value: isChildActive,
                              onChanged: (val) {
                                setState(() {
                                  _ayarlar.aktifModuller[childId] = val;
                                });
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSwitch({
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    const Color accentColor = Color(0xFFEA4335);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => onChanged(!value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 44,
          height: 24,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: value ? accentColor : Colors.grey.shade300,
            borderRadius: BorderRadius.circular(12),
            boxShadow: value
                ? [
                    BoxShadow(
                      color: accentColor.withValues(alpha: 0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 200),
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: value
                  ? const Icon(Icons.check, size: 12, color: accentColor)
                  : null,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModuleCard({
    required String title,
    required String description,
    required String info,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isNarrow = constraints.maxWidth < 560;

        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.all(isNarrow ? 16 : 24),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2C3E50).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        icon,
                        color: const Color(0xFF2C3E50),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: isNarrow ? 16 : 18,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF1E293B),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            description,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    _buildSwitch(value: value, onChanged: onChanged),
                  ],
                ),
              ),
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(
                  horizontal: isNarrow ? 16 : 24,
                  vertical: 16,
                ),
                decoration: const BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(20),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 1),
                      child: Icon(
                        Icons.info_outline_rounded,
                        color: Color(0xFF2C3E50),
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        info,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF2C3E50),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
