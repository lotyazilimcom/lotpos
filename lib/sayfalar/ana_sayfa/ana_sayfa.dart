import 'dart:async';

import 'package:flutter/material.dart';
import '../../bilesenler/tab_acici_scope.dart';
import '../../servisler/oturum_servisi.dart';
import '../../servisler/veritabani_yapilandirma.dart';
import '../../temalar/app_theme.dart';
import '../../yardimcilar/format_yardimcisi.dart';
import 'ana_sayfa_servisi.dart';
import 'modeller/dashboard_ozet_modeli.dart';
import 'bilesenler/dashboard_shimmer.dart';
import 'bilesenler/dashboard_durum_seridi.dart';
import 'bilesenler/dashboard_kpi_karti.dart';
import 'bilesenler/dashboard_grafik_karti.dart';
import 'bilesenler/dashboard_uyari_karti.dart';
import 'bilesenler/dashboard_finans_karti.dart';
import 'bilesenler/dashboard_hizli_islemler.dart';
import 'bilesenler/dashboard_son_islemler.dart';

/// Lot Pos V1.0 — Ana Sayfa (Master Dashboard)
/// Operasyon Kontrol Merkezi — Kullanıcının anlık ticari sağlığını
/// görebileceği, şeffaf, canlı ve rol bazlı bir kontrol paneli.
class AnaSayfa extends StatefulWidget {
  const AnaSayfa({super.key});

  @override
  State<AnaSayfa> createState() => _AnaSayfaState();
}

class _AnaSayfaState extends State<AnaSayfa> {
  DashboardOzet? _ozet;
  bool _yukleniyor = true;
  bool _detaylarYukleniyor = false;
  String _tarihFiltresi = 'bugun';
  DateTime _sonYenilenme = DateTime.now();

  @override
  void initState() {
    super.initState();
    final servis = AnaSayfaServisi();
    final cacheliOzet = servis.cacheliDashboardVerisiniGetir(
      tarihFiltresi: _tarihFiltresi,
    );
    final cacheZamani = servis.cacheZamaniniGetir(
      tarihFiltresi: _tarihFiltresi,
    );

    if (cacheliOzet != null) {
      _ozet = cacheliOzet;
      _yukleniyor = false;
      _sonYenilenme = cacheZamani ?? _sonYenilenme;
      _detaylarYukleniyor = false;
      _verileriYukle(arkaPlanda: true);
      return;
    }

    unawaited(_diskOnbellektenYukle());
    unawaited(_verileriKademeliYukle());
  }

  Future<void> _diskOnbellektenYukle() async {
    final servis = AnaSayfaServisi();
    final cacheliOzet = await servis.diskCacheliDashboardVerisiniGetir(
      tarihFiltresi: _tarihFiltresi,
    );
    if (!mounted || cacheliOzet == null || _ozet != null) return;

    setState(() {
      _ozet = cacheliOzet;
      _yukleniyor = false;
      _detaylarYukleniyor = false;
      _sonYenilenme =
          servis.cacheZamaniniGetir(tarihFiltresi: _tarihFiltresi) ??
          DateTime.now();
    });

    unawaited(_verileriYukle(arkaPlanda: true));
  }

  Future<void> _verileriKademeliYukle() async {
    if (!mounted) return;
    final servis = AnaSayfaServisi();
    final talepEdilenFiltre = _tarihFiltresi;

    try {
      final DashboardOzet hizliOzet = await servis.dashboardHizliVerileriniGetir(
        tarihFiltresi: talepEdilenFiltre,
      );
      if (!mounted || talepEdilenFiltre != _tarihFiltresi) return;
      setState(() {
        _ozet = hizliOzet;
        _yukleniyor = false;
        _detaylarYukleniyor = true;
        _sonYenilenme = DateTime.now();
      });
      unawaited(_verileriYukle(arkaPlanda: true));
    } catch (e) {
      if (!mounted || talepEdilenFiltre != _tarihFiltresi) return;
      await _verileriYukle(arkaPlanda: false);
    }
  }

  Future<void> _verileriYukle({bool arkaPlanda = false}) async {
    if (!mounted) return;
    final servis = AnaSayfaServisi();
    final talepEdilenFiltre = _tarihFiltresi;
    final bloklayiciYukleme = !arkaPlanda && _ozet == null;

    if (bloklayiciYukleme) {
      setState(() => _yukleniyor = true);
    }

    try {
      final ozet = await servis.dashboardVerileriniGetir(
        tarihFiltresi: talepEdilenFiltre,
      );
      if (!mounted || talepEdilenFiltre != _tarihFiltresi) return;
      setState(() {
        _ozet = ozet;
        _yukleniyor = false;
        _detaylarYukleniyor = false;
        _sonYenilenme =
            servis.cacheZamaniniGetir(tarihFiltresi: talepEdilenFiltre) ??
            DateTime.now();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (_ozet == null) {
          _yukleniyor = false;
        }
        _detaylarYukleniyor = false;
      });
    }
  }

