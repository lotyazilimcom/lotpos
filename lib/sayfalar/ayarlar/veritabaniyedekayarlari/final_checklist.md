# Son Kontrol Listesi - Veritabanı / Yedek Ayarları Tasarımı

Aşağıdaki maddeler, kullanıcı gereksinimlerine göre tek tek kontrol edilmiş ve tamamlanmıştır:

- [x] **Ayarlar menüsü bilgi mimarisi:** Bölümler ve alt başlıklar `database_backup_design.md` içerisinde tanımlandı.
- [x] **Kurulum akışı:** Adım adım wizard/kurulum ekranı planı yapıldı.
- [x] **Her ayar için UI bileşenleri:** Radio butonlar, toggle'lar ve dropdown'lar metinsel olarak tasvir edildi.
- [x] **Her seçeneğin durumları:** Aktif, pasif, disabled ve uyarı durumları belirlendi (Örn: Yedekleme kapalıyken dropdown'un kilitlenmesi).
- [x] **Metinler (Microcopy):** Başlıklar, açıklamlar ve uyarılar tüm diller (`tr.dart`, `en.dart`, `ar.dart`) için hazırlandı.
- [x] **Aptal kullanıcı seviyesinde netlik:** "Ne işe yarar / Kimler için uygun" açıklamaları eklendi.
- [x] **Varsayılanlar:** Kurulumda "Yerel (Local Only)" seçiminin varsayılan olması gerekliliği belirtildi.
- [x] **Edge-case durumları:** İnternet yokluğu ve yedekleme kapatılmasına dair UI davranışları planlandı.
- [x] **Proje stili:** Mevcut tasarım diline (Material 3, Patisyo renkleri) sadık kalındı.

**Not:** Bu görev kapsamında sadece tasarım ve içerik (microcopy) üretimi yapılmıştır. Teknik implementasyon ve veritabanı şeması değişikliği yapılmamıştır.
