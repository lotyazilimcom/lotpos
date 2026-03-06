import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

class PencereDurumuServisi with WindowListener {
  static final PencereDurumuServisi _instance =
      PencereDurumuServisi._internal();
  factory PencereDurumuServisi() => _instance;
  PencereDurumuServisi._internal();

  static const String _prefsKey = 'patisyov10.window_state.v1';
  static const Duration _debounce = Duration(milliseconds: 350);

  Timer? _saveTimer;
  bool _listenerAttached = false;

  PencereDurumu? _cached;

  Future<PencereDurumu?> kayitliDurumuGetir() async {
    if (_cached != null) return _cached;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      _cached = PencereDurumu.fromJson(data);
      return _cached;
    } catch (_) {
      return null;
    }
  }

  Future<void> dinlemeyiBaslat() async {
    if (_listenerAttached) return;
    windowManager.addListener(this);
    _listenerAttached = true;
  }

  @override
  void onWindowResized() => _scheduleSave();

  @override
  void onWindowResize() => _scheduleSave();

  @override
  void onWindowMaximize() => _scheduleSave();

  @override
  void onWindowUnmaximize() => _scheduleSave();

  @override
  void onWindowEnterFullScreen() => _scheduleSave();

  @override
  void onWindowLeaveFullScreen() => _scheduleSave();

  @override
  void onWindowClose() => _scheduleSave(immediate: true);

  void _scheduleSave({bool immediate = false}) {
    _saveTimer?.cancel();
    _saveTimer = Timer(immediate ? Duration.zero : _debounce, () {
      unawaited(_saveNow());
    });
  }

  Future<void> _saveNow() async {
    final prefs = await SharedPreferences.getInstance();

    final bool isMaximized = await windowManager.isMaximized();
    final bool isFullScreen = await windowManager.isFullScreen();
    final bool isMinimized = await windowManager.isMinimized();

    PencereDurumu next = _cached ?? const PencereDurumu();

    if (!isMaximized && !isFullScreen && !isMinimized) {
      final size = await windowManager.getSize();
      next = next.copyWith(width: size.width, height: size.height);
    }

    next = next.copyWith(isMaximized: isMaximized);

    _cached = next;
    await prefs.setString(_prefsKey, jsonEncode(next.toJson()));
  }
}

class PencereDurumu {
  final double width;
  final double height;
  final bool isMaximized;

  const PencereDurumu({
    this.width = 1280,
    this.height = 720,
    this.isMaximized = true,
  });

  Size get size => Size(width, height);

  PencereDurumu copyWith({double? width, double? height, bool? isMaximized}) {
    return PencereDurumu(
      width: width ?? this.width,
      height: height ?? this.height,
      isMaximized: isMaximized ?? this.isMaximized,
    );
  }

  Map<String, dynamic> toJson() => {
    'width': width,
    'height': height,
    'isMaximized': isMaximized,
  };

  static PencereDurumu fromJson(Map<String, dynamic> json) {
    double toDouble(dynamic v, double fallback) {
      if (v == null) return fallback;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString()) ?? fallback;
    }

    final width = toDouble(json['width'], 1280);
    final height = toDouble(json['height'], 720);
    final isMaximized = json['isMaximized'] == true;

    return PencereDurumu(
      width: width,
      height: height,
      isMaximized: isMaximized,
    );
  }
}
