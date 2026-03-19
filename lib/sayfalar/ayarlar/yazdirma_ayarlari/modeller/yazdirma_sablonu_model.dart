import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:lospos/sayfalar/ayarlar/yazdirma_ayarlari/modeller/barkod_grafik_model.dart';
import 'package:lospos/sayfalar/ayarlar/yazdirma_ayarlari/modeller/barkod_kagit_modeli.dart';
import 'package:lospos/sayfalar/ayarlar/yazdirma_ayarlari/modeller/qr_kod_icerik_model.dart';

bool _boolFromDynamic(dynamic value) {
  if (value == null) return false;
  if (value is bool) return value;
  if (value is num) return value != 0;
  final s = value.toString().trim().toLowerCase();
  return s == 'true' || s == '1' || s == 'yes' || s == 'y';
}

String _stringFromDynamic(dynamic value, String fallback) {
  if (value == null) return fallback;
  return value.toString();
}

String _normalizeFontWeightString(dynamic raw) {
  final v = _stringFromDynamic(raw, 'normal').trim();
  if (v.isEmpty) return 'normal';

  // Legacy values may be stored as `FontWeight.bold` / `FontWeight.w700`
  if (v.startsWith('FontWeight.')) {
    return v.substring('FontWeight.'.length);
  }
  return v;
}

Map<String, dynamic>? _mapFromDynamic(dynamic value) {
  if (value == null) return null;
  if (value is Map<String, dynamic>) {
    return Map<String, dynamic>.from(value);
  }
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  if (value is String) {
    try {
      final decoded = jsonDecode(value);
      if (decoded is Map) {
        return decoded.map((key, item) => MapEntry(key.toString(), item));
      }
    } catch (_) {}
  }
  return null;
}

Map<String, dynamic>? _cloneMap(Map<String, dynamic>? value) {
  if (value == null) return null;
  try {
    final cloned = jsonDecode(jsonEncode(value));
    if (cloned is Map) {
      return cloned.map((key, item) => MapEntry(key.toString(), item));
    }
  } catch (_) {}
  return Map<String, dynamic>.from(value);
}

const Object _layoutElementNoChange = Object();

class YazdirmaSablonuModel {
  final int? id;
  final String name;
  final String docType; // 'invoice', 'waybill', 'voucher', 'receipt', 'barcode'
  final String? paperSize; // 'A4', 'A5', 'Custom'
  final double? customWidth; // mm
  final double? customHeight; // mm
  final double itemRowSpacing; // mm (Ürün satır araları)
  final String? backgroundImage; // base64
  final double backgroundOpacity; // 0.0 to 1.0
  final double backgroundX; // mm
  final double backgroundY; // mm
  final double? backgroundWidth; // mm
  final double? backgroundHeight; // mm
  final List<LayoutElement> layout;
  final bool isDefault;
  final bool isLandscape;
  final String? viewMatrix; // Matrix4 data as string (16 doubles)
  final Map<String, dynamic>? templateConfigJson;

  YazdirmaSablonuModel({
    this.id,
    required this.name,
    required this.docType,
    this.paperSize = 'A4',
    this.customWidth,
    this.customHeight,
    this.itemRowSpacing = 1.0,
    this.backgroundImage,
    this.backgroundOpacity = 0.5,
    this.backgroundX = 0.0,
    this.backgroundY = 0.0,
    this.backgroundWidth,
    this.backgroundHeight,
    required this.layout,
    this.isDefault = false,
    this.isLandscape = false,
    this.viewMatrix,
    this.templateConfigJson,
  });

  bool get _looksLikeLegacyVoucherTemplate {
    if (docType != 'receipt') return false;
    final normalizedName = name.trim().toLowerCase();
    return normalizedName.contains('makbuz');
  }

  String get effectiveDocType {
    if (_looksLikeLegacyVoucherTemplate) return 'voucher';
    return docType;
  }

  bool get usesDynamicThermalFlow => paperSize == 'Thermal80Cutter';

  String? get paperSizeTranslationKey => paperSizeTranslationKeyFor(paperSize);

  BarkodKagitAyari? get barcodePaperConfig {
    if (!BarkodKagitKatalog.barkodKagitMi(paperSize)) return null;
    return BarkodKagitKatalog.ayarOlustur(
      paperSize ?? BarkodKagitKatalog.varsayilanA4Preset.paperSizeCode,
      storedConfig: _mapFromDynamic(templateConfigJson),
    );
  }

