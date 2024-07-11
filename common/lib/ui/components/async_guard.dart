/*
 * Copyright (c) 2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/util/logger.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../animation/animated_size_and_fade.dart';

/// A widget that guards the rendering of its children based on the state of a provided asynchronous value.
///
/// This widget can be used to handle different states of an asynchronous operation and render different widgets accordingly.
/// It can handle loading, error and data states.
///
/// Compared to [AsyncValueWidget], this widget only "guards" the asyncValue[toGuard].
/// That means that the childs are expected to listen to the same asyncValue using [Consumer] or [ConsumerWidget] for the data state.
/// An usecase for that would be to have a provider "A" that is used by the childOnData's provider "B" and "C".
class AsyncGuard extends ConsumerWidget {
  /// Creates an instance of [AsyncGuard].
  ///
  /// The [toGuard] and [childOnData] parameters must not be null.
  const AsyncGuard({
    super.key,
    this.debugLabel,
    required this.toGuard,
    this.animate = false,
    this.animationAlignment = Alignment.topCenter,
    this.childOnLoading,
    this.childOnError,
    required this.childOnData,
  });

  /// An optional label for debugging purposes.
  final String? debugLabel;

  /// The provider that this widget is guarding. It should return a boolean indicating whether the child should be shown.
  final ProviderListenable<AsyncValue<bool>> toGuard;

  /// The widget to show when the [toGuard] provider is in a loading state.
  final Widget? childOnLoading;

  /// A function that returns a widget to show when the [toGuard] provider is in an error state.
  final Function(Object error, StackTrace stacktrace)? childOnError;

  /// The widget to show when the [toGuard] provider has data.
  final Widget childOnData;

  /// A flag indicating whether to animate transitions between states.
  final bool animate;

  /// The alignment of the animation.
  final Alignment animationAlignment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var asyncValue = ref.watch(toGuard);
    if (debugLabel != null) logger.i('Rebuilding Async Guard: $debugLabel with $asyncValue');

    // Switch on the state of the async value to determine which widget to render.
    var w = switch (asyncValue) {
      // We handle all data states (Equals to when (skipLoading: true, skipRefresh: true))
      AsyncValue(hasValue: true, hasError: false, value: true) => KeyedSubtree(
          key: Key('guardData-$key'),
          child: childOnData,
        ),
      // We handle ERROR async value, this is similar to skipOnRefresh: true -> Error Widget.
      // !!! If loading state with with error (a reload due to watch change) -> This will not be triggered
      AsyncError(error: var err, stackTrace: var stack) when childOnError != null => KeyedSubtree(
          key: Key('guadErr-$key'),
          child: childOnError!.call(err, stack),
        ),

      // We handle all Loading states. SkipOnReload and SkipOnRefresh must be handeled above!
      AsyncValue(isLoading: true) when childOnLoading != null => KeyedSubtree(
          key: Key('guardLoad-$key'),
          child: childOnLoading!,
        ),
      // If none of the above cases match, render an empty widget.
      _ => SizedBox.shrink(key: Key('guardNone-$key')),
    };

    // If animation is not enabled, return the widget as is.
    if (!animate) return w;

    // const animationDuration = Duration(seconds: 15);
    const animationDuration = kThemeAnimationDuration;

    return AnimatedSizeAndFade(
      alignment: animationAlignment,
      fadeDuration: animationDuration,
      sizeDuration: animationDuration,
      child: w,
    );

    // THIS might also be a good consideration
    // return AnimatedSwitcher(
    //   // duration: kThemeAnimationDuration,
    //   duration: animationDuration,
    //   switchInCurve: Curves.easeInOut,
    //   switchOutCurve: Curves.easeInOut,
    //   layoutBuilder: (currentChild, previousChildren) {
    //     return Stack(
    //       clipBehavior: Clip.none,
    //       alignment: Alignment.topCenter,
    //       children: <Widget>[
    //         ...previousChildren,
    //         if (currentChild != null) currentChild,
    //       ],
    //     );
    //   },
    //   transitionBuilder: (child, anim) => SizeTransition(
    //     sizeFactor: anim,
    //     axisAlignment: -1,
    //     child: child,
    //   ),
    //   child: w,
    // );
  }
}
