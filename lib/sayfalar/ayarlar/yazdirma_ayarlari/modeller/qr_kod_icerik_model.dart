class QrKodIcerikTuru {
  static const String plainText = 'plain_text';
  static const String url = 'url';
  static const String email = 'email';
  static const String phone = 'phone';
  static const String sms = 'sms';
  static const String wifi = 'wifi';
  static const String vcard = 'vcard';

  static const List<String> values = [
    plainText,
    url,
    email,
    phone,
    sms,
    wifi,
    vcard,
  ];
}

class QrKodIcerikModel {
  final String type;
  final String plainText;
  final String url;
  final String emailAddress;
  final String emailSubject;
  final String emailBody;
  final String phoneNumber;
  final String smsNumber;
  final String smsMessage;
  final String wifiSsid;
  final String wifiPassword;
  final String wifiEncryption;
  final bool wifiHidden;
  final String contactName;
  final String contactCompany;
  final String contactTitle;
  final String contactPhone;
  final String contactEmail;
  final String contactWebsite;
  final String contactAddress;
  final String contactNote;

  const QrKodIcerikModel({
    this.type = QrKodIcerikTuru.vcard,
    this.plainText = '',
    this.url = '',
    this.emailAddress = '',
    this.emailSubject = '',
    this.emailBody = '',
    this.phoneNumber = '',
    this.smsNumber = '',
    this.smsMessage = '',
    this.wifiSsid = '',
    this.wifiPassword = '',
    this.wifiEncryption = 'WPA',
    this.wifiHidden = false,
    this.contactName = '',
    this.contactCompany = '',
    this.contactTitle = '',
    this.contactPhone = '',
    this.contactEmail = '',
    this.contactWebsite = '',
    this.contactAddress = '',
    this.contactNote = '',
  });

  factory QrKodIcerikModel.defaultLotYazilim() {
    const receiptSummary =
        'Belge: {{invoice_no}}\n'
        'Tarih: {{date}} {{time}}\n'
        'Toplam: {{grand_total_rounded}} {{currency}}';

    return const QrKodIcerikModel(
      type: QrKodIcerikTuru.vcard,
      plainText:
          'Lot Yazılım\n'
          'Lot POS\n'
          'Perakende ve ticari yönetim sistemi\n'
          'Belge: {{invoice_no}}\n'
          'Tarih: {{date}} {{time}}\n'
          'Toplam: {{grand_total_rounded}} {{currency}}',
      url: '{{seller_web}}',
      emailAddress: '{{seller_email}}',
      emailSubject: 'Lot Yazılım | {{invoice_no}}',
      emailBody: receiptSummary,
      phoneNumber: '{{seller_phone}}',
      smsNumber: '{{seller_phone}}',
      smsMessage:
          'Lot Yazılım | {{invoice_no}} | {{grand_total_rounded}} {{currency}}',
      contactName: 'Lot Yazılım',
      contactCompany: 'Lot POS',
      contactTitle: 'Perakende ve ticari yönetim sistemi',
      contactPhone: '{{seller_phone}}',
      contactEmail: '{{seller_email}}',
      contactWebsite: '{{seller_web}}',
      contactAddress: '{{seller_address}}',
      contactNote: receiptSummary,
    );
  }

  factory QrKodIcerikModel.fromMap(Map<String, dynamic> map) {
    final rawType = (map['type'] ?? '').toString().trim();
    final normalizedType = QrKodIcerikTuru.values.contains(rawType)
        ? rawType
        : QrKodIcerikTuru.vcard;

    return QrKodIcerikModel(
      type: normalizedType,
      plainText: (map['plainText'] ?? '').toString(),
      url: (map['url'] ?? '').toString(),
      emailAddress: (map['emailAddress'] ?? '').toString(),
      emailSubject: (map['emailSubject'] ?? '').toString(),
      emailBody: (map['emailBody'] ?? '').toString(),
      phoneNumber: (map['phoneNumber'] ?? '').toString(),
      smsNumber: (map['smsNumber'] ?? '').toString(),
      smsMessage: (map['smsMessage'] ?? '').toString(),
      wifiSsid: (map['wifiSsid'] ?? '').toString(),
      wifiPassword: (map['wifiPassword'] ?? '').toString(),
      wifiEncryption: (map['wifiEncryption'] ?? 'WPA').toString(),
      wifiHidden:
          map['wifiHidden'] == true ||
          map['wifiHidden']?.toString().toLowerCase() == 'true',
      contactName: (map['contactName'] ?? '').toString(),
      contactCompany: (map['contactCompany'] ?? '').toString(),
      contactTitle: (map['contactTitle'] ?? '').toString(),
      contactPhone: (map['contactPhone'] ?? '').toString(),
      contactEmail: (map['contactEmail'] ?? '').toString(),
      contactWebsite: (map['contactWebsite'] ?? '').toString(),
      contactAddress: (map['contactAddress'] ?? '').toString(),
      contactNote: (map['contactNote'] ?? '').toString(),
    );
  }

