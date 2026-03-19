---
description: Lospos projesinde yeni sayfa oluştururken uyulması gereken standartlar ve kullanılması gereken yardımcı sınıflar
---

# 📋 Lospos Sayfa Geliştirme Standartları

Bu döküman, Lospos projesinde yeni bir sayfa veya bileşen oluştururken uyulması gereken tüm standartları, kısayolları, renklendirme kurallarını ve yardımcı sınıfların kullanımını içerir.

---

## 🎨 1. İŞLEM TÜRÜ RENKLENDİRME

**Dosya:** `lib/yardimcilar/islem_turu_renkleri.dart`

DataTable'larda işlem türlerine göre satır renklendirmesi için `IslemTuruRenkleri` sınıfını kullanın.

### Renk Kategorileri:

| İşlem Türü | Arkaplan | Metin | İkon |
|------------|----------|-------|------|
| **Açılış Stoğu** | `#E8EAF6` (Indigo 50) | `#3949AB` (Indigo 600) | `#5C6BC0` (Indigo 400) |
| **Devir Girdi/Çıktı** | `#F3E5F5` (Purple 50) | `#7B1FA2` (Purple 700) | `#AB47BC` (Purple 400) |
| **Üretim** | `#FFF8E1` (Amber 50) | `#FF8F00` (Amber 800) | `#FFB300` (Amber 600) |
| **Sevkiyat Girdi** | `#E0F2F1` (Teal 50) | `#00796B` (Teal 700) | `#26A69A` (Teal 400) |
| **Sevkiyat Çıktı** | `#FFEBEE` (Red 50) | `#C62828` (Red 800) | `#EF5350` (Red 400) |
| **Varsayılan Girdi** | `#E8F5E9` (Green 50) | `#2E7D32` (Green 700) | `#66BB6A` (Green 400) |
| **Varsayılan Çıktı** | `#FCE4EC` (Pink 50) | `#C2185B` (Pink 700) | `#EC407A` (Pink 400) |

### Kullanım:

```dart
import '../../yardimcilar/islem_turu_renkleri.dart';

// Arkaplan rengi
final bgColor = IslemTuruRenkleri.arkaplanRengiGetir(customTypeLabel, isIncoming);

// Metin rengi  
final textColor = IslemTuruRenkleri.metinRengiGetir(customTypeLabel, isIncoming);

// İkon rengi
final iconColor = IslemTuruRenkleri.ikonRengiGetir(customTypeLabel, isIncoming);
```

---

## ⌨️ 2. KLAVYE KISAYOLLARI

### Liste Sayfaları (urunler_sayfasi, uretimler_sayfasi, depolar_sayfasi)

| Kısayol | İşlev | Koşul | Popup Etiket |
|---------|-------|-------|--------------|
| **ESC** | Overlay kapat / Arama temizle / Filtre sıfırla | - | - |
| **F1** | Yeni Ekle | - | ✅ |
| **F2** | Seçili Düzenle | Satır seçili olmalı | ✅ |
| **F3** | Ara (Arama kutusuna odaklan) | - | - |
| **F5** | Yenile | - | - |
| **F6** | Aktif/Pasif Toggle | Satır seçili olmalı | ✅ |
| **F7** | Yazdır | - | ✅ |
| **F8** | Seçilileri Toplu Sil | Seçili öğeler olmalı | - |
| **F10** | Stok İşlemi (Devir/Üretim/Sevkiyat) | Duruma göre | ✅ |
| **F11** | Fiyat Değiştir | - | ✅ |
| **F12** | KDV Değiştir | - | ✅ |
| **Delete** | Seçili Satırı Sil | Satır seçili olmalı | ✅ |
| **Numpad Delete** | Seçili Satırı Sil | Satır seçili olmalı | - |
| **↑ / ↓ Ok Tuşları** | Satırlar arası / Detay satırları arası navigasyon | - | - |
| **Enter** | Satırı Aç/Kapat (Genişlet/Daralt) | Ana satır seçili olmalı | - |

