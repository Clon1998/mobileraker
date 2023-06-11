/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:mobileraker/ui/components/horizontal_scroll_indicator.dart';

class AdaptiveHorizontalScroll extends HookWidget {
  const AdaptiveHorizontalScroll(
      {Key? key,
      required this.pageStorageKey,
      this.children = const [],
      this.minWidth = 150,
      this.maxWidth = 200}):super(key:key);

  final List<Widget> children;

  final String pageStorageKey;

  final double minWidth;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final scrollCtrler = useScrollController();

    return Padding(
      padding: const EdgeInsets.only(left: 8, right: 8),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final int visibleCnt = (constraints.maxWidth / minWidth).floor();
          final double width = constraints.maxWidth / visibleCnt;
          return Column(
            children: [
              SingleChildScrollView(
                key: PageStorageKey<String>('${pageStorageKey}M'),
                controller: scrollCtrler,
                scrollDirection: Axis.horizontal,
                // physics: const BouncingScrollPhysics(),
                child: SizedBox(
                  width: max(width * children.length, constraints.maxWidth),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: children
                        .map((e) => ConstrainedBox(
                            constraints: BoxConstraints(
                                minWidth: minWidth,
                                maxWidth: min(maxWidth, width)),
                            child: e))
                        .toList(),
                  ),
                ),
              ),
              if (children.length > visibleCnt && true)
                HorizontalScrollIndicator(
                  key: PageStorageKey<String>('${pageStorageKey}IC'),
                  steps: children.length,
                  controller: scrollCtrler,
                  childsPerScreen: visibleCnt,
                )
            ],
          );
        },
      ),
    );
  }
}