  static String? paperSizeTranslationKeyFor(String? paperSize) {
    return switch (paperSize) {
      'A4' => 'print.paper_size.a4',
      'A5' => 'print.paper_size.a5',
      'Continuous' => 'print.paper.continuous_form',
      'Thermal80' => 'print.paper.thermal_80',
      'Thermal80Cutter' => 'print.paper.thermal_80_cutter',
      'Thermal58' => 'print.paper.thermal_58',
      'BarcodeA4_12' => 'print.paper.barcode_a4_12',
      'BarcodeA4_24' => 'print.paper.barcode_a4_24',
      'BarcodeA4_40' => 'print.paper.barcode_a4_40',
      'BarcodeA4_65' => 'print.paper.barcode_a4_65',
      'BarcodeA4_80' => 'print.paper.barcode_a4_80',
      'BarcodeA4_95' => 'print.paper.barcode_a4_95',
      'BarcodeA4Manual' => 'print.paper.barcode_a4_manual',
      'BarcodeThermal80' => 'print.paper.barcode_thermal_manual',
      'BarcodeThermal80Cutter' => 'print.paper.barcode_thermal_cutter_manual',
      'Custom' => 'print.paper.custom_size',
      _ => null,
    };
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'doc_type': docType,
      'paper_size': paperSize,
      'custom_width': customWidth,
      'custom_height': customHeight,
      'item_row_spacing': itemRowSpacing,
      'background_image': backgroundImage,
      'background_opacity': backgroundOpacity,
      'background_x': backgroundX,
      'background_y': backgroundY,
      'background_width': backgroundWidth,
      'background_height': backgroundHeight,
      'layout_json': jsonEncode(layout.map((e) => e.toMap()).toList()),
      'is_default': isDefault ? 1 : 0,
      'is_landscape': isLandscape ? 1 : 0,
      'view_matrix': viewMatrix,
      'template_config_json': templateConfigJson == null
          ? null
          : jsonEncode(templateConfigJson),
    };
  }

  factory YazdirmaSablonuModel.fromMap(Map<String, dynamic> map) {
    List<LayoutElement> layoutList = [];
    if (map['layout_json'] != null) {
      try {
        final List<dynamic> decoded = jsonDecode(map['layout_json']);
        layoutList = decoded.map((e) => LayoutElement.fromMap(e)).toList();
      } catch (e) {
        debugPrint('Layout parse error: $e');
      }
    }

    return YazdirmaSablonuModel(
      id: map['id'],
      name: map['name'] ?? '',
      docType: map['doc_type'] ?? '',
      paperSize: map['paper_size'],
      customWidth: (map['custom_width'] as num?)?.toDouble(),
      customHeight: (map['custom_height'] as num?)?.toDouble(),
      itemRowSpacing: (map['item_row_spacing'] as num?)?.toDouble() ?? 1.0,
      backgroundImage: map['background_image'],
      backgroundOpacity: (map['background_opacity'] as num?)?.toDouble() ?? 0.5,
      backgroundX: (map['background_x'] as num?)?.toDouble() ?? 0.0,
      backgroundY: (map['background_y'] as num?)?.toDouble() ?? 0.0,
      backgroundWidth: (map['background_width'] as num?)?.toDouble(),
      backgroundHeight: (map['background_height'] as num?)?.toDouble(),
      layout: layoutList,
      isDefault: map['is_default'] == 1,
      isLandscape: map['is_landscape'] == 1,
      viewMatrix: map['view_matrix'],
      templateConfigJson: _mapFromDynamic(map['template_config_json']),
    );
  }
}

class LayoutElement {
  final String id;
  final String key; // data key (e.g. 'customer_name', 'total')
  final String label; // display label
  final String elementType; // 'text' | 'image'
  final bool isStatic; // true => label basılır
  final bool repeat; // true => satır bazlı tekrarlanır
  final double x; // mm or percentage? Let's use mm for precision
  final double y; // mm
  final double width; // mm
  final double height; // mm
  final String fontSize; // 'small', 'medium', 'large' or numeric
  final String fontWeight; // 'normal', 'bold'
  final bool italic; // true => italic font/style
  final bool underline; // true => underline decoration
  final String alignment; // 'left', 'center', 'right'
  final String vAlignment; // 'top', 'center', 'bottom'
  final String? color; // hex color
  final String? backgroundColor; // hex color or null
  final String? fontFamily; // 'Roboto', 'OpenSans', etc.
  final Map<String, dynamic>? extraConfig; // element specific metadata

  LayoutElement({
    required this.id,
    required this.key,
    required this.label,
    this.elementType = 'text',
    this.isStatic = false,
    this.repeat = false,
    required this.x,
    required this.y,
    this.width = 50,
    this.height = 10,
    this.fontSize = '12',
    this.fontWeight = 'normal',
    this.italic = false,
    this.underline = false,
    this.alignment = 'left',
    this.vAlignment = 'center',
    this.color = '#000000',
    this.backgroundColor,
    this.fontFamily = 'Inter',
    Map<String, dynamic>? extraConfig,
  }) : extraConfig = _cloneMap(extraConfig);

