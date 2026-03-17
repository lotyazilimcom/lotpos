import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'lisans_servisi.dart';
import 'pro_satin_alma_servisi.dart'
    show ProOdemeFormEtiketleri, ProSatinAlmaOnBilgi, ProSatinAlmaServisi;

class LosPayKrediDialogMetinleri {
  final String title;
  final String subtitle;
  final String creditStepLabel;
  final String formStepLabel;
  final String checkoutStepLabel;
  final String creditSectionTitle;
  final String creditSectionSubtitle;
  final String creditInfoText;
  final String creditAmountLabel;
  final String creditAmountHelp;
  final String creditAmountPlaceholder;
  final String pricePerCreditLabel;
  final String totalPriceLabel;
  final String minimumCreditsNote;
  final String minimumChargeNote;
  final String summaryTitle;
  final String summaryBody;
  final String summaryCreditsLabel;
  final String summaryUnitPriceLabel;
  final String summaryMinimumCreditsLabel;
  final String summaryMinimumChargeLabel;
  final String currentBalanceLabel;
  final String formSectionTitle;
  final String existingCustomerNote;
  final String newCustomerNote;
  final String invoiceNote;
  final String footerNote;
  final String changeCreditsLabel;
  final String continueLabel;
  final String cancelLabel;
  final String backLabel;
  final String purchaseButtonTemplate;
  final String loadingText;
  final String requiredFieldText;
  final String invalidEmailText;
  final String creditAmountRequiredText;
  final String creditAmountMinText;
  final String creditAmountMaxText;
  final String creditAmountStepText;
  final String checkoutOpenErrorText;
  final String copySuccessText;
  final String checkoutOpenedBannerText;
  final String paymentReceivedBannerText;
  final String creditLoadedBannerText;
  final String checkoutTrackingWaitingTitle;
  final String checkoutTrackingWaitingBody;
  final String checkoutTrackingPaymentReceivedTitle;
  final String checkoutTrackingPaymentReceivedBody;
  final String checkoutTrackingCompletedTitle;
  final String checkoutTrackingCompletedBody;
  final String checkoutTimelineOpenedTitle;
  final String checkoutTimelineOpenedSubtitle;
  final String checkoutTimelineWaitingTitle;
  final String checkoutTimelineWaitingSubtitle;
  final String checkoutTimelineReceivedSubtitle;
  final String checkoutTimelineActivationTitle;
  final String checkoutTimelineActivationSubtitle;
  final String checkoutTimelineCompletedSubtitle;
  final String checkoutOpenAgainHint;
  final String checkoutBrowserHint;
  final String checkoutReloadLabel;
  final String checkoutCopyLinkLabel;
  final String checkoutOpenAgainLabel;
  final String checkoutFooterWaitingText;
  final String checkoutFooterPaymentReceivedText;
  final String checkoutFooterCompletedText;
  final String eventLabelOrderCreated;
  final String eventLabelFailed;
  final String eventLabelCancelled;
  final String eventLabelRefunded;
  final String creditUnitLabel;

  const LosPayKrediDialogMetinleri({
    required this.title,
    required this.subtitle,
    required this.creditStepLabel,
    required this.formStepLabel,
    required this.checkoutStepLabel,
    required this.creditSectionTitle,
    required this.creditSectionSubtitle,
    required this.creditInfoText,
    required this.creditAmountLabel,
    required this.creditAmountHelp,
    required this.creditAmountPlaceholder,
    required this.pricePerCreditLabel,
    required this.totalPriceLabel,
    required this.minimumCreditsNote,
    required this.minimumChargeNote,
    required this.summaryTitle,
    required this.summaryBody,
    required this.summaryCreditsLabel,
    required this.summaryUnitPriceLabel,
    required this.summaryMinimumCreditsLabel,
    required this.summaryMinimumChargeLabel,
    required this.currentBalanceLabel,
    required this.formSectionTitle,
    required this.existingCustomerNote,
    required this.newCustomerNote,
    required this.invoiceNote,
    required this.footerNote,
    required this.changeCreditsLabel,
    required this.continueLabel,
    required this.cancelLabel,
    required this.backLabel,
    required this.purchaseButtonTemplate,
    required this.loadingText,
    required this.requiredFieldText,
    required this.invalidEmailText,
    required this.creditAmountRequiredText,
    required this.creditAmountMinText,
    required this.creditAmountMaxText,
    required this.creditAmountStepText,
    required this.checkoutOpenErrorText,
    required this.copySuccessText,
    required this.checkoutOpenedBannerText,
    required this.paymentReceivedBannerText,
    required this.creditLoadedBannerText,
    required this.checkoutTrackingWaitingTitle,
    required this.checkoutTrackingWaitingBody,
    required this.checkoutTrackingPaymentReceivedTitle,
    required this.checkoutTrackingPaymentReceivedBody,
    required this.checkoutTrackingCompletedTitle,
    required this.checkoutTrackingCompletedBody,
    required this.checkoutTimelineOpenedTitle,
    required this.checkoutTimelineOpenedSubtitle,
    required this.checkoutTimelineWaitingTitle,
    required this.checkoutTimelineWaitingSubtitle,
    required this.checkoutTimelineReceivedSubtitle,
    required this.checkoutTimelineActivationTitle,
    required this.checkoutTimelineActivationSubtitle,
    required this.checkoutTimelineCompletedSubtitle,
    required this.checkoutOpenAgainHint,
    required this.checkoutBrowserHint,
    required this.checkoutReloadLabel,
    required this.checkoutCopyLinkLabel,
    required this.checkoutOpenAgainLabel,
    required this.checkoutFooterWaitingText,
    required this.checkoutFooterPaymentReceivedText,
    required this.checkoutFooterCompletedText,
    required this.eventLabelOrderCreated,
    required this.eventLabelFailed,
    required this.eventLabelCancelled,
    required this.eventLabelRefunded,
    required this.creditUnitLabel,
  });

