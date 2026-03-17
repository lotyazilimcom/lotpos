import 'package:flutter/foundation.dart';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'lisans_servisi.dart';
import 'online_veritabani_servisi.dart';
import 'oturum_servisi.dart';

class ProPlanOzelligi {
  final String id;
  final String text;

  const ProPlanOzelligi({required this.id, required this.text});

  factory ProPlanOzelligi.fromJson(Map<String, dynamic> json) {
    return ProPlanOzelligi(
      id: (json['id'] ?? '').toString().trim(),
      text: (json['text'] ?? '').toString().trim(),
    );
  }
}

class ProPlanPaketi {
  final String id;
  final String code;
  final String title;
  final String badge;
  final String price;
  final String equivalent;
  final String note;
  final bool highlighted;
  final List<ProPlanOzelligi> features;

  const ProPlanPaketi({
    required this.id,
    required this.code,
    required this.title,
    required this.badge,
    required this.price,
    required this.equivalent,
    required this.note,
    required this.highlighted,
    required this.features,
  });

  factory ProPlanPaketi.fromJson(Map<String, dynamic> json) {
    final rawFeatures = (json['features'] as List?) ?? const [];
    final features = rawFeatures
        .whereType<Map>()
        .map(
          (entry) => ProPlanOzelligi.fromJson(
            Map<String, dynamic>.from(entry.cast<String, dynamic>()),
          ),
        )
        .where((feature) => feature.text.isNotEmpty)
        .toList();

    return ProPlanPaketi(
      id: (json['id'] ?? '').toString().trim(),
      code: (json['code'] ?? '').toString().trim(),
      title: (json['title'] ?? '').toString().trim(),
      badge: (json['badge'] ?? '').toString().trim(),
      price: (json['price'] ?? '').toString().trim(),
      equivalent: (json['equivalent'] ?? '').toString().trim(),
      note: (json['note'] ?? '').toString().trim(),
      highlighted: json['highlighted'] == true,
      features: features,
    );
  }

  ProPlanPaketi copyWith({
    String? id,
    String? code,
    String? title,
    String? badge,
    String? price,
    String? equivalent,
    String? note,
    bool? highlighted,
    List<ProPlanOzelligi>? features,
  }) {
    return ProPlanPaketi(
      id: id ?? this.id,
      code: code ?? this.code,
      title: title ?? this.title,
      badge: badge ?? this.badge,
      price: price ?? this.price,
      equivalent: equivalent ?? this.equivalent,
      note: note ?? this.note,
      highlighted: highlighted ?? this.highlighted,
      features: features ?? this.features,
    );
  }
}

class ProOdemeDialogMetinleri {
  final String title;
  final String subtitle;
  final String planStepLabel;
  final String formStepLabel;
  final String planSectionTitle;
  final String planSectionSubtitle;
  final String planInfoText;
  final String formSectionTitle;
  final String existingCustomerNote;
  final String newCustomerNote;
  final String invoiceNote;
  final String footerNote;
  final String checkoutWaitingTitle;
  final String checkoutWaitingBody;
  final String checkoutCopyLinkLabel;
  final String checkoutOpenAgainLabel;
  final String changePlanLabel;
  final String continueLabel;
  final String cancelLabel;
  final String backLabel;
  final String chooseLabel;
  final String selectedLabel;
  final String purchaseButtonTemplate;
  final String licenseIdLabel;
  final String hardwareIdLabel;

  const ProOdemeDialogMetinleri({
    required this.title,
    required this.subtitle,
    required this.planStepLabel,
    required this.formStepLabel,
    required this.planSectionTitle,
    required this.planSectionSubtitle,
    required this.planInfoText,
    required this.formSectionTitle,
    required this.existingCustomerNote,
    required this.newCustomerNote,
    required this.invoiceNote,
    required this.footerNote,
    required this.checkoutWaitingTitle,
    required this.checkoutWaitingBody,
    required this.checkoutCopyLinkLabel,
    required this.checkoutOpenAgainLabel,
    required this.changePlanLabel,
    required this.continueLabel,
    required this.cancelLabel,
    required this.backLabel,
    required this.chooseLabel,
    required this.selectedLabel,
    required this.purchaseButtonTemplate,
    required this.licenseIdLabel,
    required this.hardwareIdLabel,
  });

