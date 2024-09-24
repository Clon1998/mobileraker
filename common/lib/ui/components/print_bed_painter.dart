/*
 * Copyright (c) 2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:math';

import 'package:flutter/widgets.dart';

import '../../util/painter_utils.dart';

/// A custom painter that draws a print bed with a logo, grid and axis
///
/// The print bed is drawn in the coordinate system of the printer (The bed)
/// Additional elements are expected to be drawn in the printer's bed coordinates too.

abstract class PrintBedPainter extends CustomPainter {
  const PrintBedPainter({
    required this.bedWidth,
    required this.bedHeight,
    required this.bedXOffset,
    required this.bedYOffset,
    required this.backgroundColor,
    required this.logoColor,
    required this.gridColor,
    required this.axisColor,
    required this.originColors,
  });

  // The size of the bed in mm
  final double bedWidth;

  // The size of the bed in mm
  final double bedHeight;

  // The offset of the bed in mm (X-start)
  final double bedXOffset;

  // The offset of the bed in mm (Y-start)
  final double bedYOffset;

  // The color of the background
  final Color backgroundColor;

  // The color of the logo
  final Color logoColor;

  // The color of the grid
  final Color gridColor;

  // The color of the axis
  final Color axisColor;

  // The color of the origin indicators
  final ({Color x, Color y}) originColors;

  // Whether to render the logo
  bool get renderLogo;

  // Whether to render the grid
  bool get renderGrid;

  // Whether to render the axis
  bool get renderAxis;

  @override
  void paint(Canvas canvas, Size size) {
    // Before drawing anything, save the canvas state to restore it later
    final myCanvas = canvas;

    final canvasWidth = size.width;
    final canvasHeight = size.height;
    final scaleX = canvasWidth / bedWidth;
    final scaleY = canvasHeight / bedHeight;

    // logger.w('BED: $bedWidth x $bedHeight, CANVAS: $canvasWidth x $canvasHeight, SCALE: $scaleX x $scaleY');
    // logger.w('Offset: X:$bedXOffset Y:$bedYOffset');

    // Calculate the scale factor for the logo
    final double logoSize = min(canvasWidth, canvasHeight);
    final logoScale = logoSize / 512; // Assuming the original logo size is 512x512
    final logoTransform = Matrix4.identity()
      ..translate((canvasWidth - logoSize) / 2, (canvasHeight - logoSize) / 2) // Center the logo
      ..scale(logoScale, logoScale);

    final scaleMatrix = Matrix4.identity()
      ..scale(scaleX, -scaleY) // Scale X normally, but flip Y with -scaleY
      ..translate(0.0 - bedXOffset, -bedHeight - bedYOffset); // Translate to correct the Y offset

    final backgroundPaint = filledPaint(backgroundColor);
    final logoPaint = filledPaint(logoColor);
    final gridPaint = strokePaint(gridColor, 1.0);
    final axisPaint = strokePaint(axisColor, 1.0);
    final oXPaint = strokePaint(originColors.x, 2.0);
    final oYPaint = strokePaint(originColors.y, 2.0);

    // Clip the canvas to the available (UI) size
    myCanvas.clipRect(Rect.fromPoints(const Offset(0, 0), Offset(size.width, size.height)));

    // Draw Background as Surface Color
    myCanvas.drawPaint(backgroundPaint);
    if (renderLogo) myCanvas.drawPath(mrLogoPath.transform(logoTransform.storage), logoPaint);

    canvas.save();

    // Apply the scale matrix to be able to draw in klipper(bed) coordinates
    myCanvas.transform(scaleMatrix.storage);

    // Draw the background elements
    if (renderGrid) myCanvas.drawPath(constructGrid(), gridPaint);
    if (renderGrid) myCanvas.drawPath(constructGrid(50), gridPaint);
    if (renderAxis) myCanvas.drawPath(constructAxis(), axisPaint);

    // Draw Origin Indicators
    if (renderAxis) myCanvas.drawPath(constructOriginIndicator(20, true, false), oXPaint);
    if (renderAxis) myCanvas.drawPath(constructOriginIndicator(20, false, true), oYPaint);
  }

  Paint filledPaint(Color color) {
    return Paint()
      ..color = color
      ..style = PaintingStyle.fill;
  }

  Paint strokePaint(Color color, double strokeWidth) {
    return Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
  }

  /// Constructs a path for the bed axis
  Path constructAxis() {
    final p = Path();
    // X-Axis
    p.moveTo(bedXOffset, 0);
    p.lineTo(bedWidth + bedXOffset, 0);

    // Y-Axis
    p.moveTo(0, bedYOffset);
    p.lineTo(0, bedHeight + bedYOffset);

    return p;
  }

  /// Constructs a path for a grid with a distance of 10mm
  Path constructGrid([double dist = 10.0]) {
    final path = Path();

    // Calculate the start and end points for both axes
    double startX = (bedXOffset ~/ dist) * dist;
    double endX = bedWidth + bedXOffset;
    double startY = (bedYOffset ~/ dist) * dist;
    double endY = bedHeight + bedYOffset;

    // Vertical lines
    for (double x = startX; x <= endX; x += dist) {
      if (x == 0) continue;
      path.moveTo(x, bedYOffset);
      path.lineTo(x, endY);
    }

    // Horizontal lines
    for (double y = startY; y <= endY; y += dist) {
      if (y == 0) continue;
      path.moveTo(bedXOffset, y);
      path.lineTo(endX, y);
    }

    return path;
  }

  /// Constructs a path the represents origin indicators (Arrows)
  Path constructOriginIndicator(double len, [bool showX = true, bool showY = true]) {
    final path = Path();
    // final borderOffset = (bedYOffset+bedXOffset)/2 < 5.0? 5.0: 0.0;
    // Offset from x(0) and y(0) for the arrows
    const borderOffset = 5.0;

    // Where the arrow starts from the origin
    const arrowStart = 5.0;

    if (showX) {
      path.moveTo(borderOffset + arrowStart, borderOffset);
      path.lineTo(borderOffset + len + arrowStart, borderOffset);
      path.lineTo(borderOffset + len + arrowStart - 5, 5 + borderOffset);
    }

    if (showY) {
      path.moveTo(borderOffset, borderOffset + arrowStart);
      path.lineTo(borderOffset, borderOffset + len + arrowStart);
      path.lineTo(5 + borderOffset, borderOffset + len + arrowStart - 5);
    }

    return path;
  }
}
