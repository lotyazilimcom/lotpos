import '../../../../servisler/ayarlar_veritabani_servisi.dart';
import '../modeller/genel_ayarlar_model.dart';

class GenelAyarlarVeriKaynagi {
  Future<GenelAyarlarModel> ayarlariGetir() async {
    try {
      return await AyarlarVeritabaniServisi().genelAyarlariGetir();
    } catch (e) {
      // Hata durumunda varsayılanları dön
      return GenelAyarlarModel();
    }
  }

  Future<void> ayarlariKaydet(GenelAyarlarModel ayarlar) async {
    await AyarlarVeritabaniServisi().genelAyarlariKaydet(ayarlar);
  }
}