  factory ProOdemeDialogMetinleri.fromJson(
    Map<String, dynamic> json,
    ProOdemeDialogMetinleri fallback,
  ) {
    String read(String key, String fallbackValue) {
      final value = (json[key] ?? '').toString().trim();
      return value.isEmpty ? fallbackValue : value;
    }

    return ProOdemeDialogMetinleri(
      title: read('title', fallback.title),
      subtitle: read('subtitle', fallback.subtitle),
      planStepLabel: read('planStepLabel', fallback.planStepLabel),
      formStepLabel: read('formStepLabel', fallback.formStepLabel),
      planSectionTitle: read('planSectionTitle', fallback.planSectionTitle),
      planSectionSubtitle: read(
        'planSectionSubtitle',
        fallback.planSectionSubtitle,
      ),
      planInfoText: read('planInfoText', fallback.planInfoText),
      formSectionTitle: read('formSectionTitle', fallback.formSectionTitle),
      existingCustomerNote: read(
        'existingCustomerNote',
        fallback.existingCustomerNote,
      ),
      newCustomerNote: read('newCustomerNote', fallback.newCustomerNote),
      invoiceNote: read('invoiceNote', fallback.invoiceNote),
      footerNote: read('footerNote', fallback.footerNote),
      checkoutWaitingTitle: read(
        'checkoutWaitingTitle',
        fallback.checkoutWaitingTitle,
      ),
      checkoutWaitingBody: read(
        'checkoutWaitingBody',
        fallback.checkoutWaitingBody,
      ),
      checkoutCopyLinkLabel: read(
        'checkoutCopyLinkLabel',
        fallback.checkoutCopyLinkLabel,
      ),
      checkoutOpenAgainLabel: read(
        'checkoutOpenAgainLabel',
        fallback.checkoutOpenAgainLabel,
      ),
      changePlanLabel: read('changePlanLabel', fallback.changePlanLabel),
      continueLabel: read('continueLabel', fallback.continueLabel),
      cancelLabel: read('cancelLabel', fallback.cancelLabel),
      backLabel: read('backLabel', fallback.backLabel),
      chooseLabel: read('chooseLabel', fallback.chooseLabel),
      selectedLabel: read('selectedLabel', fallback.selectedLabel),
      purchaseButtonTemplate: read(
        'purchaseButtonTemplate',
        fallback.purchaseButtonTemplate,
      ),
      licenseIdLabel: read('licenseIdLabel', fallback.licenseIdLabel),
      hardwareIdLabel: read('hardwareIdLabel', fallback.hardwareIdLabel),
    );
  }
}

class ProOdemeFormEtiketleri {
  final String companyName;
  final String fullName;
  final String phone;
  final String email;
  final String city;
  final String address;
  final String taxOffice;
  final String taxId;

  const ProOdemeFormEtiketleri({
    required this.companyName,
    required this.fullName,
    required this.phone,
    required this.email,
    required this.city,
    required this.address,
    required this.taxOffice,
    required this.taxId,
  });

  factory ProOdemeFormEtiketleri.fromJson(
    Map<String, dynamic> json,
    ProOdemeFormEtiketleri fallback,
  ) {
    String read(String key, String fallbackValue) {
      final value = (json[key] ?? '').toString().trim();
      return value.isEmpty ? fallbackValue : value;
    }

    return ProOdemeFormEtiketleri(
      companyName: read('companyName', fallback.companyName),
      fullName: read('fullName', fallback.fullName),
      phone: read('phone', fallback.phone),
      email: read('email', fallback.email),
      city: read('city', fallback.city),
      address: read('address', fallback.address),
      taxOffice: read('taxOffice', fallback.taxOffice),
      taxId: read('taxId', fallback.taxId),
    );
  }
}

class ProSatinAlmaOnBilgi {
  final String? customerId;
  final String hardwareId;
  final String licenseId;
  final String companyName;
  final String fullName;
  final String phone;
  final String email;
  final String city;
  final String address;
  final String taxOffice;
  final String taxId;
  final bool mevcutMusteri;

  const ProSatinAlmaOnBilgi({
    required this.customerId,
    required this.hardwareId,
    required this.licenseId,
    required this.companyName,
    required this.fullName,
    required this.phone,
    required this.email,
    required this.city,
    required this.address,
    required this.taxOffice,
    required this.taxId,
    required this.mevcutMusteri,
  });
}

class ProCheckoutSonucu {
  final Uri checkoutUri;
  final String checkoutId;

  const ProCheckoutSonucu({
    required this.checkoutUri,
    required this.checkoutId,
  });
}

class ProCheckoutIzlemeDurumu {
  final String? customerId;
  final String? lastEvent;
  final DateTime? lastEventAt;
  final String? subscriptionStatus;
  final String? variantName;
  final bool odemeAlindi;