  static const String qrContentConfigKey = 'qrContent';
  static const String barcodeGraphicConfigKey = 'barcodeGraphic';

  QrKodIcerikModel? get qrContentConfig =>
      QrKodIcerikModel.fromDynamic(extraConfig?[qrContentConfigKey]);

  BarkodGrafikModel? get barcodeGraphicConfig =>
      BarkodGrafikModel.fromDynamic(extraConfig?[barcodeGraphicConfigKey]);

  LayoutElement withQrContentConfig(QrKodIcerikModel? config) {
    final updatedConfig = extraConfig == null
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(extraConfig!);

    if (config == null) {
      updatedConfig.remove(qrContentConfigKey);
    } else {
      updatedConfig[qrContentConfigKey] = config.toMap();
    }

    return copyWith(extraConfig: updatedConfig.isEmpty ? null : updatedConfig);
  }

  LayoutElement withBarcodeGraphicConfig(BarkodGrafikModel? config) {
    final updatedConfig = extraConfig == null
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(extraConfig!);

    if (config == null) {
      updatedConfig.remove(barcodeGraphicConfigKey);
    } else {
      updatedConfig[barcodeGraphicConfigKey] = config.toMap();
    }

    return copyWith(extraConfig: updatedConfig.isEmpty ? null : updatedConfig);
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'key': key,
      'label': label,
      'elementType': elementType,
      'isStatic': isStatic,
      'repeat': repeat,
      'x': x,
      'y': y,
      'width': width,
      'height': height,
      'fontSize': fontSize,
      'fontWeight': fontWeight,
      'italic': italic,
      'underline': underline,
      'alignment': alignment,
      'vAlignment': vAlignment,
      'color': color,
      'backgroundColor': backgroundColor,
      'fontFamily': fontFamily,
      'extraConfig': extraConfig,
    };
  }

  factory LayoutElement.fromMap(Map<String, dynamic> map) {
    return LayoutElement(
      id: map['id'] ?? '',
      key: map['key'] ?? '',
      label: map['label'] ?? '',
      elementType: map['elementType'] ?? 'text',
      isStatic: _boolFromDynamic(map['isStatic']),
      repeat: _boolFromDynamic(map['repeat']),
      x: (map['x'] as num?)?.toDouble() ?? 0.0,
      y: (map['y'] as num?)?.toDouble() ?? 0.0,
      width: (map['width'] as num?)?.toDouble() ?? 50.0,
      height: (map['height'] as num?)?.toDouble() ?? 10.0,
      fontSize: _stringFromDynamic(map['fontSize'], '10'),
      fontWeight: _normalizeFontWeightString(map['fontWeight']),
      italic:
          _boolFromDynamic(map['italic']) || _boolFromDynamic(map['isItalic']),
      underline:
          _boolFromDynamic(map['underline']) ||
          _boolFromDynamic(map['isUnderline']),
      alignment: map['alignment'] ?? 'left',
      vAlignment: map['vAlignment'] ?? 'center',
      color: map['color'],
      backgroundColor: map['backgroundColor'],
      fontFamily: map['fontFamily'] ?? 'Inter',
      extraConfig: _mapFromDynamic(map['extraConfig']),
    );
  }

  LayoutElement copyWith({
    String? id,
    String? key,
    String? label,
    String? elementType,
    bool? isStatic,
    bool? repeat,
    double? x,
    double? y,
    double? width,
    double? height,
    String? fontSize,
    String? fontWeight,
    bool? italic,
    bool? underline,
    String? alignment,
    String? vAlignment,
    String? color,
    String? backgroundColor,
    String? fontFamily,
    Object? extraConfig = _layoutElementNoChange,
  }) {
    return LayoutElement(
      id: id ?? this.id,
      key: key ?? this.key,
      label: label ?? this.label,
      elementType: elementType ?? this.elementType,
      isStatic: isStatic ?? this.isStatic,
      repeat: repeat ?? this.repeat,
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      height: height ?? this.height,
      fontSize: fontSize ?? this.fontSize,
      fontWeight: fontWeight ?? this.fontWeight,
      italic: italic ?? this.italic,
      underline: underline ?? this.underline,
      alignment: alignment ?? this.alignment,
      vAlignment: vAlignment ?? this.vAlignment,
      color: color ?? this.color,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      fontFamily: fontFamily ?? this.fontFamily,
      extraConfig: identical(extraConfig, _layoutElementNoChange)
          ? this.extraConfig
          : extraConfig as Map<String, dynamic>?,
    );
  }
}
