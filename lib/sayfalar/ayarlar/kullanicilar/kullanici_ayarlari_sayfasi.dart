import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../yardimcilar/ceviri/ceviri_servisi.dart';
import '../../../yardimcilar/responsive_yardimcisi.dart';
import '../../../bilesenler/genisletilebilir_tablo.dart';
import '../../../bilesenler/onay_dialog.dart';
import '../../../../bilesenler/highlight_text.dart';
import '../../../bilesenler/tarih_araligi_secici_dialog.dart';
import 'kullanici_ekle_sayfasi.dart';
import 'modeller/kullanici_model.dart';
import 'modeller/kullanici_hareket_model.dart';
import '../../../../servisler/ayarlar_veritabani_servisi.dart';
import '../../../../servisler/personel_islemleri_veritabani_servisi.dart';
import '../../ayarlar/genel_ayarlar/modeller/genel_ayarlar_model.dart';
import '../../../yardimcilar/format_yardimcisi.dart';
import '../../../yardimcilar/mesaj_yardimcisi.dart';
import '../../../yardimcilar/yazdirma/genisletilebilir_print_service.dart';
import '../../ortak/genisletilebilir_print_preview_screen.dart';
import 'kullanici_odeme_yap_sayfasi.dart';
import 'kullanici_alacaklandir_sayfasi.dart';
import '../../../yardimcilar/islem_turu_renkleri.dart';

class KullaniciAyarlarSayfasi extends StatefulWidget {
  const KullaniciAyarlarSayfasi({super.key});

  @override
  State<KullaniciAyarlarSayfasi> createState() =>
      _KullaniciAyarlarSayfasiState();
}

