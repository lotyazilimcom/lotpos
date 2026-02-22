import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:patisyov10/servisler/yazdirma_veritabani_servisi.dart';
import 'package:patisyov10/sayfalar/ayarlar/yazdirma_ayarlari/alanlar/yazdirma_alanlari.dart';
import 'package:patisyov10/sayfalar/ayarlar/yazdirma_ayarlari/modeller/yazdirma_sablonu_model.dart';
import 'package:file_selector/file_selector.dart';
import 'package:patisyov10/bilesenler/onay_dialog.dart';
import 'package:patisyov10/yardimcilar/ceviri/ceviri_servisi.dart';
import 'package:patisyov10/yardimcilar/mesaj_yardimcisi.dart';

class YazdirmaSablonTasarimci extends StatefulWidget {
  final YazdirmaSablonuModel? sablon;

  const YazdirmaSablonTasarimci({super.key, this.sablon});

  @override
  State<YazdirmaSablonTasarimci> createState() =>
      _YazdirmaSablonTasarimciState();
}

class _YazdirmaSablonTasarimciState extends State<YazdirmaSablonTasarimci> {
  final YazdirmaVeritabaniServisi _dbServisi = YazdirmaVeritabaniServisi();

  static const double _canvasFitPaddingPx = 40.0;
  static const double _backgroundOverlayPaddingPx = 24.0;
  static const double _minViewScale = 0.1;
  static const double _maxViewScale = 5.0;
  static const double _mouseWheelScaleFactor = 200.0;

  late String _name;
  late String _docType;
  late String _paperSize;
  late double _customWidth;
  late double _customHeight;
  late double _itemRowSpacing = 1.0;
  String? _backgroundImage;
  Uint8List? _bgImageBytes;
  List<LayoutElement> _layout = [];
  bool _isDefault = false;
  bool _isLandscape = false;

  double _backgroundOpacity = 0.5;
  double _backgroundX = 0.0;
  double _backgroundY = 0.0;
  double? _backgroundWidth;
  double? _backgroundHeight;

  LayoutElement? _selectedElement;
  final List<String> _selectedIds = [];
  final TransformationController _transformationController =
      TransformationController();
  final GlobalKey _canvasKey = GlobalKey();
  bool _initialCanvasViewApplied = false;
  bool _initialCanvasViewScheduled = false;
  bool _isDraggingElement = false; // Track if an element is being dragged
  bool _isDuplicating = false; // Track if we are in Alt-duplicate mode
  bool _isSpacePressed = false; // Photoshop-style pan tool (Space)
  bool _isSpacePanning = false;
  Offset _spacePanStartViewportPos = Offset.zero;
  Offset _spacePanStartTranslation = Offset.zero;
  bool _isMarqueeSelecting = false;
  Offset _marqueeStartScenePos = Offset.zero;
  Offset _marqueeCurrentScenePos = Offset.zero;
  List<String> _marqueeBaseSelection = const [];
  Offset _dragStartScenePos =
      Offset.zero; // Pointer position in scene at drag start
  double _elementStartPosX = 0; // Element X at drag start
  double _elementStartPosY = 0; // Element Y at drag start
  double _elementStartWidth = 0; // Element Width at resize start
  double _elementStartHeight = 0; // Element Height at resize start
  static const String _backgroundId = 'background_image_layer';
  final FocusNode _canvasFocusNode = FocusNode();
  String? _editingElementId; // ID of the element currently being edited inline
  final TextEditingController _inlineEditController = TextEditingController();
  final FocusNode _inlineEditFocusNode = FocusNode();

  // A4 dimensions in mm: 210 x 297
  // Screen scale factor (pixels per mm). Let's use a base of 3.0 for clarity.
  final double _scale = 3.8; // px / mm approx.
  final TextEditingController _fieldSearchController = TextEditingController();
  String _fieldSearchQuery = '';

  final List<String> _fontFamilies = [
    'Inter',
    'Roboto',
    'OpenSans',
    'Lato',
    'Montserrat',
    'Oswald',
    'Raleway',
    'Merriweather',
    'PlayfairDisplay',
    'Nunito',
    'NotoSans',
    'TitilliumWeb',
    'Ubuntu',
  ];

  final Map<String, FontWeight> _fontWeights = {
    'Thin': FontWeight.w100,
    'Light': FontWeight.w300,
    'Regular': FontWeight.w400,
    'Medium': FontWeight.w500,
    'Bold': FontWeight.w700,
    'Black': FontWeight.w900,
  };

  void _elementSil(LayoutElement el) {
    if (_selectedIds.isEmpty) {
      _selectedIds.add(el.id);
    }
    final count = _selectedIds.length;
    showDialog(
      context: context,
      builder: (context) => OnayDialog(
        baslik: count > 1
            ? tr(
                'print.designer.delete_fields_with_count',
              ).replaceAll('{count}', '$count')
            : tr('print.designer.delete_field'),
        mesaj: count > 1
            ? tr(
                'print.designer.delete_fields_confirm_with_count',
              ).replaceAll('{count}', '$count')
            : tr('print.designer.delete_field_confirm'),
        isDestructive: true,
        onayButonMetni: tr('common.delete'),
        onOnay: () {
          setState(() {
            _layout.removeWhere(
              (e) => _selectedIds.contains(e.id) || e.id == el.id,
            );
            _selectedElement = null;
            _selectedIds.clear();
          });
        },
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    if (widget.sablon != null) {
      _name = widget.sablon!.name;
      _docType = widget.sablon!.docType;
      _paperSize = widget.sablon!.paperSize ?? 'A4';
      _customWidth = widget.sablon!.customWidth ?? 210;
      _customHeight = widget.sablon!.customHeight ?? 297;
      _itemRowSpacing = widget.sablon!.itemRowSpacing;
      _backgroundImage = widget.sablon!.backgroundImage;
      _backgroundOpacity = widget.sablon!.backgroundOpacity;
      _backgroundX = widget.sablon!.backgroundX;
      _backgroundY = widget.sablon!.backgroundY;
      _backgroundWidth = widget.sablon!.backgroundWidth;
      _backgroundHeight = widget.sablon!.backgroundHeight;
      _layout = List.from(widget.sablon!.layout);
      _isDefault = widget.sablon!.isDefault;
      _isLandscape = widget.sablon!.isLandscape;
      if (_backgroundImage != null) {
        _bgImageBytes = base64Decode(_backgroundImage!);
      }
    } else {
      _name = tr('print.designer.new_template_name');
      _docType = 'invoice';
      _paperSize = 'A4';
      _customWidth = 210;
      _customHeight = 297;
      _itemRowSpacing = 1.0;
      _layout = [];
      _isDefault = false;
      _isLandscape = false;
      _backgroundOpacity = 0.5;
      _backgroundX = 0.0;
      _backgroundY = 0.0;

      _backgroundWidth = null;
      _backgroundHeight = null;
    }

    _fieldSearchController.addListener(() {
      final q = _fieldSearchController.text.trim().toLowerCase();
      if (q == _fieldSearchQuery) return;
      setState(() => _fieldSearchQuery = q);
    });

    // [2026] Undo History Init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _saveToHistory();
    });
  }

  // [2026 FEATURE] Undo History
  final List<List<LayoutElement>> _history = [];
  bool _isLocked = false;

  void _saveToHistory() {
    // Deep copy current layout
    final snapshot = _layout
        .map(
          (e) => LayoutElement(
            id: e.id,
            key: e.key,
            label: e.label,
            elementType: e.elementType,
            isStatic: e.isStatic,
            repeat: e.repeat,
            x: e.x,
            y: e.y,
            width: e.width,
            height: e.height,
            fontSize: e.fontSize,
            fontWeight: e.fontWeight,
            italic: e.italic,
            underline: e.underline,
            alignment: e.alignment,
            vAlignment: e.vAlignment,
            color: e.color,
            fontFamily: e.fontFamily,
            backgroundColor: e.backgroundColor,
          ),
        )
        .toList();

    // If we have restored and then edited, clear 'future' history?
    // For simplicity, this implementation is a linear history stack.
    // If we undo and then edit, we lose the "redo" path (standard behavior).

    // Add to history
    _history.add(snapshot);
    // Keep max 5 steps (user request)
    if (_history.length > 6) {
      // 1 current + 5 undo
      _history.removeAt(0);
    }
  }

  void _undo() {
    if (_history.length <= 1) return;

    // Remove current state
    _history.removeLast();
    // Get previous state
    final previous = _history.last;

    // Restore
    setState(() {
      // Must deep copy again to decouple from history
      _layout = previous
          .map(
            (e) => LayoutElement(
              id: e.id,
              key: e.key,
              label: e.label,
              elementType: e.elementType,
              isStatic: e.isStatic,
              repeat: e.repeat,
              x: e.x,
              y: e.y,
              width: e.width,
              height: e.height,
              fontSize: e.fontSize,
              fontWeight: e.fontWeight,
              italic: e.italic,
              underline: e.underline,
              alignment: e.alignment,
              vAlignment: e.vAlignment,
              color: e.color,
              fontFamily: e.fontFamily,
              backgroundColor: e.backgroundColor,
            ),
          )
          .toList();

      _selectedIds.clear(); // Clear selection on undo to avoid ghost selection
      _selectedElement = null;
    });
  }

  void _resetView() {
    _initialCanvasViewApplied = false;
    // Force re-schedule view
    // Triggering a rebuild will catch _scheduleInitialCanvasView logic in build
    setState(() {});
  }

  @override
  void dispose() {
    _fieldSearchController.dispose();
    _inlineEditController.dispose();
    _inlineEditFocusNode.dispose();
    _canvasFocusNode.dispose();
    super.dispose();
  }

  Size _getPaperSize() {
    Size size;
    switch (_paperSize) {
      case 'A4':
        size = const Size(210, 297);
        break;
      case 'A5':
        size = const Size(148, 210);
        break;
      case 'Continuous': // Sürekli Form
        size = const Size(240, 280);
        break;
      case 'Thermal80': // 80mm Termal
        size = const Size(80, 200);
        break;
      case 'Thermal58': // 58mm Termal
        size = const Size(58, 150);
        break;
      case 'Custom':
        size = Size(_customWidth, _customHeight);
        break;
      default:
        size = const Size(210, 297);
    }

    if (_isLandscape) {
      return Size(size.height, size.width);
    }
    return size;
  }

  void _deleteSelected() {
    if (_isInputFocused()) return;
    if (_selectedIds.isEmpty) return;
    if (_selectedIds.isNotEmpty) {
      if (_selectedIds.contains(_backgroundId)) {
        setState(() {
          _backgroundImage = null;
          _bgImageBytes = null;
          _selectedIds.remove(_backgroundId);
        });
        return;
      }

      final firstId = _selectedIds.first;
      final index = _layout.indexWhere((e) => e.id == firstId);
      if (index != -1) {
        _elementSil(_layout[index]);
        _saveToHistory(); // Save state
      }
    }
  }

  void _duplicateSelected() {
    if (_selectedElement == null) return;
    _duplicateElement(
      _selectedElement!,
      _selectedElement!.x + 5.0,
      _selectedElement!.y + 5.0,
    );
  }

  void _moveSelected(double dx, double dy) {
    if (_isInputFocused()) return;
    if (_selectedIds.isEmpty) return;
    final paperSize = _getPaperSize();

    setState(() {
      for (final id in _selectedIds) {
        if (id == _backgroundId) {
          _backgroundX += dx;
          _backgroundY += dy;
          continue;
        }

        final index = _layout.indexWhere((e) => e.id == id);
        if (index != -1) {
          final el = _layout[index];
          final x = (el.x + dx).clamp(0.0, paperSize.width - el.width);
          final y = (el.y + dy).clamp(0.0, paperSize.height - el.height);

          final updated = LayoutElement(
            id: el.id,
            key: el.key,
            label: el.label,
            elementType: el.elementType,
            isStatic: el.isStatic,
            repeat: el.repeat,
            x: x,
            y: y,
            width: el.width,
            height: el.height,
            fontSize: el.fontSize,
            fontWeight: el.fontWeight,
            alignment: el.alignment,
            vAlignment: el.vAlignment,
            italic: el.italic,
            underline: el.underline,
            color: el.color,
            fontFamily: el.fontFamily,
            backgroundColor: el.backgroundColor,
          );
          _layout[index] = updated;
          if (_selectedElement?.id == id) {
            _selectedElement = updated;
          }
        }
      }
    });
  }

