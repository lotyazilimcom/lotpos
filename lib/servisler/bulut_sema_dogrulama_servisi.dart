import 'package:flutter/foundation.dart';
import 'package:postgres/postgres.dart';

import 'veritabani_yapilandirma.dart';

class BulutSemaDogrulamaServisi {
  static final BulutSemaDogrulamaServisi _instance =
      BulutSemaDogrulamaServisi._internal();
  factory BulutSemaDogrulamaServisi() => _instance;
  BulutSemaDogrulamaServisi._internal();

  static final Map<String, bool> _hazirCache = <String, bool>{};
  static final Map<String, Future<bool>> _inFlight = <String, Future<bool>>{};

  static const String _requiredExtension = 'pg_trgm';

  static const List<String> _requiredTables = <String>[
    'account_metadata',
    'bank_transactions',
    'bank_transactions_default',
    'banks',
    'cash_register_transactions',
    'cash_register_transactions_default',
    'cash_registers',
    'cheque_transactions',
    'cheques',
    'company_settings',
    'credit_card_transactions',
    'credit_card_transactions_default',
    'credit_cards',
    'currency_rates',
    'current_account_transactions',
    'current_account_transactions_default',
    'current_accounts',
    'depots',
    'expense_items',
    'expenses',
    'general_settings',
    'hidden_descriptions',
    'installments',
    'note_transactions',
    'order_items',
    'orders',
    'orders_default',
    'print_templates',
    'product_devices',
    'product_metadata',
    'production_metadata',
    'production_recipe_items',
    'production_stock_movements',
    'production_stock_movements_default',
    'productions',
    'products',
    'promissory_notes',
    'quick_products',
    'quote_items',
    'quotes',
    'quotes_default',
    'roles',
    'saved_descriptions',
    'sequences',
    'shipments',
    'stock_movements',
    'stock_movements_default',
    'sync_outbox',
    'table_counts',
    'user_transactions',
    'user_transactions_default',
    'users',
    'warehouse_stocks',
  ];