  static QrKodIcerikModel? fromDynamic(dynamic raw) {
    if (raw is Map) {
      return QrKodIcerikModel.fromMap(Map<String, dynamic>.from(raw));
    }
    return null;
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'plainText': plainText,
      'url': url,
      'emailAddress': emailAddress,
      'emailSubject': emailSubject,
      'emailBody': emailBody,
      'phoneNumber': phoneNumber,
      'smsNumber': smsNumber,
      'smsMessage': smsMessage,
      'wifiSsid': wifiSsid,
      'wifiPassword': wifiPassword,
      'wifiEncryption': wifiEncryption,
      'wifiHidden': wifiHidden,
      'contactName': contactName,
      'contactCompany': contactCompany,
      'contactTitle': contactTitle,
      'contactPhone': contactPhone,
      'contactEmail': contactEmail,
      'contactWebsite': contactWebsite,
      'contactAddress': contactAddress,
      'contactNote': contactNote,
    };
  }

  QrKodIcerikModel copyWith({
    String? type,
    String? plainText,
    String? url,
    String? emailAddress,
    String? emailSubject,
    String? emailBody,
    String? phoneNumber,
    String? smsNumber,
    String? smsMessage,
    String? wifiSsid,
    String? wifiPassword,
    String? wifiEncryption,
    bool? wifiHidden,
    String? contactName,
    String? contactCompany,
    String? contactTitle,
    String? contactPhone,
    String? contactEmail,
    String? contactWebsite,
    String? contactAddress,
    String? contactNote,
  }) {
    return QrKodIcerikModel(
      type: type ?? this.type,
      plainText: plainText ?? this.plainText,
      url: url ?? this.url,
      emailAddress: emailAddress ?? this.emailAddress,
      emailSubject: emailSubject ?? this.emailSubject,
      emailBody: emailBody ?? this.emailBody,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      smsNumber: smsNumber ?? this.smsNumber,
      smsMessage: smsMessage ?? this.smsMessage,
      wifiSsid: wifiSsid ?? this.wifiSsid,
      wifiPassword: wifiPassword ?? this.wifiPassword,
      wifiEncryption: wifiEncryption ?? this.wifiEncryption,
      wifiHidden: wifiHidden ?? this.wifiHidden,
      contactName: contactName ?? this.contactName,
      contactCompany: contactCompany ?? this.contactCompany,
      contactTitle: contactTitle ?? this.contactTitle,
      contactPhone: contactPhone ?? this.contactPhone,
      contactEmail: contactEmail ?? this.contactEmail,
      contactWebsite: contactWebsite ?? this.contactWebsite,
      contactAddress: contactAddress ?? this.contactAddress,
      contactNote: contactNote ?? this.contactNote,
    );
  }

  String buildPayload(Map<String, dynamic> values) {
    return switch (type) {
      QrKodIcerikTuru.url => _buildUrlPayload(values),
      QrKodIcerikTuru.email => _buildEmailPayload(values),
      QrKodIcerikTuru.phone => _buildPhonePayload(values),
      QrKodIcerikTuru.sms => _buildSmsPayload(values),
      QrKodIcerikTuru.wifi => _buildWifiPayload(values),
      QrKodIcerikTuru.vcard => _buildVcardPayload(values),
      _ => _resolveTokens(plainText, values).trim(),
    };
  }

  String _buildUrlPayload(Map<String, dynamic> values) {
    final resolved = _resolveTokens(url, values).trim();
    if (resolved.isEmpty) return '';
    if (resolved.contains('://')) return resolved;
    if (resolved.startsWith('mailto:') || resolved.startsWith('tel:')) {
      return resolved;
    }
    return 'https://$resolved';
  }

  String _buildEmailPayload(Map<String, dynamic> values) {
    final address = _resolveTokens(emailAddress, values).trim();
    if (address.isEmpty) return '';
    final query = <String, String>{};
    final subject = _resolveTokens(emailSubject, values).trim();
    final body = _resolveTokens(emailBody, values).trim();
    if (subject.isNotEmpty) query['subject'] = subject;
    if (body.isNotEmpty) query['body'] = body;
    return Uri(
      scheme: 'mailto',
      path: address,
      queryParameters: query.isEmpty ? null : query,
    ).toString();
  }

  String _buildPhonePayload(Map<String, dynamic> values) {
    final phone = _resolveTokens(phoneNumber, values).trim();
    if (phone.isEmpty) return '';
    return 'tel:${phone.replaceAll(' ', '')}';
  }

  String _buildSmsPayload(Map<String, dynamic> values) {
    final number = _resolveTokens(smsNumber, values).trim();
    final message = _resolveTokens(smsMessage, values).trim();
    if (number.isEmpty && message.isEmpty) return '';
    if (message.isEmpty) return 'SMSTO:$number';
    return 'SMSTO:$number:$message';
  }

  String _buildWifiPayload(Map<String, dynamic> values) {
    final ssid = _escapeWifiValue(_resolveTokens(wifiSsid, values).trim());
    if (ssid.isEmpty) return '';
    final password = _escapeWifiValue(
      _resolveTokens(wifiPassword, values).trim(),
    );
    final security = _normalizeWifiEncryption(wifiEncryption);
    final hiddenValue = wifiHidden ? 'true' : 'false';
    final hiddenPart = wifiHidden ? 'H:$hiddenValue;' : '';
    final passwordPart = security == 'nopass' ? '' : 'P:$password;';
    return 'WIFI:T:$security;S:$ssid;$passwordPart$hiddenPart;';
  }

  String _buildVcardPayload(Map<String, dynamic> values) {
    final fn = _escapeVcard(_resolveTokens(contactName, values).trim());
    final org = _escapeVcard(_resolveTokens(contactCompany, values).trim());
    final title = _escapeVcard(_resolveTokens(contactTitle, values).trim());
    final phone = _escapeVcard(_resolveTokens(contactPhone, values).trim());
    final email = _escapeVcard(_resolveTokens(contactEmail, values).trim());
    final website = _escapeVcard(_resolveTokens(contactWebsite, values).trim());
    final address = _escapeVcard(_resolveTokens(contactAddress, values).trim());
    final note = _escapeVcard(_resolveTokens(contactNote, values).trim());

    final lines = <String>['BEGIN:VCARD', 'VERSION:4.0'];
    if (fn.isNotEmpty) {
      lines.add('FN:$fn');
    }
    if (org.isNotEmpty) lines.add('ORG:$org');
    if (title.isNotEmpty) lines.add('TITLE:$title');
    if (phone.isNotEmpty) lines.add('TEL;TYPE=work,voice:$phone');
    if (email.isNotEmpty) lines.add('EMAIL:$email');
    if (website.isNotEmpty) lines.add('URL:$website');
    if (address.isNotEmpty) lines.add('ADR:;;$address;;;;');
    if (note.isNotEmpty) lines.add('NOTE:$note');
    lines.add('END:VCARD');
    return lines.join('\n');
  }

  String _resolveTokens(String template, Map<String, dynamic> values) {
    return template.replaceAllMapped(_placeholderPattern, (match) {
      final key = (match.group(1) ?? '').trim();
      if (key.isEmpty) return '';
      final value = values[key];
      if (value == null) return '';
      if (value is Iterable) {
        return value.map((item) => item?.toString() ?? '').join(', ');
      }
      return value.toString();
    });
  }

  String _normalizeWifiEncryption(String raw) {
    final value = raw.trim().toUpperCase();
    if (value == 'WEP') return 'WEP';
    if (value == 'NOPASS') return 'nopass';
    return 'WPA';
  }

  String _escapeWifiValue(String value) {
    return value
        .replaceAll('\\', '\\\\')
        .replaceAll(';', r'\;')
        .replaceAll(',', r'\,')
        .replaceAll(':', r'\:');
  }

  String _escapeVcard(String value) {
    return value
        .replaceAll('\\', '\\\\')
        .replaceAll('\n', r'\n')
        .replaceAll(';', r'\;')
        .replaceAll(',', r'\,');
  }

  static final RegExp _placeholderPattern = RegExp(
    r'\{\{\s*([a-zA-Z0-9_]+)\s*\}\}',
  );
}
