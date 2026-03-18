import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../servisler/lisans_servisi.dart';
import '../yardimcilar/ceviri/ceviri_servisi.dart';

class LisansDiyalog extends StatefulWidget {
  const LisansDiyalog({super.key});

  @override
  State<LisansDiyalog> createState() => _LisansDiyalogState();
}

class _LisansDiyalogState extends State<LisansDiyalog> {
  static const String _manualCodePrefix = 'ALI';

  bool _yukleniyor = false;
  String? _hataMesaji;
  bool _basarili = false;
  final TextEditingController _manuelKodController = TextEditingController();

  int get _manuelKodRakamSayisi =>
      _manuelKodController.text.replaceAll(RegExp(r'[^0-9]'), '').length;

  bool get _manuelKodTamamlandi => _manuelKodRakamSayisi == 12;

  String get _manuelKodDegeri {
    final formatted = _manuelKodController.text.trim();
    if (formatted.isEmpty) return '';
    return '$_manualCodePrefix$formatted';
  }

  @override
  void initState() {
    super.initState();
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
      if (!mounted) return;

      if (sonuc) {
        setState(() {
          _basarili = true;
        });
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) Navigator.of(context).pop(true);
        });
      } else {
        setState(() {
          _hataMesaji = tr('login.license.error.not_found');
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _hataMesaji = tr('login.license.error.connection');
      });
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
        _manuelKodDegeri,
      );

      if (!mounted) return;

      switch (sonuc) {
        case ManualLisansUygulamaSonucu.basarili:
        case ManualLisansUygulamaSonucu.litePaketeGecildi:
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

  void _kopyala(String value) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(tr('login.license.copy_success'))));
  }

  @override
  Widget build(BuildContext context) {
    final hardwareId = LisansServisi().hardwareId ?? 'TANIMSIZ';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenHeight = MediaQuery.of(context).size.height;
    final dialogMaxHeight = screenHeight < 760
        ? screenHeight * 0.80
        : screenHeight * 0.72;
    final dialogPadding = screenHeight < 760 ? 18.0 : 20.0;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 400, maxHeight: dialogMaxHeight),
        child: Container(
          padding: EdgeInsets.all(dialogPadding),
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
          child: ScrollConfiguration(
            behavior: ScrollConfiguration.of(
              context,
            ).copyWith(scrollbars: false),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEA4335).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.security_outlined,
                          color: Color(0xFFEA4335),
                          size: 21,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tr('login.license.title'),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF1A1F38),
                              ),
                            ),
                            Text(
                              tr('login.license.subtitle'),
                              style: TextStyle(
                                fontSize: 11,
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
                  const SizedBox(height: 14),
                  ListenableBuilder(
                    listenable: LisansServisi(),
                    builder: (context, _) {
                      final masterLicenseId =
                          LisansServisi().licenseId ?? 'TANIMSIZ';
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _KimlikBilgiKart(
                              label: tr('login.license.master_id'),
                              value: masterLicenseId,
                              icon: Icons.vpn_key_rounded,
                              isDark: isDark,
                              onCopy: () => _kopyala(masterLicenseId),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _KimlikBilgiKart(
                              label: tr('login.license.hardware_id'),
                              value: hardwareId,
                              icon: Icons.computer,
                              isDark: isDark,
                              onCopy: () => _kopyala(hardwareId),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  ListenableBuilder(
                    listenable: LisansServisi(),
                    builder: (context, _) {
                      final lisans = LisansServisi();
                      final isLite = lisans.isLiteMode;
                      final endDate = lisans.licenseEndDate?.toLocal();
                      final accent = isLite
                          ? const Color(0xFFEA4335)
                          : const Color(0xFFF39C12);

                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(11),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: isDark ? 0.14 : 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: accent.withValues(
                              alpha: isDark ? 0.28 : 0.18,
                            ),
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
                                      fontSize: 11.5,
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
                                  ? tr('login.license.lite_summary_body')
                                  : (endDate != null
                                        ? 'Lisans bitiş tarihi: ${endDate.toString().split(' ').first}'
                                        : 'Lisans aktif.'),
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                height: 1.35,
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.9)
                                    : const Color(0xFF2C3E50),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  Text(
                    tr('login.license.help'),
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey[500],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 12),
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
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFFF39C12,
                          ).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: const Color(
                              0xFFF39C12,
                            ).withValues(alpha: 0.18),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tr('login.license.manual_title'),
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.0,
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
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                height: 1.3,
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.85)
                                    : const Color(0xFF2C3E50),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.05)
                                    : const Color(0xFFF8F9FA),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.1)
                                      : Colors.grey[200]!,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 11,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(
                                        0xFFEA4335,
                                      ).withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Text(
                                      _manualCodePrefix,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontFamily: 'monospace',
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 1.4,
                                        color: Color(0xFFEA4335),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: TextField(
                                      controller: _manuelKodController,
                                      onChanged: (_) => setState(() {}),
                                      keyboardType: TextInputType.number,
                                      textInputAction: TextInputAction.done,
                                      inputFormatters: [
                                        _ManualActivationCodeFormatter(),
                                      ],
                                      enabled: !_yukleniyor && !_basarili,
                                      decoration: InputDecoration(
                                        hintText: tr(
                                          'login.license.manual_placeholder',
                                        ),
                                        border: InputBorder.none,
                                        isDense: true,
                                        counterText: '',
                                      ),
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontFamily: 'monospace',
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 1.0,
                                        color: isDark
                                            ? Colors.white
                                            : const Color(0xFF1A1F38),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  if (_hataMesaji != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _hataMesaji!,
                        style: const TextStyle(
                          color: Colors.red,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  if (_basarili)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      margin: const EdgeInsets.only(bottom: 10),
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
                              fontSize: 11,
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
                            height: 48,
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
                                        fontSize: 12,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                            ),
                          );
                        }

                        return Column(
                          children: [
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: OutlinedButton(
                                onPressed:
                                    _yukleniyor || _basarili || !onlineReady
                                    ? null
                                    : _lisansAktifEt,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF2C3E50),
                                  side: BorderSide(
                                    color: onlineReady
                                        ? const Color(
                                            0xFF2C3E50,
                                          ).withValues(alpha: 0.18)
                                        : Colors.grey.shade300,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Text(
                                  onlineReady
                                      ? tr('login.license.button')
                                      : tr(
                                          'login.license.offline_verify_disabled',
                                        ),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 11,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: FilledButton(
                                onPressed:
                                    _yukleniyor ||
                                        _basarili ||
                                        !_manuelKodTamamlandi
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
                                          fontSize: 12,
                                          letterSpacing: 0.6,
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
      ),
    );
  }
}

class _KimlikBilgiKart extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final bool isDark;
  final VoidCallback onCopy;

  const _KimlikBilgiKart({
    required this.label,
    required this.value,
    required this.icon,
    required this.isDark,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.9,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(icon, size: 15, color: Colors.grey),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.4,
                    fontSize: 14,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy_rounded, size: 17),
                onPressed: onCopy,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                tooltip: tr('common.select'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ManualActivationCodeFormatter extends TextInputFormatter {
  static const String _prefix = 'ALI';
  static const int _maxDigitLength = 12;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final upper = newValue.text.toUpperCase();
    var normalized = upper.replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (normalized.startsWith(_prefix)) {
      normalized = normalized.substring(_prefix.length);
    }

    var digitsOnly = normalized.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.length > _maxDigitLength) {
      digitsOnly = digitsOnly.substring(0, _maxDigitLength);
    }

    final buffer = StringBuffer();
    for (var i = 0; i < digitsOnly.length; i++) {
      buffer.write(digitsOnly[i]);
      if ((i == 3 || i == 7) && i != digitsOnly.length - 1) {
        buffer.write('-');
      }
    }

    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
