import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';

import '../../../../yardimcilar/ceviri/ceviri_servisi.dart';
import '../../../../bilesenler/onay_dialog.dart';
import '../modeller/kullanici_model.dart';

typedef KullaniciDuzenleIslevi = void Function(KullaniciModel kullanici);
typedef KullaniciSilIslevi = void Function(KullaniciModel kullanici);
typedef KullaniciDurumDegistirIslevi =
    void Function(KullaniciModel kullanici, bool aktifMi);

class KullaniciVeriKaynagi extends DataGridSource {
  KullaniciVeriKaynagi({
    required this.context,
    required this.onDuzenle,
    required this.onSil,
    required this.onDurumDegistir,
    List<KullaniciModel>? kullanicilar,
  }) {
    if (kullanicilar != null) {
      _kullanicilar = kullanicilar;
      _olusturSatirlar();
    }
  }

  final BuildContext context;
  final KullaniciDuzenleIslevi onDuzenle;
  final KullaniciSilIslevi onSil;
  final KullaniciDurumDegistirIslevi onDurumDegistir;

  List<KullaniciModel> _kullanicilar = [];
  List<DataGridRow> _satirlar = [];
  int _toplamAdminSayisi = 0;

  final Set<String> _seciliIdler = {};

  static const Color _aktifRenk = Color(0xFF16A34A);
  static const Color _pasifRenk = Color(0xFFEA580C);
  static const Color _rolAdminRenk = Color(0xFFE11D48);
  static const Color _rolKasiyerRenk = Color(0xFF0EA5E9);
  static const Color _rolGarsonRenk = Color(0xFFF59E0B);

  void verileriGuncelle(
    List<KullaniciModel> goruntulenenler, {
    int toplamAdminSayisi = 0,
  }) {
    _kullanicilar = goruntulenenler;
    _toplamAdminSayisi = toplamAdminSayisi;
    _olusturSatirlar();
    notifyListeners();
  }

  void _olusturSatirlar() {
    _satirlar = _kullanicilar
        .map(
          (k) => DataGridRow(
            cells: [
              const DataGridCell<bool>(columnName: 'checkbox', value: false),
              DataGridCell<KullaniciModel>(columnName: 'kullanici', value: k),
              DataGridCell<String>(columnName: 'telefon', value: k.telefon),
              DataGridCell<String>(columnName: 'rol', value: k.rol),
              DataGridCell<bool>(columnName: 'durum', value: k.aktifMi),
              DataGridCell<KullaniciModel>(columnName: 'actions', value: k),
            ],
          ),
        )
        .toList();
  }

  @override
  List<DataGridRow> get rows => _satirlar;

  @override
  DataGridRowAdapter buildRow(DataGridRow row) {
    final KullaniciModel kullanici =
        row.getCells().last.value as KullaniciModel;
    final bool secili = _seciliIdler.contains(kullanici.id);

    return DataGridRowAdapter(
      color: secili ? Colors.blue.withValues(alpha: 0.06) : Colors.white,
      cells: row.getCells().map((hucre) {
        Alignment hizalama = Alignment.centerLeft;
        if (hucre.columnName == 'checkbox') {
          hizalama = Alignment.center;
        }
        return Container(
          alignment: hizalama,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: _hucreOlustur(hucre, kullanici),
        );
      }).toList(),
    );
  }

