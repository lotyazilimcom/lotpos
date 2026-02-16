# 2025-08 Sonrası Flutter & PostgreSQL Notları (Proje Odaklı)

Bu doküman; bu repodaki mevcut durum + 2025-08 sonrasında çıkan ana sürümlere ait (resmi) release notes / breaking changes başlıklarını hızlıca toparlamak için tutulur.

## Projede tespit edilen sürümler

- Flutter SDK (local): `Flutter 3.38.6` (stable) + `Dart 3.10.7`
- Proje Dart constraint: `pubspec.yaml -> environment.sdk: ^3.9.2` (Dart 3.9.2+)
- PostgreSQL server (local): `14.20 (Homebrew)` (`SHOW server_version;`)
- Dart PostgreSQL driver: `postgres` package `3.5.9` (`pubspec.lock`)

## Flutter (2025-08 sonrası stable)

Kaynak:
- “What’s new” zaman çizelgesi: https://docs.flutter.dev/release/whats-new
- Flutter release notes: https://docs.flutter.dev/release/release-notes
- Breaking changes: https://docs.flutter.dev/release/breaking-changes

### 3.35 (13 Aug 2025)

- Release notes: https://docs.flutter.dev/release/release-notes/release-notes-3.35.0
- Breaking changes (3.35):
  - Component theme normalization updates: https://docs.flutter.dev/release/breaking-changes/component-theme-normalization-updates
  - Deprecate `DropdownButtonFormField.value` → `initialValue`: https://docs.flutter.dev/release/breaking-changes/deprecate-dropdownbuttonformfield-value
  - Deprecate app bar color: https://docs.flutter.dev/release/breaking-changes/appbar-theme-color
  - Radio redesign: https://docs.flutter.dev/release/breaking-changes/radio-api-redesign
  - Removed semantics elevation/thickness: https://docs.flutter.dev/release/breaking-changes/remove-semantics-elevation-and-thickness
  - `Form` artık sliver değil: https://docs.flutter.dev/release/breaking-changes/form-semantics
  - Android default `abiFilters`: https://docs.flutter.dev/release/breaking-changes/default-abi-filters-android
  - macOS/Windows thread merge: https://docs.flutter.dev/release/breaking-changes/macos-windows-merged-threads
  - `Visibility` focus değişikliği: https://docs.flutter.dev/release/breaking-changes/visibility-maintainfocusability
  - `$FLUTTER_ROOT/version` dosyası değişti: https://docs.flutter.dev/release/breaking-changes/flutter-root-version-file

“What’s new” sayfasındaki öne çıkanlar:
- Web’de hot reload artık deneysel flag istemiyor.
- Widget Previewer (Chrome) dokümantasyonu geldi (experimental).
- Android’de ekran paylaşımında hassas içerik koruma ile ilgili yeni doküman.

### 3.38 (12 Nov 2025) + patch’ler (örn. 3.38.6)

- Release notes: https://docs.flutter.dev/release/release-notes/release-notes-3.38.0
- Breaking changes (3.38):
  - `CupertinoDynamicColor` wide gamut: https://docs.flutter.dev/release/breaking-changes/wide-gamut-cupertino-dynamic-color
  - Deprecate `OverlayPortal.targetsRootOverlay`: https://docs.flutter.dev/release/breaking-changes/deprecate-overlay-portal-targets-root
  - Deprecate `SemanticsProperties.focusable`: https://docs.flutter.dev/release/breaking-changes/deprecate-focusable
  - SnackBar action auto-dismiss değişti: https://docs.flutter.dev/release/breaking-changes/snackbar-with-action-behavior-update
  - Android default transition → `PredictiveBackPageTransitionBuilder`: https://docs.flutter.dev/release/breaking-changes/default-android-page-transition
  - iOS UISceneDelegate adoption: https://docs.flutter.dev/release/breaking-changes/uiscenedelegate

“What’s new” sayfasındaki öne çıkanlar:
- `flutter run` için web dev config file desteği (host/port/header/proxy vb).
- Widget Previewer IDE entegrasyonları iyileştirildi (hala experimental).
- iOS: Apple’ın UIScene lifecycle zorunluluğu için destek notları.
- docs.flutter.dev altyapısı Jaspr ile yenilendi (doküman tarafı).

## Dart (2025-08 sonrası)

Not: Dart 3.10 içeriği için blog linkleri bazı ortamlarda JS/cookie isteyebiliyor; aşağıdaki resmi dokümanlar erişilebilir.

- Dot shorthands: https://dart.dev/language/dot-shorthands
- Hooks (build hooks + native assets): https://dart.dev/tools/hooks
- Deprecation annotations: https://dart.dev/language/metadata

## PostgreSQL (2025-08 sonrası)

### PostgreSQL 18 (Major)

Kaynak (release notes): https://www.postgresql.org/docs/release/18.0/

18.0 “Overview” başlığındaki özet maddeler:
- AIO subsystem (bazı scan/vacuum vb işlerde performans iyileştirmeleri)
- `pg_upgrade` artık optimizer istatistiklerini koruyor
- Multicolumn B-tree için “skip scan” lookup desteği (daha fazla index kullanımı)
- `uuidv7()` (timestamp sıralı UUID)
- Generated columns için “virtual generated columns” (read-time compute) varsayılan oldu
- OAuth authentication desteği
- `INSERT/UPDATE/DELETE/MERGE ... RETURNING` içinde `OLD`/`NEW` desteği
- Temporal constraints (range üstünden PK/UK/FK constraint’leri)

Migration notları (18’e geçişte dikkat çeken başlıklar):
- `initdb` default: data checksums açık (opsiyon: `--no-data-checksums`; `pg_upgrade` checksum uyumu ister)
- MD5 password auth deprecated (ileride kaldırılacak)
- `VACUUM/ANALYZE` inheritance children’ları da işler (`ONLY` ile eski davranış)
- CSV `COPY FROM` artık `\\.` satırını EOF gibi davranmaz (eski `psql` ile `\\copy` davranışına dikkat)

### Bu projeye etkisi (özet)

- Şu an aktif kullanılan sunucu `PostgreSQL 14.20`. Major upgrade (14 → 18) düşünülürse: yedek/restore, `pg_upgrade`, auth yöntemi (MD5), checksum ayarları ve client araç sürümleri planlanmalı.
- Flutter tarafında proje zaten `3.38.6` ile çalışıyor; ama breaking changes linklerindeki maddeler (özellikle UI bileşen API/deprecation’ları) için kod taraması yapılmalı.

