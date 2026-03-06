import 'dart:async';
import 'dart:math' as math show max;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Flutter 3.41.1 `RawAutocomplete` için geçici güvenlik yamalı fork.
///
/// Sorun: Framework, `widget.focusNode` verildiğinde `_onFocusChange` listener'ını
/// `dispose()` sırasında yanlış callback ile remove ediyor. Bu da route değişimi /
/// focus değişimi esnasında `OverlayPortalController.hide` assert'ine yol açıyor:
/// `_zOrderIndex != null`.
///
/// Bu sınıf aynı davranışı korur, sadece:
/// - FocusNode listener ekleme/çıkarma callback'ini düzeltir.
/// - `hide()` çağrısını `isShowing` ile guard eder (detached controller assert'ini önler).
class PatisyoRawAutocomplete<T extends Object> extends StatefulWidget {
  const PatisyoRawAutocomplete({
    super.key,
    required this.optionsViewBuilder,
    required this.optionsBuilder,
    this.optionsViewOpenDirection = OptionsViewOpenDirection.down,
    this.displayStringForOption = RawAutocomplete.defaultStringForOption,
    this.fieldViewBuilder,
    this.focusNode,
    this.onSelected,
    this.textEditingController,
    this.initialValue,
  }) : assert(
         fieldViewBuilder != null ||
             (key != null && focusNode != null && textEditingController != null),
         'Pass in a fieldViewBuilder, or otherwise create a separate field and pass in the FocusNode, TextEditingController, and a key. Use the key with RawAutocomplete.onFieldSubmitted.',
       ),
       assert((focusNode == null) == (textEditingController == null)),
       assert(
         !(textEditingController != null && initialValue != null),
         'textEditingController and initialValue cannot be simultaneously defined.',
       );

  final AutocompleteFieldViewBuilder? fieldViewBuilder;
  final FocusNode? focusNode;
  final AutocompleteOptionsViewBuilder<T> optionsViewBuilder;
  final OptionsViewOpenDirection optionsViewOpenDirection;
  final AutocompleteOptionToString<T> displayStringForOption;
  final AutocompleteOnSelected<T>? onSelected;
  final AutocompleteOptionsBuilder<T> optionsBuilder;
  final TextEditingController? textEditingController;
  final TextEditingValue? initialValue;

  @override
  State<PatisyoRawAutocomplete<T>> createState() =>
      _PatisyoRawAutocompleteState<T>();
}

