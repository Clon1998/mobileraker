/*
 * Copyright (c) 2024. Patrick Schmidt.
 * All rights reserved.
 */

// ignore_for_file: avoid-redundant-else

import 'package:collection/collection.dart';
import 'package:common/util/logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:reorderables/src/widgets/passthrough_overlay.dart';
import 'package:reorderables/src/widgets/reorderable_mixin.dart';
import 'package:reorderables/src/widgets/reorderable_widget.dart';
import 'package:reorderables/src/widgets/typedefs.dart';

typedef ReorderableMultiColRowItemBuilder = Widget Function(
    BuildContext context, Axis? direction, List<List<Widget>> children,
    [List<Widget?>? header, List<Widget?>? footer]);

typedef OnPositionReorder = void Function((int, int) oldPos, (int, int) newPos);
typedef OnPositionReorderStarted = void Function((int, int) pos);
typedef OnNoPositionReorder = void Function((int, int) pos);

class ReorderableMultiColRow extends StatefulWidget {
  /// Creates a reorderable list.
  ReorderableMultiColRow({
    super.key,
    this.header,
    this.footer,
    required this.children,
    required this.onReorder,
    this.direction,
    this.scrollDirection = Axis.vertical,
    this.padding,
    this.buildItemsContainer,
    this.buildDraggableFeedback,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.onNoReorder,
    this.onReorderStarted,
    this.scrollController,
    this.needsLongPressDraggable = true,
    this.draggingWidgetOpacity = 0.2,
    this.reorderAnimationDuration,
    this.draggedItemBuilder,
  }) : assert(
          children.flattened.every((Widget w) => w.key != null),
          'All children of this widget must have a key.',
        );

  /// A non-reorderable header widget to show before the list.
  ///
  /// If null, no header will appear at the top/left of the widget.
  final List<Widget?>? header;

  final Widget Function(BuildContext context, int index, int jndex)? draggedItemBuilder;

  /// A non-reorderable footer widget to show after the list.
  ///
  /// If null, no footer will appear at the bottom/right of the widget.
  final List<Widget?>? footer;

  /// The widgets to display.
  final List<List<Widget>> children;

  /// The [Axis] along which the list scrolls.
  ///
  /// List [children] can only drag along this [Axis].
  final Axis? direction;
  final Axis scrollDirection;
  final ScrollController? scrollController;

  /// The amount of space by which to inset the [children].
  final EdgeInsets? padding;

  /// Called when a child is dropped into a new position to shuffle the
  /// children.
  final OnPositionReorder onReorder;
  final OnNoPositionReorder? onNoReorder;

  /// Called when the draggable starts being dragged.
  final OnPositionReorderStarted? onReorderStarted;

  final ReorderableMultiColRowItemBuilder? buildItemsContainer;
  final BuildDraggableFeedback? buildDraggableFeedback;

  final MainAxisAlignment mainAxisAlignment;

  final bool needsLongPressDraggable;
  final double draggingWidgetOpacity;

  final Duration? reorderAnimationDuration;

  @override
  State<ReorderableMultiColRow> createState() => _ReorderableMultiColRowState();
}

// This top-level state manages an Overlay that contains the list and
// also any Draggables it creates.
//
// _ReorderableListContent manages the list itself and reorder operations.
//
// The Overlay doesn't properly keep state by building new overlay entries,
// and so we cache a single OverlayEntry for use as the list layer.
// That overlay entry then builds a _ReorderableListContent which may
// insert Draggables into the Overlay above itself.
class _ReorderableMultiColRowState extends State<ReorderableMultiColRow> {
  // We use an inner overlay so that the dragging list item doesn't draw outside of the list itself.
  final GlobalKey _overlayKey = GlobalKey(debugLabel: '$ReorderableMultiColRow overlay key');

  // This entry contains the scrolling list itself.
  late PassthroughOverlayEntry _listOverlayEntry;

