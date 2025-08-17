/*
 * Copyright (c) 2024-2025. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:async';
import 'dart:ui' as ui;

import 'package:common/data/dto/machine/bed_mesh/bed_mesh.dart';
import 'package:common/ui/components/print_bed_painter.dart';
import 'package:common/util/extensions/linear_gradient_extension.dart';
import 'package:common/util/logger.dart';
import 'package:common/util/num_scaler.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';
import 'package:touchable/touchable.dart';

class BedMeshPlot extends StatefulWidget {
  final BedMesh? bedMesh;
  final (double, double) bedMin; // values from config
  final (double, double) bedMax; // values from config
  final bool isProbed;
  final bool interactive;

  const BedMeshPlot({
    super.key,
    required this.bedMesh,
    required this.bedMin,
    required this.bedMax,
    this.isProbed = true,
    this.interactive = false,
  });

  @override
  State<BedMeshPlot> createState() => _BedMeshPlotState();
}

class _BedMeshPlotState extends State<BedMeshPlot> {
  OverlayEntry? _overlayEntry;
  final EdgeInsets _marginTooltip = const EdgeInsets.all(8);
  Timer? _hideTimer;

  @override
  Widget build(BuildContext context) {
    if (widget.bedMesh?.profileName?.isNotEmpty != true) {
      return Center(child: const Text('bottom_sheets.bedMesh.no_mesh_loaded').tr());
    }

    var meshCords = (widget.isProbed) ? widget.bedMesh!.probedCoordinates : widget.bedMesh!.meshCoordinates;
    var zRange = (widget.isProbed) ? widget.bedMesh!.zValueRangeProbed : widget.bedMesh!.zValueRangeMesh;

    NumScaler scaler = NumScaler(originMin: zRange.$1, originMax: zRange.$2, targetMin: 0, targetMax: 1);

    // Theme stuff
    var themeData = Theme.of(context);

    // Define the gradients
    LinearGradient gradient = gradientForRange(zRange.$1, zRange.$2, scaler: scaler);

    return AspectRatio(
      aspectRatio: (widget.bedMax.$1 - widget.bedMin.$1) / (widget.bedMax.$2 - widget.bedMin.$2),
      child: CanvasTouchDetector(
        gesturesToOverride: widget.interactive? const [
          GestureType.onTapDown,
          GestureType.onTapUp,
          GestureType.onPanUpdate,
          GestureType.onPanEnd,
          GestureType.onLongPressStart,
        ]:[],
        builder: (context) => CustomPaint(
          painter: _BedMeshPainter(
            bedWidth: widget.bedMax.$1 - widget.bedMin.$1,
            bedHeight: widget.bedMax.$2 - widget.bedMin.$2,
            bedXOffset: widget.bedMin.$1,
            bedYOffset: widget.bedMin.$2,
            bedMesh: widget.bedMesh!,
            isProbed: widget.isProbed,
            gradient: gradient,
            scaler: scaler,
            backgroundColor: themeData.colorScheme.surface,
            logoColor: themeData.colorScheme.onSurface.withOpacity(0.05),
            gridColor: themeData.disabledColor.withOpacity(0.1),
            axisColor: themeData.disabledColor.withOpacity(0.5),
            originColors: (x: Colors.red, y: Colors.blue),
            context: context,
            onShowTooltip: _showTooltip,
            onHideTooltip: _removeOverlay,
          ),
        ),
      ),
    );
  }

  void _showTooltip(double x, double y, double z, Offset globalPosition) {
    _removeOverlay();

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
    NumberFormat formatterXY = NumberFormat('#0.00mm', context.locale.toStringWithSeparator());
    NumberFormat formatterZ = NumberFormat('#0.0000mm', context.locale.toStringWithSeparator());

    // Create tooltip content
    String tooltipText = 'X: ${formatterXY.format(x)}\nY: ${formatterXY.format(y)}\nZ: ${formatterZ.format(z)}';

    // Calculate tooltip size
    final textPainter = TextPainter(
      text: TextSpan(text: tooltipText, style: textStyle),
      textDirection: ui.TextDirection.ltr,
    );

    final Size tooltipSize;
    try {
      textPainter.layout(maxWidth: screenSize.width * 0.8);
      tooltipSize = Size(textPainter.width + _marginTooltip.horizontal, textPainter.height + _marginTooltip.vertical);
    } finally {
      textPainter.dispose();
    }

    // Calculate tooltip position with screen edge protection
    double left = globalPosition.dx - tooltipSize.width / 2;
    double top = globalPosition.dy - tooltipSize.height - 10; // 10px above the point

    // Keep tooltip within screen bounds
    left = left.clamp(8.0, screenSize.width - tooltipSize.width - 8.0);
    top = top.clamp(8.0, screenSize.height - tooltipSize.height - 8.0);

    _overlayEntry = OverlayEntry(
      builder: (_) => Positioned(
        left: left,
        top: top,
        child: Material(
          color: tooltipBackground,
          borderRadius: BorderRadius.circular(4),
          elevation: 4,
          child: Padding(
            padding: _marginTooltip,
            child: Text(tooltipText, style: textStyle),
          ),
        ),
      ),
    );

    _resetTimer();
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _resetTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 2), _removeOverlay);
  }

  void _removeOverlay() {
    _hideTimer?.cancel();
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _removeOverlay();
    super.dispose();
  }
}

LinearGradient gradientForRange(double min, double max, {bool inverse = false, Axis axis = Axis.vertical, NumScaler? scaler}) {
  scaler ??= NumScaler(originMin: min, originMax: max, targetMin: 0, targetMax: 1);
  assert(scaler.targetMin == 0 && scaler.targetMax == 1, 'Target min and max must be 0 and 1');
  // Stops must be equal to colors length and should go from 0 (min) to 1 (max) that's why we scale...

  if (min == 0 && max == 0) {
    return LinearGradient(
      begin: _getGradientBegin(axis, inverse),
      end: _getGradientEnd(axis, inverse),
      colors: const [Colors.blue, Colors.red],
    );
  }

  return LinearGradient(
    begin: _getGradientBegin(axis, inverse),
    end: _getGradientEnd(axis, inverse),
    colors: [if (min < 0) Colors.blue, Colors.white, if (max > 0) Colors.red],
    stops: [
      scaler.scale(min).toDouble(),
      if (min < 0 && max > 0) scaler.scale(0).toDouble(),
      scaler.scale(max).toDouble(),
    ],
  );
}

Alignment _getGradientBegin(Axis axis, bool inverse) {
  if (axis == Axis.vertical) {
    return inverse ? Alignment.bottomCenter : Alignment.topCenter;
  }
  return inverse ? Alignment.centerRight : Alignment.centerLeft;
}

Alignment _getGradientEnd(Axis axis, bool inverse) {
  if (axis == Axis.vertical) {
    return inverse ? Alignment.topCenter : Alignment.bottomCenter;
  }
  return inverse ? Alignment.centerLeft : Alignment.centerRight;
}

class _BedMeshPainter extends PrintBedPainter {
  const _BedMeshPainter({
    required super.bedWidth,
    required super.bedHeight,
    required super.bedXOffset,
    required super.bedYOffset,
    required this.context,
    required this.isProbed,
    required this.bedMesh,
    required this.scaler,
    required this.gradient,
    required super.backgroundColor,
    required super.logoColor,
    required super.gridColor,
    required super.axisColor,
    required super.originColors,
    required this.onShowTooltip,
    required this.onHideTooltip,
  });

  @override
  final renderLogo = true;
  @override
  final renderGrid = true;
  @override
  final renderAxis = true;

  final BuildContext context;
  final bool isProbed;
  final BedMesh bedMesh;
  final NumScaler scaler;
  final LinearGradient gradient;
  final Function(double x, double y, double z, Offset globalPosition) onShowTooltip;
  final VoidCallback onHideTooltip;

  @override
  void paint(Canvas canvas, Size size) {
    TouchyCanvas myCanvas = TouchyCanvas(context, canvas);

    super.paint(canvas, size);

    var meshCords = isProbed ? bedMesh.probedCoordinates : bedMesh.meshCoordinates;
    var meshParams = bedMesh.activeProfile!.meshParams;

    // Determine the distance between two points in x and y direction
    final xCount = isProbed ? meshParams.xCount : (meshParams.xCount - 1) * (meshParams.meshXPPS + 1) + 1;
    final yCount = isProbed ? meshParams.yCount : (meshParams.yCount - 1) * (meshParams.meshYPPS + 1) + 1;

    final xStep = (meshParams.maxX - meshParams.minX) / (xCount - 1);
    final yStep = (meshParams.maxY - meshParams.minY) / (yCount - 1);

    // Log the xCount, yCount, actualXCount, actualYCount, xStep, yStep
    talker.info(
      'BedMeshPlot: total:${meshCords.length} xCount: $xCount, yCount: $yCount, xStep: $xStep, yStep: $yStep',
    );

    for (var ([x, y, z]) in meshCords) {
      final zColor = gradient.getColorAtPosition(scaler.scale(z).toDouble());

      myCanvas.drawRect(
        Rect.fromCenter(center: Offset(x, y), width: xStep, height: yStep),
        filledPaint(zColor),
        onTapDown: (details) => _showTooltipForPoint(x, y, z, details.localPosition),
        // onTapUp: (_) => onHideTooltip(),
        // onPanEnd: (_) => onHideTooltip(),
        onPanUpdate: (details) => _showTooltipForPoint(x, y, z, details.localPosition),
        // onPanUpdate: (details) => talker.info("XXX-$details"),
        onLongPressStart: (_) => talker.info("LongPressStart"),
        onLongPressMoveUpdate: (details) => talker.info("Rofl-$details"),
      );
    }

    canvas.restore();
  }

  void _showTooltipForPoint(double x, double y, double z, Offset localPosition) {
    RenderBox box = context.findRenderObject() as RenderBox;
    Offset globalPosition = box.localToGlobal(localPosition);

    // Convert canvas coordinates back to bed coordinates
    double bedX = x + bedXOffset;
    double bedY = y + bedYOffset;

    onShowTooltip(bedX, bedY, z, globalPosition);
  }

  @override
  bool shouldRepaint(_BedMeshPainter oldDelegate) {
    return oldDelegate.bedMesh != bedMesh || oldDelegate.isProbed != isProbed || oldDelegate.gradient != gradient;
  }
}