  static const List<String> _requiredIndexes = <String>[
    'idx_accounts_ad_trgm',
    'idx_accounts_aktif_btree',
    'idx_accounts_city_btree',
    'idx_accounts_created_at_btree',
    'idx_accounts_created_at_covering',
    'idx_accounts_kod_btree',
    'idx_accounts_kod_trgm',
    'idx_accounts_search_tags_gin',
    'idx_accounts_type_btree',
    'idx_banks_search_tags_gin',
    'idx_bt_bank_id',
    'idx_bt_created_at',
    'idx_bt_created_at_brin',
    'idx_bt_date',
    'idx_bt_integration_ref',
    'idx_bt_type',
    'idx_cash_registers_code_trgm',
    'idx_cash_registers_name_trgm',
    'idx_cash_registers_search_tags_gin',
    'idx_cat_account_id',
    'idx_cat_date_brin',
    'idx_cat_date_btree',
    'idx_cat_ref',
    'idx_cct_created_at',
    'idx_cct_credit_card_id',
    'idx_cct_date',
    'idx_cct_integration_ref',
    'idx_cct_type',
    'idx_cheque_transactions_cheque_id',
    'idx_cheque_transactions_search_tags_gin',
    'idx_cheques_check_no_trgm',
    'idx_cheques_company_id',
    'idx_cheques_customer_name_trgm',
    'idx_cheques_due_date_brin',
    'idx_cheques_is_active',
    'idx_cheques_issue_date_brin',
    'idx_cheques_ref',
    'idx_cheques_search_tags_gin',
    'idx_cheques_type',
    'idx_credit_cards_search_tags_gin',
    'idx_crt_cash_register_id',
    'idx_crt_created_at',
    'idx_crt_created_at_brin',
    'idx_crt_date',
    'idx_crt_integration_ref',
    'idx_crt_type',
    'idx_currency_rates_pair',
    'idx_depots_ad_trgm',
    'idx_depots_kod_btree',
    'idx_depots_kod_trgm',
    'idx_depots_search_tags_gin',
    'idx_expense_items_expense_id',
    'idx_expenses_aktif_btree',
    'idx_expenses_baslik_trgm',
    'idx_expenses_kategori_btree',
    'idx_expenses_kod_trgm',
    'idx_expenses_kullanici_btree',
    'idx_expenses_odeme_durumu_btree',
    'idx_expenses_search_tags_gin',
    'idx_expenses_tarih_brin',
    'idx_installments_cari',
    'idx_installments_ref',
    'idx_kasa_trans_default_basic',
    'idx_note_transactions_note_id',
    'idx_note_transactions_search_tags_gin',
    'idx_notes_company_id',
    'idx_notes_customer_name_trgm',
    'idx_notes_due_date_brin',
    'idx_notes_is_active',
    'idx_notes_issue_date_brin',
    'idx_notes_note_no_trgm',
    'idx_notes_ref',
    'idx_notes_search_tags_gin',
    'idx_notes_type',
    'idx_order_items_order_id',
    'idx_orders_integration_ref',
    'idx_orders_tarih',
    'idx_pd_identity_value',
    'idx_pd_product_id',
    'idx_productions_ad_trgm',
    'idx_productions_aktif_btree',
    'idx_productions_barkod_trgm',
    'idx_productions_birim_btree',
    'idx_productions_created_by',
    'idx_productions_grubu_btree',
    'idx_productions_kdv_btree',
    'idx_productions_kod_btree',
    'idx_productions_kod_trgm',
    'idx_productions_kullanici_trgm',
    'idx_productions_ozellikler_trgm',
    'idx_productions_search_tags_gin',
    'idx_products_ad_trgm',
    'idx_products_aktif_btree',
    'idx_products_barkod_btree',
    'idx_products_barkod_trgm',
    'idx_products_birim_btree',
    'idx_products_created_at_brin',
    'idx_products_created_by',
    'idx_products_grubu_btree',
    'idx_products_kdv_btree',
    'idx_products_kod_btree',
    'idx_products_kod_trgm',
    'idx_products_search_tags_gin',
    'idx_psm_created_at_brin',
    'idx_psm_date',
    'idx_psm_production_id',
    'idx_psm_related_shipments_gin',
    'idx_psm_warehouse_id',
    'idx_quote_items_quote_id',
    'idx_quotes_integration_ref',
    'idx_quotes_tarih',
    'idx_recipe_product_code',
    'idx_recipe_production_id',
    'idx_saved_descriptions_search',
    'idx_shipments_created_by_trgm',
    'idx_shipments_date',
    'idx_shipments_description_trgm',
    'idx_shipments_dest_id',
    'idx_shipments_items_gin',
    'idx_shipments_source_id',
    'idx_sm_created_at_brin',
    'idx_sm_date',
    'idx_sm_date_brin',
    'idx_sm_product_id',
    'idx_sm_ref',
    'idx_sm_shipment_id',
    'idx_sm_warehouse_id',
    'idx_sync_outbox_status',
    'idx_ut_date_brin',
    'idx_ut_type',
    'idx_ut_user_id',
    'idx_warehouse_stocks_pcode',
    'idx_warehouse_stocks_wid',
  ];

  static const List<String> _requiredFunctions = <String>[
    'get_professional_label',
    'normalize_text',
    'refresh_current_account_search_tags',
    'trg_refresh_account_search_tags',
    'update_account_metadata',
    'update_bank_search_tags',
    'update_cash_register_search_tags',
    'update_credit_card_search_tags',
    'update_depots_search_tags',
    'update_product_metadata',
    'update_production_metadata',
    'update_productions_search_tags',
    'update_table_counts',
  ];

  static const List<_TriggerRef> _requiredTriggers = <_TriggerRef>[
    _TriggerRef('trg_cat_refresh_search_tags', 'current_account_transactions'),
    _TriggerRef('trg_update_account_metadata', 'current_accounts'),
    _TriggerRef('trg_update_bank_search_tags', 'bank_transactions'),
    _TriggerRef(
      'trg_update_cash_register_search_tags',
      'cash_register_transactions',
    ),
    _TriggerRef('trg_update_credit_card_search_tags', 'credit_card_transactions'),
    _TriggerRef('trg_update_depots_search_tags', 'depots'),
    _TriggerRef('trg_update_productions_count', 'productions'),
    _TriggerRef('trg_update_productions_metadata', 'productions'),
    _TriggerRef('trg_update_productions_search_tags', 'productions'),
    _TriggerRef('trg_update_products_count', 'products'),
    _TriggerRef('trg_update_products_metadata', 'products'),
  ];