  factory LosPayKrediDialogMetinleri.fromJson(
    Map<String, dynamic> json,
    LosPayKrediDialogMetinleri fallback,
  ) {
    String read(String key, String fallbackValue) {
      final value = (json[key] ?? '').toString().trim();
      return value.isEmpty ? fallbackValue : value;
    }

    return LosPayKrediDialogMetinleri(
      title: read('title', fallback.title),
      subtitle: read('subtitle', fallback.subtitle),
      creditStepLabel: read('creditStepLabel', fallback.creditStepLabel),
      formStepLabel: read('formStepLabel', fallback.formStepLabel),
      checkoutStepLabel: read('checkoutStepLabel', fallback.checkoutStepLabel),
      creditSectionTitle: read(
        'creditSectionTitle',
        fallback.creditSectionTitle,
      ),
      creditSectionSubtitle: read(
        'creditSectionSubtitle',
        fallback.creditSectionSubtitle,
      ),
      creditInfoText: read('creditInfoText', fallback.creditInfoText),
      creditAmountLabel: read('creditAmountLabel', fallback.creditAmountLabel),
      creditAmountHelp: read('creditAmountHelp', fallback.creditAmountHelp),
      creditAmountPlaceholder: read(
        'creditAmountPlaceholder',
        fallback.creditAmountPlaceholder,
      ),
      pricePerCreditLabel: read(
        'pricePerCreditLabel',
        fallback.pricePerCreditLabel,
      ),
      totalPriceLabel: read('totalPriceLabel', fallback.totalPriceLabel),
      minimumCreditsNote: read(
        'minimumCreditsNote',
        fallback.minimumCreditsNote,
      ),
      minimumChargeNote: read(
        'minimumChargeNote',
        fallback.minimumChargeNote,
      ),
      summaryTitle: read('summaryTitle', fallback.summaryTitle),
      summaryBody: read('summaryBody', fallback.summaryBody),
      summaryCreditsLabel: read(
        'summaryCreditsLabel',
        fallback.summaryCreditsLabel,
      ),
      summaryUnitPriceLabel: read(
        'summaryUnitPriceLabel',
        fallback.summaryUnitPriceLabel,
      ),
      summaryMinimumCreditsLabel: read(
        'summaryMinimumCreditsLabel',
        fallback.summaryMinimumCreditsLabel,
      ),
      summaryMinimumChargeLabel: read(
        'summaryMinimumChargeLabel',
        fallback.summaryMinimumChargeLabel,
      ),
      currentBalanceLabel: read(
        'currentBalanceLabel',
        fallback.currentBalanceLabel,
      ),
      formSectionTitle: read('formSectionTitle', fallback.formSectionTitle),
      existingCustomerNote: read(
        'existingCustomerNote',
        fallback.existingCustomerNote,
      ),
      newCustomerNote: read('newCustomerNote', fallback.newCustomerNote),
      invoiceNote: read('invoiceNote', fallback.invoiceNote),
      footerNote: read('footerNote', fallback.footerNote),
      changeCreditsLabel: read(
        'changeCreditsLabel',
        fallback.changeCreditsLabel,
      ),
      continueLabel: read('continueLabel', fallback.continueLabel),
      cancelLabel: read('cancelLabel', fallback.cancelLabel),
      backLabel: read('backLabel', fallback.backLabel),
      purchaseButtonTemplate: read(
        'purchaseButtonTemplate',
        fallback.purchaseButtonTemplate,
      ),
      loadingText: read('loadingText', fallback.loadingText),
      requiredFieldText: read(
        'requiredFieldText',
        fallback.requiredFieldText,
      ),
      invalidEmailText: read('invalidEmailText', fallback.invalidEmailText),
      creditAmountRequiredText: read(
        'creditAmountRequiredText',
        fallback.creditAmountRequiredText,
      ),
      creditAmountMinText: read(
        'creditAmountMinText',
        fallback.creditAmountMinText,
      ),
      creditAmountMaxText: read(
        'creditAmountMaxText',
        fallback.creditAmountMaxText,
      ),
      creditAmountStepText: read(
        'creditAmountStepText',
        fallback.creditAmountStepText,
      ),
      checkoutOpenErrorText: read(
        'checkoutOpenErrorText',
        fallback.checkoutOpenErrorText,
      ),
      copySuccessText: read('copySuccessText', fallback.copySuccessText),
      checkoutOpenedBannerText: read(
        'checkoutOpenedBannerText',
        fallback.checkoutOpenedBannerText,
      ),
      paymentReceivedBannerText: read(
        'paymentReceivedBannerText',
        fallback.paymentReceivedBannerText,
      ),
      creditLoadedBannerText: read(
        'creditLoadedBannerText',
        fallback.creditLoadedBannerText,
      ),
      checkoutTrackingWaitingTitle: read(
        'checkoutTrackingWaitingTitle',
        fallback.checkoutTrackingWaitingTitle,
      ),
      checkoutTrackingWaitingBody: read(
        'checkoutTrackingWaitingBody',
        fallback.checkoutTrackingWaitingBody,
      ),
      checkoutTrackingPaymentReceivedTitle: read(
        'checkoutTrackingPaymentReceivedTitle',
        fallback.checkoutTrackingPaymentReceivedTitle,
      ),
      checkoutTrackingPaymentReceivedBody: read(
        'checkoutTrackingPaymentReceivedBody',
        fallback.checkoutTrackingPaymentReceivedBody,
      ),
      checkoutTrackingCompletedTitle: read(
        'checkoutTrackingCompletedTitle',
        fallback.checkoutTrackingCompletedTitle,
      ),
      checkoutTrackingCompletedBody: read(
        'checkoutTrackingCompletedBody',
        fallback.checkoutTrackingCompletedBody,
      ),
      checkoutTimelineOpenedTitle: read(
        'checkoutTimelineOpenedTitle',
        fallback.checkoutTimelineOpenedTitle,
      ),
      checkoutTimelineOpenedSubtitle: read(
        'checkoutTimelineOpenedSubtitle',
        fallback.checkoutTimelineOpenedSubtitle,
      ),
      checkoutTimelineWaitingTitle: read(
        'checkoutTimelineWaitingTitle',
        fallback.checkoutTimelineWaitingTitle,
      ),
      checkoutTimelineWaitingSubtitle: read(
        'checkoutTimelineWaitingSubtitle',
        fallback.checkoutTimelineWaitingSubtitle,
      ),
      checkoutTimelineReceivedSubtitle: read(
        'checkoutTimelineReceivedSubtitle',
        fallback.checkoutTimelineReceivedSubtitle,
      ),
      checkoutTimelineActivationTitle: read(
        'checkoutTimelineActivationTitle',
        fallback.checkoutTimelineActivationTitle,
      ),
      checkoutTimelineActivationSubtitle: read(
        'checkoutTimelineActivationSubtitle',
        fallback.checkoutTimelineActivationSubtitle,
      ),
      checkoutTimelineCompletedSubtitle: read(
        'checkoutTimelineCompletedSubtitle',
        fallback.checkoutTimelineCompletedSubtitle,
      ),
      checkoutOpenAgainHint: read(
        'checkoutOpenAgainHint',
        fallback.checkoutOpenAgainHint,
      ),
      checkoutBrowserHint: read(
        'checkoutBrowserHint',
        fallback.checkoutBrowserHint,
      ),
      checkoutReloadLabel: read(
        'checkoutReloadLabel',
        fallback.checkoutReloadLabel,
      ),
      checkoutCopyLinkLabel: read(
        'checkoutCopyLinkLabel',
        fallback.checkoutCopyLinkLabel,
      ),
      checkoutOpenAgainLabel: read(
        'checkoutOpenAgainLabel',
        fallback.checkoutOpenAgainLabel,
      ),
      checkoutFooterWaitingText: read(
        'checkoutFooterWaitingText',
        fallback.checkoutFooterWaitingText,
      ),
      checkoutFooterPaymentReceivedText: read(
        'checkoutFooterPaymentReceivedText',
        fallback.checkoutFooterPaymentReceivedText,
      ),
      checkoutFooterCompletedText: read(
        'checkoutFooterCompletedText',
        fallback.checkoutFooterCompletedText,
      ),
      eventLabelOrderCreated: read(
        'eventLabelOrderCreated',
        fallback.eventLabelOrderCreated,
      ),
      eventLabelFailed: read('eventLabelFailed', fallback.eventLabelFailed),
      eventLabelCancelled: read(
        'eventLabelCancelled',
        fallback.eventLabelCancelled,
      ),
      eventLabelRefunded: read(
        'eventLabelRefunded',
        fallback.eventLabelRefunded,
      ),
      creditUnitLabel: read('creditUnitLabel', fallback.creditUnitLabel),
    );
  }
}

