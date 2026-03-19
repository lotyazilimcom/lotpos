# 📋 LOSPOS KAPSAMLI TEST CHECKLIST

## 🎯 Hedef
Tüm modüllerin eksiksiz test edilmesi. Her modülde:
- ✅ Listeleme (100 kayıt)
- ✅ Ekleme
- ✅ Düzenleme
- ✅ Silme (tek + toplu)
- ✅ Arama & Filtreleme
- ✅ DataTable sayfalama

---

## 📦 1. DEPOLAR MODÜLü

### 1.1 Depo Listeleme
- [ ] Menüden "Depolar" sayfasını aç
- [ ] 5 deponun listelendiğini doğrula
- [ ] Sütunları kontrol et: Kod, Ad, Adres, Sorumlu, Telefon, Durum

### 1.2 Depo Arama/Filtreleme
- [ ] Arama kutusuna "Merkez" yaz → 1 sonuç
- [ ] Arama kutusuna "Depo" yaz → Tüm sonuçlar
- [ ] Aktif/Pasif filtresi dene

### 1.3 Depo Ekleme
- [ ] "Yeni Depo" butonuna tıkla
- [ ] Tüm alanları doldur (kod: D006, ad: Test Depo)
- [ ] Kaydet → Başarı mesajı görülmeli
- [ ] Listede yeni depoyu doğrula

### 1.4 Depo Düzenleme
- [ ] Listeden bir depo seç → Detay aç
- [ ] Adres alanını değiştir
- [ ] Kaydet → Değişikliği doğrula

### 1.5 Depo Silme
- [ ] Pasif olan depoyu seç
- [ ] Sil → Onay dialogu çıkmalı
- [ ] Onayla → Depo silinmeli

---

## 🛒 2. ÜRÜNLER MODÜLü

### 2.1 Ürün Listeleme
- [ ] Menüden "Ürünler" sayfasını aç
- [ ] 100 ürünün listelendiğini doğrula
- [ ] Sayfalama çalışıyor mu? (25, 50, 100 kayıt/sayfa)
- [ ] Sütunları kontrol et: Kod, Ad, Birim, Fiyatlar, KDV, Stok

### 2.2 Ürün Arama/Filtreleme
- [ ] Arama: "Domates" → İlgili ürünler
- [ ] Arama: Barkod numarası ile
- [ ] Filtre: Grup = "Sebze"
- [ ] Filtre: KDV = %18
- [ ] Filtre: Aktif/Pasif

### 2.3 Ürün Ekleme
- [ ] "Yeni Ürün" butonuna tıkla
- [ ] Zorunlu alanları doldur
- [ ] Barkod otomatik oluşturuluyor mu?
- [ ] Kaydet → Başarı mesajı

### 2.4 Ürün Düzenleme
- [ ] Bir ürün seç → Detay aç
- [ ] Fiyat değiştir
- [ ] Kaydet → Değişikliği doğrula

### 2.5 Ürün Silme
- [ ] Bir ürün seç → Sil
- [ ] Toplu seçim yap (5 ürün) → Toplu sil

### 2.6 Toplu İşlemler
- [ ] Toplu fiyat güncelleme (%10 artır)
- [ ] Toplu KDV güncelleme

---

## 👥 3. CARİ HESAPLAR MODÜLü

### 3.1 Cari Hesap Listeleme
- [ ] Menüden "Cari Hesaplar" sayfasını aç
- [ ] 100 hesabın listelendiğini doğrula
- [ ] Sayfalama kontrol

### 3.2 Cari Hesap Arama/Filtreleme
- [ ] Arama: Firma adı ile
- [ ] Arama: Cari kodu ile
- [ ] Filtre: Hesap Türü = "Alıcı"
- [ ] Filtre: Şehir = "İstanbul"

### 3.3 Cari Hesap Ekleme
- [ ] "Yeni Cari Hesap" tıkla
- [ ] Zorunlu alanları doldur
- [ ] Vergi bilgilerini gir
- [ ] Kaydet

### 3.4 Cari Hesap Düzenleme
- [ ] Bir hesap seç → Detay
- [ ] Telefon güncelle
- [ ] Kaydet

### 3.5 Cari Hesap Silme
- [ ] Bir hesap sil
- [ ] Toplu seçim + toplu sil

### 3.6 Cari İşlemler (Son Hareketler)
- [ ] Bir cari hesap aç
- [ ] "Son Hareketler" sekmesini kontrol et
- [ ] Borç/Alacak bakiyeleri doğru mu?

---

## 💰 4. KASALAR MODÜLü

### 4.1 Kasa Listeleme
- [ ] "Kasalar" sayfasını aç
- [ ] 3 kasanın listelendiğini doğrula

### 4.2 Kasa Para Girişi
- [ ] "Para Girişi" butonuna tıkla
- [ ] Tutar gir: 5000 TL
- [ ] Cari hesap seç (müşteri ödeme)
- [ ] Açıklama yaz
- [ ] Kaydet → Bakiye güncellenmeli

