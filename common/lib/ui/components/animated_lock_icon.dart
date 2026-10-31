/*
 * Copyright (c) 2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Padlock icon that animates its shackle when [locked] changes.
///
/// Unlocking lifts the shackle out of the body and swings it open around the right leg,
/// locking plays the same motion in reverse. Respects the surrounding [IconTheme] (size + color),
/// so it can be used as a drop-in replacement for an [Icon] (e.g. in an [IconButton]).
class AnimatedLockIcon extends StatelessWidget {
  const AnimatedLockIcon({
    super.key,
    required this.locked,
    this.size,
    this.color,
    this.duration = const Duration(milliseconds: 300),
    this.semanticLabel,
  });

  final bool locked;
  final double? size;
  final Color? color;
  final Duration duration;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final iconTheme = IconTheme.of(context);
    final effectiveSize = size ?? iconTheme.size ?? 24;
    final effectiveColor = color ?? iconTheme.color ?? Theme.of(context).colorScheme.onSurface;

    return Semantics(
      label: semanticLabel,
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: locked ? 0 : 1),
        duration: duration,
        builder: (context, progress, _) => CustomPaint(
          size: Size.square(effectiveSize),
          painter: _LockPainter(progress: progress, locked: locked, color: effectiveColor),
        ),
      ),
    );
  }
}

class _LockPainter extends CustomPainter {
  _LockPainter({required this.progress, required this.locked, required this.color});

  /// 0 = locked, 1 = unlocked
  final double progress;

  /// Target state, used to know which direction the animation runs
  final bool locked;
  final Color color;

  static const double _maxLift = 1;
  static final double _maxSwing = 14 * math.pi / 180;
  static const double _minScaleDelta = 0.2;

  @override
  void paint(Canvas canvas, Size size) {
    // All coordinates are based on a 24x24 grid, matching material icons
    canvas.scale(size.width / 24, size.height / 24);

    // Quick dip to 0.8 followed by an ease back to 1 (like the scale of a switched icon), in both directions
    final traveled = locked ? 1 - progress : progress;
    final pulse = traveled < 0.25
        ? 1 - _minScaleDelta * Curves.easeOut.transform(traveled / 0.25)
        : 1 - _minScaleDelta * (1 - Curves.easeOut.transform((traveled - 0.25) / 0.75));
    canvas.translate(12, 12);
    canvas.scale(pulse);
    canvas.translate(-12, -12);

    final lift = Curves.easeOut.transform(const Interval(0, 0.5).transform(progress)) * _maxLift;
    final swing = Curves.easeOutBack.transform(const Interval(0.35, 1).transform(progress)) * _maxSwing;

    // Draw opaque into a single layer and apply the alpha once. Otherwise the parts where the shackle overlaps
    // the body would be darker for translucent colors (e.g. disabled IconButtons).
    final opaque = color.withValues(alpha: 1);
    canvas.saveLayer(const Rect.fromLTRB(0, -4, 24, 24), Paint()..color = Color.fromRGBO(0, 0, 0, color.a));

    // Shackle: the right leg reaches into the body to stay anchored while lifted, the left one ends at the body's
    // top edge so it comes free when opened
    final shackle = Path()
      ..moveTo(7.5, 10)
      ..lineTo(7.5, 8.25)
      ..arcToPoint(const Offset(16.5, 8.25), radius: const Radius.circular(4.5))
      ..lineTo(16.5, 13);

    canvas.save();
    canvas.translate(16.5, 10 - lift);
    canvas.rotate(swing);
    canvas.translate(-16.5, -10);
    canvas.drawPath(
      shackle,
      Paint()
        ..color = opaque
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round,
    );
    canvas.restore();

    // Body with a keyhole cut out
    final body = Path.combine(
      PathOperation.difference,
      Path()..addRRect(RRect.fromLTRBR(3.5, 10, 20.5, 22, const Radius.circular(3))),
      Path()..addOval(Rect.fromCircle(center: const Offset(12, 16), radius: 1.9)),
    );
    canvas.drawPath(body, Paint()..color = opaque);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_LockPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.locked != locked || oldDelegate.color != color;
}
