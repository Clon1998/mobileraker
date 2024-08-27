/*
 * Copyright (c) 2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:io';

import 'package:flutter/material.dart';

class AdaptiveDraggableScrollableSheet extends StatefulWidget {
  const AdaptiveDraggableScrollableSheet({
    super.key,
    this.maxChildSize = 1,
    this.minChildSize = 0.3,
    required this.builder,
  });

  final double maxChildSize;
  final double minChildSize;
  final ScrollableWidgetBuilder builder;

  @override
  State<AdaptiveDraggableScrollableSheet> createState() => _AdaptiveDraggableScrollableSheet();
}

class _AdaptiveDraggableScrollableSheet extends State<AdaptiveDraggableScrollableSheet> {
  final _contentKey = GlobalKey();

  double? _bodyHeight;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateHeight());
    // ViewInserts are required for the keyboard, in case the sheet has text fields. Otherwise the keyboard might overlap the text fields.
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          var maxHeight = widget.maxChildSize;
          final viewInsets = MediaQuery.maybeViewInsetsOf(context);
          final paddingOf = MediaQuery.maybePaddingOf(context);
          final sizeOf = MediaQuery.maybeSizeOf(context);
          if (_bodyHeight != null && viewInsets != null && paddingOf != null && sizeOf != null) {
            // We calculate the max height, based of the
            // 1. body height of the content
            // 2. paddingOf.bottom -> SafeArea padding, which is the padding of the bottom
            // 3. viewInsets.bottom, which is the height of the keyboard -> IF keyboard open, it should extend the sheet if needed
            // We clmap the value between min and max child size
            // logger.w('Body height: $_bodyHeight, paddingOf: $viewInsets');

            // !! Note: We need to use constraints because
            maxHeight = ((_bodyHeight! + paddingOf.bottom + viewInsets.bottom) /
                    (Platform.isIOS ? sizeOf.height : constraints.maxHeight))
                .clamp(widget.minChildSize, widget.maxChildSize);
            // logger.w('body.height: $_bodyHeight\n'
            //     'mediaQuery.height: ${sizeOf.height}\n'
            //     'constraints: $constraints\n'
            //     'paddingOf: $paddingOf\n'
            //     'viewInsets: $viewInsets\n'
            //     'maxHeight: $maxHeight');
          }

          return DraggableScrollableSheet(
            expand: false,
            maxChildSize: maxHeight,
            initialChildSize: maxHeight,
            minChildSize: widget.minChildSize,
            builder: (ctx, scrollController) {
              return Scaffold(
                body: KeyedSubtree(
                  key: _contentKey,
                  child: widget.builder(ctx, scrollController),
                ),
              );
            },
          );
        },
      );

  _updateHeight() {
    var renderObject = _contentKey.currentContext?.findRenderObject();
    if (renderObject case RenderBox()) {
      setState(() {
        _bodyHeight = renderObject.size.height;
      });
      // logger.i('Body height: $_bodyHeight');
    }
  }
}