  bool _isInputFocused() {
    final focus = FocusManager.instance.primaryFocus;
    final ctx = focus?.context;
    if (focus == null || ctx == null) return false;

    // Primary focus is often a Focus/FocusScope inside EditableText/TextField,
    // so checking only `ctx.widget is EditableText` is not reliable.
    if (ctx.widget is EditableText) return true;
    if (ctx.findAncestorWidgetOfExactType<EditableText>() != null) return true;
    if (ctx.findAncestorWidgetOfExactType<TextField>() != null) return true;
    if (ctx.findAncestorWidgetOfExactType<TextFormField>() != null) return true;

    final label = focus.debugLabel ?? '';
    return label.contains('EditableText') ||
        label.contains('TextField') ||
        label.contains('TextFormField');
  }

  double _getViewScale() {
    return _transformationController.value.getMaxScaleOnAxis();
  }

  Offset _getViewTranslation() {
    final t = _transformationController.value.getTranslation();
    return Offset(t.x, t.y);
  }

  void _setViewTransform({required double scale, required Offset translation}) {
    _transformationController.value = Matrix4.identity()
      ..translateByDouble(translation.dx, translation.dy, 0.0, 1.0)
      ..scaleByDouble(scale, scale, 1.0, 1.0);
  }

  void _panViewBy(Offset deltaViewportPx) {
    final scale = _getViewScale();
    final translation = _getViewTranslation() + deltaViewportPx;
    _setViewTransform(scale: scale, translation: translation);
  }

  void _zoomViewAt({
    required Offset focalPointViewport,
    required double scaleChange,
  }) {
    final oldScale = _getViewScale();
    final newScale = (oldScale * scaleChange).clamp(
      _minViewScale,
      _maxViewScale,
    );
    if ((newScale - oldScale).abs() < 0.0001) return;

    final scenePoint = _transformationController.toScene(focalPointViewport);
    final translation = Offset(
      focalPointViewport.dx - (scenePoint.dx * newScale),
      focalPointViewport.dy - (scenePoint.dy * newScale),
    );

    _setViewTransform(scale: newScale, translation: translation);
  }

  void _handleCanvasPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;

    final pressed = HardwareKeyboard.instance.logicalKeysPressed;
    final isAltPressed =
        pressed.contains(LogicalKeyboardKey.altLeft) ||
        pressed.contains(LogicalKeyboardKey.altRight) ||
        pressed.contains(LogicalKeyboardKey.alt);

    if (isAltPressed) {
      final delta = event.scrollDelta.dy != 0.0
          ? event.scrollDelta.dy
          : event.scrollDelta.dx;
      if (delta == 0.0) return;

      final scaleChange = math.exp(-delta / _mouseWheelScaleFactor);
      _zoomViewAt(
        focalPointViewport: event.localPosition,
        scaleChange: scaleChange,
      );
      return;
    }