  const ProCheckoutIzlemeDurumu({
    required this.customerId,
    required this.lastEvent,
    required this.lastEventAt,
    required this.subscriptionStatus,
    required this.variantName,
    required this.odemeAlindi,
  });

  const ProCheckoutIzlemeDurumu.bos()
    : customerId = null,
      lastEvent = null,
      lastEventAt = null,
      subscriptionStatus = null,
      variantName = null,
      odemeAlindi = false;
}

class ProIptalSonucu {
  final double refundAmount;
  final String paymentChannel;
  final String planTitle;
  final String refundStatus;

  const ProIptalSonucu({
    required this.refundAmount,
    required this.paymentChannel,
    required this.planTitle,
    required this.refundStatus,
  });
}

class ProSatinAlmaHatasi implements Exception {
  final String mesaj;
  const ProSatinAlmaHatasi(this.mesaj);

  @override
  String toString() => mesaj;
}

class ProOdemeProfili {
  final String locale;
  final String currencyCode;
  final bool configured;
  final ProOdemeDialogMetinleri dialog;
  final ProOdemeFormEtiketleri formLabels;
  final List<ProPlanPaketi> planlar;

  const ProOdemeProfili({
    required this.locale,
    required this.currencyCode,
    required this.configured,
    required this.dialog,
    required this.formLabels,
    required this.planlar,
  });

  ProPlanPaketi get varsayilanPlan {
    return planlar.firstWhere(
      (plan) => plan.highlighted,
      orElse: () => planlar.first,
    );
  }
}

class ProSatinAlmaServisi {
  ProSatinAlmaServisi._();

  static String odemeProfiliLocale(String locale) =>
      locale == 'tr' ? 'tr' : 'en';

  static ProOdemeDialogMetinleri _varsayilanDialog(String locale) {
    if (locale == 'tr') {
      return const ProOdemeDialogMetinleri(
        title: 'Pro Sürüm Siparişi',
        subtitle:
            'Paketinizi seçin; eksik fatura ve iletişim bilgilerini tamamlayıp güvenli ödeme sayfasına geçin.',
        planStepLabel: 'Size uygun planı seçin',
        formStepLabel: 'Faturalama ve iletişim bilgileri',
        planSectionTitle: 'Size uygun planı seçin',
        planSectionSubtitle:
            'Paket sayısı, fiyat metinleri ve plan özellikleri admin panelinden tamamen yönetilir.',
        planInfoText:
            'Seçtiğiniz paket ödeme sonrası müşteri kaydı, lisans satırı ve cihaz eşleştirmesiyle otomatik işlenir.',
        formSectionTitle: 'Faturalama ve iletişim bilgileri',
        existingCustomerNote:
            'Sistemde mevcut müşteri kaydınız bulundu. Hazır gelen alanları kontrol edip eksik bilgileri tamamlamanız yeterlidir.',
        newCustomerNote:
            'Bu cihaz için ilk Pro müşteri kaydı oluşturulacak. Fatura ve iletişim alanlarını eksiksiz doldurun.',
        invoiceNote:
            'Bu bilgiler LemonSqueezy ödeme sayfasına ön doldurma olarak gönderilir ve ödeme tamamlandığında admin panelindeki müşteri kaydı için kullanılır.',
        footerNote:
            'Fiyatlara KDV ödeme ekranında ayrıca eklenir. Satın alma sonrası cihazınız Lite listesinden çıkarılıp Pro müşteri kaydına otomatik taşınır.',
        checkoutWaitingTitle: 'Ödeme ekranı açıldı',
        checkoutWaitingBody:
            'Ödemenizi tarayıcıda tamamladıktan sonra bu ekran lisans durumunu otomatik kontrol etmeye devam eder.',
        checkoutCopyLinkLabel: 'Bağlantıyı Kopyala',
        checkoutOpenAgainLabel: 'Ödeme Sayfasını Aç',
        changePlanLabel: 'Planı değiştir',
        continueLabel: 'Devam Et',
        cancelLabel: 'İptal',
        backLabel: 'Geri',
        chooseLabel: 'Seç',
        selectedLabel: 'Seçili',
        purchaseButtonTemplate: '{price} ile Satın Al',
        licenseIdLabel: 'Lisans ID',
        hardwareIdLabel: 'Donanım Kimliği (Hardware ID)',
      );
    }

    return const ProOdemeDialogMetinleri(
      title: 'Pro Upgrade Checkout',
      subtitle:
          'Pick a plan, complete any missing billing details, and continue to the secure payment page.',
      planStepLabel: 'Choose your plan',
      formStepLabel: 'Billing and contact details',
      planSectionTitle: 'Choose the plan that fits you',
      planSectionSubtitle:
          'Package count, pricing copy, and feature lists are fully managed from the admin payment settings.',
      planInfoText:
          'After payment, the selected plan is automatically synchronized with your customer record, license entry, and connected device.',
      formSectionTitle: 'Billing and contact details',
      existingCustomerNote:
          'We found an existing customer record for this device. Review the prefilled fields and complete any missing details.',
      newCustomerNote:
          'A new Pro customer record will be created for this device. Fill in the billing and contact details completely.',
      invoiceNote:
          'These details are passed to LemonSqueezy as checkout prefill data and are used to create or update the customer record after payment.',
      footerNote:
          'VAT is added separately on the payment page. After payment, your device is automatically moved from the Lite list into the Pro customer flow.',
      checkoutWaitingTitle: 'Checkout opened',
      checkoutWaitingBody:
          'After finishing the payment in your browser, this screen keeps checking your license status automatically.',
      checkoutCopyLinkLabel: 'Copy Link',
      checkoutOpenAgainLabel: 'Open Checkout',
      changePlanLabel: 'Change plan',
      continueLabel: 'Continue',
      cancelLabel: 'Cancel',
      backLabel: 'Back',
      chooseLabel: 'Choose',
      selectedLabel: 'Selected',
      purchaseButtonTemplate: 'Buy with {price}',
      licenseIdLabel: 'License ID',
      hardwareIdLabel: 'Hardware ID',
    );
  }