  Future<void> _filtreyiUygula(String filtre) async {
    final servis = AnaSayfaServisi();
    final cacheliOzet = servis.cacheliDashboardVerisiniGetir(
      tarihFiltresi: filtre,
    );
    final cacheZamani = servis.cacheZamaniniGetir(
      tarihFiltresi: filtre,
    );

    setState(() {
      _tarihFiltresi = filtre;
      if (cacheliOzet != null) {
        _ozet = cacheliOzet;
        _yukleniyor = false;
        _detaylarYukleniyor = false;
        _sonYenilenme = cacheZamani ?? _sonYenilenme;
      } else {
        _ozet = null;
        _yukleniyor = true;
        _detaylarYukleniyor = false;
      }
    });

    if (cacheliOzet != null) {
      unawaited(_verileriYukle(arkaPlanda: true));
    } else {
      unawaited(_verileriKademeliYukle());
    }
  }

  void _tabAc(int menuIndex) {
    TabAciciScope.of(context)?.tabAc(menuIndex: menuIndex);
  }

  @override
  Widget build(BuildContext context) {
    if (_yukleniyor) {
      return const DashboardShimmer();
    }

    final ozet = _ozet;
    if (ozet == null) {
      return const Center(
        child: Text(
          'Veriler yüklenemedi',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 16,
            color: AppPalette.slate,
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final crossCount = width >= 1200
            ? 4
            : width >= 800
            ? 2
            : 1;
        final isWide = width >= 800;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─── 1. Durum Şeridi ───
              DashboardDurumSeridi(
                sirketAdi: OturumServisi().aktifSirket?.ad ?? 'Lot Pos V1.0',
                baglantiModu: VeritabaniYapilandirma.connectionMode,
                sonYenilenme: _sonYenilenme,
                seciliFiltre: _tarihFiltresi,
                onFiltreSecildi: (filtre) => _filtreyiUygula(filtre),
                onYenile: () => _verileriYukle(arkaPlanda: _ozet != null),
              ),
              const SizedBox(height: 20),

              // ─── 2. Hero KPI Kartları ───
              _buildKpiGrid(ozet, crossCount),
              const SizedBox(height: 24),

              // ─── 3. Analitik + Risk Merkezi ───
              _detaylarYukleniyor
                  ? _buildAnaliticPlaceholder(isWide)
                  : _buildAnaliticRow(ozet, isWide),
              const SizedBox(height: 24),

              // ─── 4. Orta Bant Finansal Kartlar ───
              _buildFinansGrid(ozet, crossCount),
              const SizedBox(height: 24),

              // ─── 5. Hızlı İşlemler ───
              DashboardHizliIslemler(onIslemTap: _tabAc),
              const SizedBox(height: 24),

              // ─── 6. Son İşlemler Akışı ───
              _detaylarYukleniyor
                  ? _buildSonIslemlerPlaceholder()
                  : DashboardSonIslemler(
                      islemler: ozet.sonIslemler,
                      onIslemTap: _tabAc,
                    ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  /// Hero KPI Kartları Grid
  Widget _buildKpiGrid(DashboardOzet ozet, int crossCount) {
    final kartlar = [
      DashboardKpiKarti(
        baslik: 'Toplam Kasa',
        tutar: ozet.toplamKasa,
        degisimYuzde: ozet.kasaDegisimYuzde,
        ikon: Icons.account_balance_wallet_rounded,
        renk: const Color(0xFF1E5F74),
        sparkline: ozet.kasaSparkline,
        onTap: () => _tabAc(13),
      ),
      DashboardKpiKarti(
        baslik: 'Toplam Banka',
        tutar: ozet.toplamBanka,
        degisimYuzde: ozet.bankaDegisimYuzde,
        ikon: Icons.account_balance_rounded,
        renk: const Color(0xFF2196F3),
        sparkline: ozet.bankaSparkline,
        onTap: () => _tabAc(15),
      ),
      DashboardKpiKarti(
        baslik: 'Toplam Stok Değeri',
        tutar: ozet.toplamStokDegeri,
        degisimYuzde: ozet.stokDegisimYuzde,
        ikon: Icons.inventory_rounded,
        renk: const Color(0xFF9C27B0),
        sparkline: ozet.stokSparkline,
        onTap: () => _tabAc(7),
      ),
      DashboardKpiKarti(
        baslik: 'Net Cari Bakiye',
        tutar: ozet.netCariBakiye,
        degisimYuzde: ozet.cariDegisimYuzde,
        ikon: Icons.people_alt_rounded,
        renk: AppPalette.amber,
        sparkline: ozet.cariSparkline,
        onTap: () => _tabAc(9),
      ),
      DashboardKpiKarti(
        baslik: 'Bugünkü Net Satış',
        tutar: ozet.bugunNetSatis,
        degisimYuzde: ozet.satisDegisimYuzde,
        ikon: Icons.trending_up_rounded,
        renk: const Color(0xFF27AE60),
        sparkline: ozet.satisSparkline,
        onTap: () => _tabAc(12),
      ),
    ];

    return _responsiveGrid(kartlar, crossCount);
  }

  /// Analitik Grafik + Risk (Bölünmüş Ekran)
  Widget _buildAnaliticRow(DashboardOzet ozet, bool isWide) {
    final grafik = DashboardGrafikKarti(
      satis30Gun: ozet.satis30Gun,
      alis30Gun: ozet.alis30Gun,
      onTap: () => _tabAc(12),
    );

    final uyari = DashboardUyariKarti(
      kritikStoklar: ozet.kritikStoklar,
      yaklasanVadeler: ozet.yaklasanVadeler,
      onStokTap: () => _tabAc(7),
      onCekTap: () => _tabAc(14),
      onSenetTap: () => _tabAc(17),
    );

    if (isWide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 3, child: grafik),
          const SizedBox(width: 16),
          Expanded(flex: 2, child: uyari),
        ],
      );
    }

    return Column(children: [grafik, const SizedBox(height: 16), uyari]);
  }

  Widget _buildAnaliticPlaceholder(bool isWide) {
    final grafik = _placeholderKart(height: 300);
    final uyari = _placeholderKart(height: 300);

    if (isWide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 3, child: grafik),
          const SizedBox(width: 16),
          Expanded(flex: 2, child: uyari),
        ],
      );
    }

