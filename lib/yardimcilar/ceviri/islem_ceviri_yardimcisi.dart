import 'ceviri_servisi.dart';

class IslemCeviriYardimcisi {
  IslemCeviriYardimcisi._();

  static String cevir(String raw) {
    final input = raw.trim();
    if (input.isEmpty) return raw;

    final parsedInstrument = _tryTranslateInstrumentWithStatus(input);
    if (parsedInstrument != null) return parsedInstrument;

    final directKey = _directKey(input);
    if (directKey != null) return tr(directKey);

    final parenTranslated = _tryTranslateParenPair(input);
    if (parenTranslated != null) return parenTranslated;

    return input;
  }

  static String parantezliKaynakKisaltma(String raw) {
    final input = raw.trim();
    if (input.isEmpty) return raw;

    final inner = _unwrapParens(input);
    if (inner == null) return input;

    final key = _sourceKey(inner);
    if (key == null) return input;

    return '(${tr(key)})';
  }

  static String cevirDurum(String raw) {
    final input = raw.trim();
    if (input.isEmpty) return raw;

    final key = _statusKey(input);
    if (key != null) return tr(key);

    return input;
  }

  static String? _tryTranslateInstrumentWithStatus(String input) {
    final match = RegExp(
      r'^(Çek|Cek|Senet)\s+(Alındı|Alindi|Verildi)\s*\((.+)\)$',
    ).firstMatch(input);
    if (match == null) return null;

    final instrumentRaw = match.group(1)!;
    final directionRaw = match.group(2)!;
    final rawStatus = match.group(3)!.trim();

    final String baseKey;
    final instrumentLower = instrumentRaw.toLowerCase();
    final directionLower = directionRaw.toLowerCase();
    final bool isCheck = instrumentLower == 'çek' || instrumentLower == 'cek';
    final bool isReceived =
        directionLower == 'alındı' || directionLower == 'alindi';

    if (isCheck) {
      baseKey = isReceived
          ? 'transactions.check_received'
          : 'transactions.check_given';
    } else {
      baseKey = isReceived
          ? 'transactions.note_received'
          : 'transactions.note_given';
    }

    final statusKey = _statusKey(rawStatus);
    final statusText = statusKey != null ? tr(statusKey) : rawStatus;
    return '${tr(baseKey)} ($statusText)';
  }

  static String? _directKey(String input) {
    switch (input) {
      // Account types
      case 'Alıcı':
      case 'Alici':
        return 'accounts.type.buyer';
      case 'Satıcı':
      case 'Satici':
        return 'accounts.type.seller';
      case 'Alıcı/Satıcı':
      case 'Alici/Satici':
      case 'Alıcı / Satıcı':
      case 'Alici / Satici':
        return 'accounts.type.buyer_seller';

      // Money labels
      case 'Para Alındı':
      case 'Para Alindi':
        return 'transactions.money_received';
      case 'Para Verildi':
        return 'transactions.money_paid';
      case 'Cari İşlem':
        return 'transactions.current_account_transaction';
      case 'Tahsilat':
        return 'transactions.status.collection';
      case 'Ödeme':
      case 'Odeme':
        return 'transactions.status.payment';
      case 'Personel Ödemesi':
      case 'Personel Odemesi':
        return 'transactions.personnel_payment';
      case 'Ödeme Alındı (Satış)':
      case 'Odeme Alindi (Satis)':
        return 'transactions.payment_received_sale';
      case 'Ödeme Yapıldı (Alış)':
      case 'Odeme Yapildi (Alis)':
        return 'transactions.payment_made_purchase';

      // Generic sources (may appear outside parentheses)
      case 'Kasa':
        return 'transactions.source.cash';
      case 'Banka':
        return 'transactions.source.bank';
      case 'Kredi Kartı':
      case 'K.Kartı':
      case 'K.Karti':
        return 'transactions.source.credit_card';
      case 'Cari':
      case 'Cari Hesap':
        return 'transactions.source.current_account';
      case 'Personel':
        return 'transactions.source.personnel';
      case 'Gelir':
        return 'transactions.source.income';
      case 'Diğer':
      case 'Diger':
        return 'transactions.source.other';

      // Cash / Bank / Credit Card professional labels
      case 'Kasa Tahsilat':
        return 'transactions.cash_collection';
      case 'Kasa Ödeme':
        return 'transactions.cash_payment';
      case 'Banka Tahsilat':
        return 'transactions.bank_collection';
      case 'Banka Ödeme':
        return 'transactions.bank_payment';
      case 'Banka Transfer':
        return 'transactions.bank_transfer';
      case 'Kredi Kartı Tahsilat':
        return 'transactions.credit_card_collection';
      case 'Kredi Kartı Harcama':
        return 'transactions.credit_card_expense';

      // Check / Note labels
      case 'Çek Alındı':
        return 'transactions.check_received';
      case 'Çek Verildi':
        return 'transactions.check_given';
      case 'Çek Tahsil':
        return 'transactions.check_collected';
      case 'Çek Ödendi':
        return 'transactions.check_paid';
      case 'Çek Ciro':
        return 'transactions.check_endorse';
      case 'Çek Ciro Edildi':
        return 'transactions.check_endorsed';
      case 'Karşılıksız Çek':
        return 'transactions.check_bounced';
      case 'Senet Alındı':
        return 'transactions.note_received';
      case 'Senet Verildi':
        return 'transactions.note_given';
      case 'Senet Tahsil':
        return 'transactions.note_collected';
      case 'Senet Ödendi':
        return 'transactions.note_paid';
      case 'Senet Ciro':
        return 'transactions.note_endorse';
      case 'Senet Ciro Edildi':
        return 'transactions.note_endorsed';
      case 'Karşılıksız Senet':
        return 'transactions.note_bounced';

      // Stock labels (from IslemTuruRenkleri.getProfessionalLabel)
      case 'Açılış Stoğu (Girdi)':
      case 'Acilis Stogu (Girdi)':
      case 'Açılış Stoğu (Giris)':
      case 'Acilis Stogu (Giris)':
        return 'stock.transaction.opening_stock_in';
      case 'Açılış Stoğu':
      case 'Acilis Stogu':
        return 'stock.transaction.opening_stock';
      case 'Devir Giriş':
      case 'Devir Giris':
        return 'stock.transaction.transfer_in';
      case 'Devir Çıkış':
      case 'Devir Cikis':
        return 'stock.transaction.transfer_out';
      case 'Devir':
        return 'stock.transaction.transfer';
      case 'Depo Transfer':
        return 'stock.transaction.warehouse_transfer';
      case 'Stok Giriş':
      case 'Stok Giris':
        return 'stock.transaction.stock_in';
      case 'Stok Çıkış':
      case 'Stok Cikis':
        return 'stock.transaction.stock_out';
      case 'Üretim':
      case 'Uretim':
        return 'stock.transaction.production';
      case 'Üretim Girişi':
      case 'Uretim Girisi':
        return 'stock.transaction.production_in';
      case 'Üretim Çıkışı':
      case 'Uretim Cikisi':
        return 'stock.transaction.production_out';
      case 'Sevkiyat':
        return 'stock.transaction.shipment';
      case 'Satış':
      case 'Satis':
        return 'stock.transaction.sale';
      case 'Alış':
      case 'Alis':
        return 'stock.transaction.purchase';

      // Shipment (legacy labels stored in DB)
      case 'Sevkiyat (Girdi)':
        return 'warehouses.detail.type_in';
      case 'Sevkiyat (Çıktı)':
        return 'warehouses.detail.type_out';
    }

    // Common statuses used by IslemTuruRenkleri.getProfessionalLabel
    if (input == 'Beklemede') return 'common.status.pending';
    if (input == 'Onaylandı') return 'common.status.approved';
    if (input == 'İptal Edildi') return 'common.status.cancelled';
    if (input == 'Satış Yapıldı' || input == 'Satis Yapildi') {
      return 'quotes.status.converted';
    }
    if (input == 'Alış Yapıldı' || input == 'Alis Yapildi') {
      return 'orders.status.converted';
    }

    // Debit/Credit notes
    if (input == 'Alacak Dekontu') return 'accounts.card.summary.credit_note';
    if (input == 'Borç Dekontu' || input == 'Borc Dekontu') {
      return 'accounts.card.summary.debit_note';
    }

    // Generic in/out labels
    if (input == 'Girdi') return 'products.transaction.type.input';
    if (input == 'Çıktı') return 'products.transaction.type.output';

    return null;
  }