class LosPayKrediAyarlari {
  final String variantId;
  final String variantName;
  final String productName;
  final double pricePerCredit;
  final int minCredits;
  final int maxCredits;
  final int defaultCredits;
  final int stepCredits;
  final double minimumChargeAmount;

  const LosPayKrediAyarlari({
    required this.variantId,
    required this.variantName,
    required this.productName,
    required this.pricePerCredit,
    required this.minCredits,
    required this.maxCredits,
    required this.defaultCredits,
    required this.stepCredits,
    required this.minimumChargeAmount,
  });

  factory LosPayKrediAyarlari.fromJson(
    Map<String, dynamic> json,
    LosPayKrediAyarlari fallback,
  ) {
    final pricePerCredit = (json['pricePerCredit'] as num?)?.toDouble();
    final minCredits = (json['minCredits'] as num?)?.toInt();
    final maxCredits = (json['maxCredits'] as num?)?.toInt();
    final defaultCredits = (json['defaultCredits'] as num?)?.toInt();
    final stepCredits = (json['stepCredits'] as num?)?.toInt();
    final minimumChargeAmount =
        (json['minimumChargeAmount'] as num?)?.toDouble();

    return LosPayKrediAyarlari(
      variantId: (json['variantId'] ?? fallback.variantId).toString().trim(),
      variantName:
          (json['variantName'] ?? fallback.variantName).toString().trim(),
      productName:
          (json['productName'] ?? fallback.productName).toString().trim(),
      pricePerCredit:
          pricePerCredit != null && pricePerCredit > 0
              ? pricePerCredit
              : fallback.pricePerCredit,
      minCredits:
          minCredits != null && minCredits > 0 ? minCredits : fallback.minCredits,
      maxCredits:
          maxCredits != null && maxCredits > 0 ? maxCredits : fallback.maxCredits,
      defaultCredits:
          defaultCredits != null && defaultCredits > 0
              ? defaultCredits
              : fallback.defaultCredits,
      stepCredits:
          stepCredits != null && stepCredits > 0 ? stepCredits : fallback.stepCredits,
      minimumChargeAmount:
          minimumChargeAmount != null && minimumChargeAmount > 0
              ? minimumChargeAmount
              : fallback.minimumChargeAmount,
    );
  }
}

