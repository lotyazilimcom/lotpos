/// [2026] 100B+ veri için BM25 index + Citus dağıtım hedefi.
///
/// Bu dosya Flutter bağımsızdır (tool/ scriptleri de kullanabilsin diye).
class BuyukOlcekAramaBootstrapSpec {
  static const List<String> bm25Tables = <String>[
    // Ürünler
    'products',
    'stock_movements',

    // Banka/Kasa/Kredi Kartı
    'banks',
    'bank_transactions',
    'cash_registers',
    'cash_register_transactions',
    'credit_cards',
    'credit_card_transactions',

    // Cari
    'current_accounts',
    'current_account_transactions',

    // Çek/Senet
    'cheques',
    'cheque_transactions',
    'promissory_notes',
    'note_transactions',

    // Depo/Sevkiyat
    'depots',
    'shipments',

    // Gider
    'expenses',
    'expense_items',

    // Sipariş/Teklif
    'orders',
    'order_items',
    'quotes',
    'quote_items',

    // Üretim
    'productions',
    'production_stock_movements',
  ];

  static const List<({String table, String column, String? colocateWith})>
  citusDistributionSpecs =
      <({String table, String column, String? colocateWith})>[
        // Ürünler
        (table: 'products', column: 'id', colocateWith: null),
        (table: 'stock_movements', column: 'product_id', colocateWith: 'products'),

        // Banka/Kasa/Kredi Kartı
        (table: 'banks', column: 'id', colocateWith: null),
        (table: 'bank_transactions', column: 'bank_id', colocateWith: 'banks'),

        (table: 'cash_registers', column: 'id', colocateWith: null),
        (table: 'cash_register_transactions', column: 'cash_register_id', colocateWith: 'cash_registers'),

        (table: 'credit_cards', column: 'id', colocateWith: null),
        (table: 'credit_card_transactions', column: 'credit_card_id', colocateWith: 'credit_cards'),

        // Cari
        (table: 'current_accounts', column: 'id', colocateWith: null),
        (table: 'current_account_transactions', column: 'current_account_id', colocateWith: 'current_accounts'),

        // Çek/Senet
        (table: 'cheques', column: 'id', colocateWith: null),
        (table: 'cheque_transactions', column: 'cheque_id', colocateWith: 'cheques'),

        (table: 'promissory_notes', column: 'id', colocateWith: null),
        (table: 'note_transactions', column: 'note_id', colocateWith: 'promissory_notes'),

        // Depo/Sevkiyat
        (table: 'depots', column: 'id', colocateWith: null),
        // Sevkiyat 2 depoya bağlıdır; tek dağıtım kolonu seçmek zorundayız.
        (table: 'shipments', column: 'source_warehouse_id', colocateWith: 'depots'),

        // Gider
        (table: 'expenses', column: 'id', colocateWith: null),
        (table: 'expense_items', column: 'expense_id', colocateWith: 'expenses'),

        // Sipariş/Teklif
        (table: 'orders', column: 'id', colocateWith: null),
        (table: 'order_items', column: 'order_id', colocateWith: 'orders'),

        (table: 'quotes', column: 'id', colocateWith: null),
        (table: 'quote_items', column: 'quote_id', colocateWith: 'quotes'),

        // Üretim
        (table: 'productions', column: 'id', colocateWith: null),
        (table: 'production_stock_movements', column: 'production_id', colocateWith: 'productions'),
      ];
}