    // Default: mouse wheel / trackpad scroll pans the view.
    _panViewBy(-event.scrollDelta);
  }

  Rect _marqueeRectScene() {
    final left = math.min(_marqueeStartScenePos.dx, _marqueeCurrentScenePos.dx);
    final top = math.min(_marqueeStartScenePos.dy, _marqueeCurrentScenePos.dy);
    final right = math.max(
      _marqueeStartScenePos.dx,
      _marqueeCurrentScenePos.dx,
    );
    final bottom = math.max(
      _marqueeStartScenePos.dy,
      _marqueeCurrentScenePos.dy,
    );
    return Rect.fromLTRB(left, top, right, bottom);
  }

  void _finishMarqueeSelection() {
    final rect = _marqueeRectScene();
    final hits = _layout.where((el) {
      final elRect = Rect.fromLTWH(
        el.x * _scale,
        el.y * _scale,
        el.width * _scale,
        el.height * _scale,
      );
      return rect.overlaps(elRect);
    }).toList();

    final merged = <String>[..._marqueeBaseSelection];
    for (final el in hits) {
      if (!merged.contains(el.id)) merged.add(el.id);
    }

    setState(() {
      _isMarqueeSelecting = false;
      _selectedIds
        ..clear()
        ..addAll(merged);

      if (_selectedIds.isEmpty) {
        _selectedElement = null;
        return;
      }

      final primaryId = hits.isNotEmpty ? hits.last.id : _selectedIds.last;
      final idx = _layout.indexWhere((e) => e.id == primaryId);
      _selectedElement = idx == -1 ? null : _layout[idx];
    });
  }

  Widget _buildMarqueeOverlay() {
    final rect = _marqueeRectScene();
    if (rect.isEmpty) return const SizedBox.shrink();

    return Positioned(
      left: rect.left,
      top: rect.top,
      width: rect.width,
      height: rect.height,
      child: IgnorePointer(
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF2C3E50).withValues(alpha: 0.12),
            border: Border.all(color: const Color(0xFF2C3E50), width: 1),
          ),
        ),
      ),
    );
  }

  Widget _buildSpacePanOverlay() {
    return MouseRegion(
      cursor: _isSpacePanning
          ? SystemMouseCursors.grabbing
          : SystemMouseCursors.grab,
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (event) {
          if ((event.buttons & 1) == 0) return;
          _canvasFocusNode.requestFocus();
          setState(() {
            _isSpacePanning = true;
            _spacePanStartViewportPos = event.localPosition;
            _spacePanStartTranslation = _getViewTranslation();
          });
        },
        onPointerMove: (event) {
          if (!_isSpacePanning) return;
          final delta = event.localPosition - _spacePanStartViewportPos;
          final scale = _getViewScale();
          final translation = _spacePanStartTranslation + delta;
          _setViewTransform(scale: scale, translation: translation);
        },
        onPointerUp: (_) {
          if (!_isSpacePanning) return;
          setState(() => _isSpacePanning = false);
        },
        onPointerCancel: (_) {
          if (!_isSpacePanning) return;
          setState(() => _isSpacePanning = false);
        },
      ),
    );
  }

  KeyEventResult _handleDesignerKeyEvent(FocusNode node, KeyEvent event) {
    // IMPORTANT: Don't steal keys from text inputs (backspace/delete/arrows/undo)
    // Otherwise users can't edit text in search/property fields.
    if (_isInputFocused()) return KeyEventResult.ignored;

    final isKeyDown = event is KeyDownEvent;
    final isRepeat = event is KeyRepeatEvent;
    final isKeyUp = event is KeyUpEvent;
    if (!isKeyDown && !isRepeat && !isKeyUp) return KeyEventResult.ignored;

    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.space) {
      if (isKeyDown && !_isSpacePressed) {
        setState(() => _isSpacePressed = true);
        return KeyEventResult.handled;
      }
      if (isKeyUp && _isSpacePressed) {
        setState(() {
          _isSpacePressed = false;
          _isSpacePanning = false;
        });
        return KeyEventResult.handled;
      }
      return KeyEventResult.handled;
    }

    if (isKeyUp) return KeyEventResult.ignored;
    if (_isSpacePressed) return KeyEventResult.ignored;

    final pressed = HardwareKeyboard.instance.logicalKeysPressed;

    final isShiftPressed =
        pressed.contains(LogicalKeyboardKey.shiftLeft) ||
        pressed.contains(LogicalKeyboardKey.shiftRight) ||
        pressed.contains(LogicalKeyboardKey.shift);
    final isAltPressed =
        pressed.contains(LogicalKeyboardKey.altLeft) ||
        pressed.contains(LogicalKeyboardKey.altRight) ||
        pressed.contains(LogicalKeyboardKey.alt);
    final isControlPressed =
        pressed.contains(LogicalKeyboardKey.controlLeft) ||
        pressed.contains(LogicalKeyboardKey.controlRight) ||
        pressed.contains(LogicalKeyboardKey.control);
    final isMetaPressed =
        pressed.contains(LogicalKeyboardKey.metaLeft) ||
        pressed.contains(LogicalKeyboardKey.metaRight) ||
        pressed.contains(LogicalKeyboardKey.meta);

    bool onlyModifiers({
      required bool shift,
      required bool alt,
      required bool control,
      required bool meta,
    }) {
      return isShiftPressed == shift &&
          isAltPressed == alt &&
          isControlPressed == control &&
          isMetaPressed == meta;
    }

    // Delete selected elements (no modifiers)
    if ((key == LogicalKeyboardKey.delete ||
            key == LogicalKeyboardKey.backspace) &&
        isKeyDown &&
        onlyModifiers(shift: false, alt: false, control: false, meta: false)) {
      _deleteSelected();
      return KeyEventResult.handled;
    }

    // Undo (Ctrl/Cmd + Z)
    if (key == LogicalKeyboardKey.keyZ && isKeyDown) {
      if (onlyModifiers(shift: false, alt: false, control: true, meta: false) ||
          onlyModifiers(shift: false, alt: false, control: false, meta: true)) {
        _undo();
        return KeyEventResult.handled;
      }
    }

    // Duplicate selected (Ctrl/Cmd + C)
    if (key == LogicalKeyboardKey.keyC && isKeyDown) {
      if (onlyModifiers(shift: false, alt: false, control: true, meta: false) ||
          onlyModifiers(shift: false, alt: false, control: false, meta: true)) {
        _duplicateSelected();
        return KeyEventResult.handled;
      }
    }

    // Move selected with arrows (repeat enabled)
    if (key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.arrowDown) {
      double? stepMm;
      if (onlyModifiers(
        shift: false,
        alt: false,
        control: false,
        meta: false,
      )) {
        stepMm = 1.0;
      } else if (onlyModifiers(
        shift: true,
        alt: false,
        control: false,
        meta: false,
      )) {
        stepMm = 5.0;
      } else if (onlyModifiers(
        shift: false,
        alt: true,
        control: false,
        meta: false,
      )) {
        stepMm = 0.1;
      } else if (onlyModifiers(
        shift: false,
        alt: false,
        control: true,
        meta: false,
      )) {
        stepMm = 0.1;
      }

      if (stepMm != null) {
        if (key == LogicalKeyboardKey.arrowLeft) {
          _moveSelected(-stepMm, 0.0);
        } else if (key == LogicalKeyboardKey.arrowRight) {
          _moveSelected(stepMm, 0.0);
        } else if (key == LogicalKeyboardKey.arrowUp) {
          _moveSelected(0.0, -stepMm);
        } else if (key == LogicalKeyboardKey.arrowDown) {
          _moveSelected(0.0, stepMm);
        }
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final paperSizeMm = _getPaperSize();
    final canvasSize = Size(
      paperSizeMm.width * _scale,
      paperSizeMm.height * _scale,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFE2E8F0),
      appBar: AppBar(
        title: Text(_name),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (widget.sablon == null)
            ElevatedButton.icon(
              onPressed: () => _kaydet(isNewCopy: false),
              icon: const Icon(Icons.save_rounded, size: 18),
              label: Text(
                tr('common.save'),
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEA4335),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
            )
          else ...[
            // [2026 FEATURE] Lock & Fit Controls
            Tooltip(
              message: tr('print.designer.fit_to_screen'),
              child: IconButton(
                onPressed: _resetView,
                icon: const Icon(
                  Icons.aspect_ratio_rounded,
                  color: Color(0xFF2C3E50),
                  size: 20,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Row(
              children: [
                Checkbox(
                  value: _isLocked,
                  activeColor: const Color(0xFF2C3E50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                  onChanged: (val) {
                    setState(() {
                      _isLocked = val ?? false;
                      // Clear selection when locking to prevent accidental edits
                      if (_isLocked) {
                        _selectedIds.clear();
                        _selectedElement = null;
                      }
                    });
                  },
                ),
                Text(
                  tr('common.lock'),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2C3E50),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 16),
            OutlinedButton.icon(
              onPressed: () => _kaydet(isNewCopy: true),
              icon: const Icon(Icons.copy_rounded, size: 18),
              label: Text(
                tr('common.save_as'),
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF2C3E50),
                side: const BorderSide(color: Color(0xFF2C3E50)),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: () => _kaydet(isNewCopy: false),
              icon: const Icon(Icons.check_circle_rounded, size: 18),
              label: Text(
                tr('common.update'),
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEA4335),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
            ),
          ],
          const SizedBox(width: 16),
        ],
      ),
      body: Row(
        children: [
          _buildSidebarElements(),
          Expanded(child: _buildCanvas(canvasSize)),
          _buildPropertiesPanel(),
        ],
      ),
    );
  }

  List<YazdirmaAlanTanim> get _availableFields {
    final all = YazdirmaAlanlari.tumAlanlar;
    final q = _normalizeForSearch(_fieldSearchQuery);
    if (q.isEmpty) return all;

    final matches = all.where((f) => _fieldMatchesQuery(f, q)).toList();
    matches.sort((a, b) {
      final ra = _fieldMatchRank(a, q);
      final rb = _fieldMatchRank(b, q);
      if (ra != rb) return ra.compareTo(rb);
      return _fieldLabelForUi(a).compareTo(_fieldLabelForUi(b));
    });
    return matches;
  }

  IconData _getIconForField(YazdirmaAlanTanim field) {
    // 1. Tip Kontrolü
    if (field.type == YazdirmaAlanTipi.image) return Icons.image_rounded;
    if (field.type == YazdirmaAlanTipi.line) {
      return Icons.horizontal_rule_rounded;
    }

    // 2. Anahtar Kelime Kontrolü (Özel durumlar)
    final k = field.key;
    if (k == YazdirmaAlanlari.staticTextKey) {
      return Icons.text_fields_rounded;
    }
    if (k.contains('page_no')) return Icons.format_list_numbered_rounded;
    if (k.contains('date')) return Icons.calendar_today_rounded;
    if (k.contains('time')) return Icons.schedule_rounded;

    // 3. Kategori Bazlı Kontrol
    // Satıcı
    if (k.startsWith('seller_')) {
      if (k.contains('phone')) return Icons.phone_rounded;
      if (k.contains('email')) return Icons.email_rounded;
      if (k.contains('web')) return Icons.language_rounded;
      return Icons.store_rounded;
    }

    // Cari / Müşteri
    if (k.startsWith('customer_')) {
      if (k.contains('phone')) return Icons.phone_android_rounded;
      if (k.contains('email')) return Icons.alternate_email_rounded;
      if (k.contains('web')) return Icons.public_rounded;
      if (k.contains('address')) return Icons.place_rounded;
      return Icons.person_rounded;
    }

    // Belge
    if (k.startsWith('invoice_') ||
        k.startsWith('dispatch_') ||
        k.startsWith('order_')) {
      return Icons.receipt_long_rounded;
    }

    // Ürün Satırları & Tablo
    if (k.startsWith('item_')) {
      if (k.contains('price') || k.contains('total')) {
        return Icons.attach_money_rounded;
      }
      if (k.contains('quantity')) return Icons.shopping_basket_rounded;
      if (k.contains('discount')) return Icons.percent_rounded;
      return Icons.local_offer_rounded;
    }
    if (k.contains('table')) return Icons.table_chart_rounded;

    // Toplamlar & Vergiler
    if (k.contains('total') || k.contains('amount') || k.contains('base')) {
      if (k.contains('vat') || k.contains('otv') || k.contains('oiv')) {
        return Icons.percent_rounded;
      }
      return Icons.calculate_rounded;
    }
    if (k.contains('tax')) return Icons.account_balance_rounded;

    // Lojistik / Sevkiyat
    if (k.contains('vehicle') || k.contains('driver')) {
      return Icons.local_shipping_rounded;
    }
    if (k.contains('delivery') || k.contains('received')) {
      return Icons.assignment_turned_in_rounded;
    }

    // Ödeme
    if (k.contains('payment') ||
        k.contains('cash') ||
        k.contains('card') ||
        k.contains('change')) {
      return Icons.payments_rounded;
    }

    // Varsayılan
    return Icons.short_text_rounded;
  }

  String _fieldLabelForUi(YazdirmaAlanTanim field) {
    return field.label.replaceAll(' (Üst)', '').replaceAll(' (Alt)', '');
  }

  String _normalizeForSearch(String input) {
    final lower = input.toLowerCase().trim();
    return lower
        // Turkish uppercase İ lowercases to "i̇" (i + combining dot). Normalize.
        .replaceAll('\u{0307}', '')
        .replaceAll('ç', 'c')
        .replaceAll('ğ', 'g')
        .replaceAll('ı', 'i')
        .replaceAll('ö', 'o')
        .replaceAll('ş', 's')
        .replaceAll('ü', 'u');
  }

  bool _fieldMatchesQuery(YazdirmaAlanTanim field, String q) {
    final label = _normalizeForSearch(field.label);
    final labelUi = _normalizeForSearch(_fieldLabelForUi(field));
    final key = _normalizeForSearch(field.key);
    return label.contains(q) || labelUi.contains(q) || key.contains(q);
  }

  int _fieldMatchRank(YazdirmaAlanTanim field, String q) {
    final label = _normalizeForSearch(_fieldLabelForUi(field));
    final key = _normalizeForSearch(field.key);
    if (key == q || label == q) return 0;
    if (key.startsWith(q) || label.startsWith(q)) return 1;
    if (label.contains(q)) return 2;
    return 3;
  }

  Widget _buildSidebarElements() {
    final allElements = _availableFields;

    // Gruplandırma Mantığı
    final Map<String, List<YazdirmaAlanTanim>> groups = {
      'common.general': [],
      'print.designer.group.company': [],
      'print.designer.group.customer': [],
      'print.designer.group.document': [],
      'print.designer.group.items': [],
      'print.designer.group.totals': [],
      'print.designer.group.logistics_payment': [],
    };

    for (final el in allElements) {
      final k = el.key;
      if (k == YazdirmaAlanlari.staticTextKey ||
          k == 'horizontal_line' ||
          k == 'page_no') {
        groups['common.general']!.add(el);
      } else if (k.startsWith('seller_') ||
          k == 'bank_info' ||
          k.startsWith('header_')) {
        groups['print.designer.group.company']!.add(el);
      } else if (k.startsWith('customer_') ||
          k == 'tax_office' ||
          k == 'tax_no') {
        groups['print.designer.group.customer']!.add(el);
      } else if (k.startsWith('invoice_') ||
          k.startsWith('dispatch_') ||
          k.startsWith('order_') ||
          k.startsWith('description') ||
          k == 'date' ||
          k == 'time' ||
          k == 'note' ||
          k.startsWith('serial_') ||
          k.startsWith('sequence_') ||
          k.startsWith('created_') ||
          k.startsWith('due_') ||
          k.startsWith('validity_') ||
          k.startsWith('actual_')) {
        groups['print.designer.group.document']!.add(el);
      } else if (k.startsWith('item_') || k.startsWith('items_table')) {
        groups['print.designer.group.items']!.add(el);
      } else if (k.contains('total') ||
          k.contains('amount') ||
          k.contains('base') ||
          k.contains('tax') ||
          k.contains('vat_') ||
          k.contains('otv_') ||
          k.contains('oiv_') ||
          k.contains('currency') ||
          k.contains('exchange') ||
          k.contains('rounding')) {
        groups['print.designer.group.totals']!.add(el);
      } else {
        groups['print.designer.group.logistics_payment']!.add(el);
      }
    }

    return Container(
      width: 320, // Biraz daraltalım
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ARAMA VE ÜST KISIM (Sabit)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr('print.designer.data_fields'),
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  tr('print.designer.drag_drop_hint'),
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _fieldSearchController,
                  style: const TextStyle(fontSize: 12),
                  decoration: InputDecoration(
                    hintText: tr('print.designer.quick_search'),
                    prefixIcon: const Icon(Icons.search_rounded, size: 18),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          // SCROLL ALANI
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  // HIZLI ARAÇLAR (Daha kompakt)
                  _buildCompactToolBar(),
                  const SizedBox(height: 16),

                  // GRUPLAR
                  ...groups.entries.map((entry) {
                    if (entry.value.isEmpty) return const SizedBox.shrink();
                    return _buildFieldGroup(tr(entry.key), entry.value);
                  }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactToolBar() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildMiniToolButton(
                tr('print.designer.tool.paper'),
                Icons.straighten_rounded,
                _kagitAyarlariniGoster,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _buildMiniToolButton(
                tr('print.designer.tool.template_image'),
                Icons.image_search_rounded,
                _resimYukle,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: _buildMiniToolButton(
                tr('print.designer.tool.text'),
                Icons.title_rounded,
                _addStaticHeading,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _buildMiniToolButton(
                tr('print.designer.tool.line'),
                Icons.horizontal_rule_rounded,
                _addStaticLine,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMiniToolButton(
    String label,
    IconData icon,
    VoidCallback onPressed,
  ) {
    return SizedBox(
      height: 34,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 14),
        label: Text(
          label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF475569),
          side: const BorderSide(color: Color(0xFFE2E8F0)),
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          backgroundColor: const Color(0xFFF8FAFC),
        ),
      ),
    );
  }

  Widget _buildFieldGroup(String title, List<YazdirmaAlanTanim> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Row(
            children: [
              Container(
                width: 3,
                height: 14,
                decoration: BoxDecoration(
                  color: const Color(0xFF2C3E50),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                title.toUpperCase(),
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF64748B),
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 1.1,
            crossAxisSpacing: 6,
            mainAxisSpacing: 6,
          ),
          itemBuilder: (context, index) {
            final el = items[index];
            final label = _fieldLabelForUi(el);
            final icon = _getIconForField(el);

            return Draggable<String>(
              data: el.key,
              feedback: _buildDraggableFeedback(label),
              child: MouseRegion(cursor: SystemMouseCursors.click, hitTestBehavior: HitTestBehavior.deferToChild, child: GestureDetector(
                onDoubleTap: () => _addElement(el.key),
                child: MouseRegion(
                  cursor: SystemMouseCursors.grab,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(icon, size: 16, color: const Color(0xFF2C3E50)),
                        const SizedBox(height: 6),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            label,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF334155),
                              height: 1.1,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.visible, // Kesilmesin
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )),
            );
          },
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildDraggableFeedback(String label) {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF2C3E50).withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(4),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 10,
            ),
          ],
        ),
        child: Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
      ),
    );
  }

  void _scheduleInitialCanvasView({
    required Size viewportSizePx,
    required Size canvasSizePx,
  }) {
    if (_initialCanvasViewApplied || _initialCanvasViewScheduled) return;
    if (viewportSizePx.width <= 0 || viewportSizePx.height <= 0) return;

    _initialCanvasViewScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _initialCanvasViewApplied) return;

      // Eğer kaydedilmiş bir görünüm varsa onu yükle
      if (widget.sablon?.viewMatrix != null &&
          widget.sablon!.viewMatrix!.isNotEmpty) {
        try {
          final List<double> matrixList = widget.sablon!.viewMatrix!
              .split(',')
              .map((e) => double.parse(e))
              .toList();
          if (matrixList.length == 16) {
            _transformationController.value = Matrix4.fromList(matrixList);
            _initialCanvasViewApplied = true;
            _initialCanvasViewScheduled = false;
            return;
          }
        } catch (e) {
          debugPrint('ViewMatrix yükleme hatası: $e');
        }
      }

      // Kaydedilmiş görünüm yoksa veya hatalıysa, kağıdı ORTALAYARAK aç (Yeni Şablon Mantığı)
      final paperCenterPx = Offset(
        canvasSizePx.width / 2,
        canvasSizePx.height / 2,
      );

      final availableW = (viewportSizePx.width - (_canvasFitPaddingPx * 2))
          .clamp(0.0, double.infinity);
      final availableH = (viewportSizePx.height - (_canvasFitPaddingPx * 2))
          .clamp(0.0, double.infinity);

      final scaleX = availableW / canvasSizePx.width;
      final scaleY = availableH / canvasSizePx.height;
      // Kağıdı tam görecek şekilde ölçekle
      final initialScale = math
          .min(scaleX, scaleY)
          .clamp(_minViewScale, _maxViewScale);

      final viewportCenterPx = Offset(
        viewportSizePx.width / 2,
        viewportSizePx.height / 2,
      );

      final translationPx = viewportCenterPx - (paperCenterPx * initialScale);

      _transformationController.value = Matrix4.identity()
        ..translateByDouble(translationPx.dx, translationPx.dy, 0.0, 1.0)
        ..scaleByDouble(initialScale, initialScale, 1.0, 1.0);

      _initialCanvasViewApplied = true;
      _initialCanvasViewScheduled = false;
    });
  }

  Widget _buildCanvas(Size canvasSize) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _scheduleInitialCanvasView(
          viewportSizePx: constraints.biggest,
          canvasSizePx: canvasSize,
        );

        return Container(
          color: const Color(0xFFE2E8F0), // Workspace background
          child: Focus(
            focusNode: _canvasFocusNode,
            autofocus: true,
            onKeyEvent: _handleDesignerKeyEvent,
            onFocusChange: (hasFocus) {
              if (!mounted || hasFocus) return;
              if (!_isSpacePressed &&
                  !_isSpacePanning &&
                  !_isMarqueeSelecting) {
                return;
              }
              setState(() {
                _isSpacePressed = false;
                _isSpacePanning = false;
                _isMarqueeSelecting = false;
              });
            },
            child: Listener(
              onPointerSignal: _handleCanvasPointerSignal,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  InteractiveViewer(
                    transformationController: _transformationController,
                    boundaryMargin: const EdgeInsets.all(1000),
                    minScale: _minViewScale,
                    maxScale: _maxViewScale,
                    constrained: false,
                    panEnabled: false,
                    scaleEnabled: false,
                    child: DragTarget<String>(
                      onAcceptWithDetails: (details) {
                        // Converts global screen coordinates to the paper's local pixel coordinates
                        final Offset localPosPx = _transformationController
                            .toScene(details.offset);

                        // Convert pixel coordinates to mm for the LayoutElement
                        final double xMm = localPosPx.dx / _scale;
                        final double yMm = localPosPx.dy / _scale;

                        _addElement(
                          details.data,
                          xMm.clamp(0, (canvasSize.width / _scale) - 10),
                          yMm.clamp(0, (canvasSize.height / _scale) - 5),
                        );
                      },
                      builder: (context, candidateData, rejectedData) {
                        final bgW = _backgroundWidth != null
                            ? _backgroundWidth! * _scale
                            : canvasSize.width;
                        final bgH = _backgroundHeight != null
                            ? _backgroundHeight! * _scale
                            : canvasSize.height;
                        final paddedBgW =
                            bgW + (_backgroundOverlayPaddingPx * 2);
                        final paddedBgH =
                            bgH + (_backgroundOverlayPaddingPx * 2);

                        return Container(
                          width: canvasSize.width,
                          height: canvasSize.height,
                          color: Colors.white,
                          child: Stack(
                            key: _canvasKey,
                            clipBehavior: Clip.none,
                            children: [
                              // White Paper Base + Marquee Selection
                              Positioned.fill(
                                child: MouseRegion(cursor: SystemMouseCursors.click, hitTestBehavior: HitTestBehavior.deferToChild, child: GestureDetector(
                                  onTap: () {
                                    _canvasFocusNode.requestFocus();
                                    setState(() {
                                      _selectedIds.clear();
                                      _selectedElement = null;
                                    });
                                  },
                                  onPanStart: (details) {
                                    if (_isLocked) return;
                                    if (_isSpacePressed) return;
                                    _canvasFocusNode.requestFocus();

                                    final keys = HardwareKeyboard
                                        .instance
                                        .logicalKeysPressed;
                                    final isAdditive =
                                        keys.contains(
                                          LogicalKeyboardKey.metaLeft,
                                        ) ||
                                        keys.contains(
                                          LogicalKeyboardKey.metaRight,
                                        ) ||
                                        keys.contains(
                                          LogicalKeyboardKey.controlLeft,
                                        ) ||
                                        keys.contains(
                                          LogicalKeyboardKey.controlRight,
                                        );

                                    setState(() {
                                      _isMarqueeSelecting = true;
                                      _marqueeStartScenePos =
                                          details.localPosition;
                                      _marqueeCurrentScenePos =
                                          details.localPosition;
                                      _marqueeBaseSelection = isAdditive
                                          ? List<String>.from(
                                              _selectedIds.where(
                                                (id) => id != _backgroundId,
                                              ),
                                            )
                                          : const [];
                                      if (!isAdditive) {
                                        _selectedIds.clear();
                                        _selectedElement = null;
                                      }
                                    });
                                  },
                                  onPanUpdate: (details) {
                                    if (!_isMarqueeSelecting) return;
                                    setState(() {
                                      _marqueeCurrentScenePos =
                                          details.localPosition;
                                    });
                                  },
                                  onPanEnd: (_) {
                                    if (!_isMarqueeSelecting) return;
                                    _finishMarqueeSelection();
                                  },
                                  onPanCancel: () {
                                    if (!_isMarqueeSelecting) return;
                                    setState(() => _isMarqueeSelecting = false);
                                  },
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(
                                            alpha: 0.1,
                                          ),
                                          blurRadius: 30,
                                          offset: const Offset(0, 15),
                                        ),
                                      ],
                                    ),
                                  ),
                                )),
                              ),
                              // 1. Background Image Layer
                              if (_backgroundImage != null)
                                Positioned(
                                  left:
                                      (_backgroundX * _scale) -
                                      _backgroundOverlayPaddingPx,
                                  top:
                                      (_backgroundY * _scale) -
                                      _backgroundOverlayPaddingPx,
                                  child: MouseRegion(cursor: SystemMouseCursors.click, hitTestBehavior: HitTestBehavior.deferToChild, child: GestureDetector(
                                    onTap: () {
                                      _canvasFocusNode.requestFocus();
                                      setState(() {
                                        _selectedIds.clear();
                                        _selectedIds.add(_backgroundId);
                                        _selectedElement =
                                            null; // Background is not a LayoutElement
                                      });
                                    },
                                    onPanStart: (details) {
                                      if (_isLocked) return;
                                      if (_isSpacePressed) return;
                                      _canvasFocusNode.requestFocus();

                                      final keys = HardwareKeyboard
                                          .instance
                                          .logicalKeysPressed;
                                      final isAdditive =
                                          keys.contains(
                                            LogicalKeyboardKey.metaLeft,
                                          ) ||
                                          keys.contains(
                                            LogicalKeyboardKey.metaRight,
                                          ) ||
                                          keys.contains(
                                            LogicalKeyboardKey.controlLeft,
                                          ) ||
                                          keys.contains(
                                            LogicalKeyboardKey.controlRight,
                                          );

                                      final bgLeft =
                                          (_backgroundX * _scale) -
                                          _backgroundOverlayPaddingPx;
                                      final bgTop =
                                          (_backgroundY * _scale) -
                                          _backgroundOverlayPaddingPx;
                                      final pos =
                                          details.localPosition +
                                          Offset(bgLeft, bgTop);

                                      setState(() {
                                        _isMarqueeSelecting = true;
                                        _marqueeStartScenePos = pos;
                                        _marqueeCurrentScenePos = pos;
                                        _marqueeBaseSelection = isAdditive
                                            ? List<String>.from(
                                                _selectedIds.where(
                                                  (id) => id != _backgroundId,
                                                ),
                                              )
                                            : const [];
                                        if (!isAdditive) {
                                          _selectedIds.clear();
                                          _selectedElement = null;
                                        }
                                      });
                                    },
                                    onPanUpdate: (details) {
                                      if (!_isMarqueeSelecting) return;
                                      final bgLeft =
                                          (_backgroundX * _scale) -
                                          _backgroundOverlayPaddingPx;
                                      final bgTop =
                                          (_backgroundY * _scale) -
                                          _backgroundOverlayPaddingPx;
                                      final pos =
                                          details.localPosition +
                                          Offset(bgLeft, bgTop);
                                      setState(() {
                                        _marqueeCurrentScenePos = pos;
                                      });
                                    },
                                    onPanEnd: (_) {
                                      if (!_isMarqueeSelecting) return;
                                      _finishMarqueeSelection();
                                    },
                                    onPanCancel: () {
                                      if (!_isMarqueeSelecting) return;
                                      setState(
                                        () => _isMarqueeSelecting = false,
                                      );
                                    },
                                    child: SizedBox(
                                      width: paddedBgW,
                                      height: paddedBgH,
                                      child: Stack(
                                        clipBehavior: Clip.none,
                                        children: [
                                          Positioned(
                                            left: _backgroundOverlayPaddingPx,
                                            top: _backgroundOverlayPaddingPx,
                                            child: Container(
                                              decoration: BoxDecoration(
                                                border:
                                                    _selectedIds.contains(
                                                      _backgroundId,
                                                    )
                                                    ? Border.all(
                                                        color: Colors.purple,
                                                        width: 2,
                                                      )
                                                    : null,
                                              ),
                                              child: RepaintBoundary(
                                                child: Opacity(
                                                  opacity: _backgroundOpacity,
                                                  child: _bgImageBytes != null
                                                      ? Image.memory(
                                                          _bgImageBytes!,
                                                          width: bgW,
                                                          height: bgH,
                                                          fit: BoxFit.fill,
                                                          gaplessPlayback: true,
                                                        )
                                                      : const SizedBox.shrink(),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )),
                                ),
                              // 2. Element Layers
                              ..._layout.map((el) {
                                return _buildPositionedElement(el, 0, 0);
                              }),
                              if (_isMarqueeSelecting) _buildMarqueeOverlay(),
                              // 3. Control Layers (Handles on TOP of everything)
                              ..._layout
                                  .where(
                                    (el) =>
                                        _selectedIds.contains(el.id) &&
                                        _selectedElement?.id == el.id,
                                  )
                                  .expand((el) {
                                    return [
                                      _buildResizeHandle(el, 0, 0),
                                      _buildDeleteHandle(el, 0, 0),
                                    ];
                                  }),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  if (_isSpacePressed)
                    Positioned.fill(child: _buildSpacePanOverlay()),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildResizeHandle(LayoutElement el, double offsetX, double offsetY) {
    if (_isLocked) return const SizedBox.shrink(); // Hide handles when locked
    return Positioned(
      // [2026 FIX] Add Keys to control handles
      key: ValueKey('resize_${el.id}'),
      // [2026 FIX] Smaller handles and adjusted offsets
      left:
          offsetX +
          (el.x * _scale) +
          (el.width * _scale) -
          8, // Adjusted for 16px size
      top: offsetY + (el.y * _scale) + (el.height * _scale) - 8,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (details) {
            setState(() {
              _dragStartScenePos = _transformationController.toScene(
                details.globalPosition,
              );
              _elementStartWidth = el.width;
              _elementStartHeight = el.height;
            });
          },
          onPanUpdate: (details) {
            final currentScenePos = _transformationController.toScene(
              details.globalPosition,
            );

            // Calculate total growth in pixels, then convert to scene units (mm)
            final dw = (currentScenePos.dx - _dragStartScenePos.dx) / _scale;
            final dh = (currentScenePos.dy - _dragStartScenePos.dy) / _scale;

            final w = (_elementStartWidth + dw).clamp(5.0, 500.0);
            final h = (_elementStartHeight + dh).clamp(5.0, 500.0);
            _updateElementSize(el, w, h);
          },
          child: Container(
            width: 16, // Reduced from 20
            height: 16,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: Colors.transparent),
            child: Container(
              width: 12, // Reduced from 14
              height: 12,
              decoration: const BoxDecoration(
                color: Color(0xFF2C3E50),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.open_in_full_rounded,
                size: 8, // Reduced from 9
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDeleteHandle(LayoutElement el, double offsetX, double offsetY) {
    if (_isLocked) return const SizedBox.shrink(); // Hide handles when locked
    return Positioned(
      // [2026 FIX] Add Keys to control handles
      key: ValueKey('delete_${el.id}'),
      // [2026 FIX] Smaller handles and adjusted offsets
      left: offsetX + (el.x * _scale) + (el.width * _scale) - 8, // Adjusted
      top: offsetY + (el.y * _scale) - 8,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: MouseRegion(cursor: SystemMouseCursors.click, hitTestBehavior: HitTestBehavior.deferToChild, child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _elementSil(el),
          child: Container(
            width: 16, // Reduced from 20
            height: 16,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: Colors.transparent),
            child: Container(
              width: 12, // Reduced from 14
              height: 12,
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.9),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: const Icon(
                Icons.close_rounded,
                size: 8, // Reduced from 9
                color: Colors.white,
              ),
            ),
          ),
        )),
      ),
    );
  }

  Widget _buildPositionedElement(
    LayoutElement el,
    double offsetX,
    double offsetY,
  ) {
    final isSelected = _selectedIds.contains(el.id);
    final isPrimary = _selectedElement?.id == el.id;

    return Positioned(
      // [2026 FIX] Key is CRITICAL for correct Stack rendering (prevents ghosting)
      key: ValueKey(el.id),
      left: offsetX + (el.x * _scale),
      top: offsetY + (el.y * _scale),
      child: MouseRegion(cursor: SystemMouseCursors.click, hitTestBehavior: HitTestBehavior.deferToChild, child: GestureDetector(
        onDoubleTap: () {
          if (_isLocked) return; // Protected
          if (el.isStatic) {
            setState(() {
              _editingElementId = el.id;
              _inlineEditController.text = el.label;
            });
            _inlineEditFocusNode.requestFocus();
          }
        },
        onTap: () {
          _canvasFocusNode.requestFocus();
          final isMultiSelect =
              HardwareKeyboard.instance.logicalKeysPressed.contains(
                LogicalKeyboardKey.metaLeft,
              ) ||
              HardwareKeyboard.instance.logicalKeysPressed.contains(
                LogicalKeyboardKey.metaRight,
              ) ||
              HardwareKeyboard.instance.logicalKeysPressed.contains(
                LogicalKeyboardKey.controlLeft,
              ) ||
              HardwareKeyboard.instance.logicalKeysPressed.contains(
                LogicalKeyboardKey.controlRight,
              );

          setState(() {
            if (isMultiSelect) {
              if (_selectedIds.contains(el.id)) {
                _selectedIds.remove(el.id);
                if (_selectedElement?.id == el.id) {
                  _selectedElement = _selectedIds.isNotEmpty
                      ? _layout.firstWhere((e) => e.id == _selectedIds.last)
                      : null;
                }
              } else {
                _selectedIds.add(el.id);
                _selectedElement = el;
              }
            } else {
              _selectedIds.clear();
              _selectedIds.add(el.id);
              _selectedElement = el;
            }
          });
        },
        onPanStart: (details) {
          if (_isLocked) return; // Protected
          _canvasFocusNode.requestFocus();
          setState(() {
            _isDraggingElement = true;
            final isAltPressed =
                HardwareKeyboard.instance.logicalKeysPressed.contains(
                  LogicalKeyboardKey.altLeft,
                ) ||
                HardwareKeyboard.instance.logicalKeysPressed.contains(
                  LogicalKeyboardKey.altRight,
                );

            _isDuplicating = isAltPressed;

            // Record the initial scene position of the pointer
            _dragStartScenePos = _transformationController.toScene(
              details.globalPosition,
            );
            // Record where the element was at the start
            _elementStartPosX = el.x;
            _elementStartPosY = el.y;

            if (_isDuplicating) {
              // [2026 FIX] updateState: false to avoid conflict within setState
              _duplicateElement(el, el.x, el.y, updateState: false);
            }
          });
        },
        onPanUpdate: (details) {
          if (_isLocked) return; // Protected
          if (!isPrimary && !isSelected) {
            setState(() {
              _selectedIds.clear();
              _selectedIds.add(el.id);
              _selectedElement = el;
            });
          }
          final paperSize = _getPaperSize();
          // Current pointer position in scene (in pixels)
          final currentScenePos = _transformationController.toScene(
            details.globalPosition,
          );

          // Calculate movement in pixels, then convert to mm
          final dx = (currentScenePos.dx - _dragStartScenePos.dx) / _scale;
          final dy = (currentScenePos.dy - _dragStartScenePos.dy) / _scale;

          // New position based on initial position (mm) + total delta (mm)
          final x = (_elementStartPosX + dx).clamp(
            0.0,
            paperSize.width - el.width,
          );
          final y = (_elementStartPosY + dy).clamp(
            0.0,
            paperSize.height - el.height,
          );

          final isAltPressed =
              HardwareKeyboard.instance.logicalKeysPressed.contains(
                LogicalKeyboardKey.altLeft,
              ) ||
              HardwareKeyboard.instance.logicalKeysPressed.contains(
                LogicalKeyboardKey.altRight,
              );

          if (isAltPressed) {
            if (!_isDuplicating) {
              setState(() {
                _isDuplicating = true;
                // 1. Keep the ORIGINAL at its start (atomic update)
                _updateElementPosition(
                  el,
                  _elementStartPosX,
                  _elementStartPosY,
                  updateState: false,
                );
                // 2. Create a DUPLICATE at the current ghost position (atomic update)
                _duplicateElement(el, x, y, updateState: false);
              });
            } else if (_selectedElement != null) {
              // We already duplicated for this drag, move the NEW one
              _updateElementPosition(_selectedElement!, x, y);
            }
          } else {
            // Normal drag or Alt was NOT pressed (or released during drag)
            if (_isDuplicating && _selectedElement != null) {
              _updateElementPosition(_selectedElement!, x, y);
            } else {
              _updateElementPosition(el, x, y);
            }
          }
        },
        onPanEnd: (_) {
          setState(() {
            _isDraggingElement = false;
            _isDuplicating = false;
          });
        },
        onPanCancel: () {
          setState(() {
            _isDraggingElement = false;
          });
        },
        child: MouseRegion(
          cursor: _isDraggingElement && isPrimary
              ? SystemMouseCursors.grabbing
              : SystemMouseCursors.grab,
          child: Container(
            width: el.width * _scale,
            height: el.height * _scale,
            decoration: BoxDecoration(
              border: Border.all(
                color: isPrimary
                    ? Colors
                          .black // [2026 FIX] Black border for primary selection
                    : (isSelected
                          ? Colors.black.withValues(
                              alpha: 0.5,
                            ) // Black border for secondary selection
                          : Colors.black12),
                width: isSelected ? 1 : 0.5, // [2026 FIX] Thinner border (1.0)
              ),
              color: isSelected
                  ? const Color(0xFF2C3E50).withValues(alpha: 0.1)
                  : Colors.white.withValues(alpha: 0.4),
            ),
            alignment: _getAlignment(el.alignment, el.vAlignment),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Align(
                  alignment: _getAlignment(el.alignment, el.vAlignment),
                  child: _buildElementPreview(el),
                ),
              ],
            ),
          ),
        ),
      )),
    );
  }

  Widget _buildElementPreview(LayoutElement el) {
    final Color color = el.color != null
        ? Color(int.parse(el.color!.replaceFirst('#', '0xFF')))
        : Colors.black;

    if (el.elementType == 'line') {
      return Center(
        child: Container(
          height: 1,
          width: double.infinity,
          color: color.withValues(alpha: 0.8),
        ),
      );
    }

    if (el.elementType == 'image') {
      return Center(
        child: Icon(
          Icons.image_rounded,
          size: 18,
          color: color.withValues(alpha: 0.8),
        ),
      );
    }

    final bgColor = el.backgroundColor != null
        ? Color(int.parse(el.backgroundColor!.replaceFirst('#', '0xFF')))
        : null;

    final isEditing = _editingElementId == el.id;
    if (isEditing) {
      return Container(
        color: bgColor ?? Colors.white.withValues(alpha: 0.8),
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: TextField(
          controller: _inlineEditController,
          focusNode: _inlineEditFocusNode,
          autofocus: true,
          style: TextStyle(
            fontSize: (double.tryParse(el.fontSize) ?? 12) * (_scale / 3.8),
            fontWeight: _fontWeights[el.fontWeight] ?? FontWeight.normal,
            fontStyle: el.italic ? FontStyle.italic : FontStyle.normal,
            decoration: el.underline
                ? TextDecoration.underline
                : TextDecoration.none,
            color: color,
            fontFamily: el.fontFamily,
          ),
          decoration: const InputDecoration(
            isDense: true,
            contentPadding: EdgeInsets.zero,
            border: InputBorder.none,
          ),
          textAlign: _getTextAlign(el.alignment),
          onSubmitted: (value) {
            _updateSelected(label: value);
            setState(() {
              _editingElementId = null;
            });
            _canvasFocusNode.requestFocus();
          },
          onTapOutside: (_) {
            _updateSelected(label: _inlineEditController.text);
            setState(() {
              _editingElementId = null;
            });
            _canvasFocusNode.requestFocus();
          },
        ),
      );
    }

    return Container(
      color: bgColor,
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
      child: Text(
        el.label,
        style: TextStyle(
          fontSize: (double.tryParse(el.fontSize) ?? 12) * (_scale / 3.8),
          fontWeight: _fontWeights[el.fontWeight] ?? FontWeight.normal,
          fontStyle: el.italic ? FontStyle.italic : FontStyle.normal,
          decoration: el.underline
              ? TextDecoration.underline
              : TextDecoration.none,
          color: color,
          fontFamily: el.fontFamily,
        ),
        textAlign: _getTextAlign(el.alignment),
        maxLines: 1,
        overflow: TextOverflow.visible,
      ),
    );
  }

  void _updateElementPosition(
    LayoutElement el,
    double x,
    double y, {
    bool updateState = true,
  }) {
    final index = _layout.indexWhere((e) => e.id == el.id);
    if (index != -1) {
      void apply() {
        final updated = LayoutElement(
          id: el.id,
          key: el.key,
          label: el.label,
          elementType: el.elementType,
          isStatic: el.isStatic,
          repeat: el.repeat,
          x: x,
          y: y,
          width: el.width,
          height: el.height,
          fontSize: el.fontSize,
          fontWeight: el.fontWeight,
          italic: el.italic,
          underline: el.underline,
          alignment: el.alignment,
          vAlignment: el.vAlignment,
          color: el.color,
          fontFamily: el.fontFamily,
          backgroundColor: el.backgroundColor,
        );
        _layout[index] = updated;
        _selectedElement = updated;
      }

      if (updateState) {
        setState(apply);
      } else {
        apply();
      }
    }
  }

  void _updateElementSize(LayoutElement el, double w, double h) {
    final index = _layout.indexWhere((e) => e.id == el.id);
    if (index != -1) {
      setState(() {
        final updated = LayoutElement(
          id: el.id,
          key: el.key,
          label: el.label,
          elementType: el.elementType,
          isStatic: el.isStatic,
          repeat: el.repeat,
          x: el.x,
          y: el.y,
          width: w.clamp(5, 500),
          height: h.clamp(5, 500),
          fontSize: el.fontSize,
          fontWeight: el.fontWeight,
          italic: el.italic,
          underline: el.underline,
          alignment: el.alignment,
          vAlignment: el.vAlignment,
          color: el.color,
          fontFamily: el.fontFamily,
          backgroundColor: el.backgroundColor,
        );
        _layout[index] = updated;
        _selectedElement = updated;
      });
    }
  }

  Alignment _getAlignment(String h, String v) {
    double x = -1.0;
    if (h == 'center') x = 0.0;
    if (h == 'right') x = 1.0;

    double y = 0.0;
    if (v == 'top') y = -1.0;
    if (v == 'bottom') y = 1.0;

    return Alignment(x, y);
  }

  TextAlign _getTextAlign(String align) {
    switch (align) {
      case 'center':
        return TextAlign.center;
      case 'right':
        return TextAlign.right;
      default:
        return TextAlign.left;
    }
  }

  void _alignElements(String type) {
    if (_selectedIds.length < 2) return;

    // First selected is reference (primary/anchor)
    final refId = _selectedIds.first;
    final indexRef = _layout.indexWhere((e) => e.id == refId);
    if (indexRef == -1) return;
    final refEl = _layout[indexRef];

    setState(() {
      for (var id in _selectedIds) {
        if (id == refId) continue;
        final index = _layout.indexWhere((e) => e.id == id);
        if (index == -1) continue;

        var el = _layout[index];
        double newX = el.x;
        double newY = el.y;

        switch (type) {
          case 'left':
            newX = refEl.x;
            break;
          case 'center_x':
            newX = refEl.x + (refEl.width - el.width) / 2;
            break;
          case 'right':
            newX = refEl.x + refEl.width - el.width;
            break;
          case 'top':
            newY = refEl.y;
            break;
          case 'center_y':
            newY = refEl.y + (refEl.height - el.height) / 2;
            break;
          case 'bottom':
            newY = refEl.y + refEl.height - el.height;
            break;
        }

        _layout[index] = LayoutElement(
          id: el.id,
          key: el.key,
          label: el.label,
          elementType: el.elementType,
          isStatic: el.isStatic,
          repeat: el.repeat,
          x: newX,
          y: newY,
          width: el.width,
          height: el.height,
          fontSize: el.fontSize,
          alignment: el.alignment,
          vAlignment: el.vAlignment,
          fontWeight: el.fontWeight,
          italic: el.italic,
          underline: el.underline,
          fontFamily: el.fontFamily,
          color: el.color,
          backgroundColor: el.backgroundColor,
        );
      }
    });
  }

  void _matchSize(String type) {
    if (_selectedIds.length < 2) return;

    final refId = _selectedIds.first;
    final indexRef = _layout.indexWhere((e) => e.id == refId);
    if (indexRef == -1) return;
    final refEl = _layout[indexRef];

    setState(() {
      for (var id in _selectedIds) {
        if (id == refId) continue;
        final index = _layout.indexWhere((e) => e.id == id);
        if (index == -1) continue;

        var el = _layout[index];
        double newW = el.width;
        double newH = el.height;

        if (type == 'width' || type == 'both') newW = refEl.width;
        if (type == 'height' || type == 'both') newH = refEl.height;

        _layout[index] = LayoutElement(
          id: el.id,
          key: el.key,
          label: el.label,
          elementType: el.elementType,
          isStatic: el.isStatic,
          repeat: el.repeat,
          x: el.x,
          y: el.y,
          width: newW,
          height: newH,
          fontSize: el.fontSize,
          alignment: el.alignment,
          vAlignment: el.vAlignment,
          fontWeight: el.fontWeight,
          italic: el.italic,
          underline: el.underline,
          fontFamily: el.fontFamily,
          color: el.color,
          backgroundColor: el.backgroundColor,
        );
      }
    });
  }

  Widget _buildSectionHeader(String title) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 13,
          color: Color(0xFF1E293B),
        ),
      ),
    );
  }

  Widget _buildInteractiveSection({
    required String title,
    required bool isActive,
    required List<Widget> children,
    EdgeInsets padding = const EdgeInsets.all(12),
  }) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: isActive ? 1.0 : 0.4,
      child: AbsorbPointer(
        absorbing: !isActive,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(title),
            Padding(
              padding: padding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: children,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIconButtonV2({
    required IconData icon,
    required VoidCallback? onTap,
    required String tooltip,
    bool isSelected = false,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        mouseCursor: WidgetStateMouseCursor.clickable,
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF2C3E50).withValues(alpha: 0.1)
                : (onTap == null
                      ? Colors.grey.withValues(alpha: 0.05)
                      : const Color(0xFFF1F5F9)),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF2C3E50)
                  : (onTap == null
                        ? Colors.grey.withValues(alpha: 0.2)
                        : const Color(0xFFE2E8F0)),
              width: 1.0,
            ),
          ),
          child: Icon(
            icon,
            size: 18,
            color: isSelected
                ? const Color(0xFF2C3E50)
                : (onTap == null ? Colors.grey : const Color(0xFF64748B)),
          ),
        ),
      ),
    );
  }

  Widget _buildPropertiesPanel() {
    final bool isSingleElement =
        _selectedIds.length == 1 && _selectedIds.first != _backgroundId;
    final bool isMultiElement = _selectedIds.length > 1;
    final bool isBgSelected = _selectedIds.contains(_backgroundId);

    final element = isSingleElement ? _selectedElement : null;
    final bool isStaticLine = element?.elementType == 'line';
    final bool isImage = element?.elementType == 'image';

    return Container(
      width: 300,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          left: BorderSide(color: Colors.black.withValues(alpha: 0.1)),
        ),
      ),
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // 1. Alan Özellikleri (Sadece tekli seçimde aktif)
                  _buildInteractiveSection(
                    title: tr('print.designer.field_properties'),
                    isActive: isSingleElement,
                    children: [
                      _buildPropField(
                        element?.isStatic == true && !isStaticLine
                            ? tr('print.designer.text_content')
                            : tr('common.label'),
                        element?.label ?? '',
                        (val) => _updateSelected(label: val),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildPropField(
                              '${tr('print.designer.x')} (${tr('common.unit.mm')})',
                              element?.x.toStringAsFixed(1) ?? '0.0',
                              (val) => _updateSelected(x: double.tryParse(val)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildPropField(
                              '${tr('print.designer.y')} (${tr('common.unit.mm')})',
                              element?.y.toStringAsFixed(1) ?? '0.0',
                              (val) => _updateSelected(y: double.tryParse(val)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildPropField(
                              '${tr('print.designer.width')} (${tr('common.unit.mm')})',
                              element?.width.toStringAsFixed(1) ?? '0.0',
                              (val) =>
                                  _updateSelected(width: double.tryParse(val)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildPropField(
                              '${tr('print.designer.height')} (${tr('common.unit.mm')})',
                              element?.height.toStringAsFixed(1) ?? '0.0',
                              (val) =>
                                  _updateSelected(height: double.tryParse(val)),
                            ),
                          ),
                        ],
                      ),
                      if (!isStaticLine && !isImage) ...[
                        const SizedBox(height: 12),
                        Text(
                          tr('print.designer.font_and_style'),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 8),
                        // 1. Satır: Font Boyutu
                        _buildFontSizeControl(element),
                        const SizedBox(height: 8),
                        // 2. Satır: Font Ailesi
                        DropdownButtonFormField<String>(
                          mouseCursor: WidgetStateMouseCursor.clickable,
                          dropdownMenuItemMouseCursor: WidgetStateMouseCursor.clickable,
                          isDense: true,
                          initialValue:
                              _fontFamilies.contains(element?.fontFamily)
                              ? element!.fontFamily
                              : 'Inter',
                          items: _fontFamilies
                              .map(
                                (f) => DropdownMenuItem(
                                  value: f,
                                  child: Text(
                                    f,
                                    style: TextStyle(
                                      fontFamily: f,
                                      fontSize: 11,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: isSingleElement
                              ? (val) {
                                  if (val != null) {
                                    _updateSelected(fontFamily: val);
                                  }
                                }
                              : null,
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 10,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor: const Color(0xFFF1F5F9),
                          ),
                        ),
                        const SizedBox(height: 8),
                        // 3. Satır: Font Kalınlığı
                        DropdownButtonFormField<String>(
                          mouseCursor: WidgetStateMouseCursor.clickable,
                          dropdownMenuItemMouseCursor: WidgetStateMouseCursor.clickable,
                          isDense: true,
                          initialValue:
                              _fontWeights.containsKey(element?.fontWeight)
                              ? element!.fontWeight
                              : 'Regular',
                          items: _fontWeights.keys
                              .map(
                                (w) => DropdownMenuItem(
                                  value: w,
                                  child: Text(
                                    w,
                                    style: TextStyle(
                                      fontWeight: _fontWeights[w],
                                      fontSize: 11,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: isSingleElement
                              ? (val) {
                                  if (val != null) {
                                    _updateSelected(fontWeight: val);
                                  }
                                }
                              : null,
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 10,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor: const Color(0xFFF1F5F9),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _buildIconButtonV2(
                              icon: Icons.format_italic_rounded,
                              onTap: isSingleElement
                                  ? () => _updateSelected(
                                      italic: !(element?.italic ?? false),
                                    )
                                  : null,
                              tooltip: tr('common.italic'),
                              isSelected: element?.italic == true,
                            ),
                            const SizedBox(width: 8),
                            _buildIconButtonV2(
                              icon: Icons.format_underlined_rounded,
                              onTap: isSingleElement
                                  ? () => _updateSelected(
                                      underline: !(element?.underline ?? false),
                                    )
                                  : null,
                              tooltip: tr('common.underline'),
                              isSelected: element?.underline == true,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildColorsPanel(element),
                      ],
                    ],
                  ),

                  // 2. Hizalama ve Boyutlandırma (Tekli veya Çoklu seçimde aktif)
                  _buildInteractiveSection(
                    title: tr('print.designer.alignment_sizing'),
                    isActive: isSingleElement || isMultiElement,
                    children: [
                      // Tekli Hizalama Satırı (Daima Görünür)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildIconButtonV2(
                            icon: Icons.format_align_left_rounded,
                            onTap: isSingleElement
                                ? () => _updateSelected(alignment: 'left')
                                : null,
                            tooltip: tr('print.designer.align_left'),
                            isSelected: element?.alignment == 'left',
                          ),
                          _buildIconButtonV2(
                            icon: Icons.format_align_center_rounded,
                            onTap: isSingleElement
                                ? () => _updateSelected(alignment: 'center')
                                : null,
                            tooltip: tr(
                              'print.designer.align_center_horizontal',
                            ),
                            isSelected: element?.alignment == 'center',
                          ),
                          _buildIconButtonV2(
                            icon: Icons.format_align_right_rounded,
                            onTap: isSingleElement
                                ? () => _updateSelected(alignment: 'right')
                                : null,
                            tooltip: tr('print.designer.align_right'),
                            isSelected: element?.alignment == 'right',
                          ),
                          const SizedBox(width: 4),
                          const SizedBox(
                            height: 24,
                            child: VerticalDivider(width: 1),
                          ),
                          const SizedBox(width: 4),
                          _buildIconButtonV2(
                            icon: Icons.vertical_align_top_rounded,
                            onTap: isSingleElement
                                ? () => _updateSelected(vAlignment: 'top')
                                : null,
                            tooltip: tr('print.designer.align_top'),
                            isSelected: element?.vAlignment == 'top',
                          ),
                          _buildIconButtonV2(
                            icon: Icons.vertical_align_center_rounded,
                            onTap: isSingleElement
                                ? () => _updateSelected(vAlignment: 'center')
                                : null,
                            tooltip: tr('print.designer.align_center_vertical'),
                            isSelected: element?.vAlignment == 'center',
                          ),
                          _buildIconButtonV2(
                            icon: Icons.vertical_align_bottom_rounded,
                            onTap: isSingleElement
                                ? () => _updateSelected(vAlignment: 'bottom')
                                : null,
                            tooltip: tr('print.designer.align_bottom'),
                            isSelected: element?.vAlignment == 'bottom',
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // Çoklu Seçim ve Boyut Eşitleme (Daima Görünür, Dinamik Aktif)
                      AnimatedOpacity(
                        opacity: isMultiElement ? 1.0 : 0.4,
                        duration: const Duration(milliseconds: 200),
                        child: AbsorbPointer(
                          absorbing: !isMultiElement,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tr('print.designer.multi_select_alignment'),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  _buildIconButtonV2(
                                    icon: Icons.align_horizontal_left_rounded,
                                    onTap: () => _alignElements('left'),
                                    tooltip: tr('print.designer.align_left'),
                                  ),
                                  _buildIconButtonV2(
                                    icon: Icons.align_horizontal_center_rounded,
                                    onTap: () => _alignElements('center_x'),
                                    tooltip: tr(
                                      'print.designer.align_center_horizontal',
                                    ),
                                  ),
                                  _buildIconButtonV2(
                                    icon: Icons.align_horizontal_right_rounded,
                                    onTap: () => _alignElements('right'),
                                    tooltip: tr('print.designer.align_right'),
                                  ),
                                  _buildIconButtonV2(
                                    icon: Icons.align_vertical_top_rounded,
                                    onTap: () => _alignElements('top'),
                                    tooltip: tr('print.designer.align_top'),
                                  ),
                                  _buildIconButtonV2(
                                    icon: Icons.align_vertical_center_rounded,
                                    onTap: () => _alignElements('center_y'),
                                    tooltip: tr(
                                      'print.designer.align_center_vertical',
                                    ),
                                  ),
                                  _buildIconButtonV2(
                                    icon: Icons.align_vertical_bottom_rounded,
                                    onTap: () => _alignElements('bottom'),
                                    tooltip: tr('print.designer.align_bottom'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                tr('print.designer.size_equalize'),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  _buildIconButtonV2(
                                    icon: Icons.arrow_right_alt_rounded,
                                    onTap: () => _matchSize('width'),
                                    tooltip: tr('print.designer.width'),
                                  ),
                                  _buildIconButtonV2(
                                    icon: Icons.height_rounded,
                                    onTap: () => _matchSize('height'),
                                    tooltip: tr('print.designer.height'),
                                  ),
                                  _buildIconButtonV2(
                                    icon: Icons.aspect_ratio_rounded,
                                    onTap: () => _matchSize('both'),
                                    tooltip: tr('print.designer.full_size'),
                                  ),
                                  const SizedBox(width: 38),
                                  const SizedBox(width: 38),
                                  const SizedBox(width: 38),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  // 3. Şablon Arkaplanı (Sadece arkaplan seçiliyse aktif)
                  _buildInteractiveSection(
                    title: tr('print.designer.template_background'),
                    isActive: isBgSelected,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                activeTrackColor: Colors.purple,
                                inactiveTrackColor: Colors.purple.withValues(
                                  alpha: 0.2,
                                ),
                                thumbColor: Colors.purple,
                                overlayColor: Colors.purple.withValues(
                                  alpha: 0.1,
                                ),
                                trackHeight: 3,
                                thumbShape: const RoundSliderThumbShape(
                                  enabledThumbRadius: 6,
                                ),
                              ),
                              child: Slider(
                                value: _backgroundOpacity,
                                min: 0.0,
                                max: 1.0,
                                divisions: 20,
                                onChanged: isBgSelected
                                    ? (val) => setState(
                                        () => _backgroundOpacity = val,
                                      )
                                    : null,
                              ),
                            ),
                          ),
                          Text(
                            '%${(_backgroundOpacity * 100).round()}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.purple,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Row(
              children: [
                // 1. Arkaplanı Kaldır (Kompakt ve Estetik)
                Expanded(
                  child: AnimatedOpacity(
                    opacity: _backgroundImage != null ? 1.0 : 0.4,
                    duration: const Duration(milliseconds: 200),
                    child: SizedBox(
                      height: 36,
                      child: TextButton.icon(
                        onPressed: _backgroundImage != null
                            ? () {
                                setState(() {
                                  _backgroundImage = null;
                                  _bgImageBytes = null;
                                });
                              }
                            : null,
                        icon: const Icon(Icons.wallpaper_rounded, size: 16),
                        label: Text(
                          tr('print.designer.remove_background'),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.purple,
                          backgroundColor: Colors.purple.withValues(
                            alpha: 0.08,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // 2. Seçiliyi Sil (Kompakt ve estetik)
                Expanded(
                  child: AnimatedOpacity(
                    opacity: _selectedIds.isNotEmpty ? 1.0 : 0.4,
                    duration: const Duration(milliseconds: 200),
                    child: AbsorbPointer(
                      absorbing: _selectedIds.isEmpty,
                      child: SizedBox(
                        height: 36,
                        child: TextButton.icon(
                          onPressed: () {
                            if (isSingleElement) {
                              _elementSil(_selectedElement!);
                            } else if (isMultiElement) {
                              _elementSil(
                                _layout.firstWhere(
                                  (e) => e.id == _selectedIds.first,
                                ),
                              );
                            }
                          },
                          icon: const Icon(
                            Icons.delete_sweep_rounded,
                            size: 16,
                          ),
                          label: Text(
                            tr('print.designer.delete_selected'),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.red,
                            backgroundColor: Colors.red.withValues(alpha: 0.08),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: EdgeInsets.zero,
                          ),
                        ),
                      ),
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

  Widget _buildPropField(
    String label,
    String value,
    Function(String) onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 4),
        TextFormField(
          initialValue: value,
          onChanged: _selectedIds.length == 1 ? onChanged : null,
          key: ValueKey(
            '${_selectedIds.length == 1 ? (_selectedElement?.id ?? 'bg') : 'none'}_$label',
          ),
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: const Color(0xFFF1F5F9),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 8,
            ),
          ),
        ),
      ],
    );
  }

  void _addStaticHeading() {
    final newEl = LayoutElement(
      id: 'static_${DateTime.now().millisecondsSinceEpoch}',
      key: 'static_text',
      label: tr('print.designer.new_title'),
      isStatic: true,
      x: 10,
      y: 10,
      width: 50,
      height: 10,
      fontSize: '14',
      fontWeight: 'bold',
      alignment: 'center',
      vAlignment: 'center',
      color: '#000000',
    );
    setState(() {
      _layout.add(newEl);
      _selectedIds.clear();
      _selectedIds.add(newEl.id);
      _selectedElement = newEl;
    });
  }

  void _addStaticLine() {
    final newEl = LayoutElement(
      id: 'line_${DateTime.now().millisecondsSinceEpoch}',
      key: 'static_line',
      label: tr('print.designer.line'),
      elementType: 'line',
      isStatic: true,
      x: 10,
      y: 10,
      width: 100,
      height: 2,
    );
    setState(() {
      _layout.add(newEl);
      _selectedIds.clear();
      _selectedIds.add(newEl.id);
      _selectedElement = newEl;
    });
  }

  // [2026 FIX] Debounce for add element to prevent double clicks
  int _lastAddTimestamp = 0;

  void _addElement(String key, [double? x, double? y]) {
    final now = DateTime.now().millisecondsSinceEpoch;
    // 300ms debounce
    if (now - _lastAddTimestamp < 300) return;
    _lastAddTimestamp = now;

    final def = YazdirmaAlanlari.tumAlanlar.firstWhere(
      (e) => e.key == key,
      orElse: () => YazdirmaAlanTanim(key: key, labelKey: key),
    );

    double targetX = x ?? 10.0;
    double targetY = y ?? 10.0;

    // Smart placement: and if x/y are null, place it near selected
    if (x == null && y == null && _selectedElement != null) {
      targetX = (_selectedElement!.x + 5.0).clamp(0.0, 200.0);
      targetY = (_selectedElement!.y + 5.0).clamp(0.0, 280.0);
    }

    // [2026 FIX] Unique ID with random suffix to prevent collisions
    final uniqueId = '${now}_${math.Random().nextInt(1000)}';

    final newEl = LayoutElement(
      id: uniqueId,
      key: def.key,
      label: def.isStatic ? tr('common.title') : _fieldLabelForUi(def),
      elementType: switch (def.type) {
        YazdirmaAlanTipi.image => 'image',
        YazdirmaAlanTipi.line => 'line',
        YazdirmaAlanTipi.text => 'text',
      },
      isStatic: def.isStatic,
      repeat: def.repeat,
      x: targetX,
      y: targetY,
      width: def.defaultWidthMm,
      height:
          def.defaultHeightMm * (def.type == YazdirmaAlanTipi.line ? 1 : 1.5),
      fontSize: '12',
    );
    setState(() {
      _layout.add(newEl);
      _selectedIds.clear();
      _selectedIds.add(newEl.id);
      _selectedElement = newEl;
      _saveToHistory(); // Save state
    });
  }

  void _duplicateElement(
    LayoutElement el,
    double x,
    double y, {
    bool updateState = true,
  }) {
    // [2026 FIX] Prevent ID collision with safe suffix
    final uniqueId =
        '${DateTime.now().millisecondsSinceEpoch}_${math.Random().nextInt(1000)}';

    final newEl = LayoutElement(
      id: uniqueId,
      key: el.key,
      label: el.label,
      elementType: el.elementType,
      isStatic: el.isStatic,
      repeat: el.repeat,
      x: x,
      y: y,
      width: el.width,
      height: el.height,
      fontSize: el.fontSize,
      fontWeight: el.fontWeight,
      italic: el.italic,
      underline: el.underline,
      alignment: el.alignment,
      vAlignment: el.vAlignment,
      color: el.color,
      fontFamily: el.fontFamily,
      backgroundColor: el.backgroundColor,
    );

    void apply() {
      _layout.add(newEl);
      _selectedIds.clear();
      _selectedIds.add(newEl.id);
      _selectedElement = newEl;
      _saveToHistory(); // Save state
    }

    if (updateState) {
      setState(apply);
    } else {
      apply();
    }
  }

  void _updateSelected({
    String? label,
    double? x,
    double? y,
    double? width,
    double? height,
    String? fontSize,
    String? alignment,
    String? vAlignment,
    String? fontWeight,
    bool? italic,
    bool? underline,
    String? fontFamily,
    String? backgroundColor,
    String? color,
  }) {
    if (_selectedElement == null) return;
    final index = _layout.indexWhere((e) => e.id == _selectedElement!.id);
    if (index == -1) return;

    final updated = LayoutElement(
      id: _selectedElement!.id,
      key: _selectedElement!.key,
      label: label ?? _selectedElement!.label,
      elementType: _selectedElement!.elementType,
      isStatic: _selectedElement!.isStatic,
      repeat: _selectedElement!.repeat,
      x: x ?? _selectedElement!.x,
      y: y ?? _selectedElement!.y,
      width: width ?? _selectedElement!.width,
      height: height ?? _selectedElement!.height,
      fontSize: fontSize ?? _selectedElement!.fontSize,
      alignment: alignment ?? _selectedElement!.alignment,
      vAlignment: vAlignment ?? _selectedElement!.vAlignment,
      fontWeight: fontWeight ?? _selectedElement!.fontWeight,
      italic: italic ?? _selectedElement!.italic,
      underline: underline ?? _selectedElement!.underline,
      fontFamily: fontFamily ?? _selectedElement!.fontFamily,
      color: color ?? _selectedElement!.color,
      backgroundColor: backgroundColor ?? _selectedElement!.backgroundColor,
    );

    setState(() {
      _layout[index] = updated;
      _selectedElement = updated;
      _saveToHistory(); // Save state
    });
  }

  Widget _buildFontSizeControl(LayoutElement? el) {
    // Standart font boyutları
    final sizes = [6, 8, 9, 10, 11, 12, 14, 16, 18, 20, 24, 30, 36, 48, 60, 72];
    final currentSize = el != null
        ? (double.tryParse(el.fontSize) ?? 12)
        : 12.0;

    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<double>(
            mouseCursor: WidgetStateMouseCursor.clickable,
            dropdownMenuItemMouseCursor: WidgetStateMouseCursor.clickable,
            isDense: true,
            initialValue: sizes.contains(currentSize.toInt())
                ? currentSize
                : 12,
            items: sizes
                .map(
                  (s) => DropdownMenuItem(
                    value: s.toDouble(),
                    child: Text(
                      s.toString(),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                )
                .toList(),
            onChanged: el != null
                ? (val) {
                    if (val != null) {
                      _updateSelected(fontSize: val.toString());
                    }
                  }
                : null,
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 8,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: const Color(0xFFF1F5F9),
            ),
          ),
        ),
        const SizedBox(width: 4),
        _buildMiniButton(
          Icons.remove_rounded,
          el != null
              ? () {
                  final currentIndex = sizes.indexOf(currentSize.toInt());
                  if (currentIndex > 0) {
                    _updateSelected(
                      fontSize: sizes[currentIndex - 1].toString(),
                    );
                  }
                }
              : null,
        ),
        const SizedBox(width: 4),
        _buildMiniButton(
          Icons.add_rounded,
          el != null
              ? () {
                  final currentIndex = sizes.indexOf(currentSize.toInt());
                  if (currentIndex != -1 && currentIndex < sizes.length - 1) {
                    _updateSelected(
                      fontSize: sizes[currentIndex + 1].toString(),
                    );
                  }
                }
              : null,
        ),
      ],
    );
  }

  Widget _buildMiniButton(IconData icon, VoidCallback? onTap) {
    return InkWell(
      mouseCursor: WidgetStateMouseCursor.clickable,
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(
          icon,
          size: 16,
          color: onTap != null ? const Color(0xFF2C3E50) : Colors.grey,
        ),
      ),
    );
  }

  Widget _buildColorsPanel(LayoutElement? el) {
    return Row(
      children: [
        Expanded(
          child: _buildColorControl(
            tr('print.designer.text_color'),
            el?.color,
            (val) => _updateSelected(color: val),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildColorControl(
            tr('print.designer.background'),
            el?.backgroundColor,
            (val) => _updateSelected(backgroundColor: val),
            allowTransparent: true,
          ),
        ),
      ],
    );
  }

  Widget _buildColorControl(
    String label,
    String? colorValue,
    Function(String?) onChanged, {
    bool allowTransparent = false,
  }) {
    final bool isSingleElement =
        _selectedIds.length == 1 && _selectedIds.first != _backgroundId;
    final color = colorValue != null && colorValue.isNotEmpty
        ? Color(int.parse(colorValue.replaceFirst('#', '0xFF')))
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
        const SizedBox(height: 4),
        InkWell(
          mouseCursor: WidgetStateMouseCursor.clickable,
          onTap: isSingleElement
              ? () => _showColorPicker(colorValue, onChanged, allowTransparent)
              : null,
          borderRadius: BorderRadius.circular(6),
          child: Container(
            height: 34,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(6),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Row(
              children: [
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: color ?? Colors.white,
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: color == null
                      ? const Icon(
                          Icons.grid_on_rounded,
                          size: 10,
                          color: Colors.grey,
                        )
                      : null,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    colorValue ?? (isSingleElement ? tr('common.none') : ''),
                    style: const TextStyle(fontSize: 10),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showColorPicker(
    String? currentColor,
    Function(String?) onSelect,
    bool allowTransparent,
  ) {
    // Material colors palette
    final colors = [
      '#000000',
      '#FFFFFF',
      '#F44336',
      '#E91E63',
      '#9C27B0',
      '#673AB7',
      '#3F51B5',
      '#2196F3',
      '#03A9F4',
      '#00BCD4',
      '#009688',
      '#4CAF50',
      '#8BC34A',
      '#CDDC39',
      '#FFEB3B',
      '#FFC107',
      '#FF9800',
      '#FF5722',
      '#795548',
      '#9E9E9E',
      '#607D8B',
      '#2C3E50', // Brand color
    ];
    final controller = TextEditingController(text: currentColor);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('print.designer.select_color')),
        content: SizedBox(
          width: 300,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (allowTransparent)
                    InkWell(
                      mouseCursor: WidgetStateMouseCursor.clickable,
                      onTap: () {
                        onSelect(null);
                        Navigator.pop(context);
                      },
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(
                          Icons.format_color_reset_rounded,
                          color: Colors.red,
                        ),
                      ),
                    ),
                  ...colors.map(
                    (c) => InkWell(
                      mouseCursor: WidgetStateMouseCursor.clickable,
                      onTap: () {
                        onSelect(c);
                        Navigator.pop(context);
                      },
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Color(int.parse(c.replaceFirst('#', '0xFF'))),
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              TextField(
                controller: controller,
                decoration: InputDecoration(
                  labelText: tr('print.designer.hex_color_code'),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.check_rounded),
                    onPressed: () {
                      if (controller.text.isNotEmpty) {
                        onSelect(controller.text);
                      }
                      Navigator.pop(context);
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _kagitAyarlariniGoster() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(tr('print.designer.template_paper_settings')),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  initialValue: _name,
                  decoration: InputDecoration(
                    labelText: tr('print.designer.template_name'),
                  ),
                  onChanged: (val) => setState(() => _name = val),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  mouseCursor: WidgetStateMouseCursor.clickable,
                  dropdownMenuItemMouseCursor: WidgetStateMouseCursor.clickable,
                  initialValue: _docType,
                  decoration: InputDecoration(
                    labelText: tr('print.designer.document_type'),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: 'invoice',
                      child: Text(tr('settings.print.types.invoice')),
                    ),
                    DropdownMenuItem(
                      value: 'waybill',
                      child: Text(tr('settings.print.types.waybill')),
                    ),
                    DropdownMenuItem(
                      value: 'receipt',
                      child: Text(tr('settings.print.types.receipt')),
                    ),
                    DropdownMenuItem(
                      value: 'barcode',
                      child: Text(tr('settings.print.types.barcode')),
                    ),
                  ],
                  onChanged: (val) {
                    if (val == null) return;
                    setState(() => _docType = val);
                    setDialogState(() {});
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  mouseCursor: WidgetStateMouseCursor.clickable,
                  dropdownMenuItemMouseCursor: WidgetStateMouseCursor.clickable,
                  initialValue: _paperSize,
                  decoration: InputDecoration(
                    labelText: tr('print.designer.paper_type'),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: 'A4',
                      child: Text(
                        '${tr('print.paper_size.a4')} (210x297 ${tr('common.unit.mm')})',
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'A5',
                      child: Text(
                        '${tr('print.paper_size.a5')} (148x210 ${tr('common.unit.mm')})',
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'Continuous',
                      child: Text(tr('print.paper.continuous_form')),
                    ),
                    DropdownMenuItem(
                      value: 'Thermal80',
                      child: Text(tr('print.paper.thermal_80')),
                    ),
                    DropdownMenuItem(
                      value: 'Thermal58',
                      child: Text(tr('print.paper.thermal_58')),
                    ),
                    DropdownMenuItem(
                      value: 'Custom',
                      child: Text(tr('print.paper.custom_size')),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _paperSize = val;
                        _initialCanvasViewApplied = false;
                        _initialCanvasViewScheduled = false;
                      });
                      setDialogState(() {});
                    }
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  initialValue: _itemRowSpacing.toStringAsFixed(1),
                  decoration: InputDecoration(
                    labelText:
                        '${tr('print.designer.item_row_spacing')} (${tr('common.unit.mm')})',
                    helperText: tr('print.designer.item_row_spacing_help'),
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (val) {
                    final parsed = double.tryParse(val.replaceAll(',', '.'));
                    setState(() => _itemRowSpacing = parsed ?? 1.0);
                  },
                ),
                const SizedBox(height: 16),
                Text(
                  tr('print.designer.paper_orientation'),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        mouseCursor: WidgetStateMouseCursor.clickable,
                        onTap: () {
                          setState(() {
                            _isLandscape = false;
                            _initialCanvasViewApplied = false;
                            _initialCanvasViewScheduled = false;
                          });
                          setDialogState(() {});
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: !_isLandscape
                                ? const Color(0xFF2C3E50).withValues(alpha: 0.1)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: !_isLandscape
                                  ? const Color(0xFF2C3E50)
                                  : Colors.grey.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.crop_portrait_rounded,
                                color: !_isLandscape
                                    ? const Color(0xFF2C3E50)
                                    : Colors.grey,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                tr('print.layout.portrait'),
                                style: TextStyle(
                                  color: !_isLandscape
                                      ? const Color(0xFF2C3E50)
                                      : Colors.grey,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InkWell(
                        mouseCursor: WidgetStateMouseCursor.clickable,
                        onTap: () {
                          setState(() {
                            _isLandscape = true;
                            _initialCanvasViewApplied = false;
                            _initialCanvasViewScheduled = false;
                          });
                          setDialogState(() {});
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: _isLandscape
                                ? const Color(0xFF2C3E50).withValues(alpha: 0.1)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _isLandscape
                                  ? const Color(0xFF2C3E50)
                                  : Colors.grey.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.crop_landscape_rounded,
                                color: _isLandscape
                                    ? const Color(0xFF2C3E50)
                                    : Colors.grey,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                tr('print.layout.landscape'),
                                style: TextStyle(
                                  color: _isLandscape
                                      ? const Color(0xFF2C3E50)
                                      : Colors.grey,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (_paperSize == 'Custom') ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          initialValue: _customWidth.toString(),
                          decoration: InputDecoration(
                            labelText:
                                '${tr('print.designer.width')} (${tr('common.unit.mm')})',
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (val) {
                            setState(() {
                              _customWidth = double.tryParse(val) ?? 210;
                              _initialCanvasViewApplied = false;
                              _initialCanvasViewScheduled = false;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          initialValue: _customHeight.toString(),
                          decoration: InputDecoration(
                            labelText:
                                '${tr('print.designer.height')} (${tr('common.unit.mm')})',
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (val) {
                            setState(() {
                              _customHeight = double.tryParse(val) ?? 297;
                              _initialCanvasViewApplied = false;
                              _initialCanvasViewScheduled = false;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(tr('common.close')),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _resimYukle() async {
    await showDialog(
      context: context,
      builder: (context) => _ImageUploadDialog(
        initialPaperSize: _paperSize,
        initialIsLandscape: _isLandscape,
        onApply: (imageBytes, paperSize, isLandscape, customW, customH) {
          setState(() {
            _backgroundImage = base64Encode(imageBytes);
            _bgImageBytes = imageBytes;
            _paperSize = paperSize;
            _isLandscape = isLandscape;
            if (customW != null) _customWidth = customW;
            if (customH != null) _customHeight = customH;
            _backgroundX = 0;
            _backgroundY = 0;
            _backgroundWidth = null;
            _backgroundHeight = null;

            _initialCanvasViewApplied = false;
            _initialCanvasViewScheduled = false;
          });
        },
      ),
    );
  }

  Future<void> _kaydet({bool isNewCopy = false}) async {
    String? finalName = _name;

    // Eğer yeni kayıt veya "Farklı Kaydet" ise isim sor
    if (widget.sablon == null || isNewCopy) {
      finalName = await _showNamePrompt(
        initialName: isNewCopy ? '$_name (${tr('common.copy')})' : _name,
      );
      if (finalName == null || finalName.trim().isEmpty) return;
    }

    final model = YazdirmaSablonuModel(
      id: isNewCopy ? null : widget.sablon?.id,
      name: finalName,
      docType: _docType,
      paperSize: _paperSize,
      customWidth: _customWidth,
      customHeight: _customHeight,
      itemRowSpacing: _itemRowSpacing,
      backgroundImage: _backgroundImage,
      backgroundOpacity: _backgroundOpacity,
      backgroundX: _backgroundX,
      backgroundY: _backgroundY,
      backgroundWidth: _backgroundWidth,
      backgroundHeight: _backgroundHeight,
      layout: _layout,
      isDefault: _isDefault,
      isLandscape: _isLandscape,
      viewMatrix: _transformationController.value.storage.join(','),
    );

    bool res;
    if (model.id == null) {
      final id = await _dbServisi.sablonEkle(model);
      res = id != null;
    } else {
      res = await _dbServisi.sablonGuncelle(model);
    }

    if (res && mounted) {
      MesajYardimcisi.basariGoster(
        context,
        isNewCopy
            ? tr('print.designer.success.copy_created')
            : tr('print.designer.success.saved'),
      );
      // Artık sayfa kapanmıyor
      // Navigator.pop(context);
    }
  }

  Future<String?> _showNamePrompt({required String initialName}) async {
    final controller = TextEditingController(text: initialName);
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('print.designer.template_name')),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: tr('print.designer.template_name_hint'),
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tr('common.cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEA4335),
              foregroundColor: Colors.white,
            ),
            child: Text(tr('common.save')),
          ),
        ],
      ),
    );
  }
}

class _ImageUploadDialog extends StatefulWidget {
  final String initialPaperSize;
  final bool initialIsLandscape;
  final Function(Uint8List, String, bool, double?, double?) onApply;

  const _ImageUploadDialog({
    required this.initialPaperSize,
    required this.initialIsLandscape,
    required this.onApply,
  });

  @override
  State<_ImageUploadDialog> createState() => _ImageUploadDialogState();
}

class _ImageUploadDialogState extends State<_ImageUploadDialog> {
  late String _paperSize;
  late bool _isLandscape;
  Uint8List? _imageBytes;
  double _customWidth = 210;
  double _customHeight = 297;

  @override
  void initState() {
    super.initState();
    _paperSize = widget.initialPaperSize;
    _isLandscape = widget.initialIsLandscape;
  }

  Future<void> _pickImage() async {
    final typeGroup = XTypeGroup(
      label: tr('common.images'),
      extensions: <String>['jpg', 'png', 'jpeg'],
      uniformTypeIdentifiers: ['public.image'],
    );
    final XFile? file = await openFile(
      acceptedTypeGroups: <XTypeGroup>[typeGroup],
    );
    if (file != null) {
      final bytes = await file.readAsBytes();
      setState(() {
        _imageBytes = bytes;
      });
    }
  }

  Size _getPaperSize() {
    Size size;
    switch (_paperSize) {
      case 'A4':
        size = const Size(210, 297);
        break;
      case 'A5':
        size = const Size(148, 210);
        break;
      case 'Continuous':
        size = const Size(240, 280);
        break;
      case 'Thermal80':
        size = const Size(80, 200);
        break;
      case 'Thermal58':
        size = const Size(58, 150);
        break;
      case 'Custom':
        size = Size(_customWidth, _customHeight);
        break;
      default:
        size = const Size(210, 297);
    }
    if (_isLandscape) {
      return Size(size.height, size.width);
    }
    return size;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(tr('print.designer.template_image_settings')),
      content: SizedBox(
        width: 600,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tr('print.designer.step_select_template_image'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            InkWell(
              mouseCursor: WidgetStateMouseCursor.clickable,
              onTap: _pickImage,
              child: Container(
                height: 250,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                ),
                child: _imageBytes != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Aspect Ratio Preview
                            AspectRatio(
                              aspectRatio: _getPaperSize().aspectRatio,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border.all(color: Colors.blueAccent),
                                ),
                                child: Image.memory(
                                  _imageBytes!,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_photo_alternate_rounded,
                            size: 48,
                            color: Color(0xFF2C3E50),
                          ),
                          SizedBox(height: 8),
                          Text(
                            tr('print.designer.image_click_to_select'),
                            style: TextStyle(color: Color(0xFF2C3E50)),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              tr('print.designer.step_paper_settings'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    mouseCursor: WidgetStateMouseCursor.clickable,
                    dropdownMenuItemMouseCursor: WidgetStateMouseCursor.clickable,
                    initialValue: _paperSize,
                    decoration: InputDecoration(
                      labelText: tr('print.paper_size'),
                      border: const OutlineInputBorder(),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: 'A4',
                        child: Text(tr('print.paper_size.a4')),
                      ),
                      DropdownMenuItem(
                        value: 'A5',
                        child: Text(tr('print.paper_size.a5')),
                      ),
                      DropdownMenuItem(
                        value: 'Continuous',
                        child: Text(tr('print.paper.continuous_form')),
                      ),
                      DropdownMenuItem(
                        value: 'Thermal80',
                        child: Text(tr('print.paper.thermal_80')),
                      ),
                      DropdownMenuItem(
                        value: 'Thermal58',
                        child: Text(tr('print.paper.thermal_58')),
                      ),
                      DropdownMenuItem(
                        value: 'Custom',
                        child: Text(tr('print.paper.custom')),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _paperSize = val);
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildVisToggle(
                          label: tr('print.layout.portrait'),
                          icon: Icons.crop_portrait_rounded,
                          selected: !_isLandscape,
                          onTap: () => setState(() => _isLandscape = false),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildVisToggle(
                          label: tr('print.layout.landscape'),
                          icon: Icons.crop_landscape_rounded,
                          selected: _isLandscape,
                          onTap: () => setState(() => _isLandscape = true),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (_paperSize == 'Custom') ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      initialValue: _customWidth.toString(),
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText:
                            '${tr('print.designer.width')} (${tr('common.unit.mm')})',
                      ),
                      onChanged: (v) =>
                          _customWidth = double.tryParse(v) ?? 210,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      initialValue: _customHeight.toString(),
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText:
                            '${tr('print.designer.height')} (${tr('common.unit.mm')})',
                      ),
                      onChanged: (v) =>
                          _customHeight = double.tryParse(v) ?? 297,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(tr('common.cancel')),
        ),
        FilledButton(
          onPressed: _imageBytes == null
              ? null
              : () {
                  widget.onApply(
                    _imageBytes!,
                    _paperSize,
                    _isLandscape,
                    _paperSize == 'Custom' ? _customWidth : null,
                    _paperSize == 'Custom' ? _customHeight : null,
                  );
                  Navigator.pop(context);
                },
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFEA4335),
          ),
          child: Text(tr('common.apply')),
        ),
      ],
    );
  }

  Widget _buildVisToggle({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      mouseCursor: WidgetStateMouseCursor.clickable,
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF2C3E50).withValues(alpha: 0.1)
              : Colors.transparent,
          border: Border.all(
            color: selected
                ? const Color(0xFF2C3E50)
                : Colors.grey.withValues(alpha: 0.4),
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(icon, color: selected ? const Color(0xFF2C3E50) : Colors.grey),
            Text(
              label,
              style: TextStyle(
                color: selected ? const Color(0xFF2C3E50) : Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
