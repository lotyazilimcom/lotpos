import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sticky_headers/sticky_headers.dart';
import '../yardimcilar/ceviri/ceviri_servisi.dart';

class TableDetailFocusScope extends InheritedWidget {
  final int? focusedDetailIndex;

  /// Callback to set the focused detail row index when a row is clicked
  final void Function(int index)? setFocusedDetailIndex;

  /// Callback to ensure a widget is visible (for auto-scroll)
  final void Function(BuildContext context)? ensureVisibleCallback;

  const TableDetailFocusScope({
    super.key,
    required this.focusedDetailIndex,
    this.setFocusedDetailIndex,
    this.ensureVisibleCallback,
    required super.child,
  });

  static TableDetailFocusScope? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<TableDetailFocusScope>();
  }

  @override
  bool updateShouldNotify(TableDetailFocusScope oldWidget) {
    return focusedDetailIndex != oldWidget.focusedDetailIndex ||
        setFocusedDetailIndex != oldWidget.setFocusedDetailIndex ||
        ensureVisibleCallback != oldWidget.ensureVisibleCallback;
  }
}

class GenisletilebilirTablo<T> extends StatefulWidget {
  final String title;
  final List<String>? breadcrumbs;
  final List<GenisletilebilirTabloKolon> columns;
  final List<T> data;
  final Widget Function(
    BuildContext context,
    T item,
    int index,
    bool isExpanded,
    VoidCallback toggleExpand,
  )
  rowBuilder;
  final Widget Function(BuildContext context, T item) detailBuilder;
  final Function(String) onSearch;
  final Function(int page, int rowsPerPage) onPageChanged;
  final int totalRecords;
  final Widget? actionButton;
  final EdgeInsetsGeometry? expandedContentPadding;
  final Widget? selectionWidget;
  final Widget? headerWidget;
  final bool expandAll;
  final List<Widget>? extraWidgets;
  final Function(int columnIndex, bool ascending)? onSort;
  final int? sortColumnIndex;
  final bool sortAscending;
  final bool expandOnRowTap;
  final Function(T item)? onRowTap;
  final Function(T item)? onRowDoubleTap;
  final bool Function(T item, int index)? isRowSelected;
  final Set<int>? expandedIndices;
  final Function(int index, bool isExpanded)? onExpansionChanged;
  final TextStyle? headerTextStyle;
  final int? headerMaxLines;
  final TextOverflow? headerOverflow;

  /// Helper to get count of items in detail view for keyboard navigation
  final int Function(T item)? getDetailItemCount;

  final FocusNode? focusNode;

  /// External search focus node for F3 shortcut
  final FocusNode? searchFocusNode;

  /// Callback when focused row changes via keyboard navigation
  final Function(T? item, int? index)? onFocusedRowChanged;

  /// Callback when user taps outside the table to clear selections
  final VoidCallback? onClearSelection;

  /// Custom padding for row container (default: vertical 12)
  final EdgeInsetsGeometry? rowPadding;

  /// Custom padding for header container (default: horizontal 16)
  final EdgeInsetsGeometry? headerPadding;

  const GenisletilebilirTablo({
    super.key,
    required this.title,
    this.breadcrumbs,
    required this.columns,
    required this.data,
    required this.rowBuilder,
    required this.detailBuilder,
    required this.onSearch,
    required this.onPageChanged,
    required this.totalRecords,
    this.actionButton,
    this.expandedContentPadding,
    this.selectionWidget,
    this.headerWidget,
    this.expandAll = false,
    this.extraWidgets,
    this.onSort,
    this.sortColumnIndex,
    this.sortAscending = true,
    this.expandOnRowTap = true,
    this.onRowTap,
    this.onRowDoubleTap,
    this.isRowSelected,
    this.expandedIndices,
    this.onExpansionChanged,
    this.headerTextStyle,
    this.headerMaxLines,
    this.headerOverflow,
    this.getDetailItemCount,
    this.focusNode,
    this.searchFocusNode,
    this.onFocusedRowChanged,
    this.onClearSelection,
    this.rowPadding,
    this.headerPadding,
  });

  @override
  State<GenisletilebilirTablo<T>> createState() =>
      _GenisletilebilirTabloState<T>();
}

class _GenisletilebilirTabloState<T> extends State<GenisletilebilirTablo<T>> {
  final TextEditingController _searchController = TextEditingController();
  late FocusNode _searchFocusNode;
  bool _isInternalSearchFocusNode = false;
  final FocusNode _keyboardListenerFocusNode =
      FocusNode(); // Persistent node for listener
  final ScrollController _scrollController = ScrollController();
  int _rowsPerPage = 25;
  int _currentPage = 1;
  final List<int> _rowsPerPageOptions = [10, 25, 50, 100, 250, 500];
  int? _expandedIndex;
  int? _lastAutoExpandedIndex;
  Timer? _debounce; // Debounce Timer

