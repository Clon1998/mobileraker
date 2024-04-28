/*
 * Copyright (c) 2024. Patrick Schmidt.
 * All rights reserved.
 */

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
  Widget build(BuildContext context) {
    var viewInsets = MediaQuery.viewInsetsOf(context);

    var maxHeight = widget.maxChildSize;
    var sizeOf = MediaQuery.maybeSizeOf(context);
    if (sizeOf != null && _bodyHeight != null) {
      // We calculate the max height, based of the
      // 1. body height of the content
      // 2. 70 a constant because of safe area padding?
      // 3. viewInsets.bottom, which is the height of the keyboard -> IF keyboard open, it should extend the sheet if needed
      // We clmap the value between min and max child size
      maxHeight = (((_bodyHeight! + 70 + viewInsets.bottom) / sizeOf.height) * widget.maxChildSize)
          .clamp(widget.minChildSize, widget.maxChildSize);
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
  }

  _updateHeight() {
    var renderObject = _contentKey.currentContext?.findRenderObject();
    if (renderObject case RenderBox()) {
      setState(() {
        _bodyHeight = renderObject.size.height;
      });
    }
  }
}
