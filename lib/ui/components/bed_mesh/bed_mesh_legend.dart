/*
 * Copyright (c) 2024. Patrick Schmidt.
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

  const BedMeshLegend({
    super.key,
    required this.valueRange,
    this.marginTooltip = const EdgeInsets.all(8),
  });

  @override
  State createState() => _BedMeshLegendState();
}

class _BedMeshLegendState extends State<BedMeshLegend> {
  double? _value;
  OverlayEntry? _overlayEntry;

  late final NumberFormat formatter = NumberFormat('#0.000mm', context.locale.toStringWithSeparator());

  @override
  Widget build(BuildContext context) {
    LinearGradient gradient = gradientForRange(widget.valueRange.$1, widget.valueRange.$2, true);

    // min: zMin, max: zMax
    return GestureDetector(
      onVerticalDragUpdate: (details) => _showTooltip(details.localPosition.dy),
      onTapDown: (details) {
        _showTooltip(details.localPosition.dy);
      },
      onTapUp: (details) => removeOverlay(),
      onVerticalDragEnd: (details) => removeOverlay(),
      child: AnimatedContainer(
        duration: kThemeAnimationDuration,
        width: 30,
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }

  void _showTooltip(double dy) {
    RenderBox box = context.findRenderObject() as RenderBox;

    // Prevent dragging outside of the box
    dy = dy.clamp(0, box.size.height);

    double percent = 1 - (dy / box.size.height);
    double value = widget.valueRange.$1 + (widget.valueRange.$2 - widget.valueRange.$1) * percent;
    _value = value;
    removeOverlay();

    var start = box.localToGlobal(const Offset(0, 0));

    _overlayEntry = _createOverlayEntry(start, box.size, dy);
    Overlay.of(context).insert(_overlayEntry!);
  }

  OverlayEntry _createOverlayEntry(Offset boxStartGlobal, Size boxSize, double dy) {
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

    double centerHorizontal = boxStartGlobal.dx + (boxSize.width) / 2;

    // calculate the postion of the widget from the right edge of the screen
    // This can be used to show the tooltip on the left side of the widget
    double right = screenSize.width - boxStartGlobal.dx;

    // calculate the postion of the widget from the left edge of the screen
    // This can be used to show the tooltip on the right side of the widget
    double left = boxStartGlobal.dx + boxSize.width;

    // Calculate the position of the tooltip
    double top = boxStartGlobal.dy + dy - tooltipSize.height / 2;

    return OverlayEntry(
      builder: (_) => Positioned(
        // right: right,
        left: left,
        top: top,
        child: Material(
          color: tooltipBackground, // Set the background color of the tooltip
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
