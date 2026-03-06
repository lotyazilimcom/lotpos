import 'package:flutter/material.dart';
import '../sayfalar/carihesaplar/modeller/cari_hesap_model.dart';
import '../sayfalar/urunler_ve_depolar/urunler/modeller/urun_model.dart';
import '../sayfalar/alimsatimislemleri/modeller/transaction_item.dart';

/// Tab açma callback tipi
/// menuIndex: Açılacak sayfanın menu index'i
/// initialCari: Cari Hesap gerektiren sayfalar için (Alış/Satış/Cari Kartı vb.)
/// initialUrun: Ürün Kartı sayfası için
/// cariKartiIndex = 200: Cari Kartı sayfası için özel index
/// urunKartiIndex = 201: Ürün Kartı sayfası için özel index
typedef TabAcCallback =
    void Function({
      required int menuIndex,
      CariHesapModel? initialCari,
      UrunModel? initialUrun,
      List<TransactionItem>? initialItems,
      String? initialCurrency,
      String? initialDescription,
      String? initialOrderRef,
      int? quoteRef,
      double? initialRate,
      String? initialSearchQuery,
      Map<String, dynamic>? duzenlenecekIslem,
    });

/// Tab açma fonksiyonunu child widget'lara iletmek için InheritedWidget
class TabAciciScope extends InheritedWidget {
  final TabAcCallback tabAc;

  const TabAciciScope({super.key, required this.tabAc, required super.child});

  static TabAciciScope? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<TabAciciScope>();
  }

  @override
  bool updateShouldNotify(TabAciciScope oldWidget) => tabAc != oldWidget.tabAc;

  /// Cari Kartı sayfası için sabit index (menüde tanımlı değil, dinamik)
  static const int cariKartiIndex = 200;

  /// Ürün Kartı sayfası için sabit index (menüde tanımlı değil, dinamik)
  static const int urunKartiIndex = 201;
}
