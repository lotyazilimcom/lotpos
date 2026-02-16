import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';

import '../../../../yardimcilar/ceviri/ceviri_servisi.dart';
import '../../../../bilesenler/onay_dialog.dart';
import '../modeller/rol_model.dart';

typedef RolDuzenleIslevi = void Function(RolModel rol);
typedef RolSilIslevi = void Function(RolModel rol);
typedef RolDurumDegistirIslevi = void Function(RolModel rol, bool aktifMi);

class RolVeriKaynagi extends DataGridSource {
  RolVeriKaynagi({
    required this.context,
    required this.onDuzenle,
    required this.onSil,
    required this.onDurumDegistir,
    List<RolModel>? roller,
  }) {
    if (roller != null) {
      _roller = roller;
      _olusturSatirlar();
    }
  }

  final BuildContext context;
  final RolDuzenleIslevi onDuzenle;
  final RolSilIslevi onSil;
  final RolDurumDegistirIslevi onDurumDegistir;

  List<RolModel> _roller = [];
  List<DataGridRow> _satirlar = [];

  final Set<String> _seciliIdler = {};

  static const Color _rolVarsayilanRenk = Color(0xFF10B981);
  static const Color _rolSistemRenk = Color(0xFF3B82F6);
  static const Color _aktifRenk = Color(0xFF16A34A);
  static const Color _pasifRenk = Color(0xFFEA580C);

  void verileriGuncelle(List<RolModel> roller) {
    _roller = roller;
    _olusturSatirlar();
    notifyListeners();
  }

  void _olusturSatirlar() {
    _satirlar = _roller
        .map(
          (r) => DataGridRow(
            cells: [
              const DataGridCell<bool>(columnName: 'checkbox', value: false),
              DataGridCell<RolModel>(columnName: 'rol', value: r),
              const DataGridCell<int>(columnName: 'kullanici_sayisi', value: 0),
              DataGridCell<bool>(columnName: 'durum', value: r.aktifMi),
              DataGridCell<RolModel>(columnName: 'actions', value: r),
            ],
          ),
        )
        .toList();
  }

  @override
  List<DataGridRow> get rows => _satirlar;

  @override
  DataGridRowAdapter buildRow(DataGridRow row) {
    final RolModel rol = row.getCells().last.value as RolModel;
    final bool secili = _seciliIdler.contains(rol.id);

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
          child: _hucreOlustur(hucre, rol),
        );
      }).toList(),
    );
  }

  Widget _hucreOlustur(DataGridCell hucre, RolModel rol) {
    switch (hucre.columnName) {
      case 'checkbox':
        return MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Checkbox(
            value: _seciliIdler.contains(rol.id),
            onChanged: (_) => secimiDegistir(rol.id),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
            side: const BorderSide(color: Color(0xFFD1D1D1), width: 1),
          ),
        );
      case 'rol':
        return _rolHucre(rol);
      case 'kullanici_sayisi':
        return Text(
          hucre.value.toString(),
          style: const TextStyle(fontSize: 14),
        );
      case 'durum':
        return _durumRozeti(rol.aktifMi);
      case 'actions':
        return _islemMenusu(rol);
      default:
        return Text(hucre.value.toString());
    }
  }

  Widget _rolHucre(RolModel rol) {
    final bool sistemRolu = rol.sistemRoluMu;

    final Color arkaPlan = (sistemRolu ? _rolSistemRenk : _rolVarsayilanRenk)
        .withValues(alpha: 0.12);
    final Color ikonRenk = sistemRolu ? _rolSistemRenk : _rolVarsayilanRenk;

    final String rozetAltMetin = sistemRolu
        ? tr('settings.roles.badge.system')
        : tr('settings.roles.badge.custom');

    return Row(
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: arkaPlan,
          child: Icon(
            sistemRolu ? Icons.security : Icons.person_outline,
            size: 18,
            color: ikonRenk,
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              rol.ad,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            Text(
              rozetAltMetin,
              style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
            ),
          ],
        ),
      ],
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

  Widget _islemMenusu(RolModel rol) {
    final bool sistemRolu = rol.sistemRoluMu;
    final bool korumaliRol = [
      'admin',
      'user',
      'cashier',
      'waiter',
    ].contains(rol.id);

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
                value: rol.aktifMi ? 'deactivate' : 'activate',
                enabled: !sistemRolu || korumaliRol,
                height: 44,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Icon(
                      rol.aktifMi
                          ? Icons.toggle_on_outlined
                          : Icons.toggle_off_outlined,
                      size: 20,
                      color: (sistemRolu && !korumaliRol)
                          ? Colors.grey.shade400
                          : const Color(0xFF2C3E50),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      rol.aktifMi
                          ? tr('language.menu.deactivate')
                          : tr('language.menu.activate'),
                      style: TextStyle(
                        color: (sistemRolu && !korumaliRol)
                            ? Colors.grey.shade400
                            : const Color(0xFF2C3E50),
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
                enabled: !sistemRolu && !korumaliRol,
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
                      color: (sistemRolu || korumaliRol)
                          ? Colors.grey.shade400
                          : const Color(0xFFEA4335),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      tr('settings.users.table.action.delete'),
                      style: TextStyle(
                        color: (sistemRolu || korumaliRol)
                            ? Colors.grey.shade400
                            : const Color(0xFFEA4335),
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
                onDuzenle(rol);
              } else if (deger == 'deactivate' || deger == 'activate') {
                if (sistemRolu && !korumaliRol) return;
                onDurumDegistir(rol, deger == 'activate');
              } else if (deger == 'delete') {
                if (sistemRolu) return;
                showDialog(
                  context: context,
                  barrierDismissible: true,
                  barrierColor: Colors.black.withValues(alpha: 0.35),
                  builder: (context) {
                    return OnayDialog(
                      baslik: tr('settings.roles.delete.dialog.title.single'),
                      mesaj: tr(
                        'settings.roles.delete.dialog.message.single',
                      ).replaceAll('{name}', rol.ad),
                      onayButonMetni: tr('common.delete'),
                      iptalButonMetni: tr('common.cancel'),
                      isDestructive: true,
                      onOnay: () => onSil(rol),
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
      for (final rol in _roller) {
        _seciliIdler.add(rol.id);
      }
    }
    notifyListeners();
  }

  int get seciliSayisi => _seciliIdler.length;

  bool? get tumuSeciliMi {
    if (_seciliIdler.isEmpty) return false;
    if (_seciliIdler.length == _roller.length) return true;
    return null;
  }

  List<String> get seciliIdListesi => _seciliIdler.toList();

  bool get sistemRoluSeciliMi {
    return _roller.any((r) => r.sistemRoluMu && _seciliIdler.contains(r.id));
  }

  void sayfalamaUygula(int sayfa, int satirSayisi) {
    // Büyük veri senaryolarında sayfalı veri kaynağına geçmek için kullanılabilir.
    // Şu an için tüm veri bellekte tutuluyor.
  }
}
