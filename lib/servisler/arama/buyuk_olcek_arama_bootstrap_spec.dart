/// [2026] Citus ve harici search olmadan saf PostgreSQL performans bootstrap'i.
///
/// Omurga:
/// - `pg_trgm` + `search_tags` GIN trigram
/// - `search_tags` FTS GIN
/// - Büyük tarih akışları için BRIN
/// - Keyset/cursor sıraları için temel composite index'ler
class BuyukOlcekAramaBootstrapSpec {
  static const List<String> searchTables = <String>[
    'products',
    'stock_movements',
    'banks',
    'bank_transactions',
    'cash_registers',
    'cash_register_transactions',
    'credit_cards',
    'credit_card_transactions',
    'current_accounts',
    'current_account_transactions',
    'cheques',
    'cheque_transactions',
    'promissory_notes',
    'note_transactions',
    'depots',
    'shipments',
    'expenses',
    'expense_items',
    'orders',
    'order_items',
    'quotes',
    'quote_items',
    'productions',
    'production_stock_movements',
  ];

  static const List<({String table, String column, String indexName})>
  brinSpecs = <({String table, String column, String indexName})>[
    (
      table: 'stock_movements',
      column: 'movement_date',
      indexName: 'idx_stock_movements_movement_date_brin',
    ),
    (
      table: 'production_stock_movements',
      column: 'movement_date',
      indexName: 'idx_psm_movement_date_brin',
    ),
    (
      table: 'bank_transactions',
      column: 'date',
      indexName: 'idx_bank_transactions_date_brin',
    ),
    (
      table: 'cash_register_transactions',
      column: 'date',
      indexName: 'idx_crt_date_brin',
    ),
    (
      table: 'credit_card_transactions',
      column: 'date',
      indexName: 'idx_cct_date_brin',
    ),
    (
      table: 'current_account_transactions',
      column: 'date',
      indexName: 'idx_cat_date_brin',
    ),
    (
      table: 'cheque_transactions',
      column: 'date',
      indexName: 'idx_cheque_transactions_date_brin',
    ),
    (
      table: 'note_transactions',
      column: 'date',
      indexName: 'idx_note_transactions_date_brin',
    ),
    (table: 'expenses', column: 'tarih', indexName: 'idx_expenses_tarih_brin'),
    (table: 'orders', column: 'tarih', indexName: 'idx_orders_tarih_brin'),
    (table: 'quotes', column: 'tarih', indexName: 'idx_quotes_tarih_brin'),
  ];

