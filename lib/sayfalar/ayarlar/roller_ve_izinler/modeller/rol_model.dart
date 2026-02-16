import 'dart:convert';

class RolModel {
  final String id;
  final String ad;
  final List<String> izinler;
  final bool sistemRoluMu;
  final bool aktifMi;

  RolModel({
    required this.id,
    required this.ad,
    required this.izinler,
    required this.sistemRoluMu,
    required this.aktifMi,
  });

  RolModel copyWith({
    String? id,
    String? ad,
    List<String>? izinler,
    bool? sistemRoluMu,
    bool? aktifMi,
  }) {
    return RolModel(
      id: id ?? this.id,
      ad: ad ?? this.ad,
      izinler: izinler ?? this.izinler,
      sistemRoluMu: sistemRoluMu ?? this.sistemRoluMu,
      aktifMi: aktifMi ?? this.aktifMi,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': ad,
      'permissions': jsonEncode(izinler),
      'is_system': sistemRoluMu ? 1 : 0,
      'is_active': aktifMi ? 1 : 0,
    };
  }

  factory RolModel.fromMap(Map<String, dynamic> map) {
    return RolModel(
      id: map['id'] as String,
      ad: map['name'] as String,
      izinler: List<String>.from(
        jsonDecode(map['permissions'] as String) as List<dynamic>,
      ),
      sistemRoluMu: (map['is_system'] as int) == 1,
      aktifMi: (map['is_active'] as int) == 1,
    );
  }
}

