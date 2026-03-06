import 'lisans_servisi.dart';
import 'lite_ayarlar_servisi.dart';

class LiteKisitlari {
  static bool get isLiteMode => LisansServisi().isLiteMode;

  static int get maxAktifCari => LiteAyarlarServisi().maxCurrentAccounts;
  static const int maxUrunKarti = 100;
  static int get maxGunlukSatis => LiteAyarlarServisi().maxDailyTransactions;
  static int get maxGunlukPerakendeSatis =>
      LiteAyarlarServisi().maxDailyRetailSales;
  static int get raporGun => LiteAyarlarServisi().reportDaysLimit;

  static bool get isBankCreditActive =>
      LiteAyarlarServisi().isBankCreditActive;
  static bool get isCheckPromissoryActive =>
      LiteAyarlarServisi().isCheckPromissoryActive;
  static bool get isCloudBackupActive =>
      LiteAyarlarServisi().isCloudBackupActive;
  static bool get isExcelExportActive =>
      LiteAyarlarServisi().isExcelExportActive;
}

class LiteLimitHatasi implements Exception {
  final String message;
  const LiteLimitHatasi(this.message);

  @override
  String toString() => message;
}
