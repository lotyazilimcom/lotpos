# Translation Audit (2026-01-30)

Bu rapor, 2026-01-30 itibarıyla proje çeviri (i18n) durumunu özetler.

## 1) Sonuç (Özet)

- Dil dosyaları:
  - `lib/yardimcilar/ceviri/tr.dart`
  - `lib/yardimcilar/ceviri/en.dart`
  - `lib/yardimcilar/ceviri/ar.dart`
- Key sayısı: `tr=2547`, `en=2547`, `ar=2547`
- Key setleri birebir aynı: Evet
- Duplicate key: `0`
- Boş çeviri değeri (`''` / whitespace): `0`

## 2) Kod Kullanımı

- `tr('...')` (static literal) kullanılan key sayısı: `1778`
- Eksik static key: `0`
- Dinamik key template’leri (literal map key olarak kontrol edilmez): `3`
  - `country.$countryKey`
  - `country.${entry.value}`
  - `settings.print.types.${sablon.docType}`

## 3) Bu Seans Eklenen/Düzeltilen Örnek Key’ler

- `common.go_to_related_page`
- `print.designer.fit_to_screen`
- `common.placeholder.email`
- `common.placeholder.website`
- `transactions.personnel_payment`
- `transactions.payment_received_sale`
- `transactions.payment_made_purchase`
- `stock.transaction.transfer`
- Tarih placeholder’ları: `common.placeholder.date` kullanımı yaygınlaştırıldı.

## 4) Doğrulama

- `dart format` çalıştırıldı (değişen dosyalar)
- `flutter analyze`: No issues found
- Not: `flutter test` mevcut `test/widget_test.dart` (counter örnek testi) sebebiyle fail edebilir; bu rapordaki çeviri düzeltmeleriyle ilişkili değildir.