### 4.3 Kasa Para Çıkışı
- [ ] "Para Çıkışı" butonuna tıkla
- [ ] Tutar gir: 2000 TL
- [ ] Cari hesap seç (tedarikçi ödeme)
- [ ] Kaydet → Bakiye azalmalı

### 4.4 Kasa İşlemler Listesi
- [ ] Kasayı tıkla → İşlemler listesi
- [ ] Tarih filtresi uygula
- [ ] İşlem türü filtresi

### 4.5 Kasa Ekleme/Düzenleme/Silme
- [ ] Yeni kasa ekle
- [ ] Kasa adını düzenle
- [ ] Boş kasayı sil

---

## 🏦 5. BANKALAR MODÜLü

### 5.1 Banka Listeleme
- [ ] "Bankalar" sayfasını aç
- [ ] 5 banka hesabının listelendiğini doğrula

### 5.2 Banka Para Girişi
- [ ] "Para Girişi" → Havale/EFT simülasyonu
- [ ] Tutar + Cari seç
- [ ] Kaydet

### 5.3 Banka Para Çıkışı
- [ ] "Para Çıkışı"
- [ ] Kaydet

### 5.4 Banka Transferi
- [ ] Kasadan bankaya transfer
- [ ] Bankadan kasaya transfer
- [ ] Her iki tarafın bakiyesini kontrol et

### 5.5 Banka Ekleme/Düzenleme/Silme
- [ ] Yeni banka hesabı ekle
- [ ] IBAN düzenle
- [ ] Boş hesabı sil

---

## 📝 6. ÇEKLER MODÜLü

### 6.1 Çek Listeleme
- [ ] "Çekler" sayfasını aç
- [ ] 100 çekin (50 alınan + 50 verilen) listelendiğini doğrula

### 6.2 Çek Filtreleme
- [ ] Filtre: Tür = "Alınan Çek"
- [ ] Filtre: Tür = "Verilen Çek"
- [ ] Filtre: Durum = "Beklemede"
- [ ] Tarih aralığı filtresi

### 6.3 Çek Alma (Tahsilat)
- [ ] "Çek Al" butonuna tıkla
- [ ] Tüm alanları doldur
- [ ] Kaydet → Cari bakiye güncellenmeli

### 6.4 Çek Verme
- [ ] "Çek Ver" butonuna tıkla
- [ ] Kaydet

### 6.5 Çek Tahsil Etme
- [ ] Beklemede bir çek seç
- [ ] "Tahsil Et" → Kasaya aktar
- [ ] Kasa bakiyesi artmalı

### 6.6 Çek Ciro Etme
- [ ] Bir çek seç → "Ciro Et"
- [ ] Yeni cari hesap seç
- [ ] Kaydet

### 6.7 Çek Silme
- [ ] Bir çek sil

---

## 📄 7. SENETLER MODÜLü

### 7.1 Senet Listeleme
- [ ] 100 senedin listelendiğini doğrula

### 7.2 Senet Filtreleme
- [ ] Alınan/Verilen filtresi
- [ ] Durum filtresi

### 7.3 Senet Alma
- [ ] "Senet Al" → Kaydet

### 7.4 Senet Verme
- [ ] "Senet Ver" → Kaydet

### 7.5 Senet Tahsil Etme
- [ ] Bankaya tahsil

### 7.6 Senet Ciro Etme
- [ ] Ciro işlemi

---

## 💳 8. KREDİ KARTLARI/POS MODÜLü

### 8.1 POS Listeleme
- [ ] 3 POS cihazının listelendiğini doğrula

### 8.2 Kredi Kartı Tahsilatı
- [ ] "Tahsilat" → Tutar gir
- [ ] Cari seç
- [ ] Kaydet

### 8.3 POS Ekleme/Düzenleme/Silme
- [ ] Yeni POS ekle
- [ ] Düzenle
- [ ] Sil

---

## 🛍️ 9. ALIŞ İŞLEMİ (Purchase)

### 9.1 Alış Yap
- [ ] "Alış Yap" sayfasını aç
- [ ] Tedarikçi (cari) seç veya oluştur
- [ ] 5 farklı ürün ekle:
  - Ürün kodu veya adı ile ara
  - Miktar, fiyat, KDV gir
  - İskonto uygula
- [ ] Depo seç
- [ ] "Alışı Tamamla" tıkla

### 9.2 Alış Tamamla Sayfası
- [ ] Belge türü seç (Fatura/İrsaliye)
- [ ] Fatura/İrsaliye numarası gir
- [ ] Vade tarihi seç
- [ ] Ödeme yöntemi seç (Kasa/Banka)
- [ ] Kaydet

### 9.3 Alış Sonrası Kontroller
- [ ] Cari hesap bakiyesi güncellendi mi?
- [ ] Ürün stokları arttı mı?
- [ ] Kasa/Banka bakiyesi değişti mi? (nakit ödeme ise)

---

## 🛒 10. SATIŞ İŞLEMİ (Sale)