  static ProOdemeFormEtiketleri _varsayilanFormEtiketleri(String locale) {
    if (locale == 'tr') {
      return const ProOdemeFormEtiketleri(
        companyName: 'Firma / işletme adı',
        fullName: 'Ad soyad',
        phone: 'Telefon',
        email: 'E-posta',
        city: 'Şehir',
        address: 'Açık adres',
        taxOffice: 'Vergi dairesi',
        taxId: 'Vergi no / T.C. no',
      );
    }

    return const ProOdemeFormEtiketleri(
      companyName: 'Company / business name',
      fullName: 'Full name',
      phone: 'Phone',
      email: 'Email',
      city: 'City',
      address: 'Address',
      taxOffice: 'Tax office',
      taxId: 'Tax number / ID',
    );
  }

  static List<ProPlanPaketi> varsayilanPlanlar(String locale) {
    final isTurkish = odemeProfiliLocale(locale) == 'tr';
    return [
      ProPlanPaketi(
        id: 'plan-monthly',
        code: 'monthly',
        title: isTurkish ? 'Aylık Pro' : 'Monthly Pro',
        badge: isTurkish ? 'AYLIK' : 'MONTHLY',
        price: isTurkish ? '539 TL + KDV' : '39 USD + VAT',
        equivalent: isTurkish ? '539 TL / ay' : '39 USD / month',
        note: isTurkish ? 'Esnek başlangıç' : 'Flexible start',
        highlighted: false,
        features: [
          ProPlanOzelligi(
            id: 'device',
            text: isTurkish
                ? '5 cihaza kadar Pro cihaz bağlantısı'
                : 'Up to 5 Pro device connections',
          ),
          ProPlanOzelligi(
            id: 'ai',
            text: isTurkish
                ? 'Los AI, belge tarama ve hızlı ürün çözümleri'
                : 'Los AI, document scan, and quick product workflows',
          ),
          ProPlanOzelligi(
            id: 'cloud',
            text: isTurkish
                ? 'Çevrim içi doğrulama ve bulut odaklı çalışma'
                : 'Online validation and cloud-focused operations',
          ),
          ProPlanOzelligi(
            id: 'support',
            text: isTurkish
                ? 'Öncelikli destek ve lisans takibi'
                : 'Priority support and license tracking',
          ),
        ],
      ),
      ProPlanPaketi(
        id: 'plan-semiannual',
        code: 'semiannual',
        title: isTurkish ? '6 Aylık Pro' : '6-Month Pro',
        badge: isTurkish ? 'EN POPÜLER' : 'MOST POPULAR',
        price: isTurkish ? '2.799 TL + KDV' : '199 USD + VAT',
        equivalent: isTurkish ? '466,5 TL / ay' : '33.1 USD / month',
        note: isTurkish ? 'Aylığa göre avantajlı' : 'Better than monthly',
        highlighted: true,
        features: [
          ProPlanOzelligi(
            id: 'device',
            text: isTurkish
                ? '5 cihaza kadar Pro cihaz bağlantısı'
                : 'Up to 5 Pro device connections',
          ),
          ProPlanOzelligi(
            id: 'ai',
            text: isTurkish
                ? 'Los AI, belge tarama ve hızlı ürün çözümleri'
                : 'Los AI, document scan, and quick product workflows',
          ),
          ProPlanOzelligi(
            id: 'cloud',
            text: isTurkish
                ? 'Çevrim içi doğrulama ve bulut odaklı çalışma'
                : 'Online validation and cloud-focused operations',
          ),
          ProPlanOzelligi(
            id: 'support',
            text: isTurkish
                ? 'Öncelikli destek ve lisans takibi'
                : 'Priority support and license tracking',
          ),
        ],
      ),
      ProPlanPaketi(
        id: 'plan-yearly',
        code: 'yearly',
        title: isTurkish ? 'Yıllık Pro' : 'Yearly Pro',
        badge: isTurkish ? 'EN İYİ DEĞER' : 'BEST VALUE',
        price: isTurkish ? '4.999 TL + KDV' : '349 USD + VAT',
        equivalent: isTurkish ? '416,6 TL / ay' : '29.1 USD / month',
        note: isTurkish ? 'En yüksek fiyat avantajı' : 'Best annual value',
        highlighted: false,
        features: [
          ProPlanOzelligi(
            id: 'device',
            text: isTurkish
                ? '5 cihaza kadar Pro cihaz bağlantısı'
                : 'Up to 5 Pro device connections',
          ),
          ProPlanOzelligi(
            id: 'ai',
            text: isTurkish
                ? 'Los AI, belge tarama ve hızlı ürün çözümleri'
                : 'Los AI, document scan, and quick product workflows',
          ),
          ProPlanOzelligi(
            id: 'cloud',
            text: isTurkish
                ? 'Çevrim içi doğrulama ve bulut odaklı çalışma'
                : 'Online validation and cloud-focused operations',
          ),
          ProPlanOzelligi(
            id: 'support',
            text: isTurkish
                ? 'Öncelikli destek ve lisans takibi'
                : 'Priority support and license tracking',
          ),
        ],
      ),
    ];
  }

