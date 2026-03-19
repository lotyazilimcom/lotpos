# 🏢 Lot Pos V 1.0 — Profesyonel Ön Muhasebe & İşletme Yönetim Yazılımı

> **Geliştirici:** LosSoft — [lotyazilim.com](https://lotyazilim.com)  
> **Teknoloji:** Flutter (Dart) + PostgreSQL  
> **Versiyon:** V 1.0  
> **Lisans Modeli:** PRO + LITE (Freemium)

---

## 📋 GENEL BAKIŞ

**Lot Pos V 1.0**, küçük ve orta ölçekli işletmeler için geliştirilmiş, **6 platformda** (macOS, Windows, Linux, iOS, Android, Tablet) çalışan **çapraz platform ön muhasebe ve işletme yönetim yazılımıdır**. Tek bir kod tabanıyla masaüstü, mobil ve tablet cihazlarda sorunsuz çalışır.

PostgreSQL veritabanı altyapısı sayesinde **milyarlarca kayıt** için optimize edilmiş, kurumsal düzeyde performans sunar. Yapay zeka entegrasyonu, çoklu dil desteği, gelişmiş lisans & güvenlik sistemi ve profesyonel baskı altyapısı ile rakiplerinden ayrışır.

---

## 🖥️ DESTEKLENEN PLATFORMLAR

| Platform | Durum | Açıklama |
|----------|-------|----------|
| 🍎 **macOS** | ✅ Tam Destek | Native masaüstü deneyimi |
| 🪟 **Windows** | ✅ Tam Destek | Native masaüstü deneyimi |
| 🐧 **Linux** | ✅ Tam Destek | Native masaüstü deneyimi |
| 📱 **iOS** | ✅ Tam Destek | iPhone uyumlu mobil arayüz |
| 🤖 **Android** | ✅ Tam Destek | Telefon uyumlu mobil arayüz |
| 📟 **Tablet** | ✅ Tam Destek | iPad/Android Tablet optimize edilmiş arayüz |

---

## 🏗️ TEKNOLOJİ YIĞINI

| Katman | Teknoloji |
|--------|-----------|
| **Frontend Framework** | Flutter (Dart SDK ^3.9.2) |
| **Veritabanı** | PostgreSQL (Native `postgres` paketi) |
| **Bulut Altyapısı** | Supabase (Lisans, kimlik doğrulama, senkronizasyon) |
| **Durum Yönetimi** | Provider |
| **Tablo Motoru** | Syncfusion Flutter DataGrid |
| **Yazdırma & PDF** | `printing` + `pdf` paketleri |
| **Excel Dışa Aktarım** | Syncfusion Flutter Xlsio |
| **Yapay Zeka** | Google Gemini API entegrasyonu |
| **Kriptografi** | `crypto` + `cryptography` (CIA seviyesi güvenlik) |
| **Ağ Keşfi** | NSD (Network Service Discovery) |
| **Pencere Yönetimi** | `window_manager` (masaüstü) |
| **Yazı Tipleri** | Inter, Roboto, Montserrat, Merriweather vb. (13 font ailesi) |

---

## 🎯 ANA MODÜLLER VE ÖZELLİKLER

### 1. 🛒 ALIM-SATIM İŞLEMLERİ

Tam kapsamlı alım-satım yönetim modülü. İşletmenizin tüm ticari operasyonlarını tek ekrandan yönetin.

#### 1.1 Hızlı Satış
- Tek tıkla hızlı satış yapma
- Favori ürün listesi desteği
- Barkod/kod ile anlık ürün ekleme
- Satış sonrası fiş/fatura yazdırma

#### 1.2 Alış Yapma (Satın Alma)
- Cari hesap bazlı alış kaydı
- Çoklu ürün ekleme & düzenleme
- Çoklu para birimi desteği (döviz kurları otomatik güncellenir)
- Sipariş referansı ile entegrasyon
- İşlem düzenleme & güncelleme
- Peşinat yönetimi
- Taksit takibi

#### 1.3 Satış Yapma
- Cari hesap bazlı satış kaydı
- Çoklu ürün ekleme, fiyat ve KDV düzenleme
- Sipariş/Teklif referansı ile otomatik doldurma
- Kur bazlı işlem yapma
- Satış tamamlama sayfası (ödeme yöntemi seçimi)
- Satış sonrası yazdırma/PDF çıktısı

#### 1.4 Perakende Satış (POS)
- Tam ekran POS (Point of Sale) modu
- Mobilde ayrı sayfa olarak açılır
- Hızlı ürün seçimi & barkod desteği
- Masaüstünde ve tablette ayrı optimize edilmiş arayüz

---

### 2. 📦 SİPARİŞLER & TEKLİFLER

#### 2.1 Siparişler
- Sipariş oluşturma (müşteri bazlı)
- Durum takibi (Beklemede, Onaylandı, Teslim Edildi, İptal vb.)
- Siparişi satışa dönüştürme
- Tarihe göre filtreleme & geçerlilik tarihi
- **Stok Rezervasyonu:** Sipariş oluşturulduğunda otomatik stok ayırma
- Gelişmiş arama & filtreleme (İlgili Hesap, Depo, Birim, Kullanıcı vb.)
- **Partitioned Table Yapısı:** 100 Milyar+ satır için optimize edilmiş

#### 2.2 Teklifler
- Teklif oluşturma & düzenleme
- Teklifi siparişe/satışa dönüştürme
- Geçerlilik tarihi takibi
- Çoklu para birimi desteği

---

### 3. 📦 ÜRÜNLER, DEPOLAR & ÜRETİM

#### 3.1 Ürün Yönetimi
- **Ürün Ekleme:** Kod, barkod, ad, grup, birim, KDV oranı, alış/satış fiyatı
- **Hızlı Ürün Ekleme:** Yapay zeka destekli toplu ürün ekleme (fotoğraftan ürün tanıma)
- **Ürün Kartı:** Detaylı ürün bilgisi, stok hareketleri, maliyet geçmişi
- **Cihaz/IMEI/Seri No Takibi:** Her ürüne cihaz bilgisi ekleme
- **Açılış Stoku Düzenleme:** Devir/transfer işlemleri
- **Toplu Fiyat Değiştirme:** Seçili ürünlere topluca fiyat güncelleme
- **Toplu KDV Değiştirme:** Seçili ürünlere topluca KDV oranı güncelleme
- **Devir İşlemi:** Depolar arası ürün transferi
- **Otomatik Kod Üretimi:** Alfanumerik veya sayısal, özelleştirilebilir format
- **Gelişmiş Filtreleme:** Grup, birim, KDV, aktiflik, depo, işlem türü, kullanıcı, tarih aralığı
- **Facet Sayıları:** Her filtre seçeneğinde dinamik kayıt sayısı gösterimi
- **Keyset Pagination:** Milyonlarca kayıt için optimize edilmiş sayfalama
- **Derin Arama (Deep Search):** Tüm alanlarda tam metin araması, `search_tags` indeksleme

#### 3.2 Depo Yönetimi
- **Depo Ekleme/Düzenleme/Silme**
- **Depolar Arası Sevkiyat:** Kaynak-hedef depo seçimi, çoklu ürün transferi
- **Depo İstatistikleri:** Toplam ürün miktarı, girdi/çıktı toplamları
- **Stok Senkronizasyonu:** Otomatik stok tutarlılık denetimi
- **Varsayılan Depo Atama**
- **Gelişmiş Filtreleme & Arama**

#### 3.3 Üretim (Reçete Yönetimi)
- **Üretim Kartı Oluşturma:** Ürün adı, reçete bileşenleri, birim, grup
- **Üretim Yapma:** Hammadde tüketimi + mamül üretimi
- **Maliyet Hesaplama:** Ağırlıklı Ortalama Maliyet (Weighted Average Cost)
- **Stok Hareketi Entegrasyonu:** Üretim otomatik stok günceller
- **Toplu Fiyat/KDV Değiştirme**
- **Gelişmiş Filtreleme & Arama**

---

### 4. 👥 CARİ HESAPLAR

- **Cari Hesap Ekleme:** Ad, kod, telefon, e-posta, adres, vergi dairesi, vergi no, TC kimlik no
- **Cari Kartı (Detay Sayfası):** Tüm işlem geçmişi, borç/alacak durumu, bakiye takibi
- **Borç-Alacak Dekontu İşleme**
- **Cari Açılış/Devir Düzenleme**
- **Cari Para Al/Ver İşlemi:** Nakit, banka, kredi kartı vb. ödeme yöntemi seçimi
- **Gelişmiş Arama:** Türkçe karakter normalize, `search_tags` indeksleme
- **Partitioned Table:** İşlem tabloları aylık partition ile optimize edilmiş
- **Facet İstatistikleri:** Dinamik filtre sayıları
- **Peşinat Yönetimi:** Satış/alış peşinat takibi
- **Taksit Takibi:** Taksitli ödemelerin detaylı izlenmesi

---

### 5. 💰 KASA YÖNETİMİ

- **Çoklu Kasa:** Sınırsız kasa tanımlama
- **Kasa Ekleme/Düzenleme/Silme**
- **Para Girişi & Çıkışı:** Detaylı açıklama, cari bağlantısı, personel bağlantısı
- **Varsayılan Kasa:** Otomatik seçim için varsayılan kasa belirleme
- **Sanal Kasa (Diğer Ödemeler):** Otomatik oluşturulan sistem kasası
- **Kasa İşlem Geçmişi:** Tarih aralıklı, kullanıcı bazlı filtreleme
- **İşlem Türleri:** Para Girişi, Para Çıkışı, Satış Tahsilatı, Alış Ödemesi, vb.
- **Otomatik Kasa Kodu Üretimi**
- **Deep Search:** İşlem geçmişi dahil tüm alanlarda arama
- **1 Milyar+ Kayıt Optimizasyonu**

---

### 6. 🏦 BANKA YÖNETİMİ

- **Çoklu Banka Hesabı:** Sınırsız banka hesabı tanımlama
- **Para Girişi & Çıkışı:** Havale, EFT, vb. işlem türleri
- **Banka İşlem Geçmişi & Filtreleme**
- **Otomatik Kod Üretimi**
- **Gelişmiş Arama & Raporlama**

---

### 7. 💳 KREDİ KARTI YÖNETİMİ

- **Çoklu Kredi Kartı Tanımı**
- **Kredi Kartı Para Girişi & Çıkışı**
- **İşlem Geçmişi & Filtreleme**
- **Otomatik Kod Üretimi**
- **Gelişmiş Arama & Raporlama**

---

### 8. 📝 ÇEK YÖNETİMİ

- **Çek Alma:** Detaylı çek bilgileri (tarih, tutar, keşideci, banka, şube no)
- **Çek Verme:** Borçlu çek kaydı
- **Çek Tahsili:** Çekin bankaya yatırılması/tahsil edilmesi
- **Çek Ciro:** Çekin başka bir cariye ciro edilmesi
- **Durum Takibi:** Beklemede, Tahsil Edildi, İade, vb.
- **Gelişmiş Arama & Filtreleme**

---

### 9. 📄 SENET YÖNETİMİ

- **Senet Alma:** Detaylı senet bilgileri
- **Senet Verme:** Borçlu senet kaydı
- **Senet Tahsili:** Senedin tahsil edilmesi
- **Senet Ciro:** Ciro işlemi
- **Durum Takibi**
- **Gelişmiş Arama & Filtreleme**

---

### 10. 💸 GİDER YÖNETİMİ

- **Gider Kaydı Oluşturma:** Kategori, tutar, tarih, açıklama
- **Yapay Zeka ile Gider Fişi Analizi:** Fiş fotoğrafını çekerek otomatik gider kaydı
- **Gider Listeleme & Filtreleme**

---

### 11. 👤 PERSONEL & KULLANICI YÖNETİMİ

- **Kullanıcı Ekleme/Düzenleme:** Ad, soyad, kullanıcı adı, şifre, rol, profil resmi
- **Rol Bazlı Yetkilendirme:** Her kullanıcıya özel rol atama
- **Personel Ödeme İşlemleri:** Maaş, avans, prim vb. ödemeler
- **Personel Alacaklandırma**
- **Kullanıcı İşlem Geçmişi**

---

### 12. 🔐 ROL & İZİN YÖNETİMİ

- **Özel Rol Oluşturma:** Her modül için ayrı izin tanımlama
- **Admin Rolü:** Tam yetki (tüm modüllere erişim)
- **Granüler İzinler:** Sayfa bazlı erişim kontrolü
- **Modül Bazlı Görünürlük:** Rol yetkisine göre menü öğeleri otomatik gizlenir

---

### 13. ⚙️ AYARLAR

#### 13.1 Şirket Ayarları
- **Çoklu Şirket Desteği:** Tek uygulama ile birden fazla şirket/veritabanı yönetimi
- **Şirket Ekleme/Düzenleme/Silme**
- **Şirketler Arası Geçiş:** Anlık veritabanı değiştirme
- **Şirket Bilgileri:** Ad, adres, vergi bilgileri, logo vb.

#### 13.2 Genel Ayarlar
- **Sayısal Ayarlar:** Ondalık basamak sayısı, binlik ayracı
- **Döviz Kurları:** Otomatik güncelleme (15 dk aralıklarla, 3 farklı API kaynağı)
- **Para Birimleri:** Sınırsız para birimi ekleme/yönetme (TRY, USD, EUR, GBP, vb.)
- **Vergi Ayarları:** KDV oranları yönetimi
- **Ürün & Stok Ayarları:** Varsayılan birimler, gruplar
- **Kod Üretimi Ayarları:** Alfanumerik/sayısal, önek, uzunluk, özel format
- **Yazdırma Ayarları:** Kağıt boyutu, marj, yönlendirme
- **Bağlantı Ayarları:** Veritabanı bağlantı parametreleri

#### 13.3 Modül Yönetimi
- **Modül Açma/Kapama:** Her ana modülü ayrı ayrı aktif/pasif yapma
- **Alt Modül Kontrolü:** Üst modül kapatıldığında alt menüler otomatik kapanır
- **Anlık Menü Güncelleme:** Ayar değişikliği anında menüye yansır

#### 13.4 Yapay Zeka (AI) Ayarları
- **API Anahtarı Yönetimi:** Google Gemini API key girişi
- **Model Seçimi:** Farklı Gemini modellerini seçebilme
- **AI Destekli Özellikler:**
  - 📄 Doküman Taslağı Analizi (yazdırma şablonu oluşturma)
  - 🧾 Gider Fişi Analizi (fiş fotoğrafından otomatik gider kaydı)
  - 📦 Hızlı Ürün Ekleme (fotoğraftan toplu ürün tanıma)

#### 13.5 Veritabanı Yedekleme
- **Yedek & Geri Yükleme Ayarları**
- **Veritabanı Bakım Modu:** Tüm indeksleri manuel güncelleme

#### 13.6 Dil Ayarları
- 🇹🇷 **Türkçe** — Tam destek
- 🇬🇧 **İngilizce** — Tam destek
- 🇸🇦 **Arapça** — Tam destek
- **Çeviri Düzenleme:** Mevcut çevirileri özelleştirme
- **Yeni Dil Ekleme:** Sınırsız dil paketi oluşturma
- **Dil İçe Aktarma:** Harici çeviri dosyası yükleme

#### 13.7 Yazdırma Ayarları
- **Şablon Tasarımcısı:** Sürükle-bırak yazdırma şablonu oluşturma
- **Yapay Zeka Destekli Şablon:** Fotoğraf yükleyerek otomatik şablon tasarımı
- **Özelleştirilebilir Alanlar:** Tüm veritabanı alanlarını şablona ekleme
- **Çoklu Kağıt Boyutu:** A4, A5, Letter, Custom boyutlar
- **Yatay/Dikey Yönlendirme**

---

## 🎨 KULLANICI ARAYÜZÜ ÖZELLİKLERİ

### Responsive Tasarım
- **Masaüstü (Desktop):** Yan menü + tab sistemi, çoklu pencere desteği
- **Tablet:** Hamburger menü, optimze edilmiş kart görünümü
- **Mobil:** Tam responsive kart görünümü, kaydırmalı yan menü

### Tab Sistemi (Masaüstü)
- Birden fazla sayfayı aynı anda açma
- Tab'lar arası hızlı geçiş
- Tab kapatma & "Tümünü Kapat" desteği
- Her tab bağımsız çalışır (state korunur)

### Yan Menü (Sidebar)
- **Genişletilebilir/Daraltılabilir:** Hover ile otomatik açılma, pin ile sabitlenme
- **Hiyerarşik Menü:** Ana modüller, alt menüler, torun menüler
- **Dinamik Görünürlük:** Rol ve modül ayarlarına göre otomatik filtreleme
- **Kullanıcı Bölümü:** Profil resmi, ad-soyad, şirket bilgisi, çıkış yapma

### Veri Tabloları
- **Syncfusion DataGrid:** Kurumsal düzeyde tablo bileşeni
- **Genişletilebilir Tablo:** Özelleştirilebilir kolon genişlikleri
- **Sıralama:** Her kolonda artan/azalan sıralama
- **Sayfalama:** Keyset pagination ile milyonlarca kayıtta kesintisiz performans
- **Dışa Aktarım:** Excel ve PDF formatında dışa aktarım

---

## 🔒 GÜVENLİK & LİSANS SİSTEMİ

### Lisans Modeli
| Özellik | LITE (Ücretsiz) | PRO (Lisanslı) |
|---------|-----------------|----------------|
| Temel Modüller | ✅ | ✅ |
| Kayıt Limiti | Sınırlı | ♾️ Sınırsız |
| Yazma İşlemleri | Sınırlı | ♾️ Sınırsız |
| Yapay Zeka | ❌ | ✅ |
| Çoklu Şirket | ❌ | ✅ |
| Öncelikli Destek | ❌ | ✅ |

### Güvenlik Özellikleri
- **CIA Seviyesi Şifreleme:** XOR + Base64 + HMAC imza doğrulama
- **Donanım Bazlı Kimlik:** Her cihaz için benzersiz Hardware ID (Anakart/Cihaz ID)
- **Supabase Lisans Doğrulama:** Online + Offline lisans kontrolü
- **Offline Token Doğrulama:** İnternet olmadan da lisans geçerli
- **Heartbeat Sistemi:** Periyodik canlılık sinyali
- **Otomatik LITE Moda Düşme:** Lisans bitince uygulama kapanmaz, kısıtlı modda çalışır
- **Geo IP:** Kullanıcı konumu takibi (ülke, şehir)
- **Giriş Güvenliği:** Kullanıcı adı + şifre ile oturum açma, "Beni Hatırla" seçeneği

---

## 💱 PARA BİRİMİ & DÖVİZ SİSTEMİ

- **Çoklu Para Birimi:** TRY, USD, EUR, GBP ve daha fazlası
- **Otomatik Kur Güncelleme:** 15 dakikada bir, 3 farklı API kaynağı ile:
  - open.er-api.com (Birincil)
  - frankfurter.app (Yedek)
  - currency-api.pages.dev (Son çare)
- **Manuel Kur Girişi:** İstendiğinde elle kur belirleme
- **Çapraz Kur Hesaplama:** Tüm para birimleri arasında otomatik kur hesaplama

---

## 📊 MALİYET HESAPLAMA MODELİ

- **Ağırlıklı Ortalama Maliyet (WAC):** Her stok girişinde otomatik maliyet güncelleme
- **Running Stock (Anlık Stok):** Her hareketle anlık stok durumu takibi
- **Running Cost (Anlık Maliyet):** Her hareketle anlık maliyet güncelleme
- **Geriye Dönük Düzeltme:** İşlem düzenleme/silme sonrası tüm sonraki hareketler otomatik yeniden hesaplanır

---

## 🖨️ YAZDIRMA ALTYAPISI

- **PDF Oluşturma:** Her işlem için profesyonel PDF çıktısı
- **Dinamik Şablon Sistemi:** Sürükle-bırak tasarımcı ile özel şablon
- **Yapay Zeka Şablon Tasarımı:** Fotoğraf yükle, AI şablonu tasarlasın
- **Genişletilebilir Baskı Servisi:** Tüm modüller için merkezi yazdırma altyapısı
- **Excel Dışa Aktarım:** Tüm veri tablolarını Excel'e aktarma
- **Baskı Önizleme:** Yazdırmadan önce tam sayfa önizleme
- **Çoklu Kağıt Boyutu:** A4, A5, Letter, Custom boyutlar
- **Fatura, İrsaliye, Dekont** tarzı belge çıktıları

---

## 🧠 YAPAY ZEKA ENTEGRASYONları

| Özellik | Açıklama |
|---------|----------|
| 📄 **Doküman Taslağı Analizi** | Bir belge fotoğrafı yükleyin, AI kağıt boyutu ve alanları tanıyarak otomatik yazdırma şablonu oluştursun |
| 🧾 **Gider Fişi Analizi** | Fiş/fatura fotoğrafı çekin, AI tutarı, tarihi ve detayları okuyarak otomatik gider kaydı oluştursun |
| 📦 **Hızlı Ürün Ekleme** | Ürün fotoğrafları yükleyin, AI ürün adı, fiyat ve detayları tanıyarak toplu ürün kaydı oluştursun |

---

## 🔄 VERİTABANI MİMARİSİ

### Performans Optimizasyonları
- **Partitioned Tables:** Aylık bölümlenmiş tablolar, tarihe göre otomatik partition oluşturma
- **Keyset Pagination:** Offset yerine cursor-based sayfalama, milyarlarca kayıtta sabit performans
- **Search Tags İndeksleme:** Her kayıt için aranabilir etiket sistemi, tam metin araması
- **Batch Processing:** Toplu indeksleme ve güncelleme
- **Connection Pool:** Optimze edilmiş bağlantı havuzu yönetimi
- **SARGable Predicates:** İndeks dostu SQL sorguları
- **Facet Counts:** Dinamik filtre istatistikleri (her filtre seçeneğinde kayıt sayısı)

### Veri Bütünlüğü
- **ACID Transaction Yönetimi:** Tüm işlemler transaction içinde, çakışma korumalı
- **Referanssal Bütünlük:** Bağlantılı işlemler silme korumalı
- **Otomatik Migrasyon:** Eski tablo yapılarından yeni yapılara otomatik geçiş

---

## 📱 MOBİL ÖZEL ÖZELLİKLER

- **İlk Kurulum Ekranı:** Yerel ağ keşfi veya internet bağlantısı seçimi
- **Local Network Discovery:** Aynı ağdaki sunucuyu otomatik bulma (NSD)
- **Responsive Kart Görünümü:** Tablo yerine kaydırılabilir kart listeleri
- **Hamburger Menü:** Kaydırmalı yan menü ile kolay navigasyon
- **Touch-optimized UI:** Dokunmatik ekrana uygun büyük butonlar ve alanlar

---

## 🌐 ÇOKLU DİL SİSTEMİ

- **3 Dil Dahili:** Türkçe, İngilizce, Arapça (her biri 150.000+ karakter çeviri)
- **Sınırsız Dil Ekleme:** Yeni dil paketleri oluşturma & içe aktarma
- **Çeviri Düzenleme:** Mevcut tüm çevirileri arayüzden düzenleme
- **İşlem Türü Çevirisi:** İşlem kodları her dilde otomatik çevrilir
- **Anlık Dil Değiştirme:** Uygulama yeniden başlatmadan dil değiştirme

---

## 🏢 ÇOKLU ŞİRKET DESTEĞİ

- Tek uygulamada birden fazla şirket/veritabanı yönetimi
- Şirketler arasında tek tıkla geçiş
- Her şirket kendi veritabanına sahip (tam izolasyon)
- Şirket bazlı kullanıcı & yetkilendirme

---

## 📐 BİLEŞEN MİMARİSİ

| Bileşen | Dosya | Açıklama |
|---------|-------|----------|
| Yan Menü | `yan_menu.dart` | Hiyerarşik, responsive, rol/izin duyarlı |
| Üst Bar | `ust_bar.dart` | Sayfa başlığı, menü butonu |
| Tab Yönetici | `tab_yonetici.dart` | Çoklu tab açma/kapama/seçme |
| Genişletilebilir Tablo | `genisletilebilir_tablo.dart` | Özel DataGrid implementasyonu |
| Standart Tablo | `standart_tablo.dart` | Tekli sayfa tabloları |
| Taksit İzleme | `taksit_izleme_diyalogu.dart` | Taksit takip diyaloğu |
| Tarih Aralığı Seçici | `tarih_araligi_secici_dialog.dart` | Başlangıç-bitiş tarih seçimi |
| Onay Dialog | `onay_dialog.dart` | Silme/işlem onay diyaloğu |
| Lisans Diyalog | `lisans_diyalog.dart` | PRO aktivasyon & lisans bilgileri |
| Akıllı Açıklama Input | `akilli_aciklama_input.dart` | Otomatik tamamlamalı açıklama girişi |

---

## 📈 ÖZET İSTATİSTİKLER

| Metrik | Değer |
|--------|-------|
| Toplam Sayfa Sayısı | 60+ |
| Toplam Servis/Veritabanı Servisi | 34 |
| Toplam UI Bileşeni | 17 |
| Desteklenen Dil | 3 (+ sınırsız ekleme) |
| Desteklenen Platform | 6 |
| Font Ailesi | 13 |
| Toplam Kaynak Kodu | 5.000.000+ karakter |
| Veritabanı Optimizasyon Hedefi | 1 Milyar+ kayıt |

---

## 🎯 HEDEF KİTLE

- Küçük ve Orta Ölçekli İşletmeler (KOBİ)
- Perakende Mağazalar
- Toptan Satış İşletmeleri
- Üretim Atölyeleri
- E-Ticaret ile Entegre İşletmeler
- Çok Şubeli İşletmeler
- Serbest Meslek Erbabı

---

## 🏆 RAKİPLERDEN AYRIŞAN ÖZELLİKLER

1. **6 Platformda Tek Kod Tabanı** — macOS, Windows, Linux, iOS, Android, Tablet
2. **Yapay Zeka Entegrasyonu** — Fiş analizi, ürün tanıma, şablon tasarımı
3. **Milyarlarca Kayıt Performansı** — PostgreSQL + Partitioned Tables + Keyset Pagination
4. **Çoklu Para Birimi & Otomatik Kur** — Global ticaret desteği
5. **Sınırsız Dil Desteği** — Dahili 3 dil + sınırsız yeni dil ekleme
6. **CIA Seviyesi Güvenlik** — Donanım bazlı lisans, şifreli token doğrulama
7. **Çoklu Şirket & Veritabanı** — Tek uygulama ile çoklu iş birimi yönetimi
8. **Üretim Yönetimi** — Reçete bazlı üretim, hammadde takibi, maliyet hesaplama
9. **Freemium Model** — LITE sürüm ücretsiz, PRO ile tam özellik

---

> **© 2026 LosSoft — Tüm Hakları Saklıdır.**  
> İletişim: [lotyazilim.com](https://lotyazilim.com)