  Widget _hucreOlustur(DataGridCell hucre, KullaniciModel kullanici) {
    switch (hucre.columnName) {
      case 'checkbox':
        return MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Checkbox(
            value: _seciliIdler.contains(kullanici.id),
            onChanged: (_) => secimiDegistir(kullanici.id),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
            side: const BorderSide(color: Color(0xFFD1D1D1), width: 1),
          ),
        );
      case 'kullanici':
        return _kullaniciHucre(kullanici);
      case 'telefon':
        return Text(kullanici.telefon, style: const TextStyle(fontSize: 14));
      case 'rol':
        return _rolRozeti(kullanici.rol);
      case 'durum':
        return _durumRozeti(kullanici.aktifMi);
      case 'actions':
        return _islemMenusu(kullanici);
      default:
        return Text(hucre.value.toString());
    }
  }

  Widget _kullaniciHucre(KullaniciModel kullanici) {
    final String basHarf =
        (kullanici.kullaniciAdi.isNotEmpty
                ? kullanici.kullaniciAdi
                : (kullanici.ad.isNotEmpty ? kullanici.ad : kullanici.id))
            .substring(0, 1)
            .toUpperCase();

    final String adSoyad =
        '${kullanici.ad} ${kullanici.soyad}'.trim().isNotEmpty
        ? '${kullanici.ad} ${kullanici.soyad}'.trim()
        : kullanici.kullaniciAdi;

    return Row(
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: const Color(0xFF2C3E50).withValues(alpha: 0.12),
          foregroundColor: const Color(0xFF2C3E50),
          backgroundImage:
              kullanici.profilResmi != null && kullanici.profilResmi!.isNotEmpty
              ? MemoryImage(base64Decode(kullanici.profilResmi!))
              : null,
          child: kullanici.profilResmi == null || kullanici.profilResmi!.isEmpty
              ? Text(
                  basHarf,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                )
              : null,
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              adSoyad,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            Text(
              kullanici.eposta,
              style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _rolRozeti(String rol) {
    Color arkaPlan;
    Color yaziRenk;
    IconData ikon;
    String etiket;

    switch (rol) {
      case 'admin':
        arkaPlan = _rolAdminRenk.withValues(alpha: 0.12);
        yaziRenk = _rolAdminRenk;
        ikon = Icons.security;
        etiket = tr('settings.users.role.admin');
        break;
      case 'cashier':
        arkaPlan = _rolKasiyerRenk.withValues(alpha: 0.12);
        yaziRenk = _rolKasiyerRenk;
        ikon = Icons.point_of_sale;
        etiket = tr('settings.users.role.cashier');
        break;
      case 'waiter':
        arkaPlan = _rolGarsonRenk.withValues(alpha: 0.12);
        yaziRenk = _rolGarsonRenk;
        ikon = Icons.restaurant_menu;
        etiket = tr('settings.users.role.waiter');
        break;
      default:
        arkaPlan = Colors.grey.withValues(alpha: 0.12);
        yaziRenk = Colors.grey;
        ikon = Icons.person;
        etiket = rol;
        break;
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: arkaPlan,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(ikon, size: 14, color: yaziRenk),
            const SizedBox(width: 6),
            Text(
              etiket,
              style: TextStyle(
                color: yaziRenk,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _durumRozeti(bool aktifMi) {
    final Color renk = aktifMi ? _aktifRenk : _pasifRenk;
    final String etiket = aktifMi
        ? tr('language.status.active')
        : tr('language.status.inactive');

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: renk.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: renk, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(
              etiket,
              style: TextStyle(
                color: renk,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _islemMenusu(KullaniciModel kullanici) {
    final bool isLastAdmin =
        kullanici.rol == 'admin' && _toplamAdminSayisi <= 1;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Builder(
        builder: (context) => Theme(
          data: Theme.of(context).copyWith(
            dividerTheme: const DividerThemeData(
              color: Color(0xFFEEEEEE),
              thickness: 1,
            ),
            popupMenuTheme: PopupMenuThemeData(
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: Colors.grey.shade300, width: 1),
              ),
              elevation: 6,
            ),
          ),
          child: PopupMenuButton<String>(
            icon: const Icon(Icons.more_horiz, color: Colors.grey, size: 22),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 190),
            splashRadius: 20,
            offset: const Offset(0, 8),
            tooltip: tr('settings.users.table.column.actions'),
            itemBuilder: (context) => [
              PopupMenuItem<String>(
                value: 'edit',
                enabled: true,
                height: 44,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.edit_outlined,
                      size: 20,
                      color: Color(0xFF2C3E50),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      tr('settings.users.table.action.edit'),
                      style: const TextStyle(
                        color: Color(0xFF2C3E50),
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                enabled: false,
                height: 12,
                padding: EdgeInsets.zero,
                child: Divider(
                  height: 1,
                  thickness: 1,
                  indent: 10,
                  endIndent: 10,
                  color: Color(0xFFEEEEEE),
                ),
              ),
              PopupMenuItem<String>(
                value: kullanici.aktifMi ? 'deactivate' : 'activate',
                enabled: !isLastAdmin,
                height: 44,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Icon(
                      kullanici.aktifMi
                          ? Icons.toggle_off_outlined
                          : Icons.toggle_on_outlined,
                      size: 20,
                      color: !isLastAdmin
                          ? const Color(0xFF2C3E50)
                          : Colors.grey.shade400,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      kullanici.aktifMi
                          ? tr('language.menu.deactivate')
                          : tr('language.menu.activate'),
                      style: TextStyle(
                        color: !isLastAdmin
                            ? const Color(0xFF2C3E50)
                            : Colors.grey.shade400,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                enabled: false,
                height: 12,
                padding: EdgeInsets.zero,
                child: Divider(
                  height: 1,
                  thickness: 1,
                  indent: 10,
                  endIndent: 10,
                  color: Color(0xFFEEEEEE),
                ),
              ),
              PopupMenuItem<String>(
                value: 'delete',
                enabled: !isLastAdmin,
                height: 44,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.delete_outline,
                      size: 20,
                      color: !isLastAdmin
                          ? const Color(0xFFEA4335)
                          : Colors.grey.shade400,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      tr('settings.users.table.action.delete'),
                      style: TextStyle(
                        color: !isLastAdmin
                            ? const Color(0xFFEA4335)
                            : Colors.grey.shade400,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            onSelected: (deger) {
              if (deger == 'edit') {
                onDuzenle(kullanici);
              } else if (deger == 'deactivate' || deger == 'activate') {
                if (isLastAdmin) return;
                onDurumDegistir(kullanici, deger == 'activate');
              } else if (deger == 'delete') {
                if (isLastAdmin) return;
                showDialog(
                  context: context,
                  barrierDismissible: true,
                  barrierColor: Colors.black.withValues(alpha: 0.35),
                  builder: (context) {
                    return OnayDialog(
                      baslik: tr('settings.users.delete.dialog.title.single'),
                      mesaj: tr(
                        'settings.users.delete.dialog.message.single',
                      ).replaceAll('{name}', kullanici.kullaniciAdi),
                      onayButonMetni: tr('common.delete'),
                      iptalButonMetni: tr('common.cancel'),
                      isDestructive: true,
                      onOnay: () => onSil(kullanici),
                    );
                  },
                );
              }
            },
          ),
        ),
      ),
    );
  }

  // Seçim işlemleri
  bool seciliMi(String id) => _seciliIdler.contains(id);

  void secimiDegistir(String id) {
    if (_seciliIdler.contains(id)) {
      _seciliIdler.remove(id);
    } else {
      _seciliIdler.add(id);
    }
    notifyListeners();
  }

  void tumunuSec(bool sec) {
    _seciliIdler.clear();
    if (sec) {
      for (final k in _kullanicilar) {
        _seciliIdler.add(k.id);
      }
    }
    notifyListeners();
  }

  int get seciliSayisi => _seciliIdler.length;

  bool? get tumuSeciliMi {
    if (_seciliIdler.isEmpty) return false;
    if (_seciliIdler.length == _kullanicilar.length) return true;
    return null;
  }

  List<String> get seciliIdListesi => _seciliIdler.toList();

  bool get sonYoneticiSeciliMi {
    final int seciliAdmin = _kullanicilar
        .where((k) => k.rol == 'admin' && _seciliIdler.contains(k.id))
        .length;

    if (seciliAdmin == 0) return false;

    // Eğer seçili adminler silinirse geriye admin kalmıyorsa true döner.
    return (_toplamAdminSayisi - seciliAdmin) < 1;
  }

  void sayfalamaUygula(int sayfa, int satirSayisi) {
    // Büyük veri senaryolarında sayfalı veri kaynağına geçmek için kullanılabilir.
    // Şu an için tüm veri bellekte tutuluyor.
  }
}
