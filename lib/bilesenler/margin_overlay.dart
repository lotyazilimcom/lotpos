import 'package:flutter/material.dart';
import '../yardimcilar/ceviri/ceviri_servisi.dart';

/// Chrome stili "sonsuz" ve profesyonel margin ayarlama widget'ı.
class MarginOverlay extends StatefulWidget {
  final double marginTop;
  final double marginBottom;
  final double marginLeft;
  final double marginRight;
  final Rect pageRect; // Sayfanın önizleme alanındaki tam konumu
  final double referencePageWidthMm; // Sayfanın gerçek fiziksel genişliği (mm)
  final Function(double top, double bottom, double left, double right)
  onMarginsChanged;

  const MarginOverlay({
    super.key,
    required this.marginTop,
    required this.marginBottom,
    required this.marginLeft,
    required this.marginRight,
    required this.pageRect,
    this.referencePageWidthMm = 210.0, // Default A4 Portrait
    required this.onMarginsChanged,
  });

  @override
  State<MarginOverlay> createState() => _MarginOverlayState();
}

class _MarginOverlayState extends State<MarginOverlay> {
  late double _marginTop;
  late double _marginBottom;
  late double _marginLeft;
  late double _marginRight;

  String? _activeHandle;
  String? _hoveredHandle;

  @override
  void initState() {
    super.initState();
    _marginTop = widget.marginTop;
    _marginBottom = widget.marginBottom;
    _marginLeft = widget.marginLeft;
    _marginRight = widget.marginRight;
  }

  // mm to pixel conversion using the actual reference width
  double _mmToPx(double mm) =>
      mm * (widget.pageRect.width / widget.referencePageWidthMm);
  double _pxToMm(double px) =>
      px / (widget.pageRect.width / widget.referencePageWidthMm);

  @override
  Widget build(BuildContext context) {
    // Çizgi konumları (Ekran koordinatlarında)
    final double topLineY = widget.pageRect.top + _mmToPx(_marginTop);
    final double bottomLineY = widget.pageRect.bottom - _mmToPx(_marginBottom);
    final double leftLineX = widget.pageRect.left + _mmToPx(_marginLeft);
    final double rightLineX = widget.pageRect.right - _mmToPx(_marginRight);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Üst Çizgi
        _buildLine(
          isVertical: false,
          pos: topLineY,
          labelValue: _marginTop,
          handle: 'top',
          labelPos: widget.pageRect.left + (widget.pageRect.width / 2) - 25,
          onDrag: (delta) {
            setState(
              () => _marginTop = (_pxToMm(
                topLineY - widget.pageRect.top + delta,
              )).clamp(0, 80),
            );
          },
        ),
        // Alt Çizgi
        _buildLine(
          isVertical: false,
          pos: bottomLineY,
          labelValue: _marginBottom,
          handle: 'bottom',
          labelPos: widget.pageRect.left + (widget.pageRect.width / 2) - 25,
          onDrag: (delta) {
            setState(
              () => _marginBottom = (_pxToMm(
                widget.pageRect.bottom - bottomLineY - delta,
              )).clamp(0, 80),
            );
          },
        ),
        // Sol Çizgi
        _buildLine(
          isVertical: true,
          pos: leftLineX,
          labelValue: _marginLeft,
          handle: 'left',
          labelPos: widget.pageRect.top + (widget.pageRect.height / 2) - 15,
          onDrag: (delta) {
            setState(
              () => _marginLeft = (_pxToMm(
                leftLineX - widget.pageRect.left + delta,
              )).clamp(0, 80),
            );
          },
        ),
        // Sağ Çizgi
        _buildLine(
          isVertical: true,
          pos: rightLineX,
          labelValue: _marginRight,
          handle: 'right',
          labelPos: widget.pageRect.top + (widget.pageRect.height / 2) - 15,
          onDrag: (delta) {
            setState(
              () => _marginRight = (_pxToMm(
                widget.pageRect.right - rightLineX - delta,
              )).clamp(0, 80),
            );
          },
        ),
      ],
    );
  }

  Widget _buildLine({
    required bool isVertical,
    required double pos,
    required double labelValue,
    required String handle,
    required double labelPos,
    required Function(double) onDrag,
  }) {
    final bool isActive = _activeHandle == handle;
    final bool isHovered = _hoveredHandle == handle;
    final Color color = (isActive || isHovered)
        ? const Color(0xFF1A73E8)
        : const Color(0xFF323639).withValues(alpha: 0.6);

    return Positioned(
      left: isVertical ? pos - 10 : 0,
      top: isVertical ? 0 : pos - 10,
      right: isVertical ? null : 0,
      bottom: isVertical ? 0 : null,
      child: MouseRegion(
        cursor: isVertical
            ? SystemMouseCursors.resizeColumn
            : SystemMouseCursors.resizeRow,
        onEnter: (_) => setState(() => _hoveredHandle = handle),
        onExit: (_) => setState(() => _hoveredHandle = null),
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onPanStart: (_) => setState(() => _activeHandle = handle),
          onPanUpdate: (d) => onDrag(isVertical ? d.delta.dx : d.delta.dy),
          onPanEnd: (_) {
            setState(() => _activeHandle = null);
            widget.onMarginsChanged(
              _marginTop,
              _marginBottom,
              _marginLeft,
              _marginRight,
            );
          },
          child: Container(
            width: isVertical ? 21 : double.infinity,
            height: isVertical ? double.infinity : 21,
            color: Colors.transparent,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                // Sonsuz Kesik Çizgi
                SizedBox.expand(
                  child: CustomPaint(
                    painter: _ChromeDashedPainter(
                      isVertical: isVertical,
                      color: color,
                      isActive: isActive,
                    ),
                  ),
                ),
                // mm Label (Sayfanın ortasına hizalı)
                Positioned(
                  left: isVertical ? 15 : labelPos,
                  top: isVertical ? labelPos : 15,
                  child: _buildLabel(labelValue, color, isActive || isHovered),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(double val, Color color, bool active) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(2),
        border: Border.all(
          color: active ? color : Colors.grey.shade400,
          width: 0.5,
        ),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 2)],
      ),
      child: Text(
        val.toStringAsFixed(1) + tr('common.unit.mm'),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: active ? color : Colors.black87,
        ),
      ),
    );
  }
}

class _ChromeDashedPainter extends CustomPainter {
  final bool isVertical;
  final Color color;
  final bool isActive;
  _ChromeDashedPainter({
    required this.isVertical,
    required this.color,
    required this.isActive,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = isActive ? 1.5 : 1
      ..style = PaintingStyle.stroke;
    const dashW = 4.0, dashS = 4.0;
    if (isVertical) {
      double y = 0;
      while (y < size.height) {
        canvas.drawLine(
          Offset(size.width / 2, y),
          Offset(size.width / 2, y + dashW),
          paint,
        );
        y += dashW + dashS;
      }
    } else {
      double x = 0;
      while (x < size.width) {
        canvas.drawLine(
          Offset(x, size.height / 2),
          Offset(x + dashW, size.height / 2),
          paint,
        );
        x += dashW + dashS;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => true;
}