  static ProOdemeProfili varsayilanOdemeProfili(String locale) {
    final normalizedLocale = odemeProfiliLocale(locale);
    return ProOdemeProfili(
      locale: normalizedLocale,
      currencyCode: normalizedLocale == 'tr' ? 'TRY' : 'USD',
      configured: false,
      dialog: _varsayilanDialog(normalizedLocale),
      formLabels: _varsayilanFormEtiketleri(normalizedLocale),
      planlar: varsayilanPlanlar(normalizedLocale),
    );
  }

  static Future<ProOdemeProfili> odemeProfiliniGetir({
    required String locale,
  }) async {
    final normalizedLocale = odemeProfiliLocale(locale);
    final fallback = varsayilanOdemeProfili(normalizedLocale);
    final endpoint =
        Uri.parse(
          '${LisansServisi.u}/functions/v1/get-pro-payment-profile',
        ).replace(
          queryParameters: {
            'locale': normalizedLocale,
            'ts': DateTime.now().millisecondsSinceEpoch.toString(),
          },
        );

    try {
      final response = await http.get(
        endpoint,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'apikey': LisansServisi.k,
          'Authorization': 'Bearer ${LisansServisi.k}',
          'Cache-Control': 'no-cache',
          'Pragma': 'no-cache',
        },
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return fallback;
      }

      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      final rawPackages = (payload['packages'] as List?) ?? const [];
      final parsedPackages = rawPackages
          .whereType<Map>()
          .map(
            (entry) => ProPlanPaketi.fromJson(
              Map<String, dynamic>.from(entry.cast<String, dynamic>()),
            ),
          )
          .where((plan) => plan.code.isNotEmpty && plan.title.isNotEmpty)
          .toList();

      final plans = parsedPackages.isNotEmpty
          ? parsedPackages
          : fallback.planlar;
      final highlightedExists = plans.any((plan) => plan.highlighted);
      final normalizedPlans = [
        for (var i = 0; i < plans.length; i += 1)
          plans[i].copyWith(highlighted: highlightedExists ? null : i == 1),
      ];

      return ProOdemeProfili(
        locale: (payload['locale'] ?? fallback.locale).toString().trim().isEmpty
            ? fallback.locale
            : (payload['locale'] ?? fallback.locale).toString().trim(),
        currencyCode:
            (payload['currencyCode'] ?? fallback.currencyCode)
                .toString()
                .trim()
                .isEmpty
            ? fallback.currencyCode
            : (payload['currencyCode'] ?? fallback.currencyCode)
                  .toString()
                  .trim(),
        configured: payload['configured'] == true,
        dialog: ProOdemeDialogMetinleri.fromJson(
          Map<String, dynamic>.from(
            ((payload['dialog'] as Map?) ?? const {}).cast<String, dynamic>(),
          ),
          fallback.dialog,
        ),
        formLabels: ProOdemeFormEtiketleri.fromJson(
          Map<String, dynamic>.from(
            ((payload['formLabels'] as Map?) ?? const {})
                .cast<String, dynamic>(),
          ),
          fallback.formLabels,
        ),
        planlar: normalizedPlans,
      );
    } catch (_) {
      return fallback;
    }
  }

  static Future<ProSatinAlmaOnBilgi> hazirBilgileriGetir() async {
    await LisansServisi().baslat();

    final hardwareId = (LisansServisi().hardwareId ?? '').trim().toUpperCase();
    final licenseId = (LisansServisi().licenseId ?? hardwareId)
        .trim()
        .toUpperCase();

    if (hardwareId.isEmpty) {
      throw const ProSatinAlmaHatasi(
        'Donanım kimliği bulunamadı. Uygulamayı yeniden başlatıp tekrar deneyin.',
      );
    }

    final client = Supabase.instance.client;
    final groupHardwareIds = <String>{hardwareId};
    String orFilter(String field, Iterable<String> values) => values
        .where((value) => value.trim().isNotEmpty)
        .map((value) => '$field.eq.${value.trim()}')
        .join(',');

    try {
      if (licenseId.isNotEmpty) {
        groupHardwareIds.addAll(
          await OnlineVeritabaniServisi().cihazlariGetirByLisansKimligi(
            licenseId,
          ),
        );
      }
    } catch (_) {}

    final mergedCompany = OturumServisi().aktifSirket;

    Map<String, dynamic>? customerRow;
    if (groupHardwareIds.isNotEmpty) {
      try {
        final customerRows = await client
            .from('customers')
            .select(
              'id, company_name, contact_name, phone, email, city, address, tax_office, tax_id, hardware_id',
            )
            .or(orFilter('hardware_id', groupHardwareIds));

        if (customerRows.isNotEmpty) {
          customerRow = Map<String, dynamic>.from(customerRows.first);
        }
      } catch (_) {}

      if (customerRow == null) {
        try {
          final licenseRows = await client
              .from('licenses')
              .select('customer_id, hardware_id, created_at, end_date')
              .or(orFilter('hardware_id', groupHardwareIds))
              .not('customer_id', 'is', null);

          if (licenseRows.isNotEmpty) {
            licenseRows.sort((left, right) {
              final leftEnd =
                  DateTime.tryParse(
                    left['end_date']?.toString() ?? '',
                  )?.millisecondsSinceEpoch ??
                  0;
              final rightEnd =
                  DateTime.tryParse(
                    right['end_date']?.toString() ?? '',
                  )?.millisecondsSinceEpoch ??
                  0;
              if (rightEnd != leftEnd) return rightEnd.compareTo(leftEnd);
              final leftCreated =
                  DateTime.tryParse(
                    left['created_at']?.toString() ?? '',
                  )?.millisecondsSinceEpoch ??
                  0;
              final rightCreated =
                  DateTime.tryParse(
                    right['created_at']?.toString() ?? '',
                  )?.millisecondsSinceEpoch ??
                  0;
              return rightCreated.compareTo(leftCreated);
            });

            final existingCustomerId = (licenseRows.first['customer_id'] ?? '')
                .toString()
                .trim();
            if (existingCustomerId.isNotEmpty) {
              final matched = await client
                  .from('customers')
                  .select(
                    'id, company_name, contact_name, phone, email, city, address, tax_office, tax_id, hardware_id',
                  )
                  .eq('id', existingCustomerId)
                  .maybeSingle();

              if (matched != null) {
                customerRow = Map<String, dynamic>.from(matched);
              }
            }
          }
        } catch (_) {}
      }
    }

    Map<String, dynamic>? programRow;
    try {
      programRow = await client
          .from('program_deneme')
          .select('city, ip_address, machine_name')
          .eq('hardware_id', hardwareId)
          .maybeSingle();
    } catch (_) {}

    String mergeValue(List<String?> values) {
      for (final value in values) {
        final normalized = value?.trim();
        if (normalized != null && normalized.isNotEmpty) {
          return normalized;
        }
      }
      return '';
    }

    return ProSatinAlmaOnBilgi(
      customerId: (customerRow?['id'] ?? '').toString().trim().isEmpty
          ? null
          : customerRow?['id'].toString().trim(),
      hardwareId: hardwareId,
      licenseId: licenseId,
      companyName: mergeValue([
        customerRow?['company_name']?.toString(),
        mergedCompany?.ad,
      ]),
      fullName: mergeValue([customerRow?['contact_name']?.toString()]),
      phone: mergeValue([
        customerRow?['phone']?.toString(),
        mergedCompany?.telefon,
      ]),
      email: mergeValue([
        customerRow?['email']?.toString(),
        mergedCompany?.eposta,
      ]),
      city: mergeValue([
        customerRow?['city']?.toString(),
        programRow?['city']?.toString(),
      ]),
      address: mergeValue([
        customerRow?['address']?.toString(),
        mergedCompany?.adres,
      ]),
      taxOffice: mergeValue([
        customerRow?['tax_office']?.toString(),
        mergedCompany?.vergiDairesi,
      ]),
      taxId: mergeValue([
        customerRow?['tax_id']?.toString(),
        mergedCompany?.vergiNo,
      ]),
      mevcutMusteri: customerRow != null,
    );
  }

  static Future<ProCheckoutSonucu> checkoutOlustur({
    required String planCode,
    required ProSatinAlmaOnBilgi bilgiler,
    required String companyName,
    required String fullName,
    required String phone,
    required String email,
    required String city,
    required String address,
    required String taxOffice,
    required String taxId,
    required String locale,
  }) async {
    final endpoint = Uri.parse(
      '${LisansServisi.u}/functions/v1/create-pro-upgrade-checkout',
    );

    final response = await http.post(
      endpoint,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'apikey': LisansServisi.k,
        'Authorization': 'Bearer ${LisansServisi.k}',
        'Cache-Control': 'no-cache',
        'Pragma': 'no-cache',
      },
      body: jsonEncode({
        'plan_code': planCode.trim(),
        'customer_id': bilgiler.customerId,
        'hardware_id': bilgiler.hardwareId,
        'license_id': bilgiler.licenseId,
        'company_name': companyName.trim(),
        'full_name': fullName.trim(),
        'phone': phone.trim(),
        'email': email.trim(),
        'city': city.trim(),
        'address': address.trim(),
        'tax_office': taxOffice.trim(),
        'tax_id': taxId.trim(),
        'locale': locale,
      }),
    );

    Map<String, dynamic> payload = <String, dynamic>{};
    try {
      payload = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {}

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final rawMessage =
          [
                payload['error'],
                payload['message'],
                payload['details'] is Map
                    ? (payload['details'] as Map)['error']
                    : null,
              ]
              .map((value) => (value ?? '').toString().trim())
              .firstWhere((value) => value.isNotEmpty, orElse: () => '');
      if (rawMessage.contains('LEMON_SQUEEZY_')) {
        throw const ProSatinAlmaHatasi(
          'Satış altyapısı henüz tamamlanmamış. Yönetici ödeme ayarlarını tamamladıktan sonra tekrar deneyin.',
        );
      }
      throw ProSatinAlmaHatasi(
        rawMessage.isNotEmpty
            ? rawMessage
            : 'Satın alma bağlantısı oluşturulamadı. Lütfen tekrar deneyin.',
      );
    }

    final url = (payload['checkout_url'] ?? '').toString().trim();
    if (url.isEmpty) {
      throw const ProSatinAlmaHatasi(
        'Satın alma bağlantısı oluşturuldu ancak yönlendirme adresi alınamadı.',
      );
    }

    final checkoutUri = Uri.tryParse(url);
    if (checkoutUri == null) {
      throw const ProSatinAlmaHatasi(
        'Satın alma bağlantısı geçersiz görünüyor. Lütfen tekrar deneyin.',
      );
    }

    return ProCheckoutSonucu(
      checkoutUri: checkoutUri,
      checkoutId: (payload['checkout_id'] ?? '').toString(),
    );
  }

  static Future<ProCheckoutIzlemeDurumu> odemeDurumunuGetir({
    required String hardwareId,
    String? customerId,
  }) async {
    final normalizedHardwareId = hardwareId.trim().toUpperCase();
    final normalizedCustomerId = (customerId ?? '').trim();
    final client = Supabase.instance.client;

    Map<String, dynamic>? customerRow;

    if (normalizedHardwareId.isNotEmpty) {
      final row = await client
          .from('customers')
          .select(
            'id, hardware_id, lemon_last_event, lemon_last_event_at, lemon_subscription_status, lemon_variant_name',
          )
          .eq('hardware_id', normalizedHardwareId)
          .maybeSingle();
      if (row != null) {
        customerRow = Map<String, dynamic>.from(row);
      }
    }

    if (customerRow == null && normalizedCustomerId.isNotEmpty) {
      final row = await client
          .from('customers')
          .select(
            'id, hardware_id, lemon_last_event, lemon_last_event_at, lemon_subscription_status, lemon_variant_name',
          )
          .eq('id', normalizedCustomerId)
          .maybeSingle();
      if (row != null) {
        customerRow = Map<String, dynamic>.from(row);
      }
    }

    if (customerRow == null) {
      return const ProCheckoutIzlemeDurumu.bos();
    }

    final lastEvent = (customerRow['lemon_last_event'] ?? '').toString().trim();
    final subscriptionStatus = (customerRow['lemon_subscription_status'] ?? '')
        .toString()
        .trim();
    final lastEventAtRaw = (customerRow['lemon_last_event_at'] ?? '')
        .toString()
        .trim();

    final odemeAlindi =
        const {
          'order_created',
          'subscription_created',
          'subscription_updated',
          'subscription_plan_changed',
          'subscription_payment_success',
          'subscription_payment_recovered',
        }.contains(lastEvent) ||
        const {
          'paid',
          'active',
          'on_trial',
          'past_due',
          'unpaid',
          'paused',
          'cancelled',
        }.contains(subscriptionStatus.toLowerCase());

    return ProCheckoutIzlemeDurumu(
      customerId: (customerRow['id'] ?? '').toString().trim(),
      lastEvent: lastEvent.isEmpty ? null : lastEvent,
      lastEventAt: DateTime.tryParse(lastEventAtRaw),
      subscriptionStatus: subscriptionStatus.isEmpty
          ? null
          : subscriptionStatus,
      variantName:
          (customerRow['lemon_variant_name'] ?? '').toString().trim().isEmpty
          ? null
          : (customerRow['lemon_variant_name'] ?? '').toString().trim(),
      odemeAlindi: odemeAlindi,
    );
  }

  static Future<ProIptalSonucu> proAboneliginiIptalEt({
    required String hardwareId,
    required String licenseId,
  }) async {
    final endpoint = Uri.parse(
      '${LisansServisi.u}/functions/v1/cancel-pro-subscription',
    );

    final response = await http.post(
      endpoint,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'apikey': LisansServisi.k,
        'Authorization': 'Bearer ${LisansServisi.k}',
        'Cache-Control': 'no-cache',
        'Pragma': 'no-cache',
      },
      body: jsonEncode({
        'hardware_id': hardwareId.trim().toUpperCase(),
        'license_id': licenseId.trim().toUpperCase(),
      }),
    );

    Map<String, dynamic> payload = <String, dynamic>{};
    try {
      payload = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {}

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final rawMessage =
          [
                payload['error'],
                payload['message'],
                payload['details'] is Map
                    ? (payload['details'] as Map)['error']
                    : null,
              ]
              .map((value) => (value ?? '').toString().trim())
              .firstWhere((value) => value.isNotEmpty, orElse: () => '');
      throw ProSatinAlmaHatasi(
        rawMessage.isNotEmpty
            ? rawMessage
            : 'Pro iptal ve iade işlemi tamamlanamadı. Lütfen tekrar deneyin.',
      );
    }

    return ProIptalSonucu(
      refundAmount: (payload['refund_amount'] as num?)?.toDouble() ?? 0,
      paymentChannel: (payload['payment_channel'] ?? '').toString().trim(),
      planTitle: (payload['plan_title'] ?? '').toString().trim(),
      refundStatus: (payload['refund_status'] ?? '').toString().trim(),
    );
  }

  static Future<bool> odemeSayfasiniAc(Uri uri) {
    if (kIsWeb) {
      return launchUrl(uri, webOnlyWindowName: '_blank');
    }

    final launchMode = switch (defaultTargetPlatform) {
      TargetPlatform.android ||
      TargetPlatform.iOS => LaunchMode.inAppBrowserView,
      _ => LaunchMode.externalApplication,
    };

    return launchUrl(uri, mode: launchMode);
  }

  static Future<void> odemeSayfasiniKapat() async {
    try {
      await closeInAppWebView();
    } catch (_) {}
  }

  static Future<bool> disTarayicidaAc(Uri uri) {
    if (kIsWeb) {
      return launchUrl(uri, webOnlyWindowName: '_blank');
    }
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