class LosPayKrediProfili {
  final String locale;
  final String currencyCode;
  final bool configured;
  final LosPayKrediDialogMetinleri dialog;
  final ProOdemeFormEtiketleri formLabels;
  final LosPayKrediAyarlari credit;

  const LosPayKrediProfili({
    required this.locale,
    required this.currencyCode,
    required this.configured,
    required this.dialog,
    required this.formLabels,
    required this.credit,
  });
}

class LosPayKrediCheckoutSonucu {
  final Uri checkoutUri;
  final String checkoutId;
  final String requestKey;
  final String? customerId;
  final int creditAmount;
  final double totalAmount;

  const LosPayKrediCheckoutSonucu({
    required this.checkoutUri,
    required this.checkoutId,
    required this.requestKey,
    required this.customerId,
    required this.creditAmount,
    required this.totalAmount,
  });
}

class LosPayKrediDurumu {
  final String? customerId;
  final String? status;
  final String? orderId;
  final String? orderIdentifier;
  final DateTime? updatedAt;
  final DateTime? completedAt;
  final bool odemeAlindi;
  final bool krediYuklendi;
  final double currentBalance;

  const LosPayKrediDurumu({
    required this.customerId,
    required this.status,
    required this.orderId,
    required this.orderIdentifier,
    required this.updatedAt,
    required this.completedAt,
    required this.odemeAlindi,
    required this.krediYuklendi,
    required this.currentBalance,
  });

  const LosPayKrediDurumu.bos()
    : customerId = null,
      status = null,
      orderId = null,
      orderIdentifier = null,
      updatedAt = null,
      completedAt = null,
      odemeAlindi = false,
      krediYuklendi = false,
      currentBalance = 0;
}

class LosPayKrediHatasi implements Exception {
  final String mesaj;
  const LosPayKrediHatasi(this.mesaj);

  @override
  String toString() => mesaj;
}

class LosPayKrediServisi {
  LosPayKrediServisi._();

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

