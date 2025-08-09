/*
 * Copyright (c) 2024-2025. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:ui' as ui;

import 'package:easy_localization/easy_localization.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';
import 'package:mobileraker/ui/components/bed_mesh/bed_mesh_plot.dart';

class BedMeshLegend extends StatefulWidget {
  final (double, double) valueRange;
  final EdgeInsets marginTooltip;
  final Axis axis;

  const BedMeshLegend({
    super.key,
    required this.valueRange,
    this.marginTooltip = const EdgeInsets.all(8),
    this.axis = Axis.vertical,
  });

  @override
  State createState() => _BedMeshLegendState();
}

class _BedMeshLegendState extends State<BedMeshLegend> {
  double? _value;
  OverlayEntry? _overlayEntry;

  late final NumberFormat formatter = NumberFormat('#0.000mm', context.locale.toStringWithSeparator());

  bool get _isVertical => widget.axis == Axis.vertical;

  @override
  Widget build(BuildContext context) {
    LinearGradient gradient = gradientForRange(
      widget.valueRange.$1,
      widget.valueRange.$2,
      inverse: _isVertical,
      axis: widget.axis,
    );

    return GestureDetector(
      onVerticalDragUpdate: _isVertical ? (details) => _showTooltip(details.localPosition.dy) : null,
      onHorizontalDragUpdate: _isVertical ? null : (details) => _showTooltip(details.localPosition.dx),
      onTapDown: (details) {
        final position = _isVertical ? details.localPosition.dy : details.localPosition.dx;
        _showTooltip(position);
      },
      onTapUp: (details) => removeOverlay(),
      onVerticalDragEnd: _isVertical ? (details) => removeOverlay() : null,
      onHorizontalDragEnd: _isVertical ? null : (details) => removeOverlay(),
      child: AnimatedContainer(
        duration: kThemeAnimationDuration,
        width: _isVertical ? 30 : null,
        height: _isVertical ? null : 30,
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }

  void _showTooltip(double position) {
    RenderBox box = context.findRenderObject() as RenderBox;

    // Prevent dragging outside of the box
    final maxPosition = _isVertical ? box.size.height : box.size.width;
    position = position.clamp(0, maxPosition);

    // Calculate percentage based on orientation
    double percent;
    if (_isVertical) {
      percent = 1 - (position / box.size.height); // Vertical: top = max, bottom = min
    } else {
      percent = position / box.size.width; // Horizontal: left = min, right = max
    }

    double value = widget.valueRange.$1 + (widget.valueRange.$2 - widget.valueRange.$1) * percent;
    _value = value;
    removeOverlay();

    var start = box.localToGlobal(const Offset(0, 0));

    _overlayEntry = _createOverlayEntry(start, box.size, position);
    Overlay.of(context).insert(_overlayEntry!);
  }

  OverlayEntry _createOverlayEntry(Offset boxStartGlobal, Size boxSize, double position) {
    // Get the size of the screen
    final screenSize = MediaQuery.sizeOf(context);

    var themeData = Theme.of(context);

    Color tooltipBackground, tooltipForeground;

    if (themeData.colorScheme.brightness == Brightness.light) {
      tooltipBackground = Colors.black;
      tooltipForeground = Colors.white;
    } else {
      tooltipBackground = Colors.white.darken(2);
      tooltipForeground = Colors.black;
    }

    TextStyle textStyle = TextStyle(color: tooltipForeground);

    // Create a text widget to measure the size of the tooltip
    final textWidget = Text(formatter.format(_value), style: textStyle);

    // Get the size of the tooltip
    final textPainter = TextPainter(
      text: TextSpan(text: textWidget.data, style: textWidget.style),
      maxLines: textWidget.maxLines,
      textDirection: ui.TextDirection.ltr,
    );

    final Size tooltipSize;
    try {
      textPainter.layout(maxWidth: screenSize.width);
      tooltipSize =
          Size(textPainter.width + widget.marginTooltip.horizontal, textPainter.height + widget.marginTooltip.vertical);
    } finally {
      textPainter.dispose();
    }

    // Calculate tooltip position based on orientation
    double tooltipLeft, tooltipTop;

    if (_isVertical) {
      // Vertical legend: tooltip appears to the right/left
      double centerVertical = boxStartGlobal.dy + position - tooltipSize.height / 2;
      double left = boxStartGlobal.dx + boxSize.width;

      tooltipLeft = left;
      tooltipTop = centerVertical;
    } else {
      // Horizontal legend: tooltip appears above/below
      double centerHorizontal = boxStartGlobal.dx + position - tooltipSize.width / 2;
      double top = boxStartGlobal.dy - tooltipSize.height - 8; // 8px gap above

      // If tooltip would go off screen top, show it below instead
      if (top < 0) {
        top = boxStartGlobal.dy + boxSize.height + 8; // 8px gap below
      }

      tooltipLeft = centerHorizontal.clamp(0, screenSize.width - tooltipSize.width);
      tooltipTop = top;
    }

    return OverlayEntry(
      builder: (_) => Positioned(
        left: tooltipLeft,
        top: tooltipTop,
        child: Material(
          color: tooltipBackground,
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: widget.marginTooltip,
            child: textWidget,
          ),
        ),
      ),
    );
  }

  void removeOverlay() {
    if (_overlayEntry != null) _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  void dispose() {
    removeOverlay();
    super.dispose();
  }
}