    return Column(children: [grafik, const SizedBox(height: 16), uyari]);
  }

  /// Orta Bant Finansal Kartlar Grid
  Widget _buildFinansGrid(DashboardOzet ozet, int crossCount) {
    final kartlar = [
      DashboardFinansKarti(
        baslik: 'Kredi Kartı Bakiyesi',
        deger:
            '${FormatYardimcisi.sayiFormatlaOndalikli(ozet.krediKartiBakiyesi)} ₺',
        ikon: Icons.credit_card_rounded,
        renk: const Color(0xFFE91E63),
        onTap: () => _tabAc(16),
      ),
      DashboardFinansKarti(
        baslik: 'Bekleyen Çekler',
        deger:
            '${FormatYardimcisi.sayiFormatlaOndalikli(ozet.bekleyenCekler)} ₺',
        ikon: Icons.description_outlined,
        renk: const Color(0xFF2196F3),
        onTap: () => _tabAc(14),
      ),
      DashboardFinansKarti(
        baslik: 'Bekleyen Senetler',
        deger:
            '${FormatYardimcisi.sayiFormatlaOndalikli(ozet.bekleyenSenetler)} ₺',
        ikon: Icons.article_outlined,
        renk: const Color(0xFFFF9800),
        onTap: () => _tabAc(17),
      ),
      DashboardFinansKarti(
        baslik: 'Aktif Siparişler',
        deger: '${ozet.aktifSiparisler} Adet',
        ikon: Icons.receipt_long_rounded,
        renk: const Color(0xFF1E5F74),
        onTap: () => _tabAc(18),
        adetMi: true,
      ),
      DashboardFinansKarti(
        baslik: 'Aktif Teklifler',
        deger: '${ozet.aktifTeklifler} Adet',
        ikon: Icons.request_quote_outlined,
        renk: const Color(0xFF9C27B0),
        onTap: () => _tabAc(19),
        adetMi: true,
      ),
      DashboardFinansKarti(
        baslik: 'Bu Ayki Giderler',
        deger:
            '${FormatYardimcisi.sayiFormatlaOndalikli(ozet.buAykiGiderler)} ₺',
        ikon: Icons.receipt_rounded,
        renk: AppPalette.red,
        onTap: () => _tabAc(100),
      ),
    ];

    return _responsiveGrid(kartlar, crossCount);
  }

  Widget _buildSonIslemlerPlaceholder() {
    return _placeholderKart(height: 420);
  }

  Widget _placeholderKart({required double height}) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppPalette.grey.withValues(alpha: 0.15),
        ),
        boxShadow: [
          BoxShadow(
            color: AppPalette.slate.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: AppPalette.slate.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2.4),
        ),
      ),
    );
  }

  /// Responsive grid oluşturucu
  Widget _responsiveGrid(List<Widget> items, int crossCount) {
    if (crossCount == 1) {
      return Column(
        children: items
            .map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: item,
              ),
            )
            .toList(),
      );
    }

    final rows = <Widget>[];
    for (int i = 0; i < items.length; i += crossCount) {
      final rowItems = items.sublist(
        i,
        (i + crossCount) > items.length ? items.length : i + crossCount,
      );
      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: rowItems.asMap().entries.map((entry) {
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    left: entry.key > 0 ? 8 : 0,
                    right: entry.key < rowItems.length - 1 ? 8 : 0,
                  ),
                  child: entry.value,
                ),
              );
            }).toList(),
          ),
        ),
      );
    }
    return Column(children: rows);
  }
}