  static LosPayKrediDialogMetinleri _varsayilanDialog(String locale) {
    if (locale == 'tr') {
      return const LosPayKrediDialogMetinleri(
        title: 'LosPay Kredi Yükle',
        subtitle:
            'Kredi miktarını girin, fatura bilgilerini kontrol edin ve güvenli ödeme sayfasından LosPay kredinizi otomatik yükleyin.',
        creditStepLabel: 'Kredi miktarı',
        formStepLabel: 'Faturalama ve iletişim bilgileri',
        checkoutStepLabel: 'Güvenli ödeme',
        creditSectionTitle: 'Yüklenecek kredi miktarını belirleyin',
        creditSectionSubtitle:
            'Birim fiyat, minimum kredi ve üst limit admin ödeme ayarlarından yönetilir.',
        creditInfoText:
            'Girilen kredi miktarına göre toplam tutar anında hesaplanır. Ödeme tamamlandığında kredi bakiyesi otomatik yüklenir.',
        creditAmountLabel: 'LosPay kredi miktarı',
        creditAmountHelp:
            'Tam sayı kredi girin. Toplam ödeme tutarı girilen krediye göre otomatik hesaplanır.',
        creditAmountPlaceholder: '100',
        pricePerCreditLabel: '1 kredi fiyatı',
        totalPriceLabel: 'Toplam tutar',
        minimumCreditsNote: 'En az {min} kredi satın alınabilir.',
        minimumChargeNote:
            'Toplam tutar en az {amount} olmalıdır. Bu sınır Lemon varyant taban fiyatı ile uyumlu tutulur.',
        summaryTitle: 'LosPay kredi özeti',
        summaryBody:
            'Seçtiğiniz kredi miktarı ve toplam tutar checkout ekranına güvenli şekilde aktarılır.',
        summaryCreditsLabel: 'Yüklenecek kredi',
        summaryUnitPriceLabel: 'Birim fiyat',
        summaryMinimumCreditsLabel: 'Minimum kredi',
        summaryMinimumChargeLabel: 'Minimum tutar',
        currentBalanceLabel: 'Mevcut Bakiye',
        formSectionTitle: 'Faturalama ve iletişim bilgileri',
        existingCustomerNote:
            'Sistemde mevcut müşteri kaydınız bulundu. Hazır gelen alanları kontrol edip eksik bilgileri tamamlamanız yeterlidir.',
        newCustomerNote:
            'Bu cihaz için müşteri kaydı oluşturulacak. Fatura ve iletişim alanlarını eksiksiz doldurun.',
        invoiceNote:
            'Bu bilgiler LemonSqueezy ödeme sayfasına ön doldurma olarak gönderilir ve kredi yükleme kaydında kullanılır.',
        footerNote:
            'Ödeme sonrası LosPay bakiyesi masaüstü uygulamada ve admin panelinde otomatik güncellenir.',
        changeCreditsLabel: 'Miktarı değiştir',
        continueLabel: 'Devam Et',
        cancelLabel: 'İptal',
        backLabel: 'Geri',
        purchaseButtonTemplate: '{price} ile Kredi Yükle',
        loadingText: 'Yükleniyor...',
        requiredFieldText: 'Bu alan zorunludur.',
        invalidEmailText: 'Geçerli bir e-posta girin.',
        creditAmountRequiredText: 'Kredi miktarı girin.',
        creditAmountMinText: 'En az {min} kredi girilmelidir.',
        creditAmountMaxText: 'En fazla {max} kredi girilebilir.',
        creditAmountStepText: '{step} katlarıyla ilerleyin.',
        checkoutOpenErrorText:
            'Ödeme sayfası otomatik açılamadı. Bağlantıyı kopyalayıp tarayıcıda açın.',
        copySuccessText: 'Bağlantı panoya kopyalandı.',
        checkoutOpenedBannerText:
            'Ödeme sayfası güvenli tarayıcıda açıldı. Ödeme tamamlandığında bu pencere kredi durumunu otomatik yeniler.',
        paymentReceivedBannerText:
            'Ödeme alındı. Lemon ödemeyi doğruladı; LosPay krediniz şu anda otomatik olarak yükleniyor.',
        creditLoadedBannerText:
            'LosPay krediniz yüklendi. Pencere kapatılıyor ve uygulama yeni bakiyeyi yüklüyor.',
        checkoutTrackingWaitingTitle: 'Güvenli ödeme takibi',
        checkoutTrackingWaitingBody:
            'Ödemenizi tarayıcıda tamamlayın. Bu pencere kredi yükleme sonucunu arka planda izlemeye devam eder.',
        checkoutTrackingPaymentReceivedTitle: 'Ödeme onayı alındı',
        checkoutTrackingPaymentReceivedBody:
            'Webhook bildirimi alındı. Kredi yükleme kaydı ve bakiye güncellemesi tamamlanıyor.',
        checkoutTrackingCompletedTitle: 'LosPay kredisi yüklendi',
        checkoutTrackingCompletedBody:
            'Sistem yeni bakiyeyi doğruladı. Bu pencere otomatik olarak kapanacak.',
        checkoutTimelineOpenedTitle: 'Ödeme sayfası güvenli tarayıcıda açıldı',
        checkoutTimelineOpenedSubtitle: 'lossoft.lemonsqueezy.com',
        checkoutTimelineWaitingTitle: 'Lemon ödeme sonucu bekleniyor',
        checkoutTimelineWaitingSubtitle:
            'Webhook ve veritabanı dinleme akışı siparişi izliyor.',
        checkoutTimelineReceivedSubtitle:
            'Ödeme bildirimi alındı ve kredi yükleme akışı başladı.',
        checkoutTimelineActivationTitle:
            'LosPay kredisi otomatik yüklenecek',
        checkoutTimelineActivationSubtitle:
            'Ödeme tamamlandığında bu pencere kendini kapatır.',
        checkoutTimelineCompletedSubtitle:
            'Bakiye doğrulandı. Program yeni kredi durumunu kullanıyor.',
        checkoutOpenAgainHint:
            'Tarayıcı açılmadıysa aşağıdaki butonla ödeme sayfasını tekrar açabilirsiniz.',
        checkoutBrowserHint:
            'Tarayıcı kapanırsa sorun değil. Lemon webhook bildirimi geldiğinde bu pencere otomatik güncellenecek.',
        checkoutReloadLabel: 'Yenile',
        checkoutCopyLinkLabel: 'Bağlantıyı Kopyala',
        checkoutOpenAgainLabel: 'Ödeme Sayfasını Aç',
        checkoutFooterWaitingText:
            'Ödeme tamamlandığında bu pencere kredi durumunu otomatik kontrol eder.',
        checkoutFooterPaymentReceivedText:
            'Ödeme alındı. Kredi bakiyesi hazırlanıyor; bu pencere birazdan durumu otomatik yeniler.',
        checkoutFooterCompletedText:
            'LosPay kredisi aktif. Pencere kapanırken uygulama yeni durumu kullanacak.',
        eventLabelOrderCreated: 'Ödeme alındı',
        eventLabelFailed: 'Ödeme başarısız',
        eventLabelCancelled: 'Sipariş iptal edildi',
        eventLabelRefunded: 'İade edildi',
        creditUnitLabel: 'kredi',
      );
    }

    return const LosPayKrediDialogMetinleri(
      title: 'Load LosPay Credits',
      subtitle:
          'Enter the credit amount, confirm billing details, and load LosPay credits automatically through the secure checkout page.',
      creditStepLabel: 'Credit amount',
      formStepLabel: 'Billing and contact details',
      checkoutStepLabel: 'Secure checkout',
      creditSectionTitle: 'Choose how many credits to load',
      creditSectionSubtitle:
          'Unit price, minimum credits, and upper limits are managed from the admin payment settings.',
      creditInfoText:
          'The total amount is calculated instantly from the entered credit amount. After payment, the balance is loaded automatically.',
      creditAmountLabel: 'LosPay credit amount',
      creditAmountHelp:
          'Enter an integer credit amount. The total payment amount is calculated automatically from the entered credits.',
      creditAmountPlaceholder: '100',
      pricePerCreditLabel: 'Price per credit',
      totalPriceLabel: 'Total amount',
      minimumCreditsNote: 'At least {min} credits can be purchased.',
      minimumChargeNote:
          'The total amount must be at least {amount}. Keep this aligned with the Lemon variant base price.',
      summaryTitle: 'LosPay credit summary',
      summaryBody:
          'The selected credit amount and total price are sent to the checkout securely.',
      summaryCreditsLabel: 'Credits to load',
      summaryUnitPriceLabel: 'Unit price',
      summaryMinimumCreditsLabel: 'Minimum credits',
      summaryMinimumChargeLabel: 'Minimum amount',
      currentBalanceLabel: 'Current balance',
      formSectionTitle: 'Billing and contact details',
      existingCustomerNote:
          'We found an existing customer record. Review the prefilled fields and complete any missing details.',
      newCustomerNote:
          'A customer record will be created for this device. Fill in the billing and contact details completely.',
      invoiceNote:
          'These details are passed to LemonSqueezy as checkout prefill data and are used for the credit loading record.',
      footerNote:
          'After payment, the LosPay balance is refreshed automatically in both the desktop app and the admin panel.',
      changeCreditsLabel: 'Change amount',
      continueLabel: 'Continue',
      cancelLabel: 'Cancel',
      backLabel: 'Back',
      purchaseButtonTemplate: 'Load Credits with {price}',
      loadingText: 'Loading...',
      requiredFieldText: 'This field is required.',
      invalidEmailText: 'Enter a valid email address.',
      creditAmountRequiredText: 'Enter a credit amount.',
      creditAmountMinText: 'Enter at least {min} credits.',
      creditAmountMaxText: 'Enter at most {max} credits.',
      creditAmountStepText: 'Use increments of {step}.',
      checkoutOpenErrorText:
          'The checkout page could not be opened automatically. Copy the link and open it in your browser.',
      copySuccessText: 'Checkout link copied.',
      checkoutOpenedBannerText:
          'The checkout page opened in a secure browser. This dialog will refresh the credit status automatically after payment.',
      paymentReceivedBannerText:
          'Your payment was received. Lemon confirmed it and your LosPay credits are being loaded automatically.',
      creditLoadedBannerText:
          'Your LosPay credits were loaded. This dialog will close and refresh the balance.',
      checkoutTrackingWaitingTitle: 'Secure checkout tracking',
      checkoutTrackingWaitingBody:
          'Complete the payment in your browser. This dialog keeps tracking the credit loading result in the background.',
      checkoutTrackingPaymentReceivedTitle: 'Payment confirmation received',
      checkoutTrackingPaymentReceivedBody:
          'A webhook event was received. The credit loading record and balance update are being finalized.',
      checkoutTrackingCompletedTitle: 'LosPay credits loaded',
      checkoutTrackingCompletedBody:
          'The system confirmed the new balance. This dialog will close automatically.',
      checkoutTimelineOpenedTitle: 'Checkout page opened in a secure browser',
      checkoutTimelineOpenedSubtitle: 'lossoft.lemonsqueezy.com',
      checkoutTimelineWaitingTitle: 'Waiting for Lemon payment confirmation',
      checkoutTimelineWaitingSubtitle:
          'Webhook and database listeners are tracking the order.',
      checkoutTimelineReceivedSubtitle:
          'A payment event was received and the credit loading flow started.',
      checkoutTimelineActivationTitle:
          'LosPay credits will be loaded automatically',
      checkoutTimelineActivationSubtitle:
          'This dialog closes itself as soon as the payment is completed.',
      checkoutTimelineCompletedSubtitle:
          'The balance was verified and the app is switching to the new state.',
      checkoutOpenAgainHint:
          'If the browser did not open, you can reopen the checkout page with the button below.',
      checkoutBrowserHint:
          'If the browser closes, no problem. This dialog updates automatically when Lemon sends the webhook.',
      checkoutReloadLabel: 'Reload',
      checkoutCopyLinkLabel: 'Copy Link',
      checkoutOpenAgainLabel: 'Open Checkout',
      checkoutFooterWaitingText:
          'Once the payment is completed, this dialog keeps checking your balance automatically.',
      checkoutFooterPaymentReceivedText:
          'Payment received. Your balance is being prepared and this dialog will refresh the status automatically.',
      checkoutFooterCompletedText:
          'LosPay credits are active. The app will use the new balance when this dialog closes.',
      eventLabelOrderCreated: 'Payment received',
      eventLabelFailed: 'Payment failed',
      eventLabelCancelled: 'Order cancelled',
      eventLabelRefunded: 'Refunded',
      creditUnitLabel: 'credits',
    );
  }