class _PatisyoRawAutocompleteState<T extends Object>
    extends State<PatisyoRawAutocomplete<T>> {
  final OverlayPortalController _optionsViewController = OverlayPortalController(
    debugLabel: '_PatisyoRawAutocompleteState',
  );

  static const int _pageSize = 4;
  late bool _hasFocus;
  bool _selecting = false;

  TextEditingController? _internalTextEditingController;
  TextEditingController get _textEditingController {
    return widget.textEditingController ??
        (_internalTextEditingController ??=
            TextEditingController()..addListener(_onChangedField));
  }

  FocusNode? _internalFocusNode;
  FocusNode get _focusNode {
    return widget.focusNode ??
        (_internalFocusNode ??= FocusNode()..addListener(_onFocusChange));
  }

  late final Map<Type, CallbackAction<Intent>> _actionMap =
      <Type, CallbackAction<Intent>>{
    AutocompletePreviousOptionIntent:
        _AutocompleteCallbackAction<AutocompletePreviousOptionIntent>(
      onInvoke: _highlightPreviousOption,
      isEnabledCallback: () => _canShowOptionsView,
    ),
    AutocompleteNextOptionIntent:
        _AutocompleteCallbackAction<AutocompleteNextOptionIntent>(
      onInvoke: _highlightNextOption,
      isEnabledCallback: () => _canShowOptionsView,
    ),
    AutocompleteFirstOptionIntent:
        _AutocompleteCallbackAction<AutocompleteFirstOptionIntent>(
      onInvoke: _highlightFirstOption,
      isEnabledCallback: () => _canShowOptionsView,
    ),
    AutocompleteLastOptionIntent:
        _AutocompleteCallbackAction<AutocompleteLastOptionIntent>(
      onInvoke: _highlightLastOption,
      isEnabledCallback: () => _canShowOptionsView,
    ),
    AutocompleteNextPageOptionIntent:
        _AutocompleteCallbackAction<AutocompleteNextPageOptionIntent>(
      onInvoke: _highlightNextPageOption,
      isEnabledCallback: () => _canShowOptionsView,
    ),
    AutocompletePreviousPageOptionIntent:
        _AutocompleteCallbackAction<AutocompletePreviousPageOptionIntent>(
      onInvoke: _highlightPreviousPageOption,
      isEnabledCallback: () => _canShowOptionsView,
    ),
    DismissIntent: CallbackAction<DismissIntent>(onInvoke: _hideOptions),
  };

  Iterable<T> _options = Iterable<T>.empty();
  T? _selection;
  String? _lastFieldText;
  final ValueNotifier<int> _highlightedOptionIndex = ValueNotifier<int>(0);

  static const Map<ShortcutActivator, Intent> _appleShortcuts =
      <ShortcutActivator, Intent>{
    SingleActivator(LogicalKeyboardKey.arrowUp, meta: true):
        AutocompleteFirstOptionIntent(),
    SingleActivator(LogicalKeyboardKey.arrowDown, meta: true):
        AutocompleteLastOptionIntent(),
  };

  static const Map<ShortcutActivator, Intent> _nonAppleShortcuts =
      <ShortcutActivator, Intent>{
    SingleActivator(LogicalKeyboardKey.arrowUp, control: true):
        AutocompleteFirstOptionIntent(),
    SingleActivator(LogicalKeyboardKey.arrowDown, control: true):
        AutocompleteLastOptionIntent(),
  };

  static const Map<ShortcutActivator, Intent> _commonShortcuts =
      <ShortcutActivator, Intent>{
    SingleActivator(LogicalKeyboardKey.arrowUp): AutocompletePreviousOptionIntent(),
    SingleActivator(LogicalKeyboardKey.arrowDown): AutocompleteNextOptionIntent(),
    SingleActivator(LogicalKeyboardKey.pageUp): AutocompletePreviousPageOptionIntent(),
    SingleActivator(LogicalKeyboardKey.pageDown): AutocompleteNextPageOptionIntent(),
  };

  static Map<ShortcutActivator, Intent> get _shortcuts => <ShortcutActivator, Intent>{
    ..._commonShortcuts,
    ...switch (defaultTargetPlatform) {
      TargetPlatform.iOS => _appleShortcuts,
      TargetPlatform.macOS => _appleShortcuts,
      TargetPlatform.android => _nonAppleShortcuts,
      TargetPlatform.linux => _nonAppleShortcuts,
      TargetPlatform.windows => _nonAppleShortcuts,
      TargetPlatform.fuchsia => _nonAppleShortcuts,
    },
  };

  bool get _canShowOptionsView => _focusNode.hasFocus && _options.isNotEmpty;

  void _onFocusChange() {
    if (_focusNode.hasFocus != _hasFocus) {
      _hasFocus = _focusNode.hasFocus;
      _updateOptionsViewVisibility();
    }
  }

  void _updateOptionsViewVisibility() {
    if (_canShowOptionsView) {
      _optionsViewController.show();
    } else if (_optionsViewController.isShowing) {
      _optionsViewController.hide();
    }
  }

  int _onChangedCallId = 0;
  Future<void> _onChangedField() async {
    if (_selecting) return;
    final TextEditingValue value = _textEditingController.value;

    var shouldUpdateOptions = false;
    if (value.text != _lastFieldText) {
      shouldUpdateOptions = true;
      _onChangedCallId += 1;
    }
    _lastFieldText = value.text;
    final int callId = _onChangedCallId;
    final Iterable<T> options = await widget.optionsBuilder(value);

    if (callId != _onChangedCallId || !shouldUpdateOptions) return;

    _options = options;
    _updateHighlight(_highlightedOptionIndex.value);
    final T? selection = _selection;
    if (selection != null &&
        value.text != widget.displayStringForOption(selection)) {
      _selection = null;
    }

    _updateOptionsViewVisibility();
  }

  void _onFieldSubmitted() {
    if (_optionsViewController.isShowing) {
      _select(_options.elementAt(_highlightedOptionIndex.value));
    }
  }

  void _select(T nextSelection) {
    if (nextSelection == _selection) return;
    _selecting = true;
    _selection = nextSelection;
    final String selectionString = widget.displayStringForOption(nextSelection);
    _textEditingController.value = TextEditingValue(
      selection: TextSelection.collapsed(offset: selectionString.length),
      text: selectionString,
    );
    widget.onSelected?.call(nextSelection);
    if (_optionsViewController.isShowing) {
      _optionsViewController.hide();
    }
    _selecting = false;
  }

  void _updateHighlight(int nextIndex) {
    _highlightedOptionIndex.value =
        _options.isEmpty ? 0 : nextIndex.clamp(0, _options.length - 1);
  }

  void _highlightPreviousOption(AutocompletePreviousOptionIntent intent) {
    _highlightOption(_highlightedOptionIndex.value - 1);
  }

  void _highlightNextOption(AutocompleteNextOptionIntent intent) {
    _highlightOption(_highlightedOptionIndex.value + 1);
  }

  void _highlightFirstOption(AutocompleteFirstOptionIntent intent) {
    _highlightOption(0);
  }

  void _highlightLastOption(AutocompleteLastOptionIntent intent) {
    _highlightOption(_options.length - 1);
  }

  void _highlightNextPageOption(AutocompleteNextPageOptionIntent intent) {
    _highlightOption(_highlightedOptionIndex.value + _pageSize);
  }

  void _highlightPreviousPageOption(AutocompletePreviousPageOptionIntent intent) {
    _highlightOption(_highlightedOptionIndex.value - _pageSize);
  }

  void _highlightOption(int index) {
    assert(_canShowOptionsView);
    _updateOptionsViewVisibility();
    assert(_optionsViewController.isShowing);
    _updateHighlight(index);
  }

  Object? _hideOptions(DismissIntent intent) {
    if (_optionsViewController.isShowing) {
      _optionsViewController.hide();
      return null;
    }
    return Actions.invoke(context, intent);
  }

  // Flutter core sabiti: kMinInteractiveDimension (48.0)
  // widgets.dart'ta export edilmediği için lokal sabit kullanıyoruz.
  static const double _kMinUsableHeight = 48.0;

  Widget _buildOptionsView(BuildContext context, OverlayChildLayoutInfo layoutInfo) {
    if (layoutInfo.childPaintTransform.determinant() == 0.0) {
      return const SizedBox.shrink();
    }

    final Size fieldSize = layoutInfo.childSize;
    final Matrix4 invertTransform = layoutInfo.childPaintTransform.clone()
      ..invert();

    final Rect overlayRectInField = MatrixUtils.transformRect(
      invertTransform,
      Offset.zero & layoutInfo.overlaySize,
    );

    final double spaceAbove = -overlayRectInField.top;
    final double spaceBelow = overlayRectInField.bottom - fieldSize.height;
    final bool opensUp = switch (widget.optionsViewOpenDirection) {
      OptionsViewOpenDirection.up => true,
      OptionsViewOpenDirection.down => false,
      OptionsViewOpenDirection.mostSpace => spaceAbove > spaceBelow,
    };

    final double optionsViewMaxHeight = opensUp
        ? -overlayRectInField.top
        : overlayRectInField.bottom - fieldSize.height;

    final optionsViewBoundingBox = Size(
      fieldSize.width,
      math.max(optionsViewMaxHeight, _kMinUsableHeight),
    );

    final double originY = opensUp
        ? overlayRectInField.top
        : overlayRectInField.bottom - optionsViewBoundingBox.height;

    final Matrix4 transform = layoutInfo.childPaintTransform.clone()
      ..translateByDouble(0.0, originY, 0, 1);

    final Widget child = Builder(
      builder: (BuildContext context) =>
          widget.optionsViewBuilder(context, _select, _options),
    );

    return Transform(
      transform: transform,
      child: Align(
        alignment: Alignment.topLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints.tight(optionsViewBoundingBox),
          child: Align(
            alignment:
                opensUp ? AlignmentDirectional.bottomStart : AlignmentDirectional.topStart,
            child: TextFieldTapRegion(
              child: AutocompleteHighlightedOption(
                highlightIndexNotifier: _highlightedOptionIndex,
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    final TextEditingController initialController =
        widget.textEditingController ??
        (_internalTextEditingController =
            TextEditingController.fromValue(widget.initialValue));
    initialController.addListener(_onChangedField);
    _hasFocus = _focusNode.hasFocus;

    // FIX: Doğru callback'i ekle/çıkar (framework bug workaround).
    widget.focusNode?.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(PatisyoRawAutocomplete<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.textEditingController, widget.textEditingController)) {
      oldWidget.textEditingController?.removeListener(_onChangedField);
      if (oldWidget.textEditingController == null) {
        _internalTextEditingController?.dispose();
        _internalTextEditingController = null;
      }
      widget.textEditingController?.addListener(_onChangedField);
    }

    // FIX: focus listener remove/add yanlış callback kullanıyordu.
    if (!identical(oldWidget.focusNode, widget.focusNode)) {
      oldWidget.focusNode?.removeListener(_onFocusChange);
      if (oldWidget.focusNode == null) {
        _internalFocusNode?.dispose();
        _internalFocusNode = null;
      }
      widget.focusNode?.addListener(_onFocusChange);
    }
  }

  @override
  void dispose() {
    widget.textEditingController?.removeListener(_onChangedField);
    _internalTextEditingController?.dispose();

    // FIX: Doğru callback'i kaldır.
    widget.focusNode?.removeListener(_onFocusChange);
    _internalFocusNode?.dispose();
    _highlightedOptionIndex.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Widget fieldView =
        widget.fieldViewBuilder?.call(
          context,
          _textEditingController,
          _focusNode,
          _onFieldSubmitted,
        ) ??
        const SizedBox(width: double.infinity, height: 0.0);

    return OverlayPortal.overlayChildLayoutBuilder(
      controller: _optionsViewController,
      overlayChildBuilder: _buildOptionsView,
      child: TextFieldTapRegion(
        child: Shortcuts(
          shortcuts: _shortcuts,
          child: Actions(actions: _actionMap, child: fieldView),
        ),
      ),
    );
  }
}

class _AutocompleteCallbackAction<T extends Intent> extends CallbackAction<T> {
  _AutocompleteCallbackAction({
    required super.onInvoke,
    required this.isEnabledCallback,
  });

  final bool Function() isEnabledCallback;

  @override
  bool isEnabled(T intent) => isEnabledCallback();
}
