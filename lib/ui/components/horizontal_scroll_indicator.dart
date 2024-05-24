/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:math';

import 'package:common/util/logger.dart';
import 'package:dots_indicator/dots_indicator.dart';
import 'package:flutter/material.dart';

class HorizontalScrollIndicator extends StatefulWidget {
  final int dots;
  final ScrollController controller;
  final int? childsPerScreen;
  final DotsDecorator? decorator;

  const HorizontalScrollIndicator({
    super.key,
    required this.dots,
    required this.controller,
    this.childsPerScreen,
    this.decorator,
  }) : assert(dots > 0, 'dots must be greater than 0');

  @override
  State<HorizontalScrollIndicator> createState() => _HorizontalScrollIndicatorState();
}

class _HorizontalScrollIndicatorState extends State<HorizontalScrollIndicator> {
  late int steps;

  double _curIndex = 0;

  ScrollController get controller => widget.controller;

  PageController get pageController => widget.controller as PageController;

  @override
  initState() {
    super.initState();
    _init();
  }

  @override
  void didUpdateWidget(_) {
    super.didUpdateWidget(_);
    _init();
  }

  _init() {
    steps = (widget.childsPerScreen == null) ? widget.dots : (widget.dots / widget.childsPerScreen!).ceil();

    // Ensure that only one listener is attached
    controller.removeListener(_updateIndexFromOffset);
    controller.removeListener(_updateIndexFromPage);

    if (controller is PageController?) {
      logger.d(
        'initiPage ${pageController.initialPage} - ${pageController.hasClients}',
      );
      controller.addListener(_updateIndexFromPage);
      WidgetsBinding.instance.addPostFrameCallback((_) => _updateIndexFromPage());
    } else {
      controller.addListener(_updateIndexFromOffset);
      WidgetsBinding.instance.addPostFrameCallback((_) => _updateIndexFromOffset());
    }
  }

  _updateIndexFromOffset() {
    if (!controller.hasClients || !controller.position.hasContentDimensions) {
      return;
    }
    double maxScrollExtent = controller.position.maxScrollExtent;
    if (maxScrollExtent == 0) return;

    // Width of a single step, we need to subtract 1 because the maxScrollExtent is at the start of the last step
    double wPerStep = maxScrollExtent / (steps - 1);
    // Current offset
    double offset = controller.offset;

    // Calculate index
    double newIndex = (offset / wPerStep).clamp(0, steps - 1);
    logger.d('newIndex: $newIndex, offset: $offset, maxScrollExtent: $maxScrollExtent');
    if ((_curIndex - newIndex).abs() < 0.1) return;
    setState(() {
      _curIndex = newIndex;
    });
  }

  _updateIndexFromPage() {
    if (!pageController.hasClients) {
      return;
    }

    var newIndex = (pageController.page ?? 0) * pageController.viewportFraction;
    if ((_curIndex - newIndex).abs() < 0.2) return;
    setState(() {
      _curIndex = newIndex;
    });
  }

  @override
  Widget build(BuildContext context) {
    return DotsIndicator(
      dotsCount: steps,
      position: max(_curIndex, 0),
      decorator: widget.decorator ?? DotsDecorator(activeColor: Theme.of(context).colorScheme.primary),
    );
  }

  @override
  dispose() {
    controller.removeListener(_updateIndexFromOffset);
    controller.removeListener(_updateIndexFromPage);
    super.dispose();
  }
}
