/*
 * Copyright (c) 2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:flutter/material.dart';

/// An [InteractiveViewer] that additionally supports a smooth double tap zoom, like common video/photo apps.
///
/// Double tapping while not zoomed animates to [doubleTapScale] centered on the tapped point,
/// double tapping while zoomed (by double tap or pinch) animates back to the unzoomed view.
class DoubleTapZoomViewer extends StatefulWidget {
  const DoubleTapZoomViewer({
    super.key,
    required this.child,
    this.minScale = 1,
    this.maxScale = 10,
    this.doubleTapScale = 2.5,
    this.duration = const Duration(milliseconds: 250),
    this.curve = Curves.easeOutCubic,
  });

  final Widget child;
  final double minScale;
  final double maxScale;
  final double doubleTapScale;
  final Duration duration;
  final Curve curve;

  @override
  State<DoubleTapZoomViewer> createState() => _DoubleTapZoomViewerState();
}

class _DoubleTapZoomViewerState extends State<DoubleTapZoomViewer> with SingleTickerProviderStateMixin {
  final TransformationController _transformationController = TransformationController();
  late final AnimationController _animationController = AnimationController(vsync: this, duration: widget.duration)
    ..addListener(_onAnimate);
  Animation<Matrix4>? _animation;
  Offset? _doubleTapPosition;

  void _onAnimate() {
    final animation = _animation;
    if (animation != null) _transformationController.value = animation.value;
  }

  void _onDoubleTap() {
    final current = _transformationController.value;
    final Matrix4 target;
    if (current.getMaxScaleOnAxis() > widget.minScale + 0.01) {
      target = Matrix4.identity();
    } else {
      final focal = _doubleTapPosition ?? Offset.zero;
      final s = widget.doubleTapScale.clamp(widget.minScale, widget.maxScale);
      // Scale around the tapped point, keeping it at the same position on screen
      target = Matrix4(s, 0, 0, 0, 0, s, 0, 0, 0, 0, 1, 0, -focal.dx * (s - 1), -focal.dy * (s - 1), 0, 1);
    }

    _animation = Matrix4Tween(
      begin: current,
      end: target,
    ).animate(CurvedAnimation(parent: _animationController, curve: widget.curve));
    _animationController.forward(from: 0);
  }

  // Any pinch/pan by the user takes precedence over a running double tap animation
  void _onInteractionStart(ScaleStartDetails _) {
    if (_animationController.isAnimating) _animationController.stop();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _transformationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTapDown: (details) => _doubleTapPosition = details.localPosition,
      onDoubleTap: _onDoubleTap,
      child: InteractiveViewer(
        transformationController: _transformationController,
        constrained: true,
        minScale: widget.minScale,
        maxScale: widget.maxScale,
        onInteractionStart: _onInteractionStart,
        child: widget.child,
      ),
    );
  }
}
