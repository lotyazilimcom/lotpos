# Veritabanı ve Yedekleme Sistem Tasarımı (UX/UI)

Bu belge, Patisyo v10 projesi için "Veritabanı Yapılandırması" ve "Bulut Yedekleme" sistemlerinin kullanıcı deneyimi ve arayüz tasarımını detaylandırır.

## 1. Bilgi Mimarisi
Ayarlar menüsü altında "Veritabanı / Yedek Ayarları" kısmında iki ana bölüm bulunacaktır:
- **Veritabanı Yapılandırması:** Sistemin veriyi nerede saklayacağını belirler.
- **Bulut Yedekleme Sistemi:** Yerel verilerin güvenliği için buluta yedekleme periyodunu ayarlar.

---

## 2. Kullanıcı Akışları

### A. İlk Kurulum (Wizard) Akışı
1. **Adım:** Karşılama ekranında "Veri Saklama Yöntemi" seçimi sunulur.
2. **Varsayılan:** "Yerel (Local Only)" seçili gelir.
3. **Seçim:** Kullanıcı bir mod seçer ve "Devam Et" der.
4. **Onay:** Seçilen modun riskleri/avantajları kısa bir modal ile onaylatılır.

### B. Sonradan Değiştirme Akışı
1. **Navigasyon:** Ayarlar > Veritabanı / Yedek Ayarları.
2. **Düzenleme:** Mevcut mod değiştirildiğinde sistem veritabanı geçişi (data migration) uyarısı verir.
3. **Yedekleme:** Yedekleme hızı ve durumu buradan güncellenir.

---

## 3. Ekran Tasarımı ve Bileşenler

### 3.1. Veritabanı Kullanım Modları
Üç mod, görsel olarak zengin "Seçim Kartları" (Selection Cards) ile sunulacaktır.

| Mod | Bileşen | Açıklama Metni | Durumlar |
| :--- | :--- | :--- | :--- |
| **Yerel (Local Only)** | Kart + Radyo Buton | "Verileriniz sadece bu cihazda saklanır. Hızlıdır, internet gerektirmez." | **Aktif/Varsayılan** |
| **Yerel + Bulut (Hybrid)** | Kart + Radyo Buton | "Veriler cihazda saklanır, anlık buluta senkronize edilir. Güvenli ve esnektir." | Aktif |
| **Sadece Bulut (Cloud Only)** | Kart + Radyo Buton | "Verileriniz sadece sunucularda saklanır. Cihazda yer kaplamaz, internet şarttır." | Aktif |

### 3.2. Yedekleme Sistemi
| Özellik | Bileşen | Varsayılan | Davranış |
| :--- | :--- | :--- | :--- |
| **Sistem Durumu** | Toggle (Aç/Kapat) | Açık | Kapatıldığında "Risk Uyarısı" modalı çıkar. |
| **Yedekleme Periyodu** | Dropdown (Açılır Menü) | 15 Günde Bir | Durum kapalıyken `Disabled` olur. |
| **Yedekleme Hedefi** | Bilgi Etiketi (Chip) | Bulut (Cloud) | Sabit/Düzenlenemez. |

---

## 4. Microcopy (Metin Paketi)

### Başlıklar ve Açıklamalar
- **Ana Başlık:** Veritabanı ve Yedekleme Yapılandırması
- **Alt Başlık:** Verilerinizin nerede tutulacağını ve ne sıklıkla yedekleneceğini yönetin.

### Yardım Metinleri (Ne işe yarar?)
- **Yerel:** "İnternet bağlantısının zayıf olduğu yerler için idealdir. Veri güvenliği tamamen sizin kontrolünüzdedir."
- **Hybrid:** "Hızdan ödün vermeden veri güvenliğini garanti altına almak isteyen profesyoneller içindir."
- **Cloud:** "Birden fazla cihazdan aynı anda çalışan ve veri kaybı riski almak istemeyen işletmeler içindir."

### Uyarılar
- **Yedekleme Kapalı:** "⚠️ Yedekleme kapalı. Veri kaybı durumunda kurtarma yapılamaz!"
- **Mod Değişimi:** "Dikkat! Veritabanı modunu değiştirmek verilerinizin aktarılmasını gerektirir."

---

## 5. Edge-Case Durumları (UI Davranışı)
- **İnternet Yokken Cloud Seçimi:** UI, Cloud modunu seçtirmemeli veya "İnternet bağlantısı kontrol ediliyor..." uyarısı vermelidir.
- **Yedekleme Kapatıldığında:** Periyod dropdown'ı pasif (greyed out) hale gelir ve üzerinde kilit ikonu belirir.
- **Hibrit Modda Yedekleme:** Hibrit mod zaten buluta yazdığı için periyodik yedekleme "Gerçek Zamanlı" olarak güncellenir ve manuel seçim opsiyonel hale gelir.

---

## 6. Tasarım Notları (UX Uzmanı Görüşü)
- **Güven Tasarımı:** Kullanıcıya "Verileriniz Güvende" hissini vermek için yeşil tikler ve kilit ikonları kullanılmalı.
- **Aptal Seviyesi:** Teknik terimler (Migration, Sync, Hybrid) yerine "Aktarma", "Eşitleme", "Karma" kelimeleri parantez içinde kullanılmalıdır.