**Önemli Notlar:**
- Ok tuşlarıyla satır seçimi yapıldığında `_selectedRowId` otomatik güncellenir
- Ana satır açıkken ok tuşları detay satırlarında gezinir
- Enter ile satır genişletilir/daraltılır
- **Auto-scroll:** Ok tuşlarıyla gezinildiğinde seçili satır otomatik olarak görünür hale gelir (`Scrollable.ensureVisible`)
- **Seçim Temizleme:** DataTable dışına (sidebar, boş alan vb.) tıklandığında tüm seçimler otomatik olarak temizlenir (`onClearSelection` callback'i ile)

### Ekleme/Düzenleme Sayfaları (urun_ekle, uretim_ekle)

| Kısayol | İşlev | Popup Etiket |
|---------|-------|--------------|
| **ESC** | Geri | ✅ |
| **ENTER** | Kaydet | ✅ |
| **F4** | Temizle | ✅ |
| **F9** | Resim Ekle | ✅ |

### İşlem Sayfaları (sevkiyat_olustur, devir_yap, uretim_yap)

| Kısayol | İşlev |
|---------|-------|
| **ESC** | Geri |
| **ENTER** | Kaydet |
| **F3** | Ürün/Üretim Ara |
| **F8** | Seçilileri Sil |

### Son Hareketler (Detay Satırları) Popup Menüsü

**Not:** Detay satırları için F2 ve Del kısayolları, satır **tıklanarak seçildiğinde** (mavi arka plan) aktif olur. Detay satırı seçiliyken F2 veya Del'e basıldığında ilgili işlem yapılır; seçili değilse ana satır için işlem yapılır.

| Kısayol | İşlev | Popup Etiket |
|---------|-------|--------------|
| **F2** | Hareketi Düzenle | ✅ |
| **Del** | Hareketi Sil | ✅ |

**Desteklenen İşlem Türleri (F2 ile düzenlenebilir):**

| Sayfa | İşlem Türleri |
|-------|---------------|
| **Ürünler** | Açılış Stoğu, Devir Girdi, Devir Çıktı, Sevkiyat, Üretim |
| **Üretimler** | Açılış Stoğu, Üretim (Girdi), Üretim (Çıktı) |
| **Depolar** | Sevkiyat, Açılış Stoğu, Giriş, Çıkış, Devir, Üretim |

### Uygulama Şablonu:

```dart
import 'package:flutter/services.dart';

// State içinde FocusNode tanımla
final FocusNode _searchFocusNode = FocusNode();

// dispose() içinde dispose et
@override
void dispose() {
  _searchFocusNode.dispose();
  super.dispose();
}

// build() içinde:
return Scaffold(
  body: Focus(
    autofocus: true,
    child: CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): _handleEscape,
        const SingleActivator(LogicalKeyboardKey.f1): _showAddDialog,
        const SingleActivator(LogicalKeyboardKey.f2): () {
          if (_selectedRowId == null) return;
          final item = _cachedItems.firstWhere((i) => i.id == _selectedRowId);
          _showEditDialog(item);
        },
        const SingleActivator(LogicalKeyboardKey.f3): () {
          // F3: Arama kutusuna odaklan
          _searchFocusNode.requestFocus();
        },
        const SingleActivator(LogicalKeyboardKey.f5): _fetchData,
        const SingleActivator(LogicalKeyboardKey.f6): () {
          if (_selectedRowId == null) return;
          final item = _cachedItems.firstWhere((i) => i.id == _selectedRowId);
          _toggleStatus(item, !item.aktifMi);
        },
        const SingleActivator(LogicalKeyboardKey.f7): _handlePrint,
        const SingleActivator(LogicalKeyboardKey.f8): () {
          if (_selectedIds.isEmpty) return;
          _deleteSelected();
        },
        const SingleActivator(LogicalKeyboardKey.delete): () {
          if (_selectedRowId == null) return;
          final item = _cachedItems.firstWhere((i) => i.id == _selectedRowId);
          _deleteItem(item);
        },
        const SingleActivator(LogicalKeyboardKey.numpadDecimal): () {
          // Numpad Delete - aynı işlev
          if (_selectedRowId == null) return;
          final item = _cachedItems.firstWhere((i) => i.id == _selectedRowId);
          _deleteItem(item);
        },
      },
      child: // ... içerik
    ),
  ),
);

// GenisletilebilirTablo'ya searchFocusNode ve onClearSelection geçir:
GenisletilebilirTablo<Model>(
  searchFocusNode: _searchFocusNode,
  onClearSelection: _clearAllTableSelections, // Tablo dışına tıklanınca seçimleri temizle
  // ... diğer parametreler
)

// _clearAllTableSelections fonksiyonu:
void _clearAllTableSelections() {
  setState(() {
    _selectedIds.clear();
    _selectedDetailIds.clear();
    _selectedRowId = null;
    // ... diğer seçim state'lerini temizle
  });
}
```

### Popup Menüde F Etiketi Ekleme:

```dart
PopupMenuItem<String>(
  value: 'edit',
  child: Row(
    children: [
      const Icon(Icons.edit_outlined, size: 20, color: Color(0xFF4A4A4A)),
      const SizedBox(width: 12),
      Text(tr('common.edit'), style: const TextStyle(...)),
      const Spacer(),
      Text(
        'F2',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Colors.grey.shade400,
        ),
      ),
    ],
  ),
),
```

---

## 💬 3. MESAJ GÖSTERME

**Dosya:** `lib/yardimcilar/mesaj_yardimcisi.dart`

### Kullanım:

```dart
import '../../yardimcilar/mesaj_yardimcisi.dart';

// Başarı mesajı (yeşil, 2 saniye)
MesajYardimcisi.basariGoster(context, tr('common.saved_successfully'));

// Hata mesajı (kırmızı, 4 saniye)
MesajYardimcisi.hataGoster(context, '${tr('common.error')}: $e');

// Bilgi mesajı (mavi, 3 saniye)
MesajYardimcisi.bilgiGoster(context, 'Bilgilendirme mesajı');

// Uyarı mesajı (turuncu, 3 saniye)
MesajYardimcisi.uyariGoster(context, 'Uyarı mesajı');
```

---

## 🔢 4. SAYI FORMATLAMA

**Dosya:** `lib/yardimcilar/format_yardimcisi.dart`

### Fonksiyonlar:

```dart
import '../../yardimcilar/format_yardimcisi.dart';

// Binlik ayraçlı sayı formatı (ondalık kısım yoksa göstermez)
FormatYardimcisi.sayiFormatla(
  1234567.89,
  binlik: _genelAyarlar.binlikAyiraci,  // '.'
  ondalik: _genelAyarlar.ondalikAyiraci, // ','
  decimalDigits: _genelAyarlar.fiyatOndalik, // 2
);
// Çıktı: "1.234.567,89"

// Sabit ondalık basamaklı format (her zaman ondalık gösterir)
FormatYardimcisi.sayiFormatlaOndalikli(
  1234567,
  binlik: '.',
  ondalik: ',',
  decimalDigits: 2,
);
// Çıktı: "1.234.567,00"

// KDV/Oran formatı (tam sayıysa ondalık göstermez)
FormatYardimcisi.sayiFormatlaOran(18.5, ...);
// Çıktı: "18,50" veya tam sayı ise "18"

// String'den double'a parse
final deger = FormatYardimcisi.parseDouble(
  '1.234,56',
  binlik: '.',
  ondalik: ',',
);
// Çıktı: 1234.56

// IBAN formatı (4'erli gruplar)
FormatYardimcisi.ibanFormatla('TR1234567890123456789012');
// Çıktı: "TR12 3456 7890 1234 5678 9012"
```

### Input Formatter:

```dart
TextField(
  inputFormatters: [
    CurrencyInputFormatter(
      binlik: _genelAyarlar.binlikAyiraci,
      ondalik: _genelAyarlar.ondalikAyiraci,
      maxDecimalDigits: _genelAyarlar.fiyatOndalik,
    ),
  ],
)
```

---

## 🎨 5. COLOR EXTENSIONS

**Dosya:** `lib/yardimcilar/color_extensions.dart`

`withOpacity()` deprecated uyarısını önlemek için:

```dart
import '../../yardimcilar/color_extensions.dart';

// ❌ Eski (deprecated)
Colors.blue.withOpacity(0.5)

// ✅ Yeni
Colors.blue.withValues(alpha: 0.5)
```

---

## 🖨️ 6. YAZDIRMA SERVİSLERİ

### Basit PDF (PrintService)

**Dosya:** `lib/yardimcilar/yazdirma/print_service.dart`

```dart
import '../../yardimcilar/yazdirma/print_service.dart';

final pdfBytes = await PrintService.generatePdf(
  format: PdfPageFormat.a4,
  title: 'Rapor Başlığı',
  headers: ['Kod', 'Ad', 'Fiyat'],
  data: [
    ['001', 'Ürün A', '100,00'],
    ['002', 'Ürün B', '200,00'],
  ],
);
```

### Genişletilebilir PDF (GenisletilebilirPrintService)

**Dosya:** `lib/yardimcilar/yazdirma/genisletilebilir_print_service.dart`

Detail satırları, resimler ve alt tablolar içeren master-detail yazdırma için:

```dart
import '../../yardimcilar/yazdirma/genisletilebilir_print_service.dart';

final pdfBytes = await GenisletilebilirPrintService.generatePdf(
  format: PdfPageFormat.a4,
  title: 'Ürün Listesi',
  headers: ['Kod', 'Ad', 'Fiyat'],
  data: rows.map((item) => ExpandableRowData(
    mainRow: [item.kod, item.ad, item.fiyat],
    details: {
      'Birim': item.birim,
      'Grup': item.grup,
    },
    images: item.resimler,
    transactions: hasTransactions ? DetailTable(...) : null,
  )).toList(),
  printFeatures: true,
  showHeaders: true,
  showBackground: true,
  dateInterval: '01.01.2024 - 31.12.2024',
);
```

### Excel Export (GenisletilebilirExcelService)

**Dosya:** `lib/yardimcilar/yazdirma/genisletilebilir_excel_service.dart`

```dart
import '../../yardimcilar/yazdirma/genisletilebilir_excel_service.dart';

final excelBytes = await GenisletilebilirExcelService.generateExcel(
  title: 'Ürün Listesi',
  headers: ['Kod', 'Ad', 'Fiyat'],
  data: expandableRows,
  printFeatures: true,
  dateInterval: '01.01.2024 - 31.12.2024',
);
```

---

## 🌐 7. ÇEVİRİ (i18n)

**Dosya:** `lib/yardimcilar/ceviri/ceviri_servisi.dart`

```dart
import '../../yardimcilar/ceviri/ceviri_servisi.dart';

// Çeviri alma
final text = tr('common.save'); // "Kaydet"

// Placeholder ile
final text = tr('common.confirm_delete_named').replaceAll('{name}', itemName);
```

---

## ⚙️ 8. GENEL AYARLAR

**Model:** `lib/sayfalar/ayarlar/genel_ayarlar/modeller/genel_ayarlar_model.dart`

Sayfa içinde genel ayarları yükleyin:

```dart
GenelAyarlarModel _genelAyarlar = GenelAyarlarModel();

@override
void initState() {
  super.initState();
  _loadSettings();
}

Future<void> _loadSettings() async {
  final settings = await AyarlarVeritabaniServisi().genelAyarlariGetir();
  setState(() => _genelAyarlar = settings);
}
```

### Önemli Ayar Alanları:

| Alan | Açıklama | Varsayılan |
|------|----------|------------|
| `varsayilanParaBirimi` | Varsayılan para birimi | `'TRY'` |
| `varsayilanKdvDurumu` | KDV dahil/hariç | `'excluded'` |
| `binlikAyiraci` | Binlik ayracı | `'.'` |
| `ondalikAyiraci` | Ondalık ayracı | `','` |
| `fiyatOndalik` | Fiyat ondalık basamak | `2` |
| `miktarOndalik` | Miktar ondalık basamak | `2` |
| `kurOndalik` | Kur ondalık basamak | `4` |
| `kullanilanParaBirimleri` | Para birimi listesi | `['TRY', 'USD', 'EUR', 'GBP']` |

---

## 📐 9. UI STANDARTLARI

### Popup Menü Stilleri:

```dart
Theme(
  data: Theme.of(context).copyWith(
    popupMenuTheme: PopupMenuThemeData(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.grey.shade300, width: 1),
      ),
      elevation: 6,
    ),
  ),
  child: PopupMenuButton(...),
)
```

### Popup MenuItem:

```dart
PopupMenuItem<String>(
  value: 'action',
  height: 44,
  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
  child: Row(
    children: [
      Icon(Icons.action_icon, size: 20, color: Color(0xFF4A4A4A)),
      const SizedBox(width: 12),
      Text('Action', style: TextStyle(
        color: Color(0xFF4A4A4A),
        fontWeight: FontWeight.w600,
        fontSize: 14,
      )),
      const Spacer(),
      Text('F1', style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: Colors.grey.shade400,
      )),
    ],
  ),
),
```

### Renk Kodları:

| Kullanım | Renk |
|----------|------|
| Ana metin | `Color(0xFF4A4A4A)` |
| Aktif/Link | `Color(0xFF1E5F74)` |
| Silme | `Color(0xFFE53935)` |
| Devre dışı | `Colors.grey.shade400` |
| F Etiketi | `Colors.grey.shade400` |

---

## 📁 10. DOSYA YAPISI

Yeni bir modül eklerken şu yapıyı takip edin:

```
lib/sayfalar/modul_adi/
├── modul_sayfasi.dart           # Ana liste sayfası
├── modul_ekle_sayfasi.dart      # Ekleme/Düzenleme sayfası
├── modul_ekle_dialog.dart       # Dialog versiyonu (opsiyonel)
├── fiyatlari_degistir_dialog.dart
├── kdvleri_degistir_dialog.dart
├── modeller/
│   └── modul_model.dart
└── veri_kaynagi/
    └── modul_veri_kaynagi.dart
```

---

## ✅ 11. KONTROL LİSTESİ

Yeni sayfa oluştururken:

- [ ] `CallbackShortcuts` ile klavye kısayolları ekledim
- [ ] Popup menülere F etiketleri ekledim
- [ ] `MesajYardimcisi` ile kullanıcı geri bildirimleri ekledim
- [ ] `FormatYardimcisi` ile sayı formatlama yaptım
- [ ] `GenelAyarlarModel` ile ayarları yükledim
- [ ] `IslemTuruRenkleri` ile işlem türü renklerini uyguladım
- [ ] `withValues(alpha: ...)` kullandım (withOpacity değil)
- [ ] `tr()` ile çevirileri kullandım
- [ ] Yazdırma işlevselliği ekledim
- [ ] ESC tuşu işlevselliği ekledim
- [ ] `onClearSelection` ile tablo dışı tıklamada seçim temizleme ekledim