  late FocusNode _tableFocusNode;
  bool _isInternalFocusNode = false;
  int? _focusedRowIndex;
  int? _focusedDetailRowIndex;
  DateTime? _lastTapAt;
  int? _lastTapIndex;

  bool _consumeDoubleTap(int index) {
    final now = DateTime.now();
    final lastAt = _lastTapAt;
    final lastIndex = _lastTapIndex;

    _lastTapAt = now;
    _lastTapIndex = index;

    final isDouble =
        lastAt != null &&
        lastIndex == index &&
        now.difference(lastAt) <= const Duration(milliseconds: 350);

    if (isDouble) {
      _lastTapAt = null;
      _lastTapIndex = null;
    }

    return isDouble;
  }

  @override
  void dispose() {
    _searchController.dispose();
    if (_isInternalSearchFocusNode) {
      _searchFocusNode.dispose();
    }
    _keyboardListenerFocusNode.dispose();
    if (_isInternalFocusNode) {
      _tableFocusNode.dispose();
    }
    _debounce?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  bool _isExpanded(int index) {
    if (widget.expandAll) return true;
    if (widget.expandedIndices != null) {
      return widget.expandedIndices!.contains(index);
    }
    return _expandedIndex == index;
  }

  void _toggleExpandIndex(int index) {
    final isCurrentlyExpanded = _isExpanded(index);

    // CRITICAL: Clear detail focus when collapsing
    if (isCurrentlyExpanded && _focusedRowIndex == index) {
      setState(() {
        _focusedDetailRowIndex = null;
      });
    }

    // CRITICAL: Set _focusedRowIndex when expanding (for detail navigation)
    if (!isCurrentlyExpanded) {
      setState(() {
        _focusedRowIndex = index;
      });
    }

    if (widget.onExpansionChanged != null) {
      widget.onExpansionChanged!(index, !isCurrentlyExpanded);
    } else {
      setState(() {
        if (_expandedIndex == index) {
          _expandedIndex = null;
        } else {
          _expandedIndex = index;
        }
      });
    }
  }

  /// Clear all selections - called when tapping outside the table
  void _clearAllSelections() {
    if (_focusedRowIndex != null || _focusedDetailRowIndex != null) {
      setState(() {
        _focusedRowIndex = null;
        _focusedDetailRowIndex = null;
      });
    }
    // Notify parent to clear their selections too
    widget.onClearSelection?.call();
  }

  KeyEventResult _handleKeyEvent(KeyEvent event) {
    // Only handle key events if table has focus and data exists
    if (widget.data.isEmpty) return KeyEventResult.ignored;

    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        // CRITICAL FIX: If no row is selected, select the first row
        if (_focusedRowIndex == null) {
          setState(() {
            _focusedRowIndex = 0;
            _focusedDetailRowIndex = null;
          });
          _tableFocusNode.requestFocus(); // Ensure focus stays on table
          // Notify parent about focused row change
          widget.onFocusedRowChanged?.call(widget.data[0], 0);
          return KeyEventResult.handled;
        }

        // Check if current row is expanded for detail navigation
        final isExpanded = _isExpanded(_focusedRowIndex!);
        if (isExpanded && widget.getDetailItemCount != null) {
          final itemCount = widget.getDetailItemCount!(
            widget.data[_focusedRowIndex!],
          );

          // If we are not yet in details (focus on parent), go to first detail
          if (_focusedDetailRowIndex == null) {
            if (itemCount > 0) {
              setState(() => _focusedDetailRowIndex = 0);
              return KeyEventResult.handled;
            }
          } else {
            // We are in details
            if (_focusedDetailRowIndex! < itemCount - 1) {
              // Next detail
              setState(
                () => _focusedDetailRowIndex = _focusedDetailRowIndex! + 1,
              );
              return KeyEventResult.handled;
            } else {
              // Last detail -> Next parent row
              // Move to next parent row
            }
          }
        }

        // Move to next parent row (or loop)
        final newIndex = _focusedRowIndex! < widget.data.length - 1
            ? _focusedRowIndex! + 1
            : 0;
        setState(() {
          _focusedDetailRowIndex = null; // Exit detail
          _focusedRowIndex = newIndex;
        });
        // Notify parent about focused row change
        widget.onFocusedRowChanged?.call(widget.data[newIndex], newIndex);
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        // CRITICAL FIX: If no row is selected, select the first row (or last)
        if (_focusedRowIndex == null) {
          setState(() {
            _focusedRowIndex = 0;
            _focusedDetailRowIndex = null;
          });
          _tableFocusNode.requestFocus(); // Ensure focus stays on table
          // Notify parent about focused row change
          widget.onFocusedRowChanged?.call(widget.data[0], 0);
          return KeyEventResult.handled;
        }

        // Detail navigation up
        if (_focusedDetailRowIndex != null) {
          if (_focusedDetailRowIndex! > 0) {
            setState(
              () => _focusedDetailRowIndex = _focusedDetailRowIndex! - 1,
            );
            return KeyEventResult.handled;
          } else {
            // Exit detail to main row (same index)
            setState(() => _focusedDetailRowIndex = null);
            return KeyEventResult.handled;
          }
        }

        // Move to previous parent row
        final newIndex = _focusedRowIndex! > 0
            ? _focusedRowIndex! - 1
            : widget.data.length - 1;
        setState(() {
          _focusedRowIndex = newIndex;
          _focusedDetailRowIndex = null;
        });
        // Notify parent about focused row change
        widget.onFocusedRowChanged?.call(widget.data[newIndex], newIndex);
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.enter ||
          event.logicalKey == LogicalKeyboardKey.numpadEnter) {
        // CRITICAL FIX: Both Enter keys (standard and numpad) toggle expand
        if (_focusedRowIndex != null &&
            _focusedRowIndex! < widget.data.length) {
          _toggleExpandIndex(_focusedRowIndex!);
          return KeyEventResult.handled;
        }
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  void initState() {
    super.initState();
    // Search FocusNode setup
    if (widget.searchFocusNode != null) {
      _searchFocusNode = widget.searchFocusNode!;
    } else {
      _searchFocusNode = FocusNode();
      _isInternalSearchFocusNode = true;
    }

    // Table FocusNode setup
    if (widget.focusNode != null) {
      _tableFocusNode = widget.focusNode!;
    } else {
      _tableFocusNode = FocusNode();
      _isInternalFocusNode = true;
    }

    // Debounce Conflict Fix:
    // Parent widget already handles debounce (500ms).
    // We only listen for UI state (Clear icon visibility).
    _searchController.addListener(() {
      if (mounted) setState(() {});
    });

    // CRITICAL: Request focus after frame is rendered
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_searchFocusNode.hasFocus) {
        _tableFocusNode.requestFocus();
      }
    });
  }

  @override
  void didUpdateWidget(GenisletilebilirTablo<T> oldWidget) {
    if (widget.focusNode != oldWidget.focusNode) {
      // If focus node changed, we might need to handle it, but typically unlikely.
      // For simplicity, we assume focusNode doesn't change dynamically often.
      // If it did, we'd need to dispose old internal one etc.
      if (widget.focusNode != null) {
        if (_isInternalFocusNode) {
          _tableFocusNode.dispose();
          _isInternalFocusNode = false;
        }
        _tableFocusNode = widget.focusNode!;
      }
    }
    super.didUpdateWidget(oldWidget);
    // Otomatik genişletilen satırlar değiştiyse ilk satıra odaklan ve kaydır
    final newExpanded = widget.expandedIndices;
    if (newExpanded != null && newExpanded.isNotEmpty) {
      final targetIndex = newExpanded.reduce(
        (a, b) => a < b ? a : b,
      ); // En küçük index

      final dataChanged =
          oldWidget.data != widget.data ||
          oldWidget.totalRecords != widget.totalRecords;

      // CRITICAL FIX: When rows are expanded or data changes, ensure we have a focused row
      // but only if there isn't one already to avoid jumping.
      if (_focusedRowIndex == null && widget.data.isNotEmpty) {
        setState(() {
          _focusedRowIndex = targetIndex;
          _focusedDetailRowIndex = null;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            widget.onFocusedRowChanged?.call(
              widget.data[targetIndex],
              targetIndex,
            );
          }
        });
      }

      if ((_lastAutoExpandedIndex != targetIndex || dataChanged) && mounted) {
        _lastAutoExpandedIndex = targetIndex;

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;

          if (_scrollController.hasClients) {
            // Satır yüksekliği yaklaşık 60px; listeyi bu satır görünür olacak
            // şekilde kaydır.
            // Satır yüksekliği dinamik olduğu için yaklaşık bir değer kullanıyoruz
            const rowExtent = 60.0;
            final targetOffset = (targetIndex * rowExtent).clamp(
              0.0,
              _scrollController.position.maxScrollExtent,
            );

            _scrollController.animateTo(
              targetOffset,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
          }
        });
      }
    } else {
      _lastAutoExpandedIndex = null;
    }
  }

  void _changePage(int page) {
    setState(() {
      _currentPage = page;
      _expandedIndex = null; // Sayfa değişince detayı kapat
    });
    widget.onPageChanged(_currentPage, _rowsPerPage);
  }

  void _changeRowsPerPage(int? value) {
    if (value != null) {
      setState(() {
        _rowsPerPage = value;
        _currentPage = 1;
        _expandedIndex = null;
      });
      widget.onPageChanged(_currentPage, _rowsPerPage);
    }
  }

  void _toggleExpand(int index) {
    // Notify about the previously expanded row closing, if any
    if (_expandedIndex != null && _expandedIndex != index) {
      widget.onExpansionChanged?.call(_expandedIndex!, false);
    }

    final isExpanding = _expandedIndex != index;
    setState(() {
      _focusedDetailRowIndex = null; // Clear detail focus on any expand change
      if (_expandedIndex == index) {
        _expandedIndex = null;
        // Don't clear _focusedRowIndex when collapsing, keep it on the row
      } else {
        _expandedIndex = index;
        // CRITICAL: Set focused row to the expanded row for keyboard navigation
        _focusedRowIndex = index;
      }
    });

    widget.onExpansionChanged?.call(index, isExpanding);
  }

  @override
  Widget build(BuildContext context) {
    return TapRegion(
      onTapOutside: (_) => _clearAllSelections(),
      child: GestureDetector(
        onTap: () {
          // Request focus when table area is tapped
          if (!_tableFocusNode.hasFocus) {
            _tableFocusNode.requestFocus();
          }
        },
        behavior: HitTestBehavior.translucent,
        child: Focus(
          focusNode: _tableFocusNode,
          autofocus: true, // CRITICAL: Auto-focus when widget is built
          onKeyEvent: (node, event) => _handleKeyEvent(event),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Breadcrumbs
              if (widget.breadcrumbs != null &&
                  widget.breadcrumbs!.isNotEmpty) ...[
                Row(
                  children: [
                    for (int i = 0; i < widget.breadcrumbs!.length; i++) ...[
                      if (i > 0)
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Icon(
                            Icons.chevron_right_rounded,
                            size: 16,
                            color: Colors.grey,
                          ),
                        ),
                      Text(
                        widget.breadcrumbs![i],
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: i == widget.breadcrumbs!.length - 1
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: i == widget.breadcrumbs!.length - 1
                              ? const Color(0xFF2C3E50)
                              : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
              ],

              // Title
              if (widget.title.isNotEmpty) ...[
                Text(
                  widget.title,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Header Widget (Optional)
              if (widget.headerWidget != null) ...[
                widget.headerWidget!,
                const SizedBox(height: 12),
              ],

              // Toolbar
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Left Side
                  // Left Side
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            height: 40,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 2,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<int>(
                                value: _rowsPerPage,
                                icon: const Icon(
                                  Icons.keyboard_arrow_down,
                                  size: 20,
                                  color: Color(0xFF606368),
                                ),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF333333),
                                  fontSize: 14,
                                ),
                                dropdownColor: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                elevation: 4,
                                onChanged: _changeRowsPerPage,
                                items: _rowsPerPageOptions.map((e) {
                                  return DropdownMenuItem(
                                    value: e,
                                    child: Text('$e'),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                          if (widget.extraWidgets != null) ...[
                            const SizedBox(width: 16),
                            ...widget.extraWidgets!,
                          ],
                        ],
                      ),
                      if (widget.selectionWidget != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: widget.selectionWidget!,
                        ),
                    ],
                  ),

                  // Right Side
                  Flexible(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        const SizedBox(width: 16),
                        Flexible(
                          child: Container(
                            constraints: const BoxConstraints(
                              maxWidth: 250,
                              minWidth: 100,
                            ),
                            child: KeyboardListener(
                              focusNode: _keyboardListenerFocusNode,
                              onKeyEvent: (event) {
                                if (event is KeyDownEvent &&
                                    event.logicalKey ==
                                        LogicalKeyboardKey.escape) {
                                  if (_searchController.text.isNotEmpty) {
                                    _searchController.clear();
                                    _debounce?.cancel();
                                    widget.onSearch('');
                                  }
                                }
                              },
                              child: TextField(
                                controller: _searchController,
                                focusNode: _searchFocusNode,
                                textAlignVertical: TextAlignVertical.center,
                                decoration: InputDecoration(
                                  hintText: tr('common.search'),
                                  hintStyle: const TextStyle(
                                    color: Colors.grey,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  prefixIcon: const Padding(
                                    padding: EdgeInsets.only(top: 5),
                                    child: Icon(
                                      Icons.search,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  suffixIcon: _searchController.text.isNotEmpty
                                      ? IconButton(
                                          icon: const Icon(
                                            Icons.clear,
                                            size: 18,
                                            color: Colors.grey,
                                          ),
                                          onPressed: () {
                                            _searchController.clear();
                                            _debounce?.cancel();
                                            widget.onSearch('');
                                          },
                                        )
                                      : Padding(
                                          padding: const EdgeInsets.only(
                                            right: 8,
                                            top: 12,
                                          ),
                                          child: Text(
                                            tr('common.key.f3'),
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.grey.shade400,
                                            ),
                                          ),
                                        ),
                                  contentPadding: EdgeInsets.zero,
                                  enabledBorder: UnderlineInputBorder(
                                    borderSide: BorderSide(
                                      color: Colors.grey.shade300,
                                    ),
                                  ),
                                  focusedBorder: const UnderlineInputBorder(
                                    borderSide: BorderSide(
                                      color: Color(0xFF2C3E50),
                                    ),
                                  ),
                                ),
                                onSubmitted: (value) {
                                  // Trigger search immediately on Enter
                                  widget.onSearch(value.toLowerCase());
                                },
                                onChanged: (value) {
                                  if (_debounce?.isActive ?? false) {
                                    _debounce!.cancel();
                                  }
                                  _debounce = Timer(
                                    const Duration(milliseconds: 500),
                                    () {
                                      widget.onSearch(value.toLowerCase());
                                    },
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                        if (widget.actionButton != null) ...[
                          const SizedBox(width: 16),
                          widget.actionButton!,
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Table Content (Header + Body) with Horizontal Scroll
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final double totalWidth = widget.columns.fold(
                      0,
                      (sum, col) => sum + col.width,
                    );

                    final bool hasFlex = widget.columns.any(
                      (c) => c.flex != null,
                    );

                    if (hasFlex) {
                      return Column(
                        children: [
                          // Table Header
                          Container(
                            height: 50,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border(
                                bottom: BorderSide(
                                  color: Colors.grey.shade200,
                                  width: 1,
                                ),
                              ),
                            ),
                            child: Row(
                              children: widget.columns.asMap().entries.map((
                                entry,
                              ) {
                                final index = entry.key;
                                final col = entry.value;
                                final isSorted =
                                    widget.sortColumnIndex == index;

                                Widget child = InkWell(
                                  onTap: col.allowSorting
                                      ? () {
                                          if (widget.onSort != null) {
                                            widget.onSort!(
                                              index,
                                              isSorted
                                                  ? !widget.sortAscending
                                                  : true,
                                            );
                                          }
                                        }
                                      : null,
                                  child: Container(
                                    padding:
                                        widget.headerPadding ??
                                        const EdgeInsets.symmetric(
                                          horizontal: 16,
                                        ),
                                    alignment: col.alignment,
                                    child: _buildHeaderContent(
                                      column: col,
                                      isSorted: isSorted,
                                      sortAscending: widget.sortAscending,
                                      headerTextStyle: widget.headerTextStyle,
                                      headerMaxLines: widget.headerMaxLines,
                                      headerOverflow: widget.headerOverflow,
                                    ),
                                  ),
                                );

                                if (col.flex != null) {
                                  return Expanded(
                                    flex: col.flex!,
                                    child: child,
                                  );
                                }

                                return SizedBox(width: col.width, child: child);
                              }).toList(),
                            ),
                          ),

                          // Table Body (List) - Optimized with SliverList
                          Expanded(
                            child: CustomScrollView(
                              // No controller here because StickyHeader might need its own context or we share parent?
                              // Actually Standard ListView didn't have controller attached in this branch!
                              slivers: [
                                SliverList(
                                  delegate: SliverChildBuilderDelegate((
                                    context,
                                    index,
                                  ) {
                                    final item = widget.data[index];
                                    final isExpanded =
                                        widget.expandAll ||
                                        _expandedIndex == index ||
                                        (widget.expandedIndices?.contains(
                                              index,
                                            ) ??
                                            false);
                                    final isSelected =
                                        widget.isRowSelected?.call(
                                          item,
                                          index,
                                        ) ??
                                        false;

                                    return StickyHeader(
                                      header: Material(
                                        color: Colors.white,
                                        child: InkWell(
                                          onTap: () {
                                            setState(
                                              () => _focusedRowIndex = index,
                                            );

                                            widget.onFocusedRowChanged?.call(
                                              item,
                                              index,
                                            );

                                            final isDoubleTap =
                                                widget.onRowDoubleTap != null &&
                                                _consumeDoubleTap(index);
                                            if (isDoubleTap) {
                                              if (!widget.expandOnRowTap) {
                                                widget.onRowTap?.call(item);
                                              }
                                              widget.onRowDoubleTap?.call(item);
                                              return;
                                            }

                                            if (widget.expandOnRowTap) {
                                              _toggleExpand(index);
                                            } else {
                                              widget.onRowTap?.call(item);
                                            }
                                          },
                                          hoverColor: const Color(
                                            0xFF2C3E50,
                                          ).withValues(alpha: 0.02),
                                          child: Container(
                                            constraints: const BoxConstraints(
                                              minHeight: 60,
                                            ),
                                            padding:
                                                widget.rowPadding ??
                                                const EdgeInsets.symmetric(
                                                  vertical: 12,
                                                ),
                                            decoration: BoxDecoration(
                                              color:
                                                  (isExpanded ||
                                                      isSelected ||
                                                      index == _focusedRowIndex)
                                                  ? const Color(
                                                      0xFF2C3E50,
                                                    ).withValues(alpha: 0.05)
                                                  : Colors.white,
                                              border: Border(
                                                bottom: BorderSide(
                                                  color: Colors.grey.shade200,
                                                  width: 1,
                                                ),
                                              ),
                                            ),
                                            child: widget.rowBuilder(
                                              context,
                                              item,
                                              index,
                                              isExpanded,
                                              () => _toggleExpand(index),
                                            ),
                                          ),
                                        ),
                                      ),
                                      content: AnimatedSize(
                                        duration: const Duration(
                                          milliseconds: 200,
                                        ),
                                        curve: Curves.easeInOut,
                                        alignment: Alignment.topCenter,
                                        child: Container(
                                          height: isExpanded ? null : 0,
                                          width: double.infinity,
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade50,
                                            border: Border(
                                              bottom: BorderSide(
                                                color: Colors.grey.shade200,
                                                width: 1,
                                              ),
                                            ),
                                          ),
                                          child: isExpanded
                                              ? TableDetailFocusScope(
                                                  focusedDetailIndex:
                                                      index == _focusedRowIndex
                                                      ? _focusedDetailRowIndex
                                                      : null,
                                                  setFocusedDetailIndex:
                                                      (detailIndex) {
                                                        // CRITICAL: Set the detail focus when a detail row is clicked
                                                        setState(() {
                                                          _focusedRowIndex =
                                                              index;
                                                          _focusedDetailRowIndex =
                                                              detailIndex;
                                                        });
                                                      },
                                                  ensureVisibleCallback:
                                                      (context) {
                                                        Scrollable.ensureVisible(
                                                          context,
                                                          duration:
                                                              const Duration(
                                                                milliseconds:
                                                                    200,
                                                              ),
                                                          curve:
                                                              Curves.easeInOut,
                                                        );
                                                      },
                                                  child: Padding(
                                                    padding:
                                                        widget
                                                            .expandedContentPadding ??
                                                        const EdgeInsets.all(
                                                          24.0,
                                                        ),
                                                    child: widget.detailBuilder(
                                                      context,
                                                      item,
                                                    ),
                                                  ),
                                                )
                                              : const SizedBox.shrink(),
                                        ),
                                      ),
                                    );
                                  }, childCount: widget.data.length),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    }

                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minWidth: constraints.maxWidth,
                          minHeight: constraints.maxHeight,
                          maxHeight: constraints.maxHeight,
                        ),
                        child: SizedBox(
                          width: totalWidth > constraints.maxWidth
                              ? totalWidth
                              : constraints.maxWidth,
                          child: Column(
                            children: [
                              // Table Header
                              Container(
                                height: 50, // Match StandartTablo default
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border(
                                    bottom: BorderSide(
                                      color: Colors.grey.shade200,
                                      width: 1,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  children: widget.columns.asMap().entries.map((
                                    entry,
                                  ) {
                                    final index = entry.key;
                                    final col = entry.value;
                                    final isSorted =
                                        widget.sortColumnIndex == index;

                                    Widget child = InkWell(
                                      onTap: col.allowSorting
                                          ? () {
                                              if (widget.onSort != null) {
                                                widget.onSort!(
                                                  index,
                                                  isSorted
                                                      ? !widget.sortAscending
                                                      : true,
                                                );
                                              }
                                            }
                                          : null,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                        ),
                                        alignment: col.alignment,
                                        child: _buildHeaderContent(
                                          column: col,
                                          isSorted: isSorted,
                                          sortAscending: widget.sortAscending,
                                          headerTextStyle:
                                              widget.headerTextStyle,
                                          headerMaxLines: widget.headerMaxLines,
                                          headerOverflow: widget.headerOverflow,
                                        ),
                                      ),
                                    );

                                    if (col.flex != null) {
                                      return Expanded(
                                        flex: col.flex!,
                                        child: child,
                                      );
                                    }

                                    return SizedBox(
                                      width: col.width,
                                      child: child,
                                    );
                                  }).toList(),
                                ),
                              ),

                              // Table Body (List) - Optimized with SliverList
                              Expanded(
                                child: CustomScrollView(
                                  controller: _scrollController,
                                  slivers: [
                                    SliverList(
                                      delegate: SliverChildBuilderDelegate((
                                        context,
                                        index,
                                      ) {
                                        final item = widget.data[index];
                                        final isExpanded =
                                            widget.expandAll ||
                                            _expandedIndex == index ||
                                            (widget.expandedIndices?.contains(
                                                  index,
                                                ) ??
                                                false);
                                        final isSelected =
                                            widget.isRowSelected?.call(
                                              item,
                                              index,
                                            ) ??
                                            false;

                                        return Column(
                                          children: [
                                            // Main Row
                                            InkWell(
                                              onTap: () {
                                                setState(
                                                  () =>
                                                      _focusedRowIndex = index,
                                                );

                                                widget.onFocusedRowChanged
                                                    ?.call(item, index);

                                                final isDoubleTap =
                                                    widget.onRowDoubleTap !=
                                                        null &&
                                                    _consumeDoubleTap(index);
                                                if (isDoubleTap) {
                                                  if (!widget.expandOnRowTap) {
                                                    widget.onRowTap?.call(item);
                                                  }
                                                  widget.onRowDoubleTap?.call(
                                                    item,
                                                  );
                                                  return;
                                                }

                                                if (widget.expandOnRowTap) {
                                                  _toggleExpand(index);
                                                } else {
                                                  widget.onRowTap?.call(item);
                                                }
                                              },
                                              hoverColor: const Color(
                                                0xFF2C3E50,
                                              ).withValues(alpha: 0.02),
                                              child: Container(
                                                constraints:
                                                    const BoxConstraints(
                                                      minHeight: 60,
                                                    ),
                                                padding:
                                                    widget.rowPadding ??
                                                    const EdgeInsets.symmetric(
                                                      vertical: 12,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color:
                                                      (isExpanded ||
                                                          isSelected ||
                                                          index ==
                                                              _focusedRowIndex)
                                                      ? const Color(
                                                          0xFF2C3E50,
                                                        ).withValues(
                                                          alpha: 0.05,
                                                        )
                                                      : Colors.white,
                                                  border: Border(
                                                    bottom: BorderSide(
                                                      color:
                                                          Colors.grey.shade200,
                                                      width: 1,
                                                    ),
                                                  ),
                                                ),
                                                child: widget.rowBuilder(
                                                  context,
                                                  item,
                                                  index,
                                                  isExpanded,
                                                  () => _toggleExpand(index),
                                                ),
                                              ),
                                            ),

                                            // Detail Panel
                                            AnimatedSize(
                                              duration: const Duration(
                                                milliseconds: 200,
                                              ),
                                              curve: Curves.easeInOut,
                                              alignment: Alignment.topCenter,
                                              child: Container(
                                                height: isExpanded ? null : 0,
                                                width: double.infinity,
                                                decoration: BoxDecoration(
                                                  color: Colors.grey.shade50,
                                                  border: Border(
                                                    bottom: BorderSide(
                                                      color:
                                                          Colors.grey.shade200,
                                                      width: 1,
                                                    ),
                                                  ),
                                                ),
                                                child: isExpanded
                                                    ? TableDetailFocusScope(
                                                        focusedDetailIndex:
                                                            index ==
                                                                _focusedRowIndex
                                                            ? _focusedDetailRowIndex
                                                            : null,
                                                        setFocusedDetailIndex:
                                                            (detailIndex) {
                                                              // CRITICAL: Set the detail focus when a detail row is clicked
                                                              setState(() {
                                                                _focusedRowIndex =
                                                                    index;
                                                                _focusedDetailRowIndex =
                                                                    detailIndex;
                                                              });
                                                            },
                                                        ensureVisibleCallback: (context) {
                                                          Scrollable.ensureVisible(
                                                            context,
                                                            duration:
                                                                const Duration(
                                                                  milliseconds:
                                                                      200,
                                                                ),
                                                            curve: Curves
                                                                .easeInOut,
                                                          );
                                                        },
                                                        child: Padding(
                                                          padding:
                                                              widget
                                                                  .expandedContentPadding ??
                                                              const EdgeInsets.all(
                                                                24.0,
                                                              ),
                                                          child: widget
                                                              .detailBuilder(
                                                                context,
                                                                item,
                                                              ),
                                                        ),
                                                      )
                                                    : const SizedBox.shrink(),
                                              ),
                                            ),
                                          ],
                                        );
                                      }, childCount: widget.data.length),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Pagination Footer
              _buildPaginationFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaginationFooter() {
    if (widget.totalRecords == 0) return const SizedBox.shrink();

    final int effectiveRowsPerPage = _rowsPerPage;
    final int totalPages = effectiveRowsPerPage > 0
        ? (widget.totalRecords / effectiveRowsPerPage).ceil()
        : 1;

    final int startRecord = widget.totalRecords > 0
        ? ((_currentPage - 1) * effectiveRowsPerPage + 1)
        : 0;

    int endRecord = (_currentPage * effectiveRowsPerPage);
    if (endRecord > widget.totalRecords) {
      endRecord = widget.totalRecords;
    }
    if (endRecord < startRecord) {
      endRecord = startRecord;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 600;

          final showingText = Text(
            tr('common.pagination.showing')
                .replaceAll('{start}', '$startRecord')
                .replaceAll('{end}', '$endRecord')
                .replaceAll('{total}', '${widget.totalRecords}'),
            style: const TextStyle(
              color: Color(0xFF606368),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          );

          final paginationButtons = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildPageButton(
                icon: Icons.keyboard_double_arrow_left,
                onTap: _currentPage > 1 ? () => _changePage(1) : null,
              ),
              const SizedBox(width: 8),
              _buildPageButton(
                icon: Icons.keyboard_arrow_left,
                onTap: _currentPage > 1
                    ? () => _changePage(_currentPage - 1)
                    : null,
              ),
              const SizedBox(width: 8),
              ..._buildPageNumbers(totalPages),
              const SizedBox(width: 8),
              _buildPageButton(
                icon: Icons.keyboard_arrow_right,
                onTap: _currentPage < totalPages
                    ? () => _changePage(_currentPage + 1)
                    : null,
              ),
              const SizedBox(width: 8),
              _buildPageButton(
                icon: Icons.keyboard_double_arrow_right,
                onTap: _currentPage < totalPages
                    ? () => _changePage(totalPages)
                    : null,
              ),
            ],
          );

          if (isMobile) {
            return Column(
              children: [
                showingText,
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: paginationButtons,
                ),
              ],
            );
          }

          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [showingText, paginationButtons],
          );
        },
      ),
    );
  }

  List<Widget> _buildPageNumbers(int totalPages) {
    List<Widget> buttons = [];

    // Handle edge case where there are no pages
    if (totalPages < 1) return buttons;

    int startPage = _currentPage - 2;
    int endPage = _currentPage + 2;

    if (startPage < 1) {
      endPage += (1 - startPage);
      startPage = 1;
    }
    if (endPage > totalPages) {
      startPage -= (endPage - totalPages);
      endPage = totalPages;
    }
    startPage = startPage.clamp(1, totalPages);
    endPage = endPage.clamp(1, totalPages);

    for (int i = startPage; i <= endPage; i++) {
      if (i > 1) buttons.add(const SizedBox(width: 8));
      buttons.add(
        _buildPageButton(
          text: '$i',
          isActive: i == _currentPage,
          onTap: () => _changePage(i),
        ),
      );
    }
    return buttons;
  }

  Widget _buildPageButton({
    String? text,
    IconData? icon,
    VoidCallback? onTap,
    bool isActive = false,
  }) {
    return MouseRegion(
      cursor: onTap != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minWidth: 32),
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFF2C3E50) : Colors.white,
            border: Border.all(
              color: isActive ? const Color(0xFF2C3E50) : Colors.grey.shade300,
            ),
            borderRadius: BorderRadius.circular(4),
          ),
          child: text != null
              ? Text(
                  text,
                  style: TextStyle(
                    color: isActive ? Colors.white : const Color(0xFF606368),
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                )
              : Icon(
                  icon,
                  size: 18,
                  color: onTap != null
                      ? const Color(0xFF606368)
                      : Colors.grey.shade300,
                ),
        ),
      ),
    );
  }
}

class GenisletilebilirTabloKolon {
  final String label;
  final Widget? header;
  final double width;
  final Alignment alignment;

  const GenisletilebilirTabloKolon({
    required this.label,
    this.header,
    required this.width,
    this.alignment = Alignment.centerLeft,
    this.allowSorting = false,
    this.flex,
  });

  final bool allowSorting;
  final int? flex;
}

Widget _buildHeaderContent({
  required GenisletilebilirTabloKolon column,
  required bool isSorted,
  required bool sortAscending,
  TextStyle? headerTextStyle,
  int? headerMaxLines,
  TextOverflow? headerOverflow,
}) {
  if (column.header != null) {
    return column.header!;
  }

  final baseStyle = const TextStyle(
    fontWeight: FontWeight.bold,
    color: Colors.black54,
    fontSize: 15,
  );
  final effectiveStyle = headerTextStyle != null
      ? baseStyle.merge(headerTextStyle)
      : baseStyle;

  final baseText = Text(
    column.label,
    style: effectiveStyle,
    maxLines: headerMaxLines,
    overflow: headerOverflow,
  );

  if (!column.allowSorting) {
    return baseText;
  }

  final IconData sortIcon = !isSorted
      ? Icons.swap_vert_rounded
      : (sortAscending ? Icons.arrow_upward : Icons.arrow_downward);
  final bool hasLabel = column.label.trim().isNotEmpty;

  return LayoutBuilder(
    builder: (context, constraints) {
      // Ultra-narrow columns can be smaller than icon+spacing.
      // In this case, render only a compact icon to avoid RenderFlex overflow.
      if (constraints.maxWidth <= 20) {
        return Icon(sortIcon, size: 14, color: Colors.black54);
      }

      if (!hasLabel || constraints.maxWidth <= 34) {
        return Icon(sortIcon, size: 15, color: Colors.black54);
      }

      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(child: baseText),
          const SizedBox(width: 2),
          Icon(sortIcon, size: 15, color: Colors.black54),
        ],
      );
    },
  );
}
