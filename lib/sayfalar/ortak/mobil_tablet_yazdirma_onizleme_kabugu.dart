import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../yardimcilar/ceviri/ceviri_servisi.dart';

class MobilTabletYazdirmaOnizlemeKabugu extends StatefulWidget {
  final String title;
  final String subtitle;
  final Widget preview;
  final List<Widget> settingsChildren;
  final Widget? statusCard;
  final String summaryLabel;
  final String summaryValue;
  final String summaryHint;
  final String primaryActionLabel;
  final IconData primaryActionIcon;
  final VoidCallback? onPrimaryAction;
  final String secondaryActionLabel;
  final VoidCallback onSecondaryAction;
  final VoidCallback onBack;
  final Color accentColor;

  const MobilTabletYazdirmaOnizlemeKabugu({
    super.key,
    required this.title,
    required this.subtitle,
    required this.preview,
    required this.settingsChildren,
    required this.summaryLabel,
    required this.summaryValue,
    required this.summaryHint,
    required this.primaryActionLabel,
    required this.primaryActionIcon,
    required this.onPrimaryAction,
    required this.secondaryActionLabel,
    required this.onSecondaryAction,
    required this.onBack,
    this.statusCard,
    this.accentColor = const Color(0xFF2C3E50),
  });

  @override
  State<MobilTabletYazdirmaOnizlemeKabugu> createState() =>
      _MobilTabletYazdirmaOnizlemeKabuguState();
}

class _MobilTabletYazdirmaOnizlemeKabuguState
    extends State<MobilTabletYazdirmaOnizlemeKabugu> {
  bool _ayarlarAcik = false;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final padding = MediaQuery.paddingOf(context);
    final collapsedHeight = size.width >= 700 ? 124.0 : 104.0;
    final expandedHeight = math.min(
      size.height * (size.width >= 700 ? 0.6 : 0.68),
      size.width >= 700 ? 560.0 : 620.0,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            AnimatedPadding(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              padding: EdgeInsets.fromLTRB(
                8,
                8,
                8,
                (_ayarlarAcik ? expandedHeight : collapsedHeight) + 10,
              ),
              child: Column(
                children: [
                  _buildHeader(),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: widget.accentColor.withValues(alpha: 0.08),
                            blurRadius: 24,
                            offset: const Offset(0, 14),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: widget.preview,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                height: _ayarlarAcik ? expandedHeight : collapsedHeight,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x190F172A),
                      blurRadius: 28,
                      offset: Offset(0, -8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    InkWell(
                      mouseCursor: WidgetStateMouseCursor.clickable,
                      onTap: _toggleSettings,
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          16,
                          _ayarlarAcik ? 10 : 8,
                          16,
                          _ayarlarAcik ? 14 : 10,
                        ),
                        child: _buildSheetHeader(isCompact: !_ayarlarAcik),
                      ),
                    ),
                    if (_ayarlarAcik) ...[
                      Divider(height: 1, color: Colors.grey.shade200),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (widget.statusCard != null) ...[
                                widget.statusCard!,
                                const SizedBox(height: 14),
                              ],
                              ...widget.settingsChildren,
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          16,
                          0,
                          16,
                          math.max(16, padding.bottom),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: widget.onSecondaryAction,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: widget.accentColor,
                                  side: BorderSide(
                                    color: widget.accentColor.withValues(
                                      alpha: 0.28,
                                    ),
                                  ),
                                  minimumSize: const Size.fromHeight(48),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: Text(widget.secondaryActionLabel),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: SizedBox(
                                height: 48,
                                child: _buildPrimaryButton(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: widget.accentColor.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildCircleIconButton(
            icon: Icons.arrow_back_ios_new_rounded,
            onPressed: widget.onBack,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          TextButton.icon(
            onPressed: _toggleSettings,
            icon: Icon(
              _ayarlarAcik
                  ? Icons.keyboard_arrow_down_rounded
                  : Icons.tune_rounded,
              size: 18,
            ),
            label: Text(
              tr('nav.settings'),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            style: TextButton.styleFrom(
              foregroundColor: widget.accentColor,
              backgroundColor: widget.accentColor.withValues(alpha: 0.08),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              minimumSize: const Size(0, 42),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSheetHeader({required bool isCompact}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 42,
          height: 5,
          decoration: BoxDecoration(
            color: Colors.grey.shade300,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        SizedBox(height: isCompact ? 8 : 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(child: _buildSummary(isCompact: isCompact)),
            const SizedBox(width: 10),
            SizedBox(
              height: isCompact ? 42 : 48,
              child: _buildPrimaryButton(isCompact: isCompact),
            ),
            const SizedBox(width: 8),
            _buildSettingsToggle(isCompact: isCompact),
          ],
        ),
      ],
    );
  }

  Widget _buildSummary({bool isCompact = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Container(
              width: isCompact ? 30 : 34,
              height: isCompact ? 30 : 34,
              decoration: BoxDecoration(
                color: widget.accentColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.print_rounded,
                color: widget.accentColor,
                size: isCompact ? 16 : 18,
              ),
            ),
            SizedBox(width: isCompact ? 8 : 10),
            Expanded(
              child: Text(
                widget.summaryLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: isCompact ? 12 : 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1F2937),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: isCompact ? 6 : 10),
        Text(
          widget.summaryValue,
          maxLines: isCompact ? 2 : 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: isCompact ? 12.5 : 15,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
            height: 1.15,
          ),
        ),
        if (!isCompact) ...[
          const SizedBox(height: 4),
          Text(
            widget.summaryHint,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              height: 1.35,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSettingsToggle({bool isCompact = false}) {
    return Material(
      color: Colors.grey.shade100,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        mouseCursor: WidgetStateMouseCursor.clickable,
        onTap: _toggleSettings,
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: isCompact ? 42 : 48,
          height: isCompact ? 42 : 48,
          child: Icon(
            _ayarlarAcik
                ? Icons.keyboard_arrow_down_rounded
                : Icons.keyboard_arrow_up_rounded,
            color: widget.accentColor,
          ),
        ),
      ),
    );
  }

  Widget _buildPrimaryButton({bool isCompact = false}) {
    return FilledButton.icon(
      onPressed: widget.onPrimaryAction,
      icon: Icon(widget.primaryActionIcon, size: isCompact ? 18 : 20),
      label: Text(
        widget.primaryActionLabel,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      style: FilledButton.styleFrom(
        backgroundColor: widget.accentColor,
        foregroundColor: Colors.white,
        minimumSize: Size(0, isCompact ? 42 : 48),
        padding: EdgeInsets.symmetric(
          horizontal: isCompact ? 12 : 18,
          vertical: isCompact ? 10 : 14,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  Widget _buildCircleIconButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: Colors.grey.shade100,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        mouseCursor: WidgetStateMouseCursor.clickable,
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: 46,
          height: 46,
          child: Icon(icon, color: widget.accentColor, size: 18),
        ),
      ),
    );
  }

  void _toggleSettings() {
    setState(() {
      _ayarlarAcik = !_ayarlarAcik;
    });
  }
}