### 10.1 Satış Yap
- [ ] "Satış Yap" sayfasını aç
- [ ] Müşteri (cari) seç
- [ ] 5 farklı ürün ekle
- [ ] Miktar, fiyat kontrol
- [ ] "Satışı Tamamla"

### 10.2 Satış Tamamla Sayfası
- [ ] Belge türü seç
- [ ] Ödeme al (kısmen veya tam)
- [ ] Kaydet

### 10.3 Satış Sonrası Kontroller
- [ ] Cari hesap bakiyesi güncellendi mi?
- [ ] Ürün stokları azaldı mı?
- [ ] Kasa bakiyesi arttı mı?

---

## 📦 11. SEVKİYAT İŞLEMLERİ

### 11.1 Depolar Arası Transfer
- [ ] "Sevkiyat Oluştur" 
- [ ] Kaynak depo seç
- [ ] Hedef depo seç
- [ ] Ürünler ekle
- [ ] Kaydet
- [ ] Her iki deponun stoklarını kontrol et

### 11.2 Sevkiyat Listesi
- [ ] Tüm sevkiyatları listele
- [ ] Depo filtresi uygula
- [ ] Tarih filtresi uygula

### 11.3 Sevkiyat Silme
- [ ] Bir sevkiyat sil → Stoklar geri dönmeli

---

## ⚙️ 12. AYARLAR MODÜLü

### 12.1 Genel Ayarlar
- [ ] Sayı formatlarını değiştir (binlik/ondalık)
- [ ] Kaydet → Tüm sayfalarda formatı kontrol et

### 12.2 Kullanıcılar
- [ ] 10 kullanıcının listelendiğini doğrula
- [ ] Yeni kullanıcı ekle
- [ ] Kullanıcı düzenle
- [ ] Kullanıcı sil
- [ ] Oturumu kapat → Yeni kullanıcı ile giriş yap

### 12.3 Roller ve İzinler
- [ ] 5 rolün listelendiğini doğrula
- [ ] Yeni rol ekle
- [ ] İzinleri düzenle
- [ ] Rol sil

### 12.4 Şirket Ayarları
- [ ] Şirket bilgilerini düzenle
- [ ] Logo yükle
- [ ] Kaydet

### 12.5 Dil Ayarları
- [ ] Dil değiştir (TR → EN → TR)
- [ ] Tüm metinlerin değiştiğini doğrula

---

## 🔍 13. GENEL UI/UX TESTLERİ

### 13.1 DataTable Davranışları
- [ ] Sütun sıralama (A-Z, Z-A)
- [ ] Sayfalama (ilk, son, sonraki, önceki)
- [ ] Kayıt/sayfa değişikliği
- [ ] Toplu seçim (tümünü seç/kaldır)

### 13.2 Form Doğrulama
- [ ] Boş zorunlu alanlarla kaydet → Hata mesajı
- [ ] Geçersiz format → Hata mesajı
- [ ] Yinelenen kod → Hata mesajı

### 13.3 Responsive Tasarım
- [ ] Küçük ekranda menü daraltma
- [ ] Tablo scroll çalışıyor mu?

### 13.4 Klavye Kısayolları
- [ ] ESC → Modal/sayfa kapat
- [ ] Enter → Form gönder (uygun yerlerde)

### 13.5 Bildirimler
- [ ] Başarı mesajları yeşil
- [ ] Hata mesajları kırmızı
- [ ] Uyarı mesajları sarı

---

## 🐛 14. HATA RAPORLAMA ŞABLONU

Bulunan her hata için:

```
### Hata #X
- **Modül:** [örn: Kasalar]
- **Sayfa:** [örn: Para Giriş]
- **Adımlar:**
  1. ...
  2. ...
- **Beklenen:** ...
- **Gerçekleşen:** ...
- **Ekran Görüntüsü:** [varsa]
```

---

## ✅ TEST SONUÇ ÖZETİ

| Modül | Listeleme | Ekleme | Düzenleme | Silme | Arama | Entegrasyon |
|-------|-----------|--------|-----------|-------|-------|-------------|
| Depolar | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ |
| Ürünler | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ |
| Cari Hesaplar | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ |
| Kasalar | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ |
| Bankalar | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ |
| Çekler | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ |
| Senetler | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ |
| Kredi Kartları | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ |
| Alış İşlemi | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ |
| Satış İşlemi | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ |
| Sevkiyat | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ |
| Ayarlar | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ |

**⬜ = Test Edilmedi | ✅ = Başarılı | ❌ = Hatalı**

---

## 📅 TEST TAKVİMİ

- [ ] **Gün 1:** Depolar + Ürünler + Cari Hesaplar
- [ ] **Gün 2:** Kasalar + Bankalar + Transferler
- [ ] **Gün 3:** Çekler + Senetler + Kredi Kartları
- [ ] **Gün 4:** Alış + Satış + Sevkiyat
- [ ] **Gün 5:** Ayarlar + Genel UI + Hata Düzeltme

---

**Hazırlayan:** Test Data Seeder  
**Tarih:** 2024-12-14