  static String? _tryTranslateParenPair(String input) {
    final match = RegExp(r'^(.+?)\\s*\\(([^)]+)\\)$').firstMatch(input);
    if (match == null) return null;

    final left = match.group(1)?.trim() ?? '';
    final right = match.group(2)?.trim() ?? '';
    if (left.isEmpty || right.isEmpty) return null;

    return '${_translateSimple(left)} (${_translateSimple(right)})';
  }

  static String _translateSimple(String input) {
    final parsedInstrument = _tryTranslateInstrumentWithStatus(input);
    if (parsedInstrument != null) return parsedInstrument;

    final directKey = _directKey(input);
    if (directKey != null) return tr(directKey);

    final statusKey = _statusKey(input);
    if (statusKey != null) return tr(statusKey);

    return input;
  }

  static String? _statusKey(String rawStatus) {
    switch (rawStatus) {
      case 'Tahsil Edildi':
        return 'transactions.status.collected';
      case 'Ciro Edildi':
        return 'transactions.status.endorsed';
      case 'Ödendi':
        return 'transactions.status.paid';
      case 'Karşılıksız':
        return 'transactions.status.bounced';
      case 'Portföyde':
        return 'transactions.status.in_portfolio';
      // Used in some timelines as short labels
      case 'Tahsil':
      case 'Tahsilat':
        return 'transactions.status.collection';
      case 'Ödeme':
      case 'Odeme':
        return 'transactions.status.payment';
    }
    return null;
  }

  static String? _sourceKey(String raw) {
    switch (raw) {
      case 'Kasa':
        return 'transactions.source.cash';
      case 'Banka':
        return 'transactions.source.bank';
      case 'K.Kartı':
      case 'K.Karti':
      case 'Kredi Kartı':
        return 'transactions.source.credit_card';
      case 'Cari':
      case 'Cari Hesap':
        return 'transactions.source.current_account';
      case 'Personel':
        return 'transactions.source.personnel';
      case 'Gelir':
        return 'transactions.source.income';
      case 'Diğer':
      case 'Diger':
        return 'transactions.source.other';
    }
    return null;
  }

  static String? _unwrapParens(String input) {
    if (!input.startsWith('(') || !input.endsWith(')')) return null;
    final inner = input.substring(1, input.length - 1).trim();
    return inner.isEmpty ? null : inner;
  }
}
