import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../servisler/lisans_servisi.dart';
import '../servisler/lite_ayarlar_servisi.dart';
import '../servisler/lite_kisitlari.dart';
import '../yardimcilar/ceviri/ceviri_servisi.dart';

class LisansDiyalog extends StatefulWidget {
  const LisansDiyalog({super.key});

  @override
  State<LisansDiyalog> createState() => _LisansDiyalogState();
}

class _LisansDiyalogState extends State<LisansDiyalog> {
  bool _yukleniyor = false;
  String? _hataMesaji;
  bool _basarili = false;
  final TextEditingController _manuelKodController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Dialog açıldığında online ise server state'i çek (Lite/Pro durumu).
    // UI ListenableBuilder ile otomatik güncellenecek.
    unawaited(LisansServisi().dogrula());
  }

  @override
  void dispose() {
    _manuelKodController.dispose();
    super.dispose();
  }

  Future<void> _lisansAktifEt() async {
    setState(() {
      _yukleniyor = true;
      _hataMesaji = null;
    });

    try {
      final sonuc = await LisansServisi().lisansla();
      if (mounted) {
        if (sonuc) {
          setState(() {
            _basarili = true;
          });
          // Biraz bekle ve kapat
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) Navigator.of(context).pop(true);
          });
        } else {
          setState(() {
            _hataMesaji = tr('login.license.error.not_found');
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hataMesaji = tr('login.license.error.connection');
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _yukleniyor = false;
        });
      }
    }
  }

  Future<void> _manuelKoduUygula() async {
    setState(() {
      _yukleniyor = true;
      _hataMesaji = null;
    });

    try {
      final sonuc = await LisansServisi().manuelLisansKoduUygula(
        _manuelKodController.text,
      );

      if (!mounted) return;

      switch (sonuc) {
        case ManualLisansUygulamaSonucu.basarili:
          setState(() {
            _basarili = true;
          });
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) Navigator.of(context).pop(true);
          });
          break;
        case ManualLisansUygulamaSonucu.bosKod:
          setState(() {
            _hataMesaji = tr('login.license.manual_empty');
          });
          break;
        case ManualLisansUygulamaSonucu.gecersizKod:
          setState(() {
            _hataMesaji = tr('login.license.manual_invalid');
          });
          break;
        case ManualLisansUygulamaSonucu.farkliCihaz:
          setState(() {
            _hataMesaji = tr('login.license.manual_wrong_device');
          });
          break;
        case ManualLisansUygulamaSonucu.suresiDolmus:
          setState(() {
            _hataMesaji = tr('login.license.manual_expired');
          });
          break;
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _hataMesaji = tr('login.license.manual_invalid');
      });
    } finally {
      if (mounted) {
        setState(() {
          _yukleniyor = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hardwareId = LisansServisi().hardwareId ?? 'TANIMSIZ';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 400,
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1F38) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEA4335).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.security_outlined,
                    color: Color(0xFFEA4335),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr('login.license.title'),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF1A1F38),
                        ),
                      ),
                      Text(
                        tr('login.license.subtitle'),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                  color: Colors.grey,
                ),
              ],
            ),
            const SizedBox(height: 32),
            ListenableBuilder(
              listenable: LisansServisi(),
              builder: (context, _) {
                final masterLicenseId = LisansServisi().licenseId ?? 'TANIMSIZ';

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr('login.license.master_id'),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                        color: Colors.grey[500],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : const Color(0xFFF8F9FA),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.1)
                              : Colors.grey[200]!,
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.vpn_key_rounded,
                            size: 16,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            masterLicenseId,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2,
                              fontSize: 16,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.copy_rounded, size: 18),
                            onPressed: () {
                              Clipboard.setData(
                                ClipboardData(text: masterLicenseId),
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    tr('login.license.copy_success'),
                                  ),
                                ),
                              );
                            },
                            tooltip: tr('common.select'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                );
              },
            ),
            Text(
              tr('login.license.hardware_id'),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
                color: Colors.grey[500],
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : const Color(0xFFF8F9FA),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.grey[200]!,
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.computer, size: 16, color: Colors.grey),
                  const SizedBox(width: 12),
                  Text(
                    hardwareId,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                      fontSize: 16,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: hardwareId));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(tr('login.license.copy_success')),
                        ),
                      );
                    },
                    tooltip: tr('common.select'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            ListenableBuilder(
              listenable: Listenable.merge([LisansServisi(), LiteAyarlarServisi()]),
              builder: (context, _) {
                final lisans = LisansServisi();
                final isLite = lisans.isLiteMode;
                final endDate = lisans.licenseEndDate?.toLocal();
                final accent =
                    isLite ? const Color(0xFFEA4335) : const Color(0xFFF39C12);

                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: isDark ? 0.14 : 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: accent.withValues(alpha: isDark ? 0.28 : 0.18),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            isLite
                                ? Icons.lock_rounded
                                : Icons.workspace_premium_rounded,
                            size: 18,
                            color: accent,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                          child: Text(
                              isLite ? 'Lite sürüm' : 'Pro sürüm',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF2C3E50),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        isLite
                            ? 'Şu an LITE sürüm kullanıyorsunuz. Kullanım sınırlarına takıldığınızda PRO lisans almanız gerekir.'
                            : (endDate != null
                                ? 'Lisans bitiş tarihi: ${endDate.toString().split(' ').first}'
                                : 'Lisans aktif.'),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          height: 1.3,
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.9)
                              : const Color(0xFF2C3E50),
                        ),
                      ),
                      if (isLite) ...[
                        const SizedBox(height: 10),
                        _LimitSatiri(
                          text: '• ${LiteKisitlari.maxAktifCari} Aktif Cari',
                        ),
                        _LimitSatiri(
                          text:
                              '• Günde ${LiteKisitlari.maxGunlukSatis} Alış/Satış',
                        ),
                        _LimitSatiri(
                          text:
                              '• Perakende Satış: Günde ${LiteKisitlari.maxGunlukPerakendeSatis}',
                        ),
                        _LimitSatiri(
                          text:
                              '• Raporlar: Son ${LiteKisitlari.raporGun} Gün',
                        ),
                        _LimitSatiri(
                          text:
                              '• Banka & Kredi Kartı: ${LiteKisitlari.isBankCreditActive ? 'Açık' : 'Kapalı'}',
                        ),
                        _LimitSatiri(
                          text:
                              '• Çek & Senet: ${LiteKisitlari.isCheckPromissoryActive ? 'Açık' : 'Kapalı'}',
                        ),
                        _LimitSatiri(
                          text:
                              '• Bulut Yedekleme: ${LiteKisitlari.isCloudBackupActive ? 'Açık' : 'Kapalı'} / Excel: ${LiteKisitlari.isExcelExportActive ? 'Açık' : 'Kapalı'}',
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            Text(
              tr('login.license.help'),
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[500],
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 20),
            ListenableBuilder(
              listenable: LisansServisi(),
              builder: (context, _) {
                final lisans = LisansServisi();
                final onlineReady = lisans.serverReachable;
                final isLite = lisans.isLiteMode;

                if (!isLite) {
                  return const SizedBox.shrink();
                }

                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF39C12).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFFF39C12).withValues(alpha: 0.18),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr('login.license.manual_title'),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.1,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF1A1F38),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        onlineReady
                            ? tr('login.license.manual_hint')
                            : tr('login.license.manual_offline_hint'),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          height: 1.4,
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.85)
                              : const Color(0xFF2C3E50),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _manuelKodController,
                        minLines: 1,
                        maxLines: 2,
                        onChanged: (_) => setState(() {}),
                        textCapitalization: TextCapitalization.characters,
                        keyboardType: TextInputType.visiblePassword,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[A-Za-z0-9\-\s]'),
                          ),
                        ],
                        enabled: !_yukleniyor && !_basarili,
                        decoration: InputDecoration(
                          hintText: tr('login.license.manual_placeholder'),
                          filled: true,
                          fillColor: isDark
                              ? Colors.white.withValues(alpha: 0.05)
                              : const Color(0xFFF8F9FA),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: Colors.grey[200]!),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: Colors.grey[200]!),
                          ),
                          contentPadding: const EdgeInsets.all(14),
                        ),
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.4,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF1A1F38),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 32),
            if (_hataMesaji != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _hataMesaji!,
                  style: const TextStyle(
                    color: Colors.red,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            if (_basarili)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      tr('login.license.success'),
                      style: const TextStyle(
                        color: Colors.green,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            SizedBox(
              width: double.infinity,
              child: ListenableBuilder(
                listenable: LisansServisi(),
                builder: (context, _) {
                  final lisans = LisansServisi();
                  final isLite = lisans.isLiteMode;
                  final onlineReady = lisans.serverReachable;

                  if (!isLite) {
                    return SizedBox(
                      height: 54,
                      child: FilledButton(
                        onPressed: _yukleniyor || _basarili
                            ? null
                            : () => Navigator.of(context).pop(),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFEA4335),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: _yukleniyor
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                tr('common.ok'),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 13,
                                  letterSpacing: 1,
                                ),
                              ),
                      ),
                    );
                  }

                  return Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: OutlinedButton(
                          onPressed:
                              _yukleniyor || _basarili || !onlineReady
                              ? null
                              : _lisansAktifEt,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF2C3E50),
                            side: BorderSide(
                              color: onlineReady
                                  ? const Color(0xFF2C3E50).withValues(
                                      alpha: 0.18,
                                    )
                                  : Colors.grey.shade300,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            onlineReady
                                ? tr('login.license.button')
                                : tr('login.license.offline_verify_disabled'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: FilledButton(
                          onPressed: _yukleniyor ||
                                  _basarili ||
                                  _manuelKodController.text.trim().isEmpty
                              ? null
                              : _manuelKoduUygula,
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFEA4335),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: _yukleniyor
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  tr('login.license.manual_button'),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 13,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LimitSatiri extends StatelessWidget {
  final String text;
  const _LimitSatiri({required this.text});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w900,
          height: 1.2,
          color: isDark
              ? Colors.white.withValues(alpha: 0.85)
              : const Color(0xFF2C3E50).withValues(alpha: 0.9),
        ),
      ),
    );
  }
}