  @override
  void initState() {
    super.initState();
    _listOverlayEntry = PassthroughOverlayEntry(
      opaque: false,
      builder: (BuildContext context) {
        return _ReorderableFlexContent(
          header: widget.header,
          footer: widget.footer,
          direction: widget.direction,
          scrollDirection: widget.scrollDirection,
          onReorder: widget.onReorder,
          onNoReorder: widget.onNoReorder,
          onReorderStarted: widget.onReorderStarted,
          padding: widget.padding,
          buildItemsContainer: widget.buildItemsContainer,
          buildDraggableFeedback: widget.buildDraggableFeedback,
          mainAxisAlignment: widget.mainAxisAlignment,
          scrollController: widget.scrollController,
          needsLongPressDraggable: widget.needsLongPressDraggable,
          draggingWidgetOpacity: widget.draggingWidgetOpacity,
          draggedItemBuilder: widget.draggedItemBuilder,
          reorderAnimationDuration: widget.reorderAnimationDuration ?? const Duration(milliseconds: 200),
          children: widget.children,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final PassthroughOverlay passthroughOverlay = PassthroughOverlay(
      key: _overlayKey,
      initialEntries: <PassthroughOverlayEntry>[_listOverlayEntry],
    );

    return passthroughOverlay;
  }
}

// This widget is responsible for the inside of the Overlay in the
// ReorderableFlex.
class _ReorderableFlexContent extends StatefulWidget {
  const _ReorderableFlexContent({
    this.header,
    this.footer,
    required this.children,
    required this.direction,
    required this.scrollDirection,
    required this.onReorder,
    required this.onNoReorder,
    required this.onReorderStarted,
    required this.mainAxisAlignment,
    required this.scrollController,
    required this.needsLongPressDraggable,
    required this.draggingWidgetOpacity,
    required this.buildItemsContainer,
    required this.buildDraggableFeedback,
    required this.padding,
    this.draggedItemBuilder,
    this.reorderAnimationDuration = const Duration(milliseconds: 200),
  });

  final List<Widget?>? header;
  final List<Widget?>? footer;
  final List<List<Widget>> children;
  final Axis? direction;
  final Axis scrollDirection;
  final OnPositionReorder onReorder;
  final OnNoPositionReorder? onNoReorder;
  final OnPositionReorderStarted? onReorderStarted;
  final ReorderableMultiColRowItemBuilder? buildItemsContainer;
  final BuildDraggableFeedback? buildDraggableFeedback;
  final ScrollController? scrollController;
  final EdgeInsets? padding;
  final Widget Function(BuildContext context, int index, int jndex)? draggedItemBuilder;

  final MainAxisAlignment mainAxisAlignment;
  final bool needsLongPressDraggable;
  final double draggingWidgetOpacity;
  final Duration reorderAnimationDuration;

  @override
  _ReorderableFlexContentState createState() => _ReorderableFlexContentState();
}

class _ReorderableFlexContentState extends State<_ReorderableFlexContent> with ReorderableMixin {
  // The additional margin to place around a computed drop area.
  static const double _dropAreaMargin = 0.0;

  // The member of widget.children currently being dragged.
  //
  // Null if no drag is underway.
  Widget? _draggingWidget;

  // The last computed size of the feedback widget being dragged.
  Size? _draggingFeedbackSize = const Size(0, 0);

  // The origin of the dragged widget.
  (int, int) _dragStartIndex = (-1, -1);

  // The index that the dragging widget previously occupied.
  (int, int) _prevIndex = (-1, -1);

  // The index that the dragging widget preview currently occupies.
  (int, int) _currentIndex = (-1, -1);

  // Whether or not we are currently scrolling this view to show a widget.
  bool _scrolling = false;

  Size get _dropAreaSize {
    if (_draggingFeedbackSize == null) {
      return const Size(0, 0);
    }
    return _draggingFeedbackSize! + const Offset(_dropAreaMargin, _dropAreaMargin);
  }

  void _autoScroll(Offset position) {
    if (widget.scrollController == null) return;
    // logger.i('AutoScroll: $position, sc: $scrollController');

    final screenHeight = MediaQuery.sizeOf(context).height;
    const topThreshold = 100.0;
    final bottomThreshold = screenHeight - 100.0;

    if (position.dy < topThreshold) {
      if (_scrolling) return;
      double distance = topThreshold - position.dy;
      double speed = (distance / topThreshold) * 20; // Adjust the multiplier as needed
      // logger.i('AutoScroll: Scrolling up!!! speed: $speed');
      _scrolling = true;
      _scroll(-5.5, 1.008); // Linear acceleration
    } else if (position.dy > bottomThreshold) {
      if (_scrolling) return;
      double distance = bottomThreshold - position.dy;
      double speed = (distance / bottomThreshold) * 20; // Adjust the multiplier as needed
      // logger.i('AutoScroll: Scrolling down!!! speed: $speed dist $distance');
      _scrolling = true;
      _scroll(5.5, 1.008); // Linear acceleration
    } else if (_scrolling) {
      // logger.i('AutoScroll: Stopped Scrolling!!!');
      _scrolling = false;
    }
  }

  void _scroll(double speed, double accel) async {
    if (!_scrolling) return;
    final scrollController = widget.scrollController!;
    if (scrollController.offset <= 0 && speed <= 0 ||
        scrollController.offset >= scrollController.position.maxScrollExtent && speed >= 0) {
      return;
    }

    speed = speed * accel;
    double offset = scrollController.offset + speed;
    // logger.i('AutoScroll: Scrolling!!! to $offset with speed: $speed accel: $accel');
    await scrollController.animateTo(
      offset.clamp(0.0, scrollController.position.maxScrollExtent),
      duration: Duration(milliseconds: 15),
      curve: Curves.easeIn,
    );
    _scroll(speed, accel);
  }

  void _onDragUpdate(DragUpdateDetails details) {
    _autoScroll(details.globalPosition);
  }

  void _onDragEnd(DraggableDetails details) {
    _scrolling = false;
  }

  // Wraps children in Row or Column, so that the children flow in
  // the widget's scrollDirection.
  Widget _buildContainerForMainAxis({required List<Widget> children}) {
    switch (widget.direction) {
      case Axis.horizontal:
        return Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: widget.mainAxisAlignment, children: children);
      case Axis.vertical:
      default:
        return Column(mainAxisSize: MainAxisSize.min, mainAxisAlignment: widget.mainAxisAlignment, children: children);
    }
  }

  // Wraps one of the widget's children in a DragTarget and Draggable.
  // Handles up the logic for dragging and reordering items in the list.
  Widget _wrap(Widget toWrap, (int, int) currentPos) {
    assert(toWrap.key != null);
    final (int index, int jndex) = currentPos;

    final GlobalObjectKey keyIndexGlobalKey = GlobalObjectKey(toWrap.key!);
    // We pass the toWrapWithGlobalKey into the Draggable so that when a list
    // item gets dragged, the accessibility framework can preserve the selected
    // state of the dragging item.

    final draggedItem = widget.draggedItemBuilder?.call(context, index, jndex) ?? toWrap;

    // Starts dragging toWrap.
    void onDragStarted() {
      logger.i('On Drag Started: $currentPos ${toWrap.key}');
      setState(() {
        _draggingWidget = draggedItem;
        _dragStartIndex = currentPos;
        _prevIndex = currentPos;
        _currentIndex = currentPos;
        // _entranceController.value = 1.0;
        _draggingFeedbackSize = keyIndexGlobalKey.currentContext?.size;
      });

      widget.onReorderStarted?.call(currentPos);
    }

    // Places the value from startIndex one space before the element at endIndex.
    void _reorder((int, int) startIndex, (int, int) endIndex) {
      logger.i('_reorder: $startIndex -> $endIndex');
//      debugPrint('startIndex:$startIndex endIndex:$endIndex');
      if (startIndex != endIndex) {
        widget.onReorder(startIndex, endIndex);
      } else if (widget.onNoReorder != null) {
        widget.onNoReorder!(startIndex);
      }
    }

    // Drops toWrap into the last position it was hovering over.
    void onDragEnded() {
      setState(() {
        _reorder(_dragStartIndex, _currentIndex);
        _dragStartIndex = (-1, -1);
        _currentIndex = (-1, -1);
        _prevIndex = (-1, -1);
        _draggingWidget = null;
      });
    }

    Widget buildDragTarget(
        BuildContext context, List<(int, int)?> acceptedCandidates, List<dynamic> rejectedCandidates) {
      Widget feedbackBuilder = Builder(builder: (BuildContext context) {
        BoxConstraints contentSizeConstraints = BoxConstraints.loose(_draggingFeedbackSize!); //renderObject.constraints
//          debugPrint('${DateTime.now().toString().substring(5, 22)} reorderable_flex.dart(515) $this.buildDragTarget: contentConstraints:$contentSizeConstraints _draggingFeedbackSize:$_draggingFeedbackSize');
        return (widget.buildDraggableFeedback ?? defaultBuildDraggableFeedback)(
            context, contentSizeConstraints, draggedItem);
      });

      // We build the draggable inside of a layout builder so that we can
      // constrain the size of the feedback dragging widget.

      if (toWrap case ReorderableWidget(reorderable: false)) {
        return toWrap;
      }

      // The target for dropping at the end of the list doesn't need to be
      // draggable.
      if (jndex >= widget.children[index].length) {
        return toWrap;
      }

      return widget.needsLongPressDraggable
          ? LongPressDraggable<(int, int)>(
              onDragUpdate: _onDragUpdate,
              onDragEnd: _onDragEnd,
              maxSimultaneousDrags: 1,
              axis: widget.direction,
              data: currentPos,
              ignoringFeedbackSemantics: false,

              feedback: feedbackBuilder,
              childWhenDragging: IgnorePointer(
                  ignoring: true, child: Opacity(opacity: 0, child: Container(width: 0, height: 0, child: toWrap))),
              onDragStarted: onDragStarted,
              dragAnchorStrategy: childDragAnchorStrategy,
              // When the drag ends inside a DragTarget widget, the drag
              // succeeds, and we reorder the widget into position appropriately.
              onDragCompleted: onDragEnded,
              // When the drag does not end inside a DragTarget widget, the
              // drag fails, but we still reorder the widget to the last position it
              // had been dragged to.
              onDraggableCanceled: (Velocity velocity, Offset offset) => onDragEnded(),
              child: toWrap,
            )
          : Draggable<(int, int)>(
              onDragUpdate: _onDragUpdate,
              onDragEnd: _onDragEnd,
              maxSimultaneousDrags: 1,
              axis: widget.direction,
              data: currentPos,
              ignoringFeedbackSemantics: false,
              feedback: feedbackBuilder,
              childWhenDragging: IgnorePointer(
                  ignoring: true, child: Opacity(opacity: 0, child: Container(width: 0, height: 0, child: toWrap))),
              onDragStarted: onDragStarted,
              dragAnchorStrategy: childDragAnchorStrategy,
              // When the drag ends inside a DragTarget widget, the drag
              // succeeds, and we reorder the widget into position appropriately.
              onDragCompleted: onDragEnded,
              // When the drag does not end inside a DragTarget widget, the
              // drag fails, but we still reorder the widget to the last position it
              // had been dragged to.
              onDraggableCanceled: (Velocity velocity, Offset offset) => onDragEnded(),
              child: toWrap,
            );
    }

    // We wrap the drag target in a Builder so that we can scroll to its specific context.
    return Builder(builder: (BuildContext context) {
      Widget dragTarget = DragTarget<(int, int)>(
        builder: buildDragTarget,
        onWillAcceptWithDetails: (DragTargetDetails<(int, int)> details) {
          final (int, int) toAccept = details.data;
          // If toAccept is the one we started dragging and it's not the origin
          bool willAccept = _dragStartIndex == toAccept && _dragStartIndex != currentPos;

          // Uncomment for detailed debugging information
          // debugPrint('${DateTime.now().toString().substring(5, 22)} reorderable_flex.dart(609) $this._wrap: '
          //   'onWillAccept: toAccept:$toAccept return:$willAccept _nextIndex:$_nextIndex index:$index _currentIndex:$_currentIndex _dragStartIndex:$_dragStartIndex');

          setState(() {
            (int, int) newPos = currentPos;

            if (willAccept) {
              // It's not the original position that we started dragging from, so we might need to shift
              // currentPos == _dragStartIndex is never reached because of the willAccept check above

              // We need to check if we are in the same col as the last drop position (_currentIndex)
              if (currentPos.$1 == _currentIndex.$1) {
                // We are in the same col
                logger.i('In the same col as the last drop position');

                // Now we need to determine if we need to shift or not (Handles all indexes below _dragStartIndex)
                if (currentPos.$2 == _currentIndex.$2) {
                  newPos = (currentPos.$1, currentPos.$2 + 1);
                }

                // If we are past the _dragStartIndex, we need to shift the next index by one
                if (currentPos.$1 == _dragStartIndex.$1 && // We are in the same col as the dragStart index
                    currentPos.$2 >= _dragStartIndex.$2 &&
                    _currentIndex.$2 == _dragStartIndex.$2) {
                  // This should only happen once during the start
                  newPos = (newPos.$1, newPos.$2 + 1);
                }
              } else {
                // We are in a different col
                logger.i('In a different col from the last drop position');
                if (currentPos.$2 == _currentIndex.$2) {
                  // Handles the "Skip over" or scroll from top onto the widget
                  newPos = (currentPos.$1, currentPos.$2 + 1);
                }
              }
            }

            // We skip over the _dragStartIndex in any case
            if (newPos == _dragStartIndex) {
              newPos = (newPos.$1, newPos.$2 + 1);
            }
            _prevIndex = _currentIndex;
            _currentIndex = newPos;
            logger.i(
                'Will accept: $willAccept for ${toWrap.key} at $currentPos. _start: $_dragStartIndex, _prevIndex: $_prevIndex, _currentIndex: $_currentIndex');
            // _requestAnimationToNextIndex(isAcceptingNewTarget: true);
          });

          // If the target is not the original starting point, then we will accept the drop.
          return willAccept; // _dragging == toAccept && toAccept != toWrap.key;
        },
      );

      dragTarget = KeyedSubtree(key: keyIndexGlobalKey, child: dragTarget);

      // Determine the size of the drop area to show under the dragging widget.
      Widget spacing = _draggingWidget == null
          ? SizedBox.fromSize(size: _dropAreaSize)
          : Opacity(opacity: widget.draggingWidgetOpacity, child: _draggingWidget);

      // Check if no Widget is currently being dragged. We can just build this DragTarget!
      if (_draggingWidget == null) return _buildContainerForMainAxis(children: [dragTarget]);

      // The next widget is outside of the list, so we need to build a space for it.

      final isLastInCol = currentPos.$2 == widget.children[currentPos.$1].length - 1;
      final currentIndexOverscroll = isLastInCol && currentPos == (_currentIndex.$1, _currentIndex.$2 - 1);
      final prevIndexOverscroll = isLastInCol && currentPos == (_prevIndex.$1, _prevIndex.$2 - 1);

      if (currentPos != _currentIndex && currentPos != _prevIndex && !currentIndexOverscroll && !prevIndexOverscroll) {
        // No need to build a space for the next widget as it is not the next widget
        return _buildContainerForMainAxis(children: [dragTarget]);
      }
      logger.i(
          'Building space for ${toWrap.key} at $currentPos. _start: $_dragStartIndex, _prevIndex: $_prevIndex, _currentIndex: $_currentIndex, isLastInCol: $isLastInCol, currentIndexOverscroll: $currentIndexOverscroll, prevIndexOverscroll: $prevIndexOverscroll');

      Widget preview = _AnimPreview(
        duration: widget.reorderAnimationDuration,
        constraints: _draggingFeedbackSize ?? Size(0, 0),
        inOut: true,
        child: spacing,
      );

      Widget disappearingPos = _AnimPreview(
        duration: widget.reorderAnimationDuration,
        constraints: _draggingFeedbackSize ?? Size(0, 0),
        inOut: false,
        child: spacing,
      );

      // Special case for the inital drag start where no animation is needed
      if (currentPos == _dragStartIndex && _currentIndex == _dragStartIndex && _prevIndex == _dragStartIndex) {
        return _buildContainerForMainAxis(children: [spacing, dragTarget]);
      }

      if (currentPos == _currentIndex) {
        // We need to add the disappearing widget at the end of the list if the we are at the end of the list and the next widget is the last widget
        return _buildContainerForMainAxis(children: [preview, dragTarget, if (prevIndexOverscroll) disappearingPos]);
      }
      if (currentIndexOverscroll) {
        // We need to add the disappearing widget at the end of the list if the we are at the end of the list and the next widget is the last widget
        return _buildContainerForMainAxis(
            children: [if (currentPos == _prevIndex) disappearingPos, dragTarget, preview]);
      }

      if (currentPos == _prevIndex || prevIndexOverscroll) {
        return _buildContainerForMainAxis(children: [disappearingPos, dragTarget]);
      }

      // Default case, should never be reached as it is handled above
      return _buildContainerForMainAxis(children: [dragTarget]);
    });
  }

  @override
  Widget build(BuildContext context) {
//    assert(debugCheckHasMaterialLocalizations(context));
    // We use the layout builder to constrain the cross-axis size of dragging child widgets.
//    return LayoutBuilder(builder: (BuildContext context, BoxConstraints constraints) {
    final List<List<Widget>> wrappedChildren = [];

    for (int i = 0; i < widget.children.length; i += 1) {
      wrappedChildren.add([
        for (int j = 0; j < widget.children[i].length; j += 1) _wrap(widget.children[i][j], (i, j)),
      ]);
    }
    return (widget.buildItemsContainer ?? defaultBuildItemsContainer)(
      context,
      widget.direction,
      wrappedChildren,
      widget.header,
      widget.footer,
    );
  }

  Widget defaultBuildItemsContainer(BuildContext context, Axis? direction, List<List<Widget>> children,
      [List<Widget?>? header, List<Widget?>? footer]) {
    final rowChildren = <Widget>[];
    for (int i = 0; i < children.length; i += 1) {
      final headerForCol = header?.elementAtOrNull(i);
      final footerForCol = footer?.elementAtOrNull(i);
      rowChildren.add(
        Expanded(
          child: Column(
            children: [
              if (headerForCol != null) headerForCol,
              ...children[i],
              if (footerForCol != null) footerForCol,
            ],
          ),
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: rowChildren,
    );
  }

  Widget defaultBuildDraggableFeedback(BuildContext context, BoxConstraints constraints, Widget child) {
    return Transform(
      transform: Matrix4.rotationZ(0),
      alignment: FractionalOffset.topLeft,
      child: Material(
        elevation: 6.0,
        color: Colors.transparent,
        borderRadius: BorderRadius.zero,
        child: Card(child: ConstrainedBox(constraints: constraints, child: child)),
      ),
    );
  }
}

class _AnimPreview extends HookWidget {
  const _AnimPreview({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 200),
    required this.constraints,
    this.inOut = false,
  });

  final Widget child;
  final Duration duration;
  final Size constraints;
  final bool inOut; // true = in, false = out

  @override
  Widget build(BuildContext context) {
    final ctl = useAnimationController(duration: duration, initialValue: inOut ? 0 : 1);
    if (inOut) {
      ctl.forward();
    } else {
      ctl.reverse();
    }

    final transition = SizeTransition(
      sizeFactor: ctl,
      axis: Axis.vertical,
      axisAlignment: 0,
      child: FadeTransition(opacity: ctl, child: child),
    );

    BoxConstraints contentSizeConstraints = BoxConstraints.loose(constraints);
    return ConstrainedBox(constraints: contentSizeConstraints, child: transition);
  }
}
