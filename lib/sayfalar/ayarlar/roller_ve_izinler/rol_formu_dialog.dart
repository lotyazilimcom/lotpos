import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../ayarlar/menu_ayarlari.dart';
import '../../../yardimcilar/ceviri/ceviri_servisi.dart';
import 'modeller/rol_model.dart';

class RolFormuDialog extends StatefulWidget {
  const RolFormuDialog({super.key, this.rol});

  final RolModel? rol;

  @override
  State<RolFormuDialog> createState() => _RolFormuDialogState();
}

class _RolFormuDialogState extends State<RolFormuDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late TextEditingController _adController;
  late Set<String> _seciliIzinler;

  @override
  void initState() {
    super.initState();
    _adController = TextEditingController(text: widget.rol?.ad ?? '');
    _seciliIzinler = widget.rol != null
        ? widget.rol!.izinler.toSet()
        : <String>{};
  }

  @override
  void dispose() {
    _adController.dispose();
    super.dispose();
  }

  void _tumunuSec(bool sec) {
    setState(() {
      if (sec) {
        _seciliIzinler = _tumMenuKimlikleri().toSet();
      } else {
        _seciliIzinler.clear();
      }
    });
  }

  Set<String> _tumMenuKimlikleri() {
    final Set<String> idler = {};

    void tara(MenuItem oge) {
      idler.add(oge.id);
      for (final alt in oge.children) {
        tara(alt);
      }
    }

    for (final item in MenuAyarlari.menuItems) {
      tara(item);
    }

    return idler;
  }

  void _izinDegistir(String id, bool? secili) {
    setState(() {
      if (secili == true) {
        _seciliIzinler.add(id);
      } else {
        _seciliIzinler.remove(id);
      }
    });
  }

  void _kaydet() {
    if (!_formKey.currentState!.validate()) return;

    final String ad = _adController.text.trim();
    final String id = widget.rol?.id ?? ad.toLowerCase().replaceAll(' ', '_');

    final RolModel sonuc = RolModel(
      id: id,
      ad: ad,
      izinler: _seciliIzinler.toList(),
      sistemRoluMu: widget.rol?.sistemRoluMu ?? false,
      aktifMi: widget.rol?.aktifMi ?? true,
    );

    Navigator.of(context).pop(sonuc);
  }

  @override
  Widget build(BuildContext context) {
    const double dialogRadius = 14;

    final bool duzenleme = widget.rol != null;
    final mediaQuery = MediaQuery.of(context);
    final bool isMobile = mediaQuery.size.width < 600;
    final double dialogWidth = isMobile ? mediaQuery.size.width * 0.95 : 720;
    final double maxDialogHeight = isMobile
        ? mediaQuery.size.height * 0.9
        : 640;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            Navigator.of(context).pop(),
        const SingleActivator(LogicalKeyboardKey.enter): _kaydet,
        const SingleActivator(LogicalKeyboardKey.numpadEnter): _kaydet,
      },
      child: Focus(
        autofocus: true,
        child: Dialog(
          backgroundColor: Colors.white,
          insetPadding: EdgeInsets.symmetric(
            horizontal: isMobile ? 16 : 32,
            vertical: 24,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(dialogRadius),
          ),
          child: Container(
            width: dialogWidth,
            constraints: BoxConstraints(
              maxWidth: dialogWidth,
              maxHeight: maxDialogHeight,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(dialogRadius),
            ),
            padding: EdgeInsets.fromLTRB(
              isMobile ? 18 : 28,
              24,
              isMobile ? 18 : 28,
              22,
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              duzenleme
                                  ? tr('settings.roles.form.title.edit')
                                  : tr('settings.roles.form.title.add'),
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF202124),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              tr('settings.roles.form.permissions'),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF606368),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!isMobile) ...[
                            Text(
                              tr('common.esc'),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF9AA0A6),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 32,
                                minHeight: 32,
                              ),
                              icon: const Icon(
                                Icons.close,
                                size: 22,
                                color: Color(0xFF3C4043),
                              ),
                              onPressed: () => Navigator.of(context).pop(),
                              tooltip: tr('common.close'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    tr('settings.roles.form.name'),
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.red,
                                    ),
                                  ),
                                  const Text(
                                    ' *',
                                    style: TextStyle(
                                      color: Colors.red,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _adController,
                                validator: (deger) {
                                  if (deger == null || deger.trim().isEmpty) {
                                    return tr('settings.users.form.required');
                                  }
                                  return null;
                                },
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF202124),
                                ),
                                decoration: InputDecoration(
                                  hintText: tr('settings.roles.form.name'),
                                  prefixIcon: const Icon(
                                    Icons.assignment_ind_outlined,
                                    size: 20,
                                    color: Color(0xFFBDC1C6),
                                  ),
                                  hintStyle: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w400,
                                    color: Color(0xFFBDC1C6),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  enabledBorder: const UnderlineInputBorder(
                                    borderSide: BorderSide(
                                      color: Colors.red,
                                      width: 1,
                                    ),
                                  ),
                                  focusedBorder: const UnderlineInputBorder(
                                    borderSide: BorderSide(
                                      color: Color(0xFF2C3E50),
                                      width: 2,
                                    ),
                                  ),
                                  errorStyle: const TextStyle(
                                    color: Colors.red,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  errorBorder: const UnderlineInputBorder(
                                    borderSide: BorderSide(
                                      color: Colors.red,
                                      width: 1,
                                    ),
                                  ),
                                  focusedErrorBorder:
                                      const UnderlineInputBorder(
                                        borderSide: BorderSide(
                                          color: Colors.red,
                                          width: 2,
                                        ),
                                      ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                tr('settings.roles.form.permissions'),
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              TextButton(
                                onPressed: () => _tumunuSec(true),
                                child: Text(
                                  tr('settings.roles.form.select_all'),
                                ),
                              ),
                            ],
                          ),
                          const Divider(),
                          const SizedBox(height: 8),
                          _izinListesi(),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  if (isMobile)
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final double maxRowWidth = constraints.maxWidth > 320
                            ? 320
                            : constraints.maxWidth;
                        const double gap = 12;
                        final double buttonWidth = (maxRowWidth - gap) / 2;

                        return Align(
                          alignment: Alignment.center,
                          child: SizedBox(
                            width: maxRowWidth,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: buttonWidth,
                                  child: TextButton(
                                    onPressed: () =>
                                        Navigator.of(context).pop(),
                                    style: TextButton.styleFrom(
                                      foregroundColor: const Color(0xFF2C3E50),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                      ),
                                    ),
                                    child: Text(
                                      tr('common.cancel'),
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF2C3E50),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: gap),
                                SizedBox(
                                  width: buttonWidth,
                                  child: ElevatedButton(
                                    onPressed: _kaydet,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFEA4335),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      elevation: 0,
                                    ),
                                    child: Text(
                                      duzenleme
                                          ? tr('settings.users.form.update')
                                          : tr('settings.users.form.save'),
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    )
                  else
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF2C3E50),
                          ),
                          child: Row(
                            children: [
                              Text(
                                tr('common.cancel'),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF2C3E50),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                tr('common.esc'),
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF9AA0A6),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton(
                          onPressed: _kaydet,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFEA4335),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 16,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            duzenleme
                                ? tr('settings.users.form.update')
                                : tr('settings.users.form.save'),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _izinListesi() {
    return Column(
      children: MenuAyarlari.menuItems.map(_izinOgesiOlustur).toList(),
    );
  }

  Widget _izinOgesiOlustur(MenuItem oge, {int seviye = 0}) {
    final bool secili = _seciliIzinler.contains(oge.id);
    final EdgeInsets padding = EdgeInsets.only(left: seviye * 20.0);

    return Column(
      children: [
        Padding(
          padding: padding,
          child: CheckboxListTile(
            value: secili,
            onChanged: (deger) => _izinDegistir(oge.id, deger),
            dense: true,
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            title: Text(tr(oge.labelKey)),
          ),
        ),
        if (oge.hasChildren)
          Column(
            children: oge.children
                .map((c) => _izinOgesiOlustur(c, seviye: seviye + 1))
                .toList(),
          ),
      ],
    );
  }
}