  static const List<
    ({String table, String indexName, List<String> expressions})
  >
  compositeSpecs =
      <({String table, String indexName, List<String> expressions})>[
        (
          table: 'products',
          indexName: 'idx_products_ad_id_keyset',
          expressions: <String>['ad ASC', 'id ASC'],
        ),
        (
          table: 'products',
          indexName: 'idx_products_kod_id_keyset',
          expressions: <String>['kod ASC', 'id ASC'],
        ),
        (
          table: 'products',
          indexName: 'idx_products_alis_fiyati_id_keyset',
          expressions: <String>['COALESCE(alis_fiyati, 0) ASC', 'id ASC'],
        ),
        (
          table: 'products',
          indexName: 'idx_products_satis_fiyati_1_id_keyset',
          expressions: <String>['COALESCE(satis_fiyati_1, 0) ASC', 'id ASC'],
        ),
        (
          table: 'products',
          indexName: 'idx_products_stok_id_keyset',
          expressions: <String>['COALESCE(stok, 0) ASC', 'id ASC'],
        ),
        (
          table: 'products',
          indexName: 'idx_products_birim_id_keyset',
          expressions: <String>['COALESCE(birim, \'\') ASC', 'id ASC'],
        ),
        (
          table: 'products',
          indexName: 'idx_products_aktif_mi_id_keyset',
          expressions: <String>['COALESCE(aktif_mi, 0) ASC', 'id ASC'],
        ),
        (
          table: 'banks',
          indexName: 'idx_banks_name_id_keyset',
          expressions: <String>['name ASC', 'id ASC'],
        ),
        (
          table: 'banks',
          indexName: 'idx_banks_code_id_keyset',
          expressions: <String>['code ASC', 'id ASC'],
        ),
        (
          table: 'banks',
          indexName: 'idx_banks_balance_id_keyset',
          expressions: <String>['COALESCE(balance, 0) ASC', 'id ASC'],
        ),
        (
          table: 'cash_registers',
          indexName: 'idx_cash_registers_name_id_keyset',
          expressions: <String>['name ASC', 'id ASC'],
        ),
        (
          table: 'cash_registers',
          indexName: 'idx_cash_registers_code_id_keyset',
          expressions: <String>['code ASC', 'id ASC'],
        ),
        (
          table: 'cash_registers',
          indexName: 'idx_cash_registers_address_id_keyset',
          expressions: <String>['COALESCE(address, \'\') ASC', 'id ASC'],
        ),
        (
          table: 'cash_registers',
          indexName: 'idx_cash_registers_responsible_id_keyset',
          expressions: <String>['COALESCE(responsible, \'\') ASC', 'id ASC'],
        ),
        (
          table: 'cash_registers',
          indexName: 'idx_cash_registers_phone_id_keyset',
          expressions: <String>['COALESCE(phone, \'\') ASC', 'id ASC'],
        ),
        (
          table: 'cash_registers',
          indexName: 'idx_cash_registers_is_active_id_keyset',
          expressions: <String>['COALESCE(is_active, 0) ASC', 'id ASC'],
        ),
        (
          table: 'cash_registers',
          indexName: 'idx_cash_registers_balance_id_keyset',
          expressions: <String>['COALESCE(balance, 0) ASC', 'id ASC'],
        ),
        (
          table: 'credit_cards',
          indexName: 'idx_credit_cards_name_id_keyset',
          expressions: <String>['name ASC', 'id ASC'],
        ),
        (
          table: 'credit_cards',
          indexName: 'idx_credit_cards_code_id_keyset',
          expressions: <String>['code ASC', 'id ASC'],
        ),
        (
          table: 'credit_cards',
          indexName: 'idx_credit_cards_address_id_keyset',
          expressions: <String>['COALESCE(address, \'\') ASC', 'id ASC'],
        ),
        (
          table: 'credit_cards',
          indexName: 'idx_credit_cards_responsible_id_keyset',
          expressions: <String>['COALESCE(responsible, \'\') ASC', 'id ASC'],
        ),
        (
          table: 'credit_cards',
          indexName: 'idx_credit_cards_phone_id_keyset',
          expressions: <String>['COALESCE(phone, \'\') ASC', 'id ASC'],
        ),
        (
          table: 'credit_cards',
          indexName: 'idx_credit_cards_is_active_id_keyset',
          expressions: <String>['COALESCE(is_active, 0) ASC', 'id ASC'],
        ),
        (
          table: 'credit_cards',
          indexName: 'idx_credit_cards_balance_id_keyset',
          expressions: <String>['COALESCE(balance, 0) ASC', 'id ASC'],
        ),
        (
          table: 'current_accounts',
          indexName: 'idx_current_accounts_adi_id_keyset',
          expressions: <String>['adi ASC', 'id ASC'],
        ),
        (
          table: 'current_accounts',
          indexName: 'idx_current_accounts_kod_no_id_keyset',
          expressions: <String>['kod_no ASC', 'id ASC'],
        ),
        (
          table: 'current_accounts',
          indexName: 'idx_current_accounts_hesap_turu_id_keyset',
          expressions: <String>['COALESCE(hesap_turu, \'\') ASC', 'id ASC'],
        ),
        (
          table: 'current_accounts',
          indexName: 'idx_current_accounts_bakiye_borc_id_keyset',
          expressions: <String>['COALESCE(bakiye_borc, 0) ASC', 'id ASC'],
        ),
        (
          table: 'current_accounts',
          indexName: 'idx_current_accounts_bakiye_alacak_id_keyset',
          expressions: <String>['COALESCE(bakiye_alacak, 0) ASC', 'id ASC'],
        ),
        (
          table: 'current_accounts',
          indexName: 'idx_current_accounts_aktif_mi_id_keyset',
          expressions: <String>['COALESCE(aktif_mi, 0) ASC', 'id ASC'],
        ),
        (
          table: 'depots',
          indexName: 'idx_depots_ad_id_keyset',
          expressions: <String>['ad ASC', 'id ASC'],
        ),
        (
          table: 'depots',
          indexName: 'idx_depots_kod_id_keyset',
          expressions: <String>['kod ASC', 'id ASC'],
        ),
        (
          table: 'depots',
          indexName: 'idx_depots_adres_id_keyset',
          expressions: <String>['COALESCE(adres, \'\') ASC', 'id ASC'],
        ),
        (
          table: 'depots',
          indexName: 'idx_depots_sorumlu_id_keyset',
          expressions: <String>['COALESCE(sorumlu, \'\') ASC', 'id ASC'],
        ),
        (
          table: 'depots',
          indexName: 'idx_depots_telefon_id_keyset',
          expressions: <String>['COALESCE(telefon, \'\') ASC', 'id ASC'],
        ),
        (
          table: 'depots',
          indexName: 'idx_depots_aktif_mi_id_keyset',
          expressions: <String>['COALESCE(aktif_mi, 0) ASC', 'id ASC'],
        ),
        (
          table: 'expenses',
          indexName: 'idx_expenses_tarih_id_keyset',
          expressions: <String>['tarih DESC', 'id DESC'],
        ),
        (
          table: 'expenses',
          indexName: 'idx_expenses_kod_id_keyset',
          expressions: <String>['kod ASC', 'id ASC'],
        ),
        (
          table: 'expenses',
          indexName: 'idx_expenses_baslik_id_keyset',
          expressions: <String>['baslik ASC', 'id ASC'],
        ),
        (
          table: 'expenses',
          indexName: 'idx_expenses_tutar_id_keyset',
          expressions: <String>['COALESCE(tutar, 0) ASC', 'id ASC'],
        ),
        (
          table: 'expenses',
          indexName: 'idx_expenses_kategori_id_keyset',
          expressions: <String>['COALESCE(kategori, \'\') ASC', 'id ASC'],
        ),
        (
          table: 'expenses',
          indexName: 'idx_expenses_aktif_mi_id_keyset',
          expressions: <String>['COALESCE(aktif_mi, 0) ASC', 'id ASC'],
        ),
        (
          table: 'expenses',
          indexName: 'idx_expenses_aciklama_id_keyset',
          expressions: <String>['COALESCE(aciklama, \'\') ASC', 'id ASC'],
        ),
        (
          table: 'orders',
          indexName: 'idx_orders_tarih_id_keyset',
          expressions: <String>['tarih DESC', 'id DESC'],
        ),
        (
          table: 'orders',
          indexName: 'idx_orders_tutar_id_keyset',
          expressions: <String>['COALESCE(tutar, 0) ASC', 'id ASC'],
        ),
        (
          table: 'orders',
          indexName: 'idx_orders_durum_id_keyset',
          expressions: <String>['COALESCE(durum, \'\') ASC', 'id ASC'],
        ),
        (
          table: 'quotes',
          indexName: 'idx_quotes_tarih_id_keyset',
          expressions: <String>['tarih DESC', 'id DESC'],
        ),
        (
          table: 'quotes',
          indexName: 'idx_quotes_tutar_id_keyset',
          expressions: <String>['COALESCE(tutar, 0) ASC', 'id ASC'],
        ),
        (
          table: 'quotes',
          indexName: 'idx_quotes_durum_id_keyset',
          expressions: <String>['COALESCE(durum, \'\') ASC', 'id ASC'],
        ),
        (
          table: 'productions',
          indexName: 'idx_productions_ad_id_keyset',
          expressions: <String>['ad ASC', 'id ASC'],
        ),
        (
          table: 'productions',
          indexName: 'idx_productions_kod_id_keyset',
          expressions: <String>['kod ASC', 'id ASC'],
        ),
        (
          table: 'productions',
          indexName: 'idx_productions_alis_fiyati_id_keyset',
          expressions: <String>['COALESCE(alis_fiyati, 0) ASC', 'id ASC'],
        ),
        (
          table: 'productions',
          indexName: 'idx_productions_satis_fiyati_1_id_keyset',
          expressions: <String>['COALESCE(satis_fiyati_1, 0) ASC', 'id ASC'],
        ),
        (
          table: 'productions',
          indexName: 'idx_productions_stok_id_keyset',
          expressions: <String>['COALESCE(stok, 0) ASC', 'id ASC'],
        ),
        (
          table: 'productions',
          indexName: 'idx_productions_birim_id_keyset',
          expressions: <String>['COALESCE(birim, \'\') ASC', 'id ASC'],
        ),
        (
          table: 'productions',
          indexName: 'idx_productions_aktif_mi_id_keyset',
          expressions: <String>['COALESCE(aktif_mi, 0) ASC', 'id ASC'],
        ),
        (
          table: 'cheques',
          indexName: 'idx_cheques_check_no_id_keyset',
          expressions: <String>['check_no ASC', 'id ASC'],
        ),
        (
          table: 'cheques',
          indexName: 'idx_cheques_customer_name_id_keyset',
          expressions: <String>['COALESCE(customer_name, \'\') ASC', 'id ASC'],
        ),
        (
          table: 'cheques',
          indexName: 'idx_cheques_amount_id_keyset',
          expressions: <String>['COALESCE(amount, 0) ASC', 'id ASC'],
        ),
        (
          table: 'cheques',
          indexName: 'idx_cheques_issue_date_id_keyset',
          expressions: <String>['issue_date DESC', 'id DESC'],
        ),
        (
          table: 'cheques',
          indexName: 'idx_cheques_due_date_id_keyset',
          expressions: <String>['due_date DESC', 'id DESC'],
        ),
        (
          table: 'promissory_notes',
          indexName: 'idx_notes_note_no_id_keyset',
          expressions: <String>['note_no ASC', 'id ASC'],
        ),
        (
          table: 'promissory_notes',
          indexName: 'idx_notes_customer_name_id_keyset',
          expressions: <String>['COALESCE(customer_name, \'\') ASC', 'id ASC'],
        ),
        (
          table: 'promissory_notes',
          indexName: 'idx_notes_amount_id_keyset',
          expressions: <String>['COALESCE(amount, 0) ASC', 'id ASC'],
        ),
        (
          table: 'promissory_notes',
          indexName: 'idx_notes_issue_date_id_keyset',
          expressions: <String>['issue_date DESC', 'id DESC'],
        ),
        (
          table: 'promissory_notes',
          indexName: 'idx_notes_due_date_id_keyset',
          expressions: <String>['due_date DESC', 'id DESC'],
        ),
        (
          table: 'bank_transactions',
          indexName: 'idx_bank_transactions_date_id_keyset',
          expressions: <String>['date DESC', 'id DESC'],
        ),
        (
          table: 'cash_register_transactions',
          indexName: 'idx_crt_date_id_keyset',
          expressions: <String>['date DESC', 'id DESC'],
        ),
        (
          table: 'credit_card_transactions',
          indexName: 'idx_cct_date_id_keyset',
          expressions: <String>['date DESC', 'id DESC'],
        ),
        (
          table: 'current_account_transactions',
          indexName: 'idx_cat_date_id_keyset',
          expressions: <String>['date DESC', 'id DESC'],
        ),
        (
          table: 'cheque_transactions',
          indexName: 'idx_cheque_transactions_date_id_keyset',
          expressions: <String>['date DESC', 'id DESC'],
        ),
        (
          table: 'note_transactions',
          indexName: 'idx_note_transactions_date_id_keyset',
          expressions: <String>['date DESC', 'id DESC'],
        ),
      ];
}