  static LosPayKrediAyarlari _varsayilanKrediAyarlari(String locale) {
    return const LosPayKrediAyarlari(
      variantId: '1408660',
      variantName: 'LosPay Kredi',
      productName: 'LosPay Kredi',
      pricePerCredit: 0.25,
      minCredits: 100,
      maxCredits: 5000,
      defaultCredits: 100,
      stepCredits: 1,
      minimumChargeAmount: 25,
    );
  }

  static LosPayKrediProfili varsayilanOdemeProfili(String locale) {
    final normalizedLocale = ProSatinAlmaServisi.odemeProfiliLocale(locale);
    return LosPayKrediProfili(
      locale: normalizedLocale,
      currencyCode: normalizedLocale == 'tr' ? 'TRY' : 'USD',
      configured: false,
      dialog: _varsayilanDialog(normalizedLocale),
      formLabels: _varsayilanFormEtiketleri(normalizedLocale),
      credit: _varsayilanKrediAyarlari(normalizedLocale),
    );
  }

  static Future<LosPayKrediProfili> odemeProfiliniGetir({
    required String locale,
  }) async {
    final normalizedLocale = ProSatinAlmaServisi.odemeProfiliLocale(locale);
    final fallback = varsayilanOdemeProfili(normalizedLocale);
    final endpoint =
        Uri.parse('${LisansServisi.u}/functions/v1/get-lospay-credit-profile')
            .replace(
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
      return LosPayKrediProfili(
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
        dialog: LosPayKrediDialogMetinleri.fromJson(
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
        credit: LosPayKrediAyarlari.fromJson(
          Map<String, dynamic>.from(
            ((payload['credit'] as Map?) ?? const {}).cast<String, dynamic>(),
          ),
          fallback.credit,
        ),
      );
    } catch (_) {
      return fallback;
    }
  }

  static Future<ProSatinAlmaOnBilgi> hazirBilgileriGetir() {
    return ProSatinAlmaServisi.hazirBilgileriGetir();
  }

  static Future<LosPayKrediCheckoutSonucu> checkoutOlustur({
    required int creditAmount,
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
      '${LisansServisi.u}/functions/v1/create-lospay-credit-checkout',
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
        'credit_amount': creditAmount,
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
      final rawMessage = [
        payload['error'],
        payload['message'],
        payload['details'] is Map ? (payload['details'] as Map)['error'] : null,
      ]
          .map((value) => (value ?? '').toString().trim())
          .firstWhere((value) => value.isNotEmpty, orElse: () => '');

      throw LosPayKrediHatasi(
        rawMessage.isNotEmpty
            ? rawMessage
            : 'Kredi yükleme bağlantısı oluşturulamadı. Lütfen tekrar deneyin.',
      );
    }

    final url = (payload['checkout_url'] ?? '').toString().trim();
    final requestKey = (payload['request_key'] ?? '').toString().trim();
    if (url.isEmpty || requestKey.isEmpty) {
      throw const LosPayKrediHatasi(
        'Kredi yükleme bağlantısı oluşturuldu ancak checkout bilgisi eksik döndü.',
      );
    }

    final checkoutUri = Uri.tryParse(url);
    if (checkoutUri == null) {
      throw const LosPayKrediHatasi(
        'Kredi yükleme bağlantısı geçersiz görünüyor. Lütfen tekrar deneyin.',
      );
    }

    return LosPayKrediCheckoutSonucu(
      checkoutUri: checkoutUri,
      checkoutId: (payload['checkout_id'] ?? '').toString().trim(),
      requestKey: requestKey,
      customerId: (payload['customer_id'] ?? '').toString().trim().isEmpty
          ? null
          : (payload['customer_id'] ?? '').toString().trim(),
      creditAmount: (payload['credit_amount'] as num?)?.toInt() ?? creditAmount,
      totalAmount: (payload['total_amount'] as num?)?.toDouble() ?? 0,
    );
  }

  static Future<LosPayKrediDurumu> yuklemeDurumunuGetir({
    required String requestKey,
    required String hardwareId,
    String? customerId,
  }) async {
    final normalizedRequestKey = requestKey.trim();
    if (normalizedRequestKey.isEmpty) {
      return const LosPayKrediDurumu.bos();
    }

    final client = Supabase.instance.client;
    final loadRow = await client
        .from('lospay_credit_loads')
        .select(
          'customer_id, status, lemon_order_id, lemon_order_identifier, updated_at, completed_at',
        )
        .eq('request_key', normalizedRequestKey)
        .maybeSingle();

    if (loadRow == null) {
      return const LosPayKrediDurumu.bos();
    }

    final normalizedCustomerId = (customerId ?? '').trim();
    final resolvedCustomerId = (loadRow['customer_id'] ?? '').toString().trim();
    double currentBalance = 0;

    try {
      if (resolvedCustomerId.isNotEmpty || normalizedCustomerId.isNotEmpty) {
        final customerRow = await client
            .from('customers')
            .select('lospay_credit')
            .eq(
              'id',
              resolvedCustomerId.isNotEmpty
                  ? resolvedCustomerId
                  : normalizedCustomerId,
            )
            .maybeSingle();
        currentBalance =
            (customerRow?['lospay_credit'] as num?)?.toDouble() ?? 0;
      } else if (hardwareId.trim().isNotEmpty) {
        final customerRowsRaw = await client
            .from('customers')
            .select('lospay_credit')
            .eq('hardware_id', hardwareId.trim().toUpperCase());
        final customerRows =
            List<Map<String, dynamic>>.from(customerRowsRaw as List);
        for (final row in customerRows) {
          final value = (row['lospay_credit'] as num?)?.toDouble() ?? 0;
          if (value > currentBalance) {
            currentBalance = value;
          }
        }
      }
    } catch (_) {}

    if (hardwareId.trim().isNotEmpty) {
      try {
        final programRow = await client
            .from('program_deneme')
            .select('lospay_credit')
            .eq('hardware_id', hardwareId.trim().toUpperCase())
            .maybeSingle();
        final programBalance =
            (programRow?['lospay_credit'] as num?)?.toDouble() ?? 0;
        if (programBalance > currentBalance) {
          currentBalance = programBalance;
        }
      } catch (_) {}
    }

    final status = (loadRow['status'] ?? '').toString().trim().toLowerCase();
    final orderId = (loadRow['lemon_order_id'] ?? '').toString().trim();
    final orderIdentifier =
        (loadRow['lemon_order_identifier'] ?? '').toString().trim();
    final updatedAtRaw = (loadRow['updated_at'] ?? '').toString().trim();
    final completedAtRaw = (loadRow['completed_at'] ?? '').toString().trim();

    final odemeAlindi = orderId.isNotEmpty || orderIdentifier.isNotEmpty;
    final krediYuklendi = status == 'completed';

    return LosPayKrediDurumu(
      customerId: resolvedCustomerId.isEmpty ? null : resolvedCustomerId,
      status: status.isEmpty ? null : status,
      orderId: orderId.isEmpty ? null : orderId,
      orderIdentifier: orderIdentifier.isEmpty ? null : orderIdentifier,
      updatedAt: DateTime.tryParse(updatedAtRaw),
      completedAt: DateTime.tryParse(completedAtRaw),
      odemeAlindi: odemeAlindi || krediYuklendi,
      krediYuklendi: krediYuklendi,
      currentBalance: currentBalance,
    );
  }

  static Future<bool> odemeSayfasiniAc(Uri uri) {
    return ProSatinAlmaServisi.odemeSayfasiniAc(uri);
  }

  static Future<void> odemeSayfasiniKapat() {
    return ProSatinAlmaServisi.odemeSayfasiniKapat();
  }

  static Future<bool> disTarayicidaAc(Uri uri) {
    return ProSatinAlmaServisi.disTarayicidaAc(uri);
  }
}
