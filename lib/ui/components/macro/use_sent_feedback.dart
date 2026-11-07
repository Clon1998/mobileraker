/*
 * Copyright (c) 2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:flutter_hooks/flutter_hooks.dart';

/// Short "sent" confirmation after running a macro: the bool is true for [duration] after calling the callback.
///
/// Frame-driven (an animation controller instead of a Timer), so widget tests settle via pumpAndSettle and no timer
/// is left pending.
(bool, void Function()) useSentFeedback({Duration duration = const Duration(milliseconds: 1500)}) {
  final controller = useAnimationController(duration: duration);
  final active = useListenableSelector(controller, () => controller.isAnimating);
  return (active, () => controller.forward(from: 0));
}