  static const List<_ColumnRef> _requiredColumns = <_ColumnRef>[
    _ColumnRef('bank_transactions', 'company_id'),
    _ColumnRef('bank_transactions', 'integration_ref'),
    _ColumnRef('bank_transactions', 'location'),
    _ColumnRef('bank_transactions', 'location_code'),
    _ColumnRef('bank_transactions', 'location_name'),
    _ColumnRef('banks', 'company_id'),
    _ColumnRef('cash_register_transactions', 'company_id'),
    _ColumnRef('cash_register_transactions', 'integration_ref'),
    _ColumnRef('cash_register_transactions', 'location'),
    _ColumnRef('cash_register_transactions', 'location_code'),
    _ColumnRef('cash_register_transactions', 'location_name'),
    _ColumnRef('cash_registers', 'company_id'),
    _ColumnRef('cheque_transactions', 'company_id'),
    _ColumnRef('cheque_transactions', 'integration_ref'),
    _ColumnRef('cheque_transactions', 'search_tags'),
    _ColumnRef('cheques', 'company_id'),
    _ColumnRef('cheques', 'due_date'),
    _ColumnRef('cheques', 'integration_ref'),
    _ColumnRef('cheques', 'issue_date'),
    _ColumnRef('company_settings', 'adres'),
    _ColumnRef('company_settings', 'eposta'),
    _ColumnRef('company_settings', 'telefon'),
    _ColumnRef('company_settings', 'vergi_dairesi'),
    _ColumnRef('company_settings', 'vergi_no'),
    _ColumnRef('company_settings', 'web_adresi'),
    _ColumnRef('credit_card_transactions', 'company_id'),
    _ColumnRef('credit_card_transactions', 'integration_ref'),
    _ColumnRef('credit_cards', 'company_id'),
    _ColumnRef('current_account_transactions', 'aciklama2'),
    _ColumnRef('current_account_transactions', 'bakiye_alacak'),
    _ColumnRef('current_account_transactions', 'bakiye_borc'),
    _ColumnRef('current_account_transactions', 'belge'),
    _ColumnRef('current_account_transactions', 'birim'),
    _ColumnRef('current_account_transactions', 'birim_fiyat'),
    _ColumnRef('current_account_transactions', 'e_belge'),
    _ColumnRef('current_account_transactions', 'fatura_no'),
    _ColumnRef('current_account_transactions', 'ham_fiyat'),
    _ColumnRef('current_account_transactions', 'integration_ref'),
    _ColumnRef('current_account_transactions', 'irsaliye_no'),
    _ColumnRef('current_account_transactions', 'iskonto'),
    _ColumnRef('current_account_transactions', 'kur'),
    _ColumnRef('current_account_transactions', 'miktar'),
    _ColumnRef('current_account_transactions', 'para_birimi'),
    _ColumnRef('current_account_transactions', 'source_code'),
    _ColumnRef('current_account_transactions', 'source_name'),
    _ColumnRef('current_account_transactions', 'updated_at'),
    _ColumnRef('current_account_transactions', 'urun_adi'),
    _ColumnRef('current_account_transactions', 'vade_tarihi'),
    _ColumnRef('current_accounts', 'renk'),
    _ColumnRef('depots', 'search_tags'),
    _ColumnRef('expense_items', 'created_at'),
    _ColumnRef('expense_items', 'not_metni'),
    _ColumnRef('expenses', 'created_at'),
    _ColumnRef('expenses', 'kullanici'),
    _ColumnRef('expenses', 'not_metni'),
    _ColumnRef('expenses', 'search_tags'),
    _ColumnRef('expenses', 'updated_at'),
    _ColumnRef('installments', 'hareket_id'),
    _ColumnRef('note_transactions', 'company_id'),
    _ColumnRef('note_transactions', 'integration_ref'),
    _ColumnRef('note_transactions', 'search_tags'),
    _ColumnRef('order_items', 'delivered_quantity'),
    _ColumnRef('print_templates', 'background_height'),
    _ColumnRef('print_templates', 'background_opacity'),
    _ColumnRef('print_templates', 'background_width'),
    _ColumnRef('print_templates', 'background_x'),
    _ColumnRef('print_templates', 'background_y'),
    _ColumnRef('print_templates', 'is_landscape'),
    _ColumnRef('print_templates', 'item_row_spacing'),
    _ColumnRef('print_templates', 'view_matrix'),
    _ColumnRef('product_devices', 'is_sold'),
    _ColumnRef('product_devices', 'sale_ref'),
    _ColumnRef('production_stock_movements', 'consumed_items'),
    _ColumnRef('production_stock_movements', 'related_shipment_ids'),
    _ColumnRef('productions', 'search_tags'),
    _ColumnRef('products', 'updated_at'),
    _ColumnRef('promissory_notes', 'company_id'),
    _ColumnRef('promissory_notes', 'integration_ref'),
    _ColumnRef('quote_items', 'barkod'),
    _ColumnRef('quote_items', 'birim'),
    _ColumnRef('quote_items', 'birim_fiyati'),
    _ColumnRef('quote_items', 'depo_adi'),
    _ColumnRef('quote_items', 'depo_id'),
    _ColumnRef('quote_items', 'iskonto'),
    _ColumnRef('quote_items', 'kdv_durumu'),
    _ColumnRef('quote_items', 'kdv_orani'),
    _ColumnRef('quote_items', 'miktar'),
    _ColumnRef('quote_items', 'para_birimi'),
    _ColumnRef('quote_items', 'toplam_fiyati'),
    _ColumnRef('quote_items', 'urun_adi'),
    _ColumnRef('quote_items', 'urun_id'),
    _ColumnRef('quote_items', 'urun_kodu'),
    _ColumnRef('quotes', 'aciklama'),
    _ColumnRef('quotes', 'aciklama2'),
    _ColumnRef('quotes', 'cari_adi'),
    _ColumnRef('quotes', 'cari_id'),
    _ColumnRef('quotes', 'cari_kod'),
    _ColumnRef('quotes', 'durum'),
    _ColumnRef('quotes', 'gecerlilik_tarihi'),
    _ColumnRef('quotes', 'ilgili_hesap_adi'),
    _ColumnRef('quotes', 'integration_ref'),
    _ColumnRef('quotes', 'kullanici'),
    _ColumnRef('quotes', 'kur'),
    _ColumnRef('quotes', 'para_birimi'),
    _ColumnRef('quotes', 'quote_no'),
    _ColumnRef('quotes', 'search_tags'),
    _ColumnRef('quotes', 'stok_rezerve_mi'),
    _ColumnRef('quotes', 'tarih'),
    _ColumnRef('quotes', 'tur'),
    _ColumnRef('quotes', 'tutar'),
    _ColumnRef('quotes', 'updated_at'),
    _ColumnRef('shipments', 'integration_ref'),
    _ColumnRef('stock_movements', 'currency_code'),
    _ColumnRef('stock_movements', 'currency_rate'),
    _ColumnRef('stock_movements', 'integration_ref'),
    _ColumnRef('stock_movements', 'is_giris'),
    _ColumnRef('stock_movements', 'running_cost'),
    _ColumnRef('stock_movements', 'running_stock'),
    _ColumnRef('stock_movements', 'shipment_id'),
    _ColumnRef('user_transactions', 'company_id'),
    _ColumnRef('users', 'address'),
    _ColumnRef('users', 'balance_credit'),
    _ColumnRef('users', 'balance_debt'),
    _ColumnRef('users', 'hire_date'),
    _ColumnRef('users', 'info1'),
    _ColumnRef('users', 'info2'),
    _ColumnRef('users', 'position'),
    _ColumnRef('users', 'salary'),
    _ColumnRef('users', 'salary_currency'),
    _ColumnRef('warehouse_stocks', 'reserved_quantity'),
  ];

