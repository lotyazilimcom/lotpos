import 'package:flutter/foundation.dart';
import 'package:postgres/postgres.dart';
import '../sayfalar/ayarlar/yazdirma_ayarlari/modeller/yazdirma_sablonu_model.dart';
import 'veritabani_yapilandirma.dart';
import 'lisans_yazma_koruma.dart';

class YazdirmaVeritabaniServisi {
  static final YazdirmaVeritabaniServisi _instance =
      YazdirmaVeritabaniServisi._internal();
  factory YazdirmaVeritabaniServisi() => _instance;
  YazdirmaVeritabaniServisi._internal();

  Pool? _pool;

  Future<void> _poolGuncelle() async {
    // AyarlarVeritabaniServisi içindeki pool'u kullanmak en sağlıklısı
    // Ancak o private olduğu için kendi pool'umuzu oluşturuyoruz veya
    // AyarlarVeritabaniServisi üzerinden erişim sağlıyoruz.
    // Mevcut mimaride servisler bağımsız pool oluşturuyor.
    if (_pool == null) {
      final config = VeritabaniYapilandirma();
      _pool = LisansKorumaliPool(
        Pool.withEndpoints(
          [
            Endpoint(
              host: config.host,
              port: config.port,
              database: config.database,
              username: config.username,
              password: config.password,
            ),
          ],
          settings: PoolSettings(
            sslMode: config.sslMode,
            connectTimeout: config.poolConnectTimeout,
            onOpen: config.tuneConnection,
            maxConnectionCount: config.maxConnections,
          ),
        ),
      );
    }
  }

  Future<List<YazdirmaSablonuModel>> sablonlariGetir({String? docType}) async {
    await _poolGuncelle();
    if (_pool == null) return [];

    try {
      String query = 'SELECT * FROM print_templates';
      Map<String, dynamic> params = {};

      if (docType != null) {
        query += ' WHERE doc_type = @docType';
        params['docType'] = docType;
      }

      query += ' ORDER BY id DESC';

      final result = await _pool!.execute(Sql.named(query), parameters: params);
      return result
          .map((row) => YazdirmaSablonuModel.fromMap(row.toColumnMap()))
          .toList();
    } catch (e) {
      debugPrint('Şablon getirme hatası: $e');
      return [];
    }
  }

  Future<YazdirmaSablonuModel?> varsayilanSablonuGetir(String docType) async {
    await _poolGuncelle();
    if (_pool == null) return null;

    try {
      final result = await _pool!.execute(
        Sql.named(
          'SELECT * FROM print_templates WHERE doc_type = @docType AND is_default = 1 LIMIT 1',
        ),
        parameters: {'docType': docType},
      );

      if (result.isEmpty) {
        // Eğer varsayılan yoksa son ekleneni dön
        final allResult = await _pool!.execute(
          Sql.named(
            'SELECT * FROM print_templates WHERE doc_type = @docType ORDER BY id DESC LIMIT 1',
          ),
          parameters: {'docType': docType},
        );
        if (allResult.isEmpty) return null;
        return YazdirmaSablonuModel.fromMap(allResult.first.toColumnMap());
      }

      return YazdirmaSablonuModel.fromMap(result.first.toColumnMap());
    } catch (e) {
      debugPrint('Varsayılan şablon getirme hatası: $e');
      return null;
    }
  }

  Future<int?> sablonEkle(YazdirmaSablonuModel sablon) async {
    await _poolGuncelle();
    if (_pool == null) return null;

    try {
      final map = sablon.toMap();
      map.remove('id');

      // Eğer bu varsayılan ise diğerlerini temizle
      if (sablon.isDefault) {
        await _pool!.execute(
          Sql.named(
            'UPDATE print_templates SET is_default = 0 WHERE doc_type = @docType',
          ),
          parameters: {'docType': sablon.docType},
        );
      }

      final result = await _pool!.execute(
        Sql.named('''
          INSERT INTO print_templates (name, doc_type, paper_size, custom_width, custom_height, item_row_spacing, background_image, background_opacity, background_x, background_y, background_width, background_height, layout_json, is_default, is_landscape, view_matrix)
          VALUES (@name, @doc_type, @paper_size, @custom_width, @custom_height, @item_row_spacing, @background_image, @background_opacity, @background_x, @background_y, @background_width, @background_height, @layout_json, @is_default, @is_landscape, @view_matrix)
          RETURNING id
        '''),
        parameters: map,
      );

      return result.first[0] as int;
    } catch (e) {
      debugPrint('Şablon ekleme hatası: $e');
      return null;
    }
  }

  Future<bool> sablonGuncelle(YazdirmaSablonuModel sablon) async {
    await _poolGuncelle();
    if (_pool == null || sablon.id == null) return false;

    try {
      if (sablon.isDefault) {
        await _pool!.execute(
          Sql.named(
            'UPDATE print_templates SET is_default = 0 WHERE doc_type = @docType',
          ),
          parameters: {'docType': sablon.docType},
        );
      }

      await _pool!.execute(
        Sql.named('''
          UPDATE print_templates SET 
          name=@name, doc_type=@doc_type, paper_size=@paper_size, 
          custom_width=@custom_width, custom_height=@custom_height, 
          item_row_spacing=@item_row_spacing,
          background_image=@background_image, background_opacity=@background_opacity,
          background_x=@background_x, background_y=@background_y,
          background_width=@background_width, background_height=@background_height,
          layout_json=@layout_json, is_default=@is_default, is_landscape=@is_landscape,
          view_matrix=@view_matrix
          WHERE id=@id
        '''),
        parameters: sablon.toMap(),
      );
      return true;
    } catch (e) {
      debugPrint('Şablon güncelleme hatası: $e');
      return false;
    }
  }

  Future<bool> sablonSil(int id) async {
    await _poolGuncelle();
    if (_pool == null) return false;

    try {
      await _pool!.execute(
        Sql.named('DELETE FROM print_templates WHERE id = @id'),
        parameters: {'id': id},
      );
      return true;
    } catch (e) {
      debugPrint('Şablon silme hatası: $e');
      return false;
    }
  }
}