class _KullaniciAyarlarSayfasiState extends State<KullaniciAyarlarSayfasi> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';
  List<KullaniciModel> _cachedKullanicilar = [];
  GenelAyarlarModel _genelAyarlar = GenelAyarlarModel();

  bool _isLoading = false;
  int _totalRecords = 0;
  Map<String, Map<String, int>> _filterStats = {};
  final Set<String> _selectedIds = {};
  String? _selectedRowId;
  int _toplamAdminSayisi = 0;

  // Cache for detail futures to prevent reloading on selection changes
  final Map<String, Future<List<KullaniciHareketModel>>> _detailFutures = {};

  // Detay satırı seçimi için state değişkenleri
  final Map<String, Set<String>> _selectedDetailIds = {};
  final Map<String, List<String>> _visibleTransactionIds = {};

  // Detay satır seçimi için state değişkenleri (Kısayollar için)
  String? _selectedDetailTransactionId;
  KullaniciModel? _selectedDetailKullanici;

  int _rowsPerPage = 25;
  int _currentPage = 1;
  bool _isSelectAllActive = false;
  bool _isMobileToolbarExpanded = false;
  final Set<String> _expandedMobileIds = {};

  Set<int> _autoExpandedIndices = {};

  // Sorting State
  int? _sortColumnIndex = 0;
  bool _sortAscending = true;
  Timer? _debounce;
  int _aktifSorguNo = 0;

  // Filter States
  DateTime? _startDate;
  DateTime? _endDate;
  final TextEditingController _startDateController = TextEditingController();
  final TextEditingController _endDateController = TextEditingController();

  String? _selectedStatus;
  bool _isStatusFilterExpanded = false;
  final LayerLink _statusLayerLink = LayerLink();

  String? _selectedRole;
  bool _isRoleFilterExpanded = false;
  final LayerLink _roleLayerLink = LayerLink();
  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _fetchKullanicilar();

    _searchController.addListener(() {
      if (_debounce?.isActive ?? false) _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 500), () {
        if (_searchController.text != _searchQuery) {
          setState(() {
            _searchQuery = _searchController.text.toLowerCase();
            _currentPage = 1;
          });
          _fetchKullanicilar();
        }
      });
    });
  }

  Future<void> _fetchKullanicilar({bool showLoading = true}) async {
    // Clear detail cache when refreshing main list
    _detailFutures.clear();

    final int sorguNo = ++_aktifSorguNo;

    if (showLoading && mounted) {
      setState(() => _isLoading = true);
    }
    try {
      final service = AyarlarVeritabaniServisi();

      bool? aktiflikDurumu;
      if (_selectedStatus == 'active') {
        aktiflikDurumu = true;
      } else if (_selectedStatus == 'passive') {
        aktiflikDurumu = false;
      }

      final toplamSayiFuture = service.kullaniciSayisiGetir(
        aramaTerimi: _searchQuery,
        baslangicTarihi: _startDate,
        bitisTarihi: _endDate,
        rol: _selectedRole,
        aktifMi: aktiflikDurumu,
      );
      final adminSayisiFuture = service.rolKullaniciSayisiGetir('admin');

      final veri = await service.kullanicilariGetir(
        sayfa: _currentPage,
        sayfaBasinaKayit: _rowsPerPage,
        aramaTerimi: _searchQuery,
        baslangicTarihi: _startDate,
        bitisTarihi: _endDate,
        rol: _selectedRole,
        aktifMi: aktiflikDurumu,
      );

      if (!mounted || sorguNo != _aktifSorguNo) return;

      final statsFuture = service.kullaniciFiltreIstatistikleriniGetir(
        aramaTerimi: _searchQuery,
        baslangicTarihi: _startDate,
        bitisTarihi: _endDate,
        rol: _selectedRole,
        aktifMi: aktiflikDurumu,
      );

      if (mounted) {
        // Derin aramada işlemlerle eşleşen satırları otomatik genişlet
        final indices = <int>{};
        if (_searchQuery.isNotEmpty) {
          for (int i = 0; i < veri.length; i++) {
            if (veri[i].matchedInHidden) {
              indices.add(i);
            }
          }
        }

        setState(() {
          _isLoading = false;
          _cachedKullanicilar = veri;
          _autoExpandedIndices = indices;
        });
      }

      unawaited(
        toplamSayiFuture
            .then((toplamSayi) {
              if (!mounted || sorguNo != _aktifSorguNo) return;
              setState(() {
                _totalRecords = toplamSayi;
              });
            })
            .catchError((e) {
              debugPrint('Kullanıcı toplam sayısı güncellenemedi: $e');
            }),
      );

      unawaited(
        adminSayisiFuture
            .then((adminSayisi) {
              if (!mounted || sorguNo != _aktifSorguNo) return;
              setState(() {
                _toplamAdminSayisi = adminSayisi;
              });
            })
            .catchError((e) {
              debugPrint('Admin toplam sayısı güncellenemedi: $e');
            }),
      );

      unawaited(
        statsFuture
            .then((stats) {
              if (!mounted || sorguNo != _aktifSorguNo) return;
              setState(() {
                _filterStats = stats;
              });
            })
            .catchError((e) {
              debugPrint('Kullanıcı filtre istatistikleri güncellenemedi: $e');
            }),
      );
    } catch (e) {
      if (mounted && sorguNo == _aktifSorguNo) {
        setState(() => _isLoading = false);
        MesajYardimcisi.hataGoster(context, '${tr('common.error')}: $e');
      }
    }
  }

  Future<void> _loadSettings() async {
    final settings = await AyarlarVeritabaniServisi().genelAyarlariGetir();
    if (mounted) {
      setState(() {
        _genelAyarlar = settings;
      });
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _overlayEntry?.remove();
    _overlayEntry = null;
    super.dispose();
  }

  Future<void> _kullaniciEkle() async {
    final KullaniciModel? sonuc = await Navigator.push<KullaniciModel>(
      context,
      MaterialPageRoute(builder: (context) => const KullaniciEkleSayfasi()),
    );

    if (sonuc == null) return;

    String yeniId = DateTime.now().millisecondsSinceEpoch.toString();
    final KullaniciModel eklenecek = sonuc.copyWith(id: yeniId);

    await AyarlarVeritabaniServisi().kullaniciEkle(eklenecek);
    await _fetchKullanicilar();
  }

  Future<void> _kullaniciDuzenle(KullaniciModel kullanici) async {
    final KullaniciModel? sonuc = await Navigator.push<KullaniciModel>(
      context,
      MaterialPageRoute(
        builder: (context) => KullaniciEkleSayfasi(kullanici: kullanici),
      ),
    );

    if (sonuc == null) return;

    final guncellenecek = sonuc.copyWith(id: kullanici.id);
    await AyarlarVeritabaniServisi().kullaniciGuncelle(guncellenecek);
    await _fetchKullanicilar();
  }

  Future<void> _kullaniciSil(KullaniciModel kullanici) async {
    if (kullanici.rol == 'admin' && _toplamAdminSayisi <= 1) {
      if (!mounted) return;
      MesajYardimcisi.hataGoster(
        context,
        tr('settings.users.delete.error.last_admin'),
      );
      return;
    }

    await AyarlarVeritabaniServisi().kullaniciSil(kullanici.id);
    await _fetchKullanicilar();

    if (!mounted) return;
    MesajYardimcisi.basariGoster(
      context,
      tr(
        'settings.users.delete.success.single',
      ).replaceAll('{name}', kullanici.kullaniciAdi),
    );
  }

  Future<void> _kullaniciDurumDegistir(
    KullaniciModel kullanici,
    bool aktifMi,
  ) async {
    if (!aktifMi && kullanici.rol == 'admin' && _toplamAdminSayisi <= 1) {
      if (!mounted) return;
      MesajYardimcisi.hataGoster(
        context,
        tr('settings.users.deactivate.error.last_admin'),
      );
      return;
    }

    final guncel = kullanici.copyWith(aktifMi: aktifMi);
    await AyarlarVeritabaniServisi().kullaniciGuncelle(guncel);
    await _fetchKullanicilar();
  }

  Future<void> _deleteSelectedKullanicilar() async {
    if (_selectedIds.isEmpty && !_isSelectAllActive) return;

    final count = _isSelectAllActive ? _totalRecords : _selectedIds.length;

    // Seçilenler arasındaki admin sayısı
    final int seciliAdminSayisi = _cachedKullanicilar
        .where((k) => _selectedIds.contains(k.id) && k.rol == 'admin')
        .length;

    if (seciliAdminSayisi > 0 && (_toplamAdminSayisi - seciliAdminSayisi) < 1) {
      if (!mounted) return;
      MesajYardimcisi.hataGoster(
        context,
        tr('settings.users.delete.error.last_admin_multi'),
      );
      return;
    }

    final bool? onay = await showDialog<bool>(
      context: context,
      builder: (context) => OnayDialog(
        baslik: tr('common.confirmation'),
        mesaj: tr(
          'common.confirm_delete_named',
        ).replaceAll('{name}', '$count ${tr('settings.users.title')}'),
        onOnay: () {},
        isDestructive: true,
        onayButonMetni: tr('common.delete'),
      ),
    );

    if (onay == true) {
      for (final id in _selectedIds) {
        await AyarlarVeritabaniServisi().kullaniciSil(id);
      }

      setState(() {
        _selectedIds.clear();
        _isSelectAllActive = false;
      });
      if (!mounted) return;
      MesajYardimcisi.basariGoster(context, tr('common.deleted_successfully'));
      _fetchKullanicilar();
    }
  }

  void _onSelectAll(bool? value) {
    setState(() {
      _isSelectAllActive = value == true;
      if (value == true) {
        _selectedIds.clear();
      } else {
        _selectedIds.clear();
      }
    });
  }

  void _onSelectRow(bool? value, String id) {
    setState(() {
      if (value == true) {
        _selectedIds.add(id);
      } else {
        _selectedIds.remove(id);
      }
    });
  }

  void _onSort(int columnIndex, bool ascending) {
    setState(() {
      _sortColumnIndex = columnIndex;
      _sortAscending = ascending;
    });
    _fetchKullanicilar();
  }

  Future<void> _handlePrint() async {
    setState(() => _isLoading = true);
    try {
      List<ExpandableRowData> rows = [];

      // Check if any selections exist
      final hasMainSelection = _selectedIds.isNotEmpty;
      final hasDetailSelection = _selectedDetailIds.values.any(
        (s) => s.isNotEmpty,
      );

      // Determine which main rows to process
      Set<String> mainRowIdsToProcess = {};

      if (hasMainSelection) {
        mainRowIdsToProcess.addAll(_selectedIds);
      }

      if (hasDetailSelection) {
        for (var entry in _selectedDetailIds.entries) {
          if (entry.value.isNotEmpty) {
            mainRowIdsToProcess.add(entry.key);
          }
        }
      }

      // Filter data based on selection
      final dataToProcess = mainRowIdsToProcess.isNotEmpty
          ? _cachedKullanicilar
                .where((k) => mainRowIdsToProcess.contains(k.id))
                .toList()
          : _cachedKullanicilar;

      for (var i = 0; i < dataToProcess.length; i++) {
        final kullanici = dataToProcess[i];

        // Ana satır verisi
        final fullName = '${kullanici.ad} ${kullanici.soyad}'.trim();
        final usernameCell = kullanici.kullaniciAdi.isNotEmpty
            ? kullanici.kullaniciAdi
            : '-';

        final mainRow = [
          (i + 1).toString(),
          fullName,
          usernameCell,
          kullanici.telefon.isNotEmpty ? kullanici.telefon : '-',
          kullanici.iseGirisTarihi != null
              ? DateFormat('dd.MM.yyyy').format(kullanici.iseGirisTarihi!)
              : '-',
          kullanici.gorevi ?? '-',
          _getRoleDisplayName(kullanici.rol),
          kullanici.aktifMi ? tr('common.active') : tr('common.passive'),
        ];

        // Detay bilgileri
        final bakiyeFark = (kullanici.bakiyeAlacak - kullanici.bakiyeBorc);
        final bakiyeFarkTuru = bakiyeFark >= 0
            ? tr('accounts.table.type_credit')
            : tr('accounts.table.type_debit');

        Map<String, String> details = {
          tr('settings.users.form.salary.label'): kullanici.maasi != null
              ? '${FormatYardimcisi.sayiFormatlaOndalikli(kullanici.maasi!, binlik: _genelAyarlar.binlikAyiraci, ondalik: _genelAyarlar.ondalikAyiraci, decimalDigits: _genelAyarlar.fiyatOndalik)} ${kullanici.paraBirimi ?? '₺'}'
              : '-',
          tr('settings.users.form.address.label'): kullanici.adresi ?? '-',
          tr('settings.users.form.info1.label'): kullanici.bilgi1 ?? '-',
          tr('settings.users.form.info2.label'): kullanici.bilgi2 ?? '-',
          tr(
            'settings.users.table.balance_debt',
          ): '${FormatYardimcisi.sayiFormatlaOndalikli(kullanici.bakiyeBorc, binlik: _genelAyarlar.binlikAyiraci, ondalik: _genelAyarlar.ondalikAyiraci, decimalDigits: _genelAyarlar.fiyatOndalik)} ${kullanici.paraBirimi ?? '₺'}',
          tr(
            'settings.users.table.balance_credit',
          ): '${FormatYardimcisi.sayiFormatlaOndalikli(kullanici.bakiyeAlacak, binlik: _genelAyarlar.binlikAyiraci, ondalik: _genelAyarlar.ondalikAyiraci, decimalDigits: _genelAyarlar.fiyatOndalik)} ${kullanici.paraBirimi ?? '₺'}',
          '${tr('common.difference')} ($bakiyeFarkTuru)':
              '${FormatYardimcisi.sayiFormatlaOndalikli(bakiyeFark.abs(), binlik: _genelAyarlar.binlikAyiraci, ondalik: _genelAyarlar.ondalikAyiraci, decimalDigits: _genelAyarlar.fiyatOndalik)} ${kullanici.paraBirimi ?? '₺'}',
        };

        // Transactions (Son Hareketler)
        DetailTable? txTable;
        List<KullaniciHareketModel> transactions =
            await PersonelIslemleriVeritabaniServisi()
                .kullaniciHareketleriniGetir(kullanici.id);

        // Filter transactions if detail selection exists for this row
        final selectedDetailIdsForRow = _selectedDetailIds[kullanici.id];
        if (selectedDetailIdsForRow != null &&
            selectedDetailIdsForRow.isNotEmpty) {
          transactions = transactions
              .where((t) => selectedDetailIdsForRow.contains(t.id))
              .toList();
        }

        if (transactions.isNotEmpty) {
          final paraBirimi = kullanici.paraBirimi ?? '₺';
          txTable = DetailTable(
            title: tr('settings.users.detail.transactions'),
            headers: [
              tr('settings.users.transaction.type'),
              tr('settings.users.transaction.date'),
              tr('settings.users.table.balance_debt'),
              tr('settings.users.table.balance_credit'),
              tr('settings.users.transaction.description'),
              tr('cashregisters.detail.user'),
            ],
            data: transactions.map((transaction) {
              final bool isIncoming = transaction.alacak > transaction.borc;
              final String displayName = _getTransactionDisplayName(
                transaction.islemTuru,
                isIncoming,
              );
              return [
                displayName,
                DateFormat('dd.MM.yyyy HH:mm').format(transaction.tarih),
                transaction.borc > 0
                    ? '${FormatYardimcisi.sayiFormatlaOndalikli(transaction.borc, binlik: _genelAyarlar.binlikAyiraci, ondalik: _genelAyarlar.ondalikAyiraci, decimalDigits: _genelAyarlar.fiyatOndalik)} $paraBirimi'
                    : '-',
                transaction.alacak > 0
                    ? '${FormatYardimcisi.sayiFormatlaOndalikli(transaction.alacak, binlik: _genelAyarlar.binlikAyiraci, ondalik: _genelAyarlar.ondalikAyiraci, decimalDigits: _genelAyarlar.fiyatOndalik)} $paraBirimi'
                    : '-',
                transaction.aciklama.isNotEmpty ? transaction.aciklama : '-',
                kullanici.kullaniciAdi.isNotEmpty
                    ? kullanici.kullaniciAdi
                    : 'Sistem',
              ];
            }).toList(),
          );
        }

        rows.add(
          ExpandableRowData(
            mainRow: mainRow,
            details: details,
            transactions: txTable,
            imageUrls:
                kullanici.profilResmi != null &&
                    kullanici.profilResmi!.isNotEmpty
                ? [kullanici.profilResmi!]
                : null,
          ),
        );
      }

      if (mounted) setState(() => _isLoading = false);

      if (!mounted) return;

      String? dateInfo;
      final df = DateFormat('dd.MM.yyyy');
      if (_startDate != null && _endDate != null) {
        dateInfo =
            '${tr('common.date_range')}: ${df.format(_startDate!)} - ${df.format(_endDate!)}';
      } else if (_startDate != null) {
        dateInfo =
            '${tr('common.date_range')}: ${df.format(_startDate!)} - ...';
      } else if (_endDate != null) {
        dateInfo = '${tr('common.date_range')}: ... - ${df.format(_endDate!)}';
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => GenisletilebilirPrintPreviewScreen(
            title: tr('settings.users.title'),
            headers: [
              tr('language.table.orderNo'),
              tr('settings.users.table.name_surname'),
              tr('settings.users.form.username.label'),
              tr('settings.users.form.phone.label'),
              tr('settings.users.table.hire_date'),
              tr('settings.users.form.position.label'),
              tr('settings.users.form.role.label'),
              tr('common.status'),
            ],
            data: rows,
            dateInterval: dateInfo,
            initialShowDetails: false,
          ),
        ),
      );
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      MesajYardimcisi.hataGoster(context, '${tr('common.error')}: $e');
    }
  }

  String _getRoleDisplayName(String rol) {
    switch (rol) {
      case 'admin':
        return tr('settings.users.role.admin');
      case 'user':
        return tr('common.user');
      case 'cashier':
        return tr('settings.users.role.cashier');
      case 'waiter':
        return tr('settings.users.role.waiter');
      default:
        return rol;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Focus(
        autofocus: false, // Let GenisletilebilirTablo handle focus
        child: CallbackShortcuts(
          bindings: {
            // ESC: Overlay kapat / Arama temizle / Filtre sıfırla
            const SingleActivator(LogicalKeyboardKey.escape): () {
              // Priority 1: Close Overlay if open
              if (_overlayEntry != null) {
                _closeOverlay();
                return;
              }

              // Priority 2: Clear Search if active
              if (_searchController.text.isNotEmpty) {
                _searchController.clear();
                return;
              }

              // Priority 3: Clear Filters if active
              if (_startDate != null ||
                  _endDate != null ||
                  _selectedStatus != null ||
                  _selectedRole != null) {
                setState(() {
                  _startDate = null;
                  _endDate = null;
                  _selectedStatus = null;
                  _selectedRole = null;
                });
                _fetchKullanicilar();
                return;
              }
            },
            // F1: Yeni Ekle
            const SingleActivator(LogicalKeyboardKey.f1): _kullaniciEkle,
            // F2: Seçili Düzenle
            const SingleActivator(LogicalKeyboardKey.f2): () {
              // F2: Düzenle - önce seçili detay transaction varsa onu düzenle
              if (_selectedDetailTransactionId != null &&
                  _selectedDetailKullanici != null) {
                // Detay satırı için düzenleme yapılacak
                return;
              }
              // Yoksa ana satırı düzenle
              if (_selectedRowId == null) return;
              final kullanici = _cachedKullanicilar.firstWhere(
                (k) => k.id == _selectedRowId,
                orElse: () => _cachedKullanicilar.first,
              );
              if (kullanici.id == _selectedRowId) {
                _kullaniciDuzenle(kullanici);
              }
            },
            // F3: Arama kutusuna odaklan
            const SingleActivator(LogicalKeyboardKey.f3): () {
              _searchFocusNode.requestFocus();
            },
            // F5: Yenile
            const SingleActivator(LogicalKeyboardKey.f5): () {
              _fetchKullanicilar();
            },
            // F6: Aktif/Pasif Toggle
            const SingleActivator(LogicalKeyboardKey.f6): () {
              if (_selectedRowId == null) return;
              final kullanici = _cachedKullanicilar.firstWhere(
                (k) => k.id == _selectedRowId,
                orElse: () => _cachedKullanicilar.first,
              );
              if (kullanici.id != _selectedRowId) return;

              // Son admin kontrolü - popup menüdeki gibi
              final bool isLastAdmin =
                  kullanici.rol == 'admin' && _toplamAdminSayisi <= 1;

              // Son admin pasife alınamaz
              if (isLastAdmin && kullanici.aktifMi) {
                MesajYardimcisi.uyariGoster(
                  context,
                  tr('settings.users.messages.last_admin_warning'),
                );
                return;
              }

              _kullaniciDurumDegistir(kullanici, !kullanici.aktifMi);
            },
            // F7: Yazdır
            const SingleActivator(LogicalKeyboardKey.f7): _handlePrint,
            // F8: Seçilileri Toplu Sil
            const SingleActivator(LogicalKeyboardKey.f8): () {
              if (_selectedIds.isEmpty && !_isSelectAllActive) return;
              _deleteSelectedKullanicilar();
            },
            // F9: Ödeme Yap
            const SingleActivator(LogicalKeyboardKey.f9): () async {
              if (_selectedRowId == null) return;
              final kullanici = _cachedKullanicilar.firstWhere(
                (k) => k.id == _selectedRowId,
                orElse: () => _cachedKullanicilar.first,
              );
              if (kullanici.id == _selectedRowId) {
                final result = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        KullaniciOdemeYapSayfasi(kullanici: kullanici),
                  ),
                );
                if (result == true) {
                  _fetchKullanicilar();
                }
              }
            },
            // F10: Alacaklandır
            const SingleActivator(LogicalKeyboardKey.f10): () async {
              if (_selectedRowId == null) return;
              final kullanici = _cachedKullanicilar.firstWhere(
                (k) => k.id == _selectedRowId,
                orElse: () => _cachedKullanicilar.first,
              );
              if (kullanici.id == _selectedRowId) {
                final result = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        KullaniciAlacaklandirSayfasi(kullanici: kullanici),
                  ),
                );
                if (result == true) {
                  _fetchKullanicilar();
                }
              }
            },
            // Delete: Seçili Satırı Sil veya Detay Satırı Sil
            const SingleActivator(LogicalKeyboardKey.delete): () {
              // Priority 1: Detay satırı seçiliyse detay sil
              if (_selectedDetailTransactionId != null &&
                  _selectedDetailKullanici != null) {
                return;
              }
              // Priority 2: Ana satırı sil
              if (_selectedRowId == null) return;
              final kullanici = _cachedKullanicilar.firstWhere(
                (k) => k.id == _selectedRowId,
                orElse: () => _cachedKullanicilar.first,
              );
              if (kullanici.id != _selectedRowId) return;

              // Son admin kontrolü - popup menüdeki gibi
              final bool isLastAdmin =
                  kullanici.rol == 'admin' && _toplamAdminSayisi <= 1;

              // Son admin silinemez
              if (isLastAdmin) {
                MesajYardimcisi.uyariGoster(
                  context,
                  tr('settings.users.messages.last_admin_warning'),
                );
                return;
              }

              showDialog(
                context: context,
                barrierDismissible: true,
                barrierColor: Colors.black.withValues(alpha: 0.35),
                builder: (context) => OnayDialog(
                  baslik: tr('common.delete'),
                  mesaj: tr(
                    'common.confirm_delete_named',
                  ).replaceAll('{name}', kullanici.kullaniciAdi),
                  onayButonMetni: tr('common.delete'),
                  iptalButonMetni: tr('common.cancel'),
                  isDestructive: true,
                  onOnay: () => _kullaniciSil(kullanici),
                ),
              );
            },
            // Numpad Delete
            const SingleActivator(LogicalKeyboardKey.numpadDecimal): () {
              // Priority 1: Detay satırı seçiliyse detay sil
              if (_selectedDetailTransactionId != null &&
                  _selectedDetailKullanici != null) {
                return;
              }
              // Priority 2: Ana satırı sil
              if (_selectedRowId == null) return;
              final kullanici = _cachedKullanicilar.firstWhere(
                (k) => k.id == _selectedRowId,
                orElse: () => _cachedKullanicilar.first,
              );
              if (kullanici.id != _selectedRowId) return;

              // Son admin kontrolü - popup menüdeki gibi
              final bool isLastAdmin =
                  kullanici.rol == 'admin' && _toplamAdminSayisi <= 1;

              // Son admin silinemez
              if (isLastAdmin) {
                MesajYardimcisi.uyariGoster(
                  context,
                  tr('settings.users.messages.last_admin_warning'),
                );
                return;
              }

              showDialog(
                context: context,
                barrierDismissible: true,
                barrierColor: Colors.black.withValues(alpha: 0.35),
                builder: (context) => OnayDialog(
                  baslik: tr('common.delete'),
                  mesaj: tr(
                    'common.confirm_delete_named',
                  ).replaceAll('{name}', kullanici.kullaniciAdi),
                  onayButonMetni: tr('common.delete'),
                  iptalButonMetni: tr('common.cancel'),
                  isDestructive: true,
                  onOnay: () => _kullaniciSil(kullanici),
                ),
              );
            },
          },
          child: Stack(
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final bool forceMobile =
                      ResponsiveYardimcisi.tabletMi(context);
                  if (forceMobile || constraints.maxWidth < 800) {
                    return _buildMobileView();
                  } else {
                    return _buildDesktopView(_cachedKullanicilar, constraints);
                  }
                },
              ),
              if (_isLoading)
                const Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: LinearProgressIndicator(
                    minHeight: 4,
                    backgroundColor: Colors.transparent,
                    color: Color(0xFF2C3E50),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  double _calculateColumnWidth(String text, {bool sortable = false}) {
    final TextPainter textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.black54,
          fontSize: 15,
        ),
      ),
      maxLines: 1,
      textDirection: ui.TextDirection.ltr,
    )..layout();

    double width = textPainter.width + 32; // 16 padding on each side
    if (sortable) {
      width += 22; // Icon (16) + spacing (6)
    }
    return width + 10; // Extra buffer
  }

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _buildDateRangeFilter(width: double.infinity)),
          const SizedBox(width: 24),
          Expanded(child: _buildRoleFilter(width: double.infinity)),
          const SizedBox(width: 24),
          Expanded(child: _buildStatusFilter(width: double.infinity)),
        ],
      ),
    );
  }

  Future<void> _showDateRangePicker() async {
    _closeOverlay();

    final result = await showDialog<List<DateTime?>>(
      context: context,
      builder: (context) => TarihAraligiSeciciDialog(
        initialStartDate: _startDate,
        initialEndDate: _endDate,
      ),
    );

    if (result != null) {
      setState(() {
        _startDate = result[0];
        _endDate = result[1];
        if (_startDate != null) {
          _startDateController.text = DateFormat(
            'dd.MM.yyyy',
          ).format(_startDate!);
        } else {
          _startDateController.clear();
        }
        if (_endDate != null) {
          _endDateController.text = DateFormat('dd.MM.yyyy').format(_endDate!);
        } else {
          _endDateController.clear();
        }

        _currentPage = 1;
      });
      _fetchKullanicilar();
    }
  }

  void _clearDateFilter() {
    setState(() {
      _startDate = null;
      _endDate = null;
      _startDateController.clear();
      _endDateController.clear();
      _currentPage = 1;
    });
    _fetchKullanicilar();
  }

  Widget _buildDateRangeFilter({double? width}) {
    final hasSelection = _startDate != null || _endDate != null;
    return InkWell(
      onTap: _showDateRangePicker,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        width: width ?? 240,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: hasSelection
                  ? const Color(0xFF2C3E50)
                  : Colors.grey.shade300,
              width: hasSelection ? 2 : 1,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.date_range_rounded,
              size: 20,
              color: hasSelection
                  ? const Color(0xFF2C3E50)
                  : Colors.grey.shade600,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                hasSelection
                    ? '${_startDateController.text} - ${_endDateController.text}'
                    : tr('common.date_range_select'),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: hasSelection ? FontWeight.w600 : FontWeight.w500,
                  color: hasSelection
                      ? const Color(0xFF2C3E50)
                      : Colors.grey.shade700,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (hasSelection)
              InkWell(
                onTap: () {
                  _clearDateFilter();
                },
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4.0),
                  child: Icon(Icons.close, size: 16, color: Colors.grey),
                ),
              ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 20,
              color: Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleFilter({double? width}) {
    final int selectedCount = _selectedRole == null
        ? (_filterStats['ozet']?['toplam'] ?? 0)
        : (_filterStats['roller']?[_selectedRole] ?? 0);
    return CompositedTransformTarget(
      link: _roleLayerLink,
      child: InkWell(
        onTap: () {
          if (_isRoleFilterExpanded) {
            _closeOverlay();
          } else {
            _showRoleOverlay();
          }
        },
        borderRadius: BorderRadius.circular(4),
        child: Container(
          width: width ?? 160,
          padding: EdgeInsets.fromLTRB(0, 8, 0, _isRoleFilterExpanded ? 7 : 8),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: _isRoleFilterExpanded
                    ? const Color(0xFF2C3E50)
                    : Colors.grey.shade300,
                width: _isRoleFilterExpanded ? 2 : 1,
              ),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.admin_panel_settings_outlined,
                size: 20,
                color: _isRoleFilterExpanded
                    ? const Color(0xFF2C3E50)
                    : Colors.grey.shade600,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _selectedRole == null
                      ? tr('settings.users.form.role')
                      : '${_getRoleDisplayName(_selectedRole!)} ($selectedCount)',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: _isRoleFilterExpanded
                        ? const Color(0xFF2C3E50)
                        : Colors.grey.shade700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (_selectedRole != null)
                InkWell(
                  onTap: () {
                    setState(() {
                      _selectedRole = null;
                      _currentPage = 1;
                    });
                    _fetchKullanicilar();
                  },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4.0),
                    child: Icon(Icons.close, size: 16, color: Colors.grey),
                  ),
                ),
              const SizedBox(width: 4),
              AnimatedRotation(
                turns: _isRoleFilterExpanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 20,
                  color: _isRoleFilterExpanded
                      ? const Color(0xFF2C3E50)
                      : Colors.grey.shade400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusFilter({double? width}) {
    final int selectedCount = _selectedStatus == null
        ? (_filterStats['ozet']?['toplam'] ?? 0)
        : (_filterStats['durumlar']?[_selectedStatus] ?? 0);
    return CompositedTransformTarget(
      link: _statusLayerLink,
      child: InkWell(
        onTap: () {
          if (_isStatusFilterExpanded) {
            _closeOverlay();
          } else {
            _showStatusOverlay();
          }
        },
        borderRadius: BorderRadius.circular(4),
        child: Container(
          width: width ?? 160,
          padding: EdgeInsets.fromLTRB(
            0,
            8,
            0,
            _isStatusFilterExpanded ? 7 : 8,
          ),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: _isStatusFilterExpanded
                    ? const Color(0xFF2C3E50)
                    : Colors.grey.shade300,
                width: _isStatusFilterExpanded ? 2 : 1,
              ),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.filter_list_rounded,
                size: 20,
                color: _isStatusFilterExpanded
                    ? const Color(0xFF2C3E50)
                    : Colors.grey.shade600,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _selectedStatus == null
                      ? tr('common.status')
                      : (_selectedStatus == 'active'
                            ? '${tr('common.active')} ($selectedCount)'
                            : '${tr('common.passive')} ($selectedCount)'),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: _isStatusFilterExpanded
                        ? const Color(0xFF2C3E50)
                        : Colors.grey.shade700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (_selectedStatus != null)
                InkWell(
                  onTap: () {
                    setState(() {
                      _selectedStatus = null;
                      _currentPage = 1;
                    });
                    _fetchKullanicilar();
                  },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4.0),
                    child: Icon(Icons.close, size: 16, color: Colors.grey),
                  ),
                ),
              const SizedBox(width: 4),
              AnimatedRotation(
                turns: _isStatusFilterExpanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 20,
                  color: _isStatusFilterExpanded
                      ? const Color(0xFF2C3E50)
                      : Colors.grey.shade400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRoleOverlay() {
    _closeOverlay();
    setState(() => _isRoleFilterExpanded = true);

    final roles = (_filterStats['roller']?.keys.toList() ?? [])
        .map((r) => r.trim())
        .where((r) => r.isNotEmpty)
        .toSet()
        .toList();

    if (_selectedRole != null && !roles.contains(_selectedRole)) {
      roles.add(_selectedRole!);
    }

    int rolePriority(String r) {
      switch (r) {
        case 'admin':
          return 0;
        case 'cashier':
          return 1;
        case 'waiter':
          return 2;
        case 'user':
          return 3;
        default:
          return 100;
      }
    }

    roles.sort((a, b) {
      final pa = rolePriority(a);
      final pb = rolePriority(b);
      if (pa != pb) return pa.compareTo(pb);
      return a.compareTo(b);
    });

    _overlayEntry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: _closeOverlay,
              behavior: HitTestBehavior.translucent,
              child: Container(color: Colors.transparent),
            ),
          ),
          CompositedTransformFollower(
            link: _roleLayerLink,
            showWhenUnlinked: false,
            offset: const Offset(0, 42),
            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(8),
              color: Colors.white,
              child: Container(
                width: 200,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildRoleOption(
                      null,
                      tr('settings.general.option.documents.all'),
                    ),
                    ...roles.map(
                      (r) => _buildRoleOption(r, _getRoleDisplayName(r)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  Widget _buildRoleOption(String? value, String label) {
    final isSelected = _selectedRole == value;

    final int count = value == null
        ? (_filterStats['ozet']?['toplam'] ?? 0)
        : (_filterStats['roller']?[value] ?? 0);

    if (value != null && count == 0 && !isSelected) {
      return const SizedBox.shrink();
    }

    return InkWell(
      onTap: () {
        setState(() {
          _selectedRole = value;
          _isRoleFilterExpanded = false;
          _currentPage = 1;
        });
        _closeOverlay();
        _fetchKullanicilar();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color: isSelected ? const Color(0xFFE6F4EA) : Colors.transparent,
        child: Row(
          children: [
            Expanded(
              child: Text(
                '$label ($count)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? const Color(0xFF1E7E34) : Colors.black87,
                ),
              ),
            ),
            if (isSelected)
              const Icon(Icons.check, size: 16, color: Color(0xFF1E7E34)),
          ],
        ),
      ),
    );
  }

  void _showStatusOverlay() {
    _closeOverlay();
    setState(() => _isStatusFilterExpanded = true);

    _overlayEntry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: _closeOverlay,
              behavior: HitTestBehavior.translucent,
              child: Container(color: Colors.transparent),
            ),
          ),
          CompositedTransformFollower(
            link: _statusLayerLink,
            showWhenUnlinked: false,
            offset: const Offset(0, 42),
            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(8),
              color: Colors.white,
              child: Container(
                width: 200,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildStatusOption(
                      null,
                      tr('settings.general.option.documents.all'),
                    ),
                    _buildStatusOption('active', tr('common.active')),
                    _buildStatusOption('passive', tr('common.passive')),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  Widget _buildStatusOption(String? value, String label) {
    final isSelected = _selectedStatus == value;

    final int count = value == null
        ? (_filterStats['ozet']?['toplam'] ?? 0)
        : (_filterStats['durumlar']?[value] ?? 0);

    if (value != null && count == 0 && !isSelected) {
      return const SizedBox.shrink();
    }

    return InkWell(
      onTap: () {
        setState(() {
          _selectedStatus = value;
          _isStatusFilterExpanded = false;
          _currentPage = 1;
        });
        _closeOverlay();
        _fetchKullanicilar();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color: isSelected ? const Color(0xFFE6F4EA) : Colors.transparent,
        child: Row(
          children: [
            Expanded(
              child: Text(
                '$label ($count)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? const Color(0xFF1E7E34) : Colors.black87,
                ),
              ),
            ),
            if (isSelected)
              const Icon(Icons.check, size: 16, color: Color(0xFF1E7E34)),
          ],
        ),
      ),
    );
  }

  void _closeOverlay() {
    if (_overlayEntry != null) {
      _overlayEntry!.remove();
      _overlayEntry = null;
    }
    if (mounted) {
      setState(() {
        _isStatusFilterExpanded = false;
        _isRoleFilterExpanded = false;
      });
    }
  }

  Widget _buildDesktopView(
    List<KullaniciModel> kullanicilar,
    BoxConstraints constraints,
  ) {
    final bool allSelected =
        _isSelectAllActive ||
        (kullanicilar.isNotEmpty &&
            kullanicilar.every((k) => _selectedIds.contains(k.id)));

    // Calculate column widths based on header text
    final colOrderWidth = _calculateColumnWidth(
      tr('language.table.orderNo'),
      sortable: true,
    );
    // Adı Soyadı flex olacağı için minWidth veriyoruz
    final colNameMinWidth = 200.0;

    final phoneHeaderWidth = _calculateColumnWidth(
      tr('settings.users.form.phone.label'),
      sortable: false,
    );
    final phoneDataWidth = _calculateColumnWidth(
      '0 (555) 555 55 55',
    ); // Sample long phone format
    final colPhoneWidth = phoneHeaderWidth > phoneDataWidth
        ? phoneHeaderWidth
        : phoneDataWidth;
    final colHireDateWidth = _calculateColumnWidth(
      tr('settings.users.table.hire_date'),
      sortable: true,
    );
    final colPositionWidth = _calculateColumnWidth(
      tr('settings.users.form.position.label'),
      sortable: true,
    );
    // Role Column: Calculate properties for header and possible values
    final roleHeaderWidth = _calculateColumnWidth(
      tr('settings.users.form.role.label'),
      sortable: true,
    );
    final roleAdminWidth =
        _calculateColumnWidth(tr('settings.users.role.admin')) +
        45; // +45 for badge padding & icon
    final roleCashierWidth =
        _calculateColumnWidth(tr('settings.users.role.cashier')) + 45;
    final roleWaiterWidth =
        _calculateColumnWidth(tr('settings.users.role.waiter')) + 45;

    // Use the maximum width to ensure no overflow
    final colRoleWidth = [
      roleHeaderWidth,
      roleAdminWidth,
      roleCashierWidth,
      roleWaiterWidth,
    ].reduce((value, element) => value > element ? value : element);
    final colStatusWidth = _calculateColumnWidth(
      tr('common.status'),
      sortable: true,
    );
    const colActionsWidth = 100.0;

    return GenisletilebilirTablo<KullaniciModel>(
      title: tr('settings.users.title'),
      searchFocusNode: _searchFocusNode,
      getDetailItemCount: (kullanici) =>
          _visibleTransactionIds[kullanici.id]?.length ?? 0,
      onFocusedRowChanged: (item, index) {
        if (item != null) {
          setState(() => _selectedRowId = item.id);
        }
      },
      headerWidget: _buildFilters(),
      totalRecords: _totalRecords,
      expandedContentPadding: const EdgeInsets.symmetric(
        horizontal: 24,
        vertical: 0,
      ),
      onSort: _onSort,
      sortColumnIndex: _sortColumnIndex,
      sortAscending: _sortAscending,
      onPageChanged: (page, rowsPerPage) {
        setState(() {
          _currentPage = page;
          _rowsPerPage = rowsPerPage;
        });
        _fetchKullanicilar();
      },
      onSearch: (query) {
        if (_debounce?.isActive ?? false) _debounce!.cancel();
        _debounce = Timer(const Duration(milliseconds: 500), () {
          setState(() {
            _searchQuery = query;
            _currentPage = 1;
          });
          _fetchKullanicilar(showLoading: false);
        });
      },
      selectionWidget: (_selectedIds.isNotEmpty || _isSelectAllActive)
          ? MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: _deleteSelectedKullanicilar,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEA4335),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.delete_outline,
                        size: 16,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        tr('common.delete_selected').replaceAll(
                          '{count}',
                          _isSelectAllActive
                              ? '$_totalRecords (${tr('settings.general.option.documents.all')})'
                              : _selectedIds.length.toString(),
                        ),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          : null,
      expandedIndices: _autoExpandedIndices,
      onExpansionChanged: (index, isExpanded) {
        setState(() {
          if (isExpanded) {
            _autoExpandedIndices.add(index);
          } else {
            _autoExpandedIndices.remove(index);
          }
        });
      },
      actionButton: Row(
        children: [
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: _handlePrint,
              child: Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F9FA),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.print_outlined,
                      size: 18,
                      color: Colors.black87,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      tr('common.print_list'),
                      style: const TextStyle(
                        color: Colors.black87,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      tr('common.key.f7'),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: _kullaniciEkle,
              child: Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFEA4335),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.transparent),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.add, size: 18, color: Colors.white),
                    const SizedBox(width: 8),
                    Text(
                      tr('settings.users.table.action.add'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      tr('common.key.f1'),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      columns: [
        GenisletilebilirTabloKolon(
          label: '',
          width: 50,
          alignment: Alignment.center,
          header: SizedBox(
            width: 20,
            height: 20,
            child: Checkbox(
              value: allSelected,
              onChanged: _onSelectAll,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              side: const BorderSide(color: Color(0xFFD1D1D1), width: 1),
            ),
          ),
        ),
        GenisletilebilirTabloKolon(
          label: tr('language.table.orderNo'),
          width: colOrderWidth,
          alignment: Alignment.centerLeft,
          allowSorting: true,
        ),
        GenisletilebilirTabloKolon(
          label: tr('settings.users.table.name_surname'),
          width: colNameMinWidth,
          alignment: Alignment.centerLeft,
          allowSorting: true,
          flex: 1, // Only this column is flexible
        ),
        GenisletilebilirTabloKolon(
          label: tr('settings.users.form.phone.label'),
          width: colPhoneWidth,
          alignment: Alignment.centerLeft,
        ),
        GenisletilebilirTabloKolon(
          label: tr('settings.users.table.hire_date'),
          width: colHireDateWidth,
          alignment: Alignment.centerLeft,
          allowSorting: true,
        ),
        GenisletilebilirTabloKolon(
          label: tr('settings.users.form.position.label'),
          width: colPositionWidth,
          alignment: Alignment.centerLeft,
          allowSorting: true,
        ),
        GenisletilebilirTabloKolon(
          label: tr('settings.users.form.role.label'),
          width: colRoleWidth,
          alignment: Alignment.centerLeft,
          allowSorting: true,
        ),
        GenisletilebilirTabloKolon(
          label: tr('common.status'),
          width: colStatusWidth,
          alignment: Alignment.centerLeft,
          allowSorting: true,
        ),
        GenisletilebilirTabloKolon(
          label: tr('common.actions'),
          width: colActionsWidth,
        ),
      ],
      data: _cachedKullanicilar,
      isRowSelected: (kullanici, index) => _selectedRowId == kullanici.id,
      expandOnRowTap: false,
      onRowTap: (kullanici) {
        setState(() {
          _selectedRowId = kullanici.id;
        });
      },
      rowBuilder: (context, kullanici, index, isExpanded, toggleExpand) {
        final String basHarf =
            (kullanici.kullaniciAdi.isNotEmpty
                    ? kullanici.kullaniciAdi
                    : (kullanici.ad.isNotEmpty ? kullanici.ad : kullanici.id))
                .substring(0, 1)
                .toUpperCase();

        final String adSoyad = '${kullanici.ad} ${kullanici.soyad}'.trim();

        ImageProvider? avatarImage;
        if (kullanici.profilResmi != null &&
            kullanici.profilResmi!.isNotEmpty) {
          try {
            avatarImage = MemoryImage(base64Decode(kullanici.profilResmi!));
          } catch (_) {}
        }

        return Row(
          children: [
            _buildCell(
              width: 50,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: Checkbox(
                  value:
                      _isSelectAllActive || _selectedIds.contains(kullanici.id),
                  onChanged: (val) => _onSelectRow(val, kullanici.id),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                  side: const BorderSide(color: Color(0xFFD1D1D1), width: 1),
                ),
              ),
            ),
            _buildCell(
              width: colOrderWidth,
              alignment: Alignment.centerLeft,
              child: Row(
                children: [
                  InkWell(
                    onTap: toggleExpand,
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: AnimatedRotation(
                        turns: isExpanded ? 0.25 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: const Icon(
                          Icons.chevron_right_rounded,
                          size: 20,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  HighlightText(
                    text: (index + 1).toString(),
                    query: _searchQuery,
                    style: const TextStyle(color: Colors.black87, fontSize: 14),
                  ),
                ],
              ),
            ),
            _buildCell(
              width: colNameMinWidth,
              flex: 1, // Only this column is flexible
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: const Color(
                      0xFF2C3E50,
                    ).withValues(alpha: 0.12),
                    foregroundColor: const Color(0xFF2C3E50),
                    backgroundImage: avatarImage,
                    child: avatarImage == null
                        ? Text(
                            basHarf,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        HighlightText(
                          text: adSoyad.isNotEmpty
                              ? adSoyad
                              : kullanici.kullaniciAdi,
                          query: _searchQuery,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 2),
                        HighlightText(
                          text: kullanici.kullaniciAdi,
                          query: _searchQuery,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            _buildCell(
              width: colPhoneWidth,
              child: HighlightText(
                text: kullanici.telefon.isNotEmpty ? kullanici.telefon : '-',
                query: _searchQuery,
                style: const TextStyle(color: Colors.black87, fontSize: 14),
              ),
            ),
            _buildCell(
              width: colHireDateWidth,
              child: HighlightText(
                text: kullanici.iseGirisTarihi != null
                    ? DateFormat('dd.MM.yyyy').format(kullanici.iseGirisTarihi!)
                    : '-',
                query: _searchQuery,
                style: const TextStyle(color: Colors.black87, fontSize: 14),
              ),
            ),
            _buildCell(
              width: colPositionWidth,
              child: HighlightText(
                text: kullanici.gorevi ?? '-',
                query: _searchQuery,
                style: const TextStyle(color: Colors.black87, fontSize: 14),
              ),
            ),
            _buildCell(
              width: colRoleWidth,
              child: _buildRoleBadge(kullanici.rol),
            ),
            _buildCell(
              width: colStatusWidth,
              child: _buildStatusBadge(kullanici.aktifMi),
            ),
            _buildCell(
              width: colActionsWidth,
              child: _buildPopupMenu(kullanici),
            ),
          ],
        );
      },
      detailBuilder: (context, kullanici) {
        return _buildDetailView(kullanici);
      },
    );
  }

  Widget _buildCell({
    required double width,
    int? flex,
    Alignment alignment = Alignment.centerLeft,
    EdgeInsets padding = const EdgeInsets.symmetric(horizontal: 16),
    required Widget child,
  }) {
    Widget content = Container(
      padding: padding,
      alignment: alignment,
      child: child,
    );

    if (flex != null) {
      return Expanded(flex: flex, child: content);
    }
    return SizedBox(width: width, child: content);
  }

  Widget _buildRoleBadge(String rol) {
    Color arkaPlan;
    Color yaziRenk;
    IconData ikon;
    String etiket;

    switch (rol) {
      case 'admin':
        arkaPlan = const Color(0xFFE11D48).withValues(alpha: 0.12);
        yaziRenk = const Color(0xFFE11D48);
        ikon = Icons.security;
        etiket = tr('settings.users.role.admin');
        break;
      case 'user':
        arkaPlan = Colors.grey.withValues(alpha: 0.12);
        yaziRenk = Colors.grey;
        ikon = Icons.person_outline;
        etiket = tr('common.user');
        break;
      case 'cashier':
        arkaPlan = const Color(0xFF0EA5E9).withValues(alpha: 0.12);
        yaziRenk = const Color(0xFF0EA5E9);
        ikon = Icons.point_of_sale;
        etiket = tr('settings.users.role.cashier');
        break;
      case 'waiter':
        arkaPlan = const Color(0xFFF59E0B).withValues(alpha: 0.12);
        yaziRenk = const Color(0xFFF59E0B);
        ikon = Icons.restaurant_menu;
        etiket = tr('settings.users.role.waiter');
        break;
      default:
        arkaPlan = Colors.grey.withValues(alpha: 0.12);
        yaziRenk = Colors.grey;
        ikon = Icons.person;
        etiket = rol;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: arkaPlan,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(ikon, size: 14, color: yaziRenk),
          const SizedBox(width: 6),
          Text(
            etiket,
            style: TextStyle(
              color: yaziRenk,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(bool aktifMi) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: aktifMi ? const Color(0xFFE6F4EA) : const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.circle,
            size: 8,
            color: aktifMi ? const Color(0xFF28A745) : const Color(0xFF757575),
          ),
          const SizedBox(width: 6),
          Text(
            aktifMi ? tr('common.active') : tr('common.passive'),
            style: TextStyle(
              color: aktifMi
                  ? const Color(0xFF1E7E34)
                  : const Color(0xFF757575),
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailView(KullaniciModel kullanici) {
    ImageProvider? img;
    if (kullanici.profilResmi != null && kullanici.profilResmi!.isNotEmpty) {
      try {
        String b64 = kullanici.profilResmi!;
        if (b64.contains(',')) b64 = b64.split(',').last;
        img = MemoryImage(base64Decode(b64));
      } catch (_) {}
    }

    Widget buildMainImage() {
      return Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          image: img != null
              ? DecorationImage(image: img, fit: BoxFit.contain)
              : null,
        ),
        child: img == null
            ? Center(
                child: Text(
                  kullanici.ad.isNotEmpty ? kullanici.ad[0].toUpperCase() : '?',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              )
            : null,
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      color: Colors.grey.shade50,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. White Box: Header Info + Balance + Features
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // HEADER: Image + Info + Balance
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    buildMainImage(),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${kullanici.ad} ${kullanici.soyad}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: const Color(0xFFE2E8F0),
                                  ),
                                ),
                                child: Text(
                                  kullanici.kullaniciAdi,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _getRoleDisplayName(kullanici.rol),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF64748B),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Bakiye Table View
                    Container(
                      width: 250,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  tr('common.total'),
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF94A3B8),
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 70,
                                child: Text(
                                  tr('common.amount'),
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF94A3B8),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 30,
                                child: Text(
                                  tr('common.currency_short'),
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF94A3B8),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          // Borç Row
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  tr('settings.users.table.balance_debt'),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF475569),
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 70,
                                child: Text(
                                  FormatYardimcisi.sayiFormatlaOndalikli(
                                    kullanici.bakiyeBorc,
                                    binlik: _genelAyarlar.binlikAyiraci,
                                    ondalik: _genelAyarlar.ondalikAyiraci,
                                    decimalDigits: _genelAyarlar.fiyatOndalik,
                                  ),
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFFC62828), // Borç Kırmızı
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 30,
                                child: Text(
                                  kullanici.paraBirimi ?? '₺',
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          // Alacak Row
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  tr('settings.users.table.balance_credit'),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF475569),
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 70,
                                child: Text(
                                  FormatYardimcisi.sayiFormatlaOndalikli(
                                    kullanici.bakiyeAlacak,
                                    binlik: _genelAyarlar.binlikAyiraci,
                                    ondalik: _genelAyarlar.ondalikAyiraci,
                                    decimalDigits: _genelAyarlar.fiyatOndalik,
                                  ),
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF059669), // Alacak Yeşil
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 30,
                                child: Text(
                                  kullanici.paraBirimi ?? '₺',
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 4.0),
                            child: Divider(height: 1, color: Color(0xFFCBD5E1)),
                          ),
                          // Fark Row
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${tr('common.difference')} (${(kullanici.bakiyeAlacak - kullanici.bakiyeBorc) >= 0 ? tr('accounts.table.type_credit') : tr('accounts.table.type_debit')})',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF334155),
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 70,
                                child: Text(
                                  FormatYardimcisi.sayiFormatlaOndalikli(
                                    (kullanici.bakiyeAlacak -
                                            kullanici.bakiyeBorc)
                                        .abs(),
                                    binlik: _genelAyarlar.binlikAyiraci,
                                    ondalik: _genelAyarlar.ondalikAyiraci,
                                    decimalDigits: _genelAyarlar.fiyatOndalik,
                                  ),
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color:
                                        (kullanici.bakiyeAlacak -
                                                kullanici.bakiyeBorc) >=
                                            0
                                        ? const Color(0xFF059669)
                                        : const Color(0xFFC62828),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 30,
                                child: Text(
                                  kullanici.paraBirimi ?? '₺',
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),
                const SizedBox(height: 16),
                // FEATURES Section
                Text(
                  tr('settings.users.detail.features'),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 24,
                  runSpacing: 16,
                  children: [
                    _buildDetailItem(
                      tr('settings.users.form.salary.label'),
                      kullanici.maasi != null
                          ? '${FormatYardimcisi.sayiFormatlaOndalikli(kullanici.maasi!, binlik: _genelAyarlar.binlikAyiraci, ondalik: _genelAyarlar.ondalikAyiraci, decimalDigits: _genelAyarlar.fiyatOndalik)} ${kullanici.paraBirimi ?? '₺'}'
                          : '-',
                    ),
                    _buildDetailItem(
                      tr('settings.users.form.address.label'),
                      kullanici.adresi ?? '-',
                    ),
                    _buildDetailItem(
                      tr('settings.users.form.info1.label'),
                      kullanici.bilgi1 ?? '-',
                    ),
                    _buildDetailItem(
                      tr('settings.users.form.info2.label'),
                      kullanici.bilgi2 ?? '-',
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // 2. Transactions Section Title (Kasalar sayfasındaki gibi)
          Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: Checkbox(
                        value: _isAllDetailSelectedForUser(kullanici.id),
                        onChanged: (val) =>
                            _onSelectAllDetailsForUser(kullanici.id, val),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        side: const BorderSide(
                          color: Color(0xFFD1D1D1),
                          width: 1,
                        ),
                      ),
                    ),
                    const SizedBox(width: 24),
                    Text(
                      tr('settings.users.detail.transactions'),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Transactions Table Header (Kasalar sayfasındaki gibi)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade300, width: 1),
              ),
            ),
            child: Row(
              children: [
                // Checkbox alanı: Padding(horizontal: 12) + SizedBox(width: 20) = 44px
                const SizedBox(width: 44),
                Expanded(
                  flex: 2,
                  child: _buildDetailHeader(
                    tr('settings.users.transaction.type'), // İşlem
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: _buildDetailHeader(
                    tr('settings.users.transaction.date'), // Tarih
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: _buildDetailHeader(
                    tr('settings.users.table.balance_debt'), // Borç
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: _buildDetailHeader(
                    tr('settings.users.table.balance_credit'), // Alacak
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: _buildDetailHeader(
                    tr('settings.users.transaction.description'), // Açıklama
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: _buildDetailHeader(
                    tr('cashregisters.detail.user'), // Kullanıcı
                  ),
                ),
                // Actions alanı: SizedBox(width: 60) + SizedBox(width: 48) = 108px
                const SizedBox(width: 108),
              ],
            ),
          ),

          // Transactions List
          FutureBuilder<List<KullaniciHareketModel>>(
            key: ValueKey(kullanici.id),
            future: _detailFutures.putIfAbsent(
              kullanici.id,
              () => PersonelIslemleriVeritabaniServisi()
                  .kullaniciHareketleriniGetir(kullanici.id),
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20.0),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20.0),
                  child: Center(
                    child: Text('${tr('common.error')}: ${snapshot.error}'),
                  ),
                );
              }
              final transactions = snapshot.data ?? [];

              // Görünür transaction ID'lerini kaydet
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  _visibleTransactionIds[kullanici.id] = transactions
                      .map((t) => t.id)
                      .toList();
                }
              });

              if (transactions.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20.0),
                  child: Center(
                    child: Text(
                      tr('common.no_data'),
                      style: TextStyle(color: Colors.grey.shade500),
                    ),
                  ),
                );
              }

              return Column(
                children: transactions.asMap().entries.map((entry) {
                  final index = entry.key;
                  final transaction = entry.value;
                  final isLast = index == transactions.length - 1;
                  final isSelected = (_selectedDetailIds[kullanici.id] ?? {})
                      .contains(transaction.id);

                  // İşlem türüne göre girdi/çıktı belirle
                  // Borç > 0 ise çıktı (ödeme yapıldı), Alacak > 0 ise girdi (alacak eklendi)
                  final bool isIncoming = transaction.alacak > transaction.borc;

                  // Profesyonel işlem açıklaması oluştur
                  final String displayName = _getTransactionDisplayName(
                    transaction.islemTuru,
                    isIncoming,
                  );

                  final focusScope = TableDetailFocusScope.of(context);
                  final isFocused = focusScope?.focusedDetailIndex == index;

                  return Column(
                    children: [
                      _buildUserTransactionRow(
                        kullaniciId: kullanici.id,
                        transaction: transaction,
                        isSelected: isSelected,
                        isIncoming: isIncoming,
                        displayName: displayName,
                        paraBirimi: kullanici.paraBirimi ?? '₺',
                        kullaniciAdi: kullanici.kullaniciAdi,
                        onChanged: (val) => _onSelectDetailRow(
                          kullanici.id,
                          transaction.id,
                          val,
                        ),
                        isFocused: isFocused,
                        onTap: () {
                          focusScope?.setFocusedDetailIndex?.call(index);
                          // Seçili detay transaction bilgisini kaydet
                          setState(() {
                            _selectedDetailTransactionId = transaction.id;
                            _selectedDetailKullanici = kullanici;
                          });
                        },
                      ),
                      if (!isLast)
                        const Divider(
                          height: 1,
                          thickness: 1,
                          color: Color(0xFFEEEEEE),
                        ),
                    ],
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  // Kullanıcı için tüm detayların seçili olup olmadığını kontrol et
  bool _isAllDetailSelectedForUser(String kullaniciId) {
    final selectedIds = _selectedDetailIds[kullaniciId] ?? {};
    final visibleIds = _visibleTransactionIds[kullaniciId] ?? [];
    return visibleIds.isNotEmpty && selectedIds.length == visibleIds.length;
  }

  // Tüm detayları seç/kaldır
  void _onSelectAllDetailsForUser(String kullaniciId, bool? val) {
    setState(() {
      if (val == true) {
        final visibleIds = _visibleTransactionIds[kullaniciId] ?? [];
        _selectedDetailIds[kullaniciId] = Set.from(visibleIds);
      } else {
        _selectedDetailIds[kullaniciId]?.clear();
      }
    });
  }

  // Tek detay satırı seç/kaldır
  void _onSelectDetailRow(String kullaniciId, String transactionId, bool? val) {
    setState(() {
      _selectedDetailIds.putIfAbsent(kullaniciId, () => {});
      if (val == true) {
        _selectedDetailIds[kullaniciId]!.add(transactionId);
      } else {
        _selectedDetailIds[kullaniciId]!.remove(transactionId);
      }
    });
  }

  // İşlem türü için profesyonel display name oluştur
  String _getTransactionDisplayName(String islemTuru, bool isIncoming) {
    final type = islemTuru.toLowerCase();

    if (type.contains('payment') ||
        type.contains('odeme') ||
        type.contains('ödeme')) {
      return tr(
        'settings.users.transaction.type_payment',
      ); // Maaş Ödemesi / Ödeme
    } else if (type.contains('credit') || type.contains('alacak')) {
      return tr('settings.users.transaction.type_credit'); // Alacak Kaydı
    } else if (type.contains('maas') || type.contains('maaş')) {
      return tr('settings.users.transaction.type_salary'); // Maaş Ödemesi
    } else if (type.contains('prim') || type.contains('bonus')) {
      return tr('settings.users.transaction.type_bonus'); // Prim/Bonus
    } else if (type.contains('avans')) {
      return tr('settings.users.transaction.type_advance'); // Avans
    } else if (type.contains('kesinti')) {
      return tr('settings.users.transaction.type_deduction'); // Kesinti
    } else if (type.contains('tahsilat')) {
      return isIncoming
          ? tr('cashregisters.type.input') // Tahsilat
          : tr('cashregisters.type.output'); // Ödeme
    }

    // Varsayılan olarak girdi/çıktı tipini kullan
    return isIncoming
        ? tr('cashregisters.type.input')
        : tr('cashregisters.type.output');
  }

  // Kullanıcı hareket satırı widget'ı (Kasalar sayfasındaki _buildDetailRowCells gibi)
  Widget _buildUserTransactionRow({
    required String kullaniciId,
    required KullaniciHareketModel transaction,
    required bool isSelected,
    required bool isIncoming,
    required String displayName,
    required String paraBirimi,
    required String kullaniciAdi,
    required ValueChanged<bool?> onChanged,
    required VoidCallback onTap,
    required bool isFocused,
  }) {
    return Builder(
      builder: (context) {
        // Auto-scroll when focused
        if (isFocused) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) {
              Scrollable.ensureVisible(
                context,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
              );
            }
          });
        }
        return GestureDetector(
          onTap: onTap,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Container(
              constraints: const BoxConstraints(minHeight: 52),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFFC8E6C9) // Soft Green 100 for selection
                    : (isFocused
                          ? const Color(
                              0xFFE8F5E9,
                            ) // Soft Green 50 - focus color
                          : Colors.transparent),
                borderRadius: BorderRadius.circular(4),
              ),
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                    ), // 12+20+12 = 44px
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: ExcludeFocus(
                        child: Checkbox(
                          value: isSelected,
                          onChanged: onChanged,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                          side: const BorderSide(
                            color: Color(0xFFD1D1D1),
                            width: 1,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // İŞLEM TÜRÜ (Girdi/Çıktı Badge - Kasalar sayfasındaki gibi)
                  Expanded(
                    flex: 2,
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: IslemTuruRenkleri.arkaplanRengiGetir(
                              displayName,
                              isIncoming,
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Icon(
                            isIncoming
                                ? Icons.arrow_downward_rounded
                                : Icons.arrow_upward_rounded,
                            color: IslemTuruRenkleri.ikonRengiGetir(
                              displayName,
                              isIncoming,
                            ),
                            size: 14,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: HighlightText(
                            text: displayName,
                            query: _searchQuery,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: IslemTuruRenkleri.metinRengiGetir(
                                displayName,
                                isIncoming,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // TARİH
                  Expanded(
                    flex: 2,
                    child: HighlightText(
                      text: DateFormat(
                        'dd.MM.yyyy HH:mm',
                      ).format(transaction.tarih),
                      query: _searchQuery,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.black87,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // BORÇ
                  Expanded(
                    flex: 2,
                    child: HighlightText(
                      text: transaction.borc > 0
                          ? '${FormatYardimcisi.sayiFormatlaOndalikli(transaction.borc, binlik: _genelAyarlar.binlikAyiraci, ondalik: _genelAyarlar.ondalikAyiraci, decimalDigits: _genelAyarlar.fiyatOndalik)} $paraBirimi'
                          : '-',
                      query: _searchQuery,
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // ALACAK
                  Expanded(
                    flex: 2,
                    child: HighlightText(
                      text: transaction.alacak > 0
                          ? '${FormatYardimcisi.sayiFormatlaOndalikli(transaction.alacak, binlik: _genelAyarlar.binlikAyiraci, ondalik: _genelAyarlar.ondalikAyiraci, decimalDigits: _genelAyarlar.fiyatOndalik)} $paraBirimi'
                          : '-',
                      query: _searchQuery,
                      style: TextStyle(
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // AÇIKLAMA
                  Expanded(
                    flex: 3,
                    child: HighlightText(
                      text: transaction.aciklama.isNotEmpty
                          ? transaction.aciklama
                          : '-',
                      query: _searchQuery,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.black87,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // KULLANICI
                  Expanded(
                    flex: 2,
                    child: HighlightText(
                      text: kullaniciAdi.isNotEmpty ? kullaniciAdi : 'Sistem',
                      query: _searchQuery,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.black87,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 60),
                  // POPUP MENU
                  SizedBox(
                    width: 48,
                    child: _buildUserTransactionPopupMenu(
                      kullaniciId,
                      transaction,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // Kullanıcı hareket popup menüsü (Kasalar sayfasındaki _buildTransactionPopupMenu gibi)
  Widget _buildUserTransactionPopupMenu(
    String kullaniciId,
    KullaniciHareketModel transaction,
  ) {
    return Theme(
      data: Theme.of(context).copyWith(
        dividerTheme: const DividerThemeData(
          color: Color(0xFFEEEEEE),
          thickness: 1,
        ),
        popupMenuTheme: PopupMenuThemeData(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: Colors.grey.shade300, width: 1),
          ),
          elevation: 6,
        ),
      ),
      child: PopupMenuButton<String>(
        icon: const Icon(Icons.more_horiz, color: Colors.grey, size: 22),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 160),
        splashRadius: 20,
        offset: const Offset(0, 8),
        tooltip: tr('common.actions'),
        itemBuilder: (context) => [
          PopupMenuItem<String>(
            value: 'edit',
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            child: Row(
              children: [
                const Icon(
                  Icons.edit_outlined,
                  size: 20,
                  color: Color(0xFF2C3E50),
                ),
                const SizedBox(width: 12),
                Text(
                  tr('common.edit'),
                  style: const TextStyle(
                    color: Color(0xFF2C3E50),
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const Spacer(),
                Text(
                  tr('common.key.f2'),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade400,
                  ),
                ),
              ],
            ),
          ),
          const PopupMenuItem<String>(
            enabled: false,
            height: 12,
            padding: EdgeInsets.zero,
            child: Divider(
              height: 1,
              thickness: 1,
              indent: 10,
              endIndent: 10,
              color: Color(0xFFEEEEEE),
            ),
          ),
          PopupMenuItem<String>(
            value: 'delete',
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            child: Row(
              children: [
                const Icon(
                  Icons.delete_outline,
                  size: 20,
                  color: Color(0xFFEA4335),
                ),
                const SizedBox(width: 12),
                Text(
                  tr('common.delete'),
                  style: const TextStyle(
                    color: Color(0xFFEA4335),
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const Spacer(),
                Text(
                  tr('common.key.del'),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade400,
                  ),
                ),
              ],
            ),
          ),
        ],
        onSelected: (value) {
          if (value == 'edit') {
            _showEditUserTransactionDialog(kullaniciId, transaction);
          } else if (value == 'delete') {
            _handleDeleteUserTransaction(kullaniciId, transaction);
          }
        },
      ),
    );
  }

  // Kullanıcı hareket düzenleme dialog'u
  Future<void> _showEditUserTransactionDialog(
    String kullaniciId,
    KullaniciHareketModel transaction,
  ) async {
    // İşlem türüne göre doğru sayfaya yönlendir
    final kullanici = _cachedKullanicilar.firstWhere(
      (k) => k.id == kullaniciId,
      orElse: () => _cachedKullanicilar.first,
    );

    bool? result;
    // Borç > 0 ise ödeme yapılmış demektir
    if (transaction.borc > 0) {
      result = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (context) => KullaniciOdemeYapSayfasi(kullanici: kullanici),
        ),
      );
    } else {
      result = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (context) =>
              KullaniciAlacaklandirSayfasi(kullanici: kullanici),
        ),
      );
    }

    if (result == true) {
      // Detail cache'i temizle ve yenile
      _detailFutures.remove(kullaniciId);
      setState(() {});
      _fetchKullanicilar();
    }
  }

  // Kullanıcı hareket silme işlemi
  void _handleDeleteUserTransaction(
    String kullaniciId,
    KullaniciHareketModel transaction,
  ) {
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (context) => OnayDialog(
        baslik: tr('common.delete'),
        mesaj: tr('common.confirm_delete'),
        onayButonMetni: tr('common.delete'),
        iptalButonMetni: tr('common.cancel'),
        isDestructive: true,
        onOnay: () async {
          await PersonelIslemleriVeritabaniServisi().entegrasyonKaydiSil(
            transaction.id,
          );
          // Detail cache'i temizle ve yenile
          _detailFutures.remove(kullaniciId);
          if (mounted) {
            setState(() {
              _selectedDetailIds[kullaniciId]?.remove(transaction.id);
            });
          }
          _fetchKullanicilar();
        },
      ),
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return SizedBox(
      width: 200,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 4),
          HighlightText(
            text: value,
            query: _searchQuery,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailHeader(String text, {bool alignRight = false}) {
    return HighlightText(
      text: text,
      query: _searchQuery,
      textAlign: alignRight ? TextAlign.right : TextAlign.left,
      maxLines: 1,
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.bold,
        color: Colors.grey.shade600,
      ),
    );
  }

  Widget _buildPopupMenu(KullaniciModel kullanici) {
    final bool isLastAdmin =
        kullanici.rol == 'admin' && _toplamAdminSayisi <= 1;

    return Theme(
      data: Theme.of(context).copyWith(
        dividerTheme: const DividerThemeData(
          color: Color(0xFFEEEEEE),
          thickness: 1,
        ),
        popupMenuTheme: PopupMenuThemeData(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: Colors.grey.shade300, width: 1),
          ),
          elevation: 6,
        ),
      ),
      child: PopupMenuButton<String>(
        icon: const Icon(Icons.more_horiz, color: Colors.grey, size: 22),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 160),
        splashRadius: 20,
        offset: const Offset(0, 8),
        tooltip: tr('common.actions'),
        itemBuilder: (context) => [
          PopupMenuItem<String>(
            value: 'edit',
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            child: Row(
              children: [
                const Icon(
                  Icons.edit_outlined,
                  size: 20,
                  color: Color(0xFF2C3E50),
                ),
                const SizedBox(width: 12),
                Text(
                  tr('common.edit'),
                  style: const TextStyle(
                    color: Color(0xFF2C3E50),
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const Spacer(),
                Text(
                  tr('common.key.f2'),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade400,
                  ),
                ),
              ],
            ),
          ),
          const PopupMenuItem<String>(
            enabled: false,
            height: 12,
            padding: EdgeInsets.zero,
            child: Divider(
              height: 1,
              thickness: 1,
              indent: 10,
              endIndent: 10,
              color: Color(0xFFEEEEEE),
            ),
          ),
          PopupMenuItem<String>(
            value: 'make_payment',
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            child: Row(
              children: [
                const Icon(
                  Icons.payments_outlined,
                  size: 20,
                  color: Color(0xFF28A745),
                ),
                const SizedBox(width: 12),
                Text(
                  tr('settings.users.actions.make_payment'),
                  style: const TextStyle(
                    color: Color(0xFF28A745),
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const Spacer(),
                Text(
                  tr('common.key.f9'),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade400,
                  ),
                ),
              ],
            ),
          ),
          PopupMenuItem<String>(
            value: 'add_credit',
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            child: Row(
              children: [
                const Icon(
                  Icons.add_circle_outline,
                  size: 20,
                  color: Color(0xFF2C3E50),
                ),
                const SizedBox(width: 12),
                Text(
                  tr('settings.users.actions.add_credit'),
                  style: const TextStyle(
                    color: Color(0xFF2C3E50),
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const Spacer(),
                Text(
                  tr('common.key.f10'),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade400,
                  ),
                ),
              ],
            ),
          ),
          const PopupMenuItem<String>(
            enabled: false,
            height: 12,
            padding: EdgeInsets.zero,
            child: Divider(
              height: 1,
              thickness: 1,
              indent: 10,
              endIndent: 10,
              color: Color(0xFFEEEEEE),
            ),
          ),
          PopupMenuItem<String>(
            value: kullanici.aktifMi ? 'deactivate' : 'activate',
            enabled: !isLastAdmin || !kullanici.aktifMi,
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            child: Row(
              children: [
                Icon(
                  kullanici.aktifMi
                      ? Icons.toggle_off_outlined
                      : Icons.toggle_on_outlined,
                  size: 20,
                  color: (isLastAdmin && kullanici.aktifMi)
                      ? Colors.grey.shade400
                      : const Color(0xFF2C3E50),
                ),
                const SizedBox(width: 12),
                Text(
                  kullanici.aktifMi
                      ? tr('common.deactivate')
                      : tr('common.activate'),
                  style: TextStyle(
                    color: (isLastAdmin && kullanici.aktifMi)
                        ? Colors.grey.shade400
                        : const Color(0xFF2C3E50),
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const Spacer(),
                Text(
                  tr('common.key.f6'),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade400,
                  ),
                ),
              ],
            ),
          ),
          const PopupMenuItem<String>(
            enabled: false,
            height: 12,
            padding: EdgeInsets.zero,
            child: Divider(
              height: 1,
              thickness: 1,
              indent: 10,
              endIndent: 10,
              color: Color(0xFFEEEEEE),
            ),
          ),
          PopupMenuItem<String>(
            value: 'delete',
            enabled: !isLastAdmin,
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            child: Row(
              children: [
                Icon(
                  Icons.delete_outline,
                  size: 20,
                  color: isLastAdmin
                      ? Colors.grey.shade400
                      : const Color(0xFFEA4335),
                ),
                const SizedBox(width: 12),
                Text(
                  tr('common.delete'),
                  style: TextStyle(
                    color: isLastAdmin
                        ? Colors.grey.shade400
                        : const Color(0xFFEA4335),
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const Spacer(),
                Text(
                  tr('common.key.del'),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade400,
                  ),
                ),
              ],
            ),
          ),
        ],
        onSelected: (value) async {
          if (value == 'edit') {
            _kullaniciDuzenle(kullanici);
          } else if (value == 'make_payment') {
            final result = await Navigator.push<bool>(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    KullaniciOdemeYapSayfasi(kullanici: kullanici),
              ),
            );
            if (result == true) {
              _fetchKullanicilar();
            }
          } else if (value == 'add_credit') {
            final result = await Navigator.push<bool>(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    KullaniciAlacaklandirSayfasi(kullanici: kullanici),
              ),
            );
            if (result == true) {
              _fetchKullanicilar();
            }
          } else if (value == 'deactivate') {
            _kullaniciDurumDegistir(kullanici, false);
          } else if (value == 'activate') {
            _kullaniciDurumDegistir(kullanici, true);
          } else if (value == 'delete') {
            showDialog(
              context: context,
              barrierDismissible: true,
              barrierColor: Colors.black.withValues(alpha: 0.35),
              builder: (context) => OnayDialog(
                baslik: tr('common.delete'),
                mesaj: tr(
                  'common.confirm_delete_named',
                ).replaceAll('{name}', kullanici.kullaniciAdi),
                onayButonMetni: tr('common.delete'),
                iptalButonMetni: tr('common.cancel'),
                isDestructive: true,
                onOnay: () => _kullaniciSil(kullanici),
              ),
            );
          }
        },
      ),
    );
  }

  int _getActiveMobileFilterCount() {
    int count = 0;
    if (_searchController.text.trim().isNotEmpty) count++;
    if (_startDate != null || _endDate != null) count++;
    if (_selectedRole != null) count++;
    if (_selectedStatus != null) count++;
    return count;
  }

  Widget _buildMobileActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required Color textColor,
    required Color borderColor,
    required VoidCallback onTap,
    bool hasDropdown = false,
    double height = 48,
    double iconSize = 20,
    double fontSize = 14,
    EdgeInsetsGeometry padding = const EdgeInsets.symmetric(horizontal: 16),
  }) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: height,
          padding: padding,
          decoration: BoxDecoration(
            border: Border.all(color: borderColor),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: iconSize, color: textColor),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w600,
                    fontSize: fontSize,
                  ),
                ),
              ),
              if (hasDropdown) ...[
                const SizedBox(width: 8),
                Icon(
                  Icons.keyboard_arrow_down,
                  size: iconSize > 4 ? iconSize - 2 : iconSize,
                  color: textColor,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileSquareActionButton({
    required IconData icon,
    required VoidCallback onTap,
    required Color color,
    required Color iconColor,
    Color borderColor = Colors.transparent,
    double size = 40,
    String? tooltip,
  }) {
    Widget child = Material(
      color: color,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: borderColor),
          ),
          child: Icon(icon, size: 18, color: iconColor),
        ),
      ),
    );

    if (tooltip == null || tooltip.isEmpty) {
      return child;
    }

    return Tooltip(message: tooltip, child: child);
  }

  Widget _buildMobileTopActionRow() {
    final double width = MediaQuery.of(context).size.width;
    final bool isNarrow = width < 360;

    final String addLabel = isNarrow
        ? 'Ekle'
        : tr('settings.users.table.action.add');
    final String printTooltip =
        _selectedIds.isNotEmpty ||
            _selectedDetailIds.values.any((s) => s.isNotEmpty)
        ? tr('common.print_selected')
        : tr('common.print_list');

    return Row(
      children: [
        Expanded(
          child: _buildMobileActionButton(
            label: addLabel,
            icon: Icons.add,
            color: const Color(0xFFEA4335),
            textColor: Colors.white,
            borderColor: Colors.transparent,
            onTap: _kullaniciEkle,
            height: 40,
            iconSize: 16,
            fontSize: 12,
            padding: const EdgeInsets.symmetric(horizontal: 8),
          ),
        ),
        const SizedBox(width: 8),
        _buildMobileSquareActionButton(
          icon: Icons.print_outlined,
          onTap: _handlePrint,
          color: const Color(0xFFF8F9FA),
          iconColor: Colors.black87,
          borderColor: Colors.grey.shade300,
          tooltip: printTooltip,
          size: 40,
        ),
      ],
    );
  }

  Widget _buildMobileFilterGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool singleColumn = constraints.maxWidth < 360;

        if (singleColumn) {
          return Column(
            children: [
              _buildDateRangeFilter(width: double.infinity),
              const SizedBox(height: 12),
              _buildRoleFilter(width: double.infinity),
              const SizedBox(height: 12),
              _buildStatusFilter(width: double.infinity),
            ],
          );
        }

        return Column(
          children: [
            Row(
              children: [
                Expanded(child: _buildDateRangeFilter(width: double.infinity)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildRoleFilter(width: double.infinity)),
                const SizedBox(width: 12),
                Expanded(child: _buildStatusFilter(width: double.infinity)),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildMobileToolbarCard({
    required int totalRecords,
    required double maxExpandedHeight,
  }) {
    final int activeFilterCount = _getActiveMobileFilterCount();
    final bool hasSelection = _selectedIds.isNotEmpty || _isSelectAllActive;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              FocusScope.of(context).unfocus();
              setState(() {
                _isMobileToolbarExpanded = !_isMobileToolbarExpanded;
              });
              if (!_isMobileToolbarExpanded) {
                _closeOverlay();
              }
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final bool compact = constraints.maxWidth < 330;
                  final String toggleLabel = compact
                      ? (_isMobileToolbarExpanded ? 'Gizle' : 'Göster')
                      : (_isMobileToolbarExpanded
                            ? 'Filtreleri Gizle'
                            : 'Filtreleri Göster');

                  return Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFF2C3E50,
                          ).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.tune_rounded,
                          size: 16,
                          color: Color(0xFF2C3E50),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$totalRecords kayıt',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              activeFilterCount == 0
                                  ? 'Filtre yok'
                                  : '$activeFilterCount filtre aktif',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        toggleLabel,
                        style: const TextStyle(
                          color: Color(0xFF2C3E50),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 4),
                      AnimatedRotation(
                        turns: _isMobileToolbarExpanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 220),
                        child: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: Color(0xFF2C3E50),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeInOut,
            child: !_isMobileToolbarExpanded
                ? const SizedBox.shrink()
                : Column(
                    children: [
                      Divider(height: 1, color: Colors.grey.shade200),
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: maxExpandedHeight,
                        ),
                        child: SingleChildScrollView(
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    height: 48,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: Colors.grey.shade300,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                      color: Colors.white,
                                    ),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<int>(
                                        value: _rowsPerPage,
                                        items: [10, 25, 50, 100]
                                            .map(
                                              (e) => DropdownMenuItem(
                                                value: e,
                                                child: Text(e.toString()),
                                              ),
                                            )
                                            .toList(),
                                        onChanged: (val) {
                                          if (val == null) return;
                                          setState(() {
                                            _rowsPerPage = val;
                                            _currentPage = 1;
                                          });
                                          _detailFutures.clear();
                                          _fetchKullanicilar(
                                            showLoading: false,
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: TextField(
                                      controller: _searchController,
                                      focusNode: _searchFocusNode,
                                      textInputAction: TextInputAction.search,
                                      decoration: InputDecoration(
                                        hintText: tr('common.search'),
                                        prefixIcon: const Icon(
                                          Icons.search,
                                          color: Colors.grey,
                                        ),
                                        border: const UnderlineInputBorder(
                                          borderSide: BorderSide(
                                            color: Colors.grey,
                                          ),
                                        ),
                                        enabledBorder:
                                            const UnderlineInputBorder(
                                              borderSide: BorderSide(
                                                color: Colors.grey,
                                              ),
                                            ),
                                        focusedBorder:
                                            const UnderlineInputBorder(
                                              borderSide: BorderSide(
                                                color: Color(0xFF2C3E50),
                                              ),
                                            ),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              vertical: 12,
                                            ),
                                        filled: false,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (hasSelection)
                                Padding(
                                  padding: const EdgeInsets.only(top: 12),
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: MouseRegion(
                                      cursor: SystemMouseCursors.click,
                                      child: GestureDetector(
                                        onTap: _deleteSelectedKullanicilar,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFEA4335),
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                          child: Text(
                                            tr(
                                              'common.delete_selected',
                                            ).replaceAll(
                                              '{count}',
                                              _selectedIds.length.toString(),
                                            ),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 12),
                              _buildMobileFilterGrid(),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileView() {
    final int totalRecords = _totalRecords > 0
        ? _totalRecords
        : _cachedKullanicilar.length;
    final int safeRowsPerPage = _rowsPerPage <= 0 ? 25 : _rowsPerPage;
    final int totalPages = totalRecords == 0
        ? 1
        : (totalRecords / safeRowsPerPage).ceil();
    final int effectivePage = _currentPage.clamp(1, totalPages);
    if (effectivePage != _currentPage) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _currentPage = effectivePage;
          });
          _fetchKullanicilar(showLoading: false);
        }
      });
    }

    final int startRecordIndex = (effectivePage - 1) * safeRowsPerPage;
    final int endRecord = totalRecords == 0
        ? 0
        : (startRecordIndex + _cachedKullanicilar.length).clamp(
            0,
            totalRecords,
          );
    final int showingStart = totalRecords == 0 ? 0 : startRecordIndex + 1;

    final mediaQuery = MediaQuery.of(context);
    final bool isKeyboardVisible = mediaQuery.viewInsets.bottom > 0;
    final double availableHeight =
        mediaQuery.size.height -
        mediaQuery.padding.vertical -
        mediaQuery.viewInsets.bottom;
    final double maxExpandedHeight = (availableHeight * 0.5).clamp(
      180.0,
      420.0,
    );

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: [
                  Text(
                    tr('settings.users.title'),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: _buildMobileToolbarCard(
                totalRecords: totalRecords,
                maxExpandedHeight: maxExpandedHeight,
              ),
            ),
            if (!isKeyboardVisible)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: _buildMobileTopActionRow(),
              ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                itemCount: _cachedKullanicilar.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  return _buildUserCard(_cachedKullanicilar[index]);
                },
              ),
            ),
            if (!isKeyboardVisible)
              _buildMobilePagination(
                effectivePage: effectivePage,
                totalPages: totalPages,
                totalRecords: totalRecords,
                showingStart: showingStart,
                endRecord: endRecord,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserCard(KullaniciModel kullanici) {
    final bool isExpanded = _expandedMobileIds.contains(kullanici.id);

    final String basHarf =
        (kullanici.kullaniciAdi.isNotEmpty
                ? kullanici.kullaniciAdi
                : (kullanici.ad.isNotEmpty ? kullanici.ad : kullanici.id))
            .substring(0, 1)
            .toUpperCase();

    final String adSoyad = '${kullanici.ad} ${kullanici.soyad}'.trim();

    ImageProvider? avatarImage;
    if (kullanici.profilResmi != null && kullanici.profilResmi!.isNotEmpty) {
      try {
        avatarImage = MemoryImage(base64Decode(kullanici.profilResmi!));
      } catch (_) {}
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: Checkbox(
                  value: _selectedIds.contains(kullanici.id),
                  onChanged: (v) => _onSelectRow(v, kullanici.id),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                  side: const BorderSide(color: Color(0xFFD1D1D1)),
                ),
              ),
              const SizedBox(width: 12),
              CircleAvatar(
                radius: 24,
                backgroundColor: const Color(
                  0xFF2C3E50,
                ).withValues(alpha: 0.12),
                foregroundColor: const Color(0xFF2C3E50),
                backgroundImage: avatarImage,
                child: avatarImage == null
                    ? Text(
                        basHarf,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 18,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      adSoyad.isNotEmpty ? adSoyad : kullanici.kullaniciAdi,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_getRoleDisplayName(kullanici.rol)} • ${kullanici.telefon}',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [_buildPopupMenu(kullanici)],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatusBadge(kullanici.aktifMi),
              IconButton(
                icon: Icon(
                  isExpanded ? Icons.expand_less : Icons.expand_more,
                  color: const Color(0xFF2C3E50),
                ),
                onPressed: () {
                  setState(() {
                    if (isExpanded) {
                      _expandedMobileIds.remove(kullanici.id);
                    } else {
                      _expandedMobileIds.add(kullanici.id);
                    }
                  });
                },
              ),
            ],
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 260),
            alignment: Alignment.topCenter,
            curve: Curves.easeInOut,
            child: isExpanded
                ? Column(
                    children: [
                      const Divider(height: 18, color: Color(0xFFEEEEEE)),
                      _buildMobileUserDetails(kullanici),
                      const SizedBox(height: 16),
                      _buildMobileUserTransactions(kullanici),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileUserDetails(KullaniciModel kullanici) {
    final String paraBirimi = kullanici.paraBirimi ?? 'TRY';
    final String borc = FormatYardimcisi.sayiFormatlaOndalikli(
      kullanici.bakiyeBorc,
      binlik: _genelAyarlar.binlikAyiraci,
      ondalik: _genelAyarlar.ondalikAyiraci,
      decimalDigits: _genelAyarlar.fiyatOndalik,
    );
    final String alacak = FormatYardimcisi.sayiFormatlaOndalikli(
      kullanici.bakiyeAlacak,
      binlik: _genelAyarlar.binlikAyiraci,
      ondalik: _genelAyarlar.ondalikAyiraci,
      decimalDigits: _genelAyarlar.fiyatOndalik,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildMobileUserProperty(
          tr('settings.users.form.username.label'),
          kullanici.kullaniciAdi,
        ),
        _buildMobileUserProperty(
          tr('settings.users.form.email.label'),
          kullanici.eposta.isNotEmpty ? kullanici.eposta : '-',
        ),
        _buildMobileUserProperty(
          tr('settings.users.form.phone.label'),
          kullanici.telefon.isNotEmpty ? kullanici.telefon : '-',
        ),
        _buildMobileUserProperty(
          tr('settings.users.form.position.label'),
          (kullanici.gorevi ?? '').isNotEmpty ? kullanici.gorevi! : '-',
        ),
        _buildMobileUserProperty(
          tr('settings.users.table.balance_debt'),
          '$borc $paraBirimi',
          valueColor: Colors.red.shade700,
          boldValue: true,
        ),
        _buildMobileUserProperty(
          tr('settings.users.table.balance_credit'),
          '$alacak $paraBirimi',
          valueColor: Colors.green.shade700,
          boldValue: true,
        ),
      ],
    );
  }

  Widget _buildMobileUserTransactions(KullaniciModel kullanici) {
    final String paraBirimi = kullanici.paraBirimi ?? 'TRY';

    return FutureBuilder<List<KullaniciHareketModel>>(
      key: ValueKey('mobile-user-tx-${kullanici.id}'),
      future: _detailFutures.putIfAbsent(
        kullanici.id,
        () => PersonelIslemleriVeritabaniServisi().kullaniciHareketleriniGetir(
          kullanici.id,
        ),
      ),
      builder: (context, snapshot) {
        final transactions = snapshot.data ?? [];
        final selectedIds = _selectedDetailIds[kullanici.id] ?? {};
        final allSelected =
            transactions.isNotEmpty &&
            selectedIds.length == transactions.length;

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _visibleTransactionIds[kullanici.id] = transactions
              .map((t) => t.id)
              .toList(growable: false);
        });

        Widget body;
        if (snapshot.connectionState == ConnectionState.waiting) {
          body = const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          );
        } else if (snapshot.hasError) {
          body = Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: Text('${tr('common.error')}: ${snapshot.error}'),
            ),
          );
        } else if (transactions.isEmpty) {
          body = Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: Text(
                tr('common.no_data'),
                style: TextStyle(color: Colors.grey.shade500),
              ),
            ),
          );
        } else {
          body = Column(
            children: transactions.asMap().entries.map((entry) {
              final index = entry.key;
              final tx = entry.value;
              final isLast = index == transactions.length - 1;

              final bool isIncoming = tx.alacak > tx.borc;
              final String title = _getTransactionDisplayName(
                tx.islemTuru,
                isIncoming,
              );
              final double amount = isIncoming ? tx.alacak : tx.borc;
              final String amountText = FormatYardimcisi.sayiFormatlaOndalikli(
                amount,
                binlik: _genelAyarlar.binlikAyiraci,
                ondalik: _genelAyarlar.ondalikAyiraci,
                decimalDigits: _genelAyarlar.fiyatOndalik,
              );
              final String dateText = DateFormat(
                'dd.MM.yyyy HH:mm',
              ).format(tx.tarih);

              return Column(
                children: [
                  _buildMobileUserTransactionRow(
                    id: tx.id,
                    isSelected: selectedIds.contains(tx.id),
                    onChanged: (val) =>
                        _onSelectDetailRow(kullanici.id, tx.id, val),
                    isIncoming: isIncoming,
                    title: title,
                    date: dateText,
                    amountText: '$amountText $paraBirimi',
                    description: tx.aciklama,
                  ),
                  if (!isLast)
                    const Divider(
                      height: 16,
                      thickness: 1,
                      color: Color(0xFFEEEEEE),
                    ),
                ],
              );
            }).toList(),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: Checkbox(
                    value: allSelected,
                    onChanged: transactions.isEmpty
                        ? null
                        : (val) =>
                              _onSelectAllDetailsForUser(kullanici.id, val),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                    side: const BorderSide(color: Color(0xFFD1D1D1), width: 1),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  tr('settings.users.detail.transactions'),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            body,
          ],
        );
      },
    );
  }

  Widget _buildMobileUserTransactionRow({
    required String id,
    required bool isSelected,
    required ValueChanged<bool?> onChanged,
    required bool isIncoming,
    required String title,
    required String date,
    required String amountText,
    required String description,
  }) {
    final String trimmedDescription = description.trim();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: SizedBox(
            width: 20,
            height: 20,
            child: Checkbox(
              value: isSelected,
              onChanged: onChanged,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              side: const BorderSide(color: Color(0xFFD1D1D1), width: 1),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: IslemTuruRenkleri.arkaplanRengiGetir(
                        title,
                        isIncoming,
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Icon(
                      isIncoming
                          ? Icons.arrow_downward_rounded
                          : Icons.arrow_upward_rounded,
                      color: IslemTuruRenkleri.ikonRengiGetir(
                        title,
                        isIncoming,
                      ),
                      size: 14,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: IslemTuruRenkleri.metinRengiGetir(
                          title,
                          isIncoming,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    date,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.payments_outlined,
                    size: 14,
                    color: Colors.grey.shade500,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    amountText,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isIncoming
                          ? Colors.green.shade700
                          : Colors.red.shade700,
                    ),
                  ),
                ],
              ),
              if (trimmedDescription.isNotEmpty) ...[
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.notes_outlined,
                      size: 14,
                      color: Colors.grey.shade500,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        trimmedDescription,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMobileUserProperty(
    String label,
    String value, {
    Color? valueColor,
    bool boldValue = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: boldValue ? FontWeight.w700 : FontWeight.w500,
                color: valueColor ?? Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobilePagination({
    required int effectivePage,
    required int totalPages,
    required int totalRecords,
    required int showingStart,
    required int endRecord,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Row(
        children: [
          IconButton(
            onPressed: effectivePage > 1
                ? () {
                    setState(() => _currentPage = effectivePage - 1);
                    _fetchKullanicilar(showLoading: false);
                  }
                : null,
            icon: const Icon(Icons.chevron_left),
          ),
          Expanded(
            child: Text(
              tr('common.pagination.showing')
                  .replaceAll('{start}', showingStart.toString())
                  .replaceAll('{end}', endRecord.toString())
                  .replaceAll('{total}', totalRecords.toString()),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
          IconButton(
            onPressed: effectivePage < totalPages
                ? () {
                    setState(() => _currentPage = effectivePage + 1);
                    _fetchKullanicilar(showLoading: false);
                  }
                : null,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}