  static final String _kontrolSql = _buildKontrolSql();

  Future<bool> bulutSemasiHazirMi({
    required Pool executor,
    required String databaseName,
  }) async {
    if (VeritabaniYapilandirma.connectionMode != 'cloud') return false;
    if (!VeritabaniYapilandirma.cloudCredentialsReady) return false;
    if (databaseName.trim().isEmpty) return false;

    final config = VeritabaniYapilandirma();
    final cacheKey =
        'cloud|${config.host}|${config.port}|${config.username}|${databaseName.trim()}';

    final cached = _hazirCache[cacheKey];
    if (cached == true) return true;

    final inFlight = _inFlight[cacheKey];
    if (inFlight != null) return inFlight;

    final future = _kontrolEt(executor);
    _inFlight[cacheKey] = future;
    try {
      final ok = await future;
      if (ok) _hazirCache[cacheKey] = true;
      return ok;
    } finally {
      _inFlight.remove(cacheKey);
    }
  }

  Future<bool> _kontrolEt(Pool executor) async {
    try {
      final result = await executor.execute(_kontrolSql);
      if (result.isEmpty) return false;

      final row = result.first;
      final bool extOk = row[0] == true;
      final bool tablesOk = row[1] == true;
      final bool indexesOk = row[2] == true;
      final bool functionsOk = row[3] == true;
      final bool triggersOk = row[4] == true;
      final bool columnsOk = row[5] == true;

      final ok =
          extOk && tablesOk && indexesOk && functionsOk && triggersOk && columnsOk;

      if (kDebugMode) {
        debugPrint(
          'BulutSemaDogrulamaServisi: ext=$extOk tables=$tablesOk indexes=$indexesOk functions=$functionsOk triggers=$triggersOk columns=$columnsOk',
        );
      }

      return ok;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('BulutSemaDogrulamaServisi: Kontrol hatası: $e');
      }
      return false;
    }
  }

  static String _buildKontrolSql() {
    String q(String v) => v.replaceAll("'", "''");

    String values1(List<String> items) =>
        items.map((e) => "('${q(e)}')").join(',\n        ');

    String values2Triggers(List<_TriggerRef> items) => items
        .map((e) => "('${q(e.name)}','${q(e.tableName)}')")
        .join(',\n        ');

    String values2Columns(List<_ColumnRef> items) => items
        .map((e) => "('${q(e.tableName)}','${q(e.columnName)}')")
        .join(',\n        ');

    return '''
      WITH
        required_tables(name) AS (
          VALUES
            ${values1(_requiredTables)}
        ),
        required_indexes(name) AS (
          VALUES
            ${values1(_requiredIndexes)}
        ),
        required_functions(name) AS (
          VALUES
            ${values1(_requiredFunctions)}
        ),
        required_triggers(name, table_name) AS (
          VALUES
            ${values2Triggers(_requiredTriggers)}
        ),
        required_columns(table_name, column_name) AS (
          VALUES
            ${values2Columns(_requiredColumns)}
        ),
        ext_ok AS (
          SELECT EXISTS (
            SELECT 1 FROM pg_extension WHERE extname = '${q(_requiredExtension)}'
          ) AS ok
        ),
        tables_ok AS (
          SELECT COUNT(DISTINCT r.name) = (SELECT COUNT(*) FROM required_tables) AS ok
          FROM required_tables r
          JOIN information_schema.tables t
            ON t.table_schema = 'public'
           AND t.table_name = r.name
        ),
        indexes_ok AS (
          SELECT COUNT(DISTINCT r.name) = (SELECT COUNT(*) FROM required_indexes) AS ok
          FROM required_indexes r
          JOIN pg_indexes i
            ON i.schemaname = 'public'
           AND i.indexname = r.name
        ),
        functions_ok AS (
          SELECT COUNT(DISTINCT r.name) = (SELECT COUNT(*) FROM required_functions) AS ok
          FROM required_functions r
          JOIN pg_proc p
            ON p.proname = r.name
          JOIN pg_namespace n
            ON n.oid = p.pronamespace
           AND n.nspname = 'public'
        ),
        triggers_ok AS (
          SELECT COUNT(DISTINCT (r.name, r.table_name)) = (SELECT COUNT(*) FROM required_triggers) AS ok
          FROM required_triggers r
          JOIN pg_trigger tg
            ON tg.tgname = r.name
           AND NOT tg.tgisinternal
          JOIN pg_class c
            ON c.oid = tg.tgrelid
           AND c.relname = r.table_name
          JOIN pg_namespace n
            ON n.oid = c.relnamespace
           AND n.nspname = 'public'
        ),
        columns_ok AS (
          SELECT COUNT(DISTINCT (r.table_name, r.column_name)) = (SELECT COUNT(*) FROM required_columns) AS ok
          FROM required_columns r
          JOIN information_schema.columns col
            ON col.table_schema = 'public'
           AND col.table_name = r.table_name
           AND col.column_name = r.column_name
        )
      SELECT
        (SELECT ok FROM ext_ok) AS ext_ok,
        (SELECT ok FROM tables_ok) AS tables_ok,
        (SELECT ok FROM indexes_ok) AS indexes_ok,
        (SELECT ok FROM functions_ok) AS functions_ok,
        (SELECT ok FROM triggers_ok) AS triggers_ok,
        (SELECT ok FROM columns_ok) AS columns_ok
    ''';
  }
}

class _TriggerRef {
  final String name;
  final String tableName;
  const _TriggerRef(this.name, this.tableName);
}

class _ColumnRef {
  final String tableName;
  final String columnName;
  const _ColumnRef(this.tableName, this.columnName);
}

