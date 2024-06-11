/*
 * Copyright (c) 2024. Patrick Schmidt.
 * All rights reserved.
 */

// ignore_for_file: avoid-redundant-else

import 'dart:async';

import 'package:collection/collection.dart';
import 'package:common/util/logger.dart';
import 'package:flutter/material.dart';
import 'package:reorderables/src/widgets/passthrough_overlay.dart';
import 'package:reorderables/src/widgets/reorderable_mixin.dart';
import 'package:reorderables/src/widgets/reorderable_widget.dart';
import 'package:reorderables/src/widgets/typedefs.dart';

typedef BuildItemsContainerV2 = Widget Function(BuildContext context, Axis? direction, List<List<Widget>> children,
    [Widget? header, Widget? footer]);

typedef OnPositionReorder = void Function((int, int) oldPos, (int, int) newPos);
typedef OnPositionReorderStarted = void Function((int, int) pos);
typedef OnNoPositionReorder = void Function((int, int) pos);

class ReorderableFlexi extends StatefulWidget {
  /// Creates a reorderable list.
  ReorderableFlexi({
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
  final Widget? header;

  final Widget Function(BuildContext context, int index, int jndex)? draggedItemBuilder;

  /// A non-reorderable footer widget to show after the list.
  ///
  /// If null, no footer will appear at the bottom/right of the widget.
  final Widget? footer;

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

  final BuildItemsContainerV2? buildItemsContainer;
  final BuildDraggableFeedback? buildDraggableFeedback;

  final MainAxisAlignment mainAxisAlignment;

  final bool needsLongPressDraggable;
  final double draggingWidgetOpacity;

  final Duration? reorderAnimationDuration;

  @override
  State<ReorderableFlexi> createState() => _ReorderableFlexiState();
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
class _ReorderableFlexiState extends State<ReorderableFlexi> {
  // We use an inner overlay so that the dragging list item doesn't draw outside of the list itself.
  final GlobalKey _overlayKey = GlobalKey(debugLabel: '$ReorderableFlexi overlay key');

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

  final Widget? header;
  final Widget? footer;
  final List<List<Widget>> children;
  final Axis? direction;
  final Axis scrollDirection;
  final OnPositionReorder onReorder;
  final OnNoPositionReorder? onNoReorder;
  final OnPositionReorderStarted? onReorderStarted;
  final BuildItemsContainerV2? buildItemsContainer;
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

class _ReorderableFlexContentState extends State<_ReorderableFlexContent>
    with TickerProviderStateMixin<_ReorderableFlexContent>, ReorderableMixin {
  // The extent along the [widget.scrollDirection] axis to allow a child to
  // drop into when the user reorders list children.
  //
  // This value is used when the extents haven't yet been calculated from
  // the currently dragging widget, such as when it first builds.
//  static const double _defaultDropAreaExtent = 1.0;

  // final GlobalKey _contentKey = GlobalKey(debugLabel: 'MultiFlex item');

  // The additional margin to place around a computed drop area.
  static const double _dropAreaMargin = 0.0;

  // How long an animation to reorder an element in the list takes.
  late Duration _reorderAnimationDuration;

  // This controls the entrance of the dragging widget into a new place.
  late AnimationController _entranceController;

  // This controls the 'ghost' of the dragging widget, which is left behind
  // where the widget used to be.
  late AnimationController _ghostController;

  // The member of widget.children currently being dragged.
  //
  // Null if no drag is underway.
  Widget? _draggingWidget;

  // The last computed size of the feedback widget being dragged.
  Size? _draggingFeedbackSize = const Size(0, 0);

  // The location that the dragging widget occupied before it started to drag.
  (int, int) _dragStartIndex = (-1, -1);

  // The index of the widget that "leaves"
  (int, int) _ghostIndex = (-1, -1);

  // The index that the dragging widget currently occupies.
  (int, int) _currentIndex = (-1, -1);

  // The index of the widget that needs to appear is dragged on
  (int, int) _nextIndex = (0, 0);

  // The original last index of the widget that was shifted
  (int, int)? _lastShift;

  // Whether or not we are currently scrolling this view to show a widget.
  bool _scrolling = false;

  Timer? _debounceTimer;

//  final GlobalKey _contentKey = GlobalKey(debugLabel: '$ReorderableFlex content key');

  Size get _dropAreaSize {
    if (_draggingFeedbackSize == null) {
      return const Size(0, 0);
    }
    return _draggingFeedbackSize! + const Offset(_dropAreaMargin, _dropAreaMargin);
  }

  @override
  void initState() {
    super.initState();
    _reorderAnimationDuration = widget.reorderAnimationDuration;
    _entranceController = AnimationController(value: 1.0, vsync: this, duration: _reorderAnimationDuration);
    _ghostController = AnimationController(value: 0, vsync: this, duration: _reorderAnimationDuration);
    _entranceController.addStatusListener(_onEntranceStatusChanged);
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _ghostController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  // Animates the droppable space from _currentIndex to _nextIndex.
  void _requestAnimationToNextIndex({bool isAcceptingNewTarget = false}) {
//    debugPrint('${DateTime.now().toString().substring(5, 22)} reorderable_flex.dart(285) $this._requestAnimationToNextIndex: '
//      '_dragStartIndex:$_dragStartIndex _ghostIndex:$_ghostIndex _currentIndex:$_currentIndex _nextIndex:$_nextIndex isAcceptingNewTarget:$isAcceptingNewTarget isCompleted:${_entranceController.isCompleted}');

    if (_entranceController.isCompleted) {
      _ghostIndex = _currentIndex;
      if (!isAcceptingNewTarget && _nextIndex == _currentIndex) {
        // && _dragStartIndex == _ghostIndex
        return;
      }

      _currentIndex = _nextIndex;
      _ghostController.reverse(from: 1.0);
      _entranceController.forward(from: 0.0).then((_) => logger.i('----- DONE ANIM ------'));
    }
  }

  // Requests animation to the latest next index if it changes during an animation.
  void _onEntranceStatusChanged(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      setState(() {
        _requestAnimationToNextIndex();
      });
    }
  }

  void _autoScroll(Offset position) {
    if (widget.scrollController == null) return;
    final scrollController = widget.scrollController!;

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
      _scroll(-3.5, 1.012); // Linear acceleration
    } else if (position.dy > bottomThreshold) {
      if (_scrolling) return;
      double distance = bottomThreshold - position.dy;
      double speed = (distance / bottomThreshold) * 20; // Adjust the multiplier as needed
      // logger.i('AutoScroll: Scrolling down!!! speed: $speed dist $distance');
      _scrolling = true;
      _scroll(3.5, 1.012); // Linear acceleration
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
    // await Future.delayed(Duration(milliseconds: 5));
    _scroll(speed, accel);
  }

  void _onDragUpdate(DragUpdateDetails details) {
    _autoScroll(details.globalPosition);
    // _autoScroller?.startAutoScrollIfNecessary(Rect.fromLTWH(details.globalPosition.dx, details.globalPosition.dy, _draggingFeedbackSize!.width, _draggingFeedbackSize!.height));
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
        _ghostIndex = currentPos;
        _currentIndex = currentPos;
        _entranceController.value = 1.0;
        _draggingFeedbackSize = keyIndexGlobalKey.currentContext?.size;
      });

      widget.onReorderStarted?.call(currentPos);
    }

    // Places the value from startIndex one space before the element at endIndex.
    void _reorder((int, int) startIndex, (int, int) endIndex) {
      //TODO Verify this and use jindex!
//      debugPrint('startIndex:$startIndex endIndex:$endIndex');
      if (startIndex != endIndex) {
        widget.onReorder(startIndex, endIndex);
      } else if (widget.onNoReorder != null) {
        widget.onNoReorder!(startIndex);
      }
      // Animates leftover space in the drop area closed.
      // TODO(djshuckerow): bring the animation in line with the Material
      // specifications.
      _ghostController.reverse(from: 0.1);
      _entranceController.reverse(from: 0);
    }

    void reorder((int, int) startIndex, (int, int) endIndex) {
//      debugPrint('startIndex:$startIndex endIndex:$endIndex');
      setState(() {
        _reorder(startIndex, endIndex);
      });
    }

    // Drops toWrap into the last position it was hovering over.
    void onDragEnded() {
      reorder(_dragStartIndex, _currentIndex);
      setState(() {
        _reorder(_dragStartIndex, _currentIndex);
        _dragStartIndex = (-1, -1);
        _ghostIndex = (-1, -1);
        _currentIndex = (-1, -1);
        _draggingWidget = null;
        _lastShift = null;
      });
    }

    Widget _makeAppearingWidget(Widget child) {
      return makeAppearingWidget(
        child,
        _entranceController,
        _draggingFeedbackSize,
        widget.direction ?? Axis.vertical,
      );
    }

    Widget _makeDisappearingWidget(Widget child) {
      return makeDisappearingWidget(
        child,
        _ghostController,
        _draggingFeedbackSize,
        widget.direction ?? Axis.vertical,
      );
    }

    Widget buildDragTarget(
        BuildContext context, List<(int, int)?> acceptedCandidates, List<dynamic> rejectedCandidates) {
      Widget feedbackBuilder = Builder(builder: (BuildContext context) {
//          RenderRepaintBoundary renderObject = _contentKey.currentContext.findRenderObject();
//          BoxConstraints contentSizeConstraints = BoxConstraints.loose(renderObject.size);
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
        onLeave: ((int, int)? data) {
          logger.i('On Leave: $currentPos');
          // If the drag leaves the DragTarget, we reset the next index to the current index.
          setState(() {
            // _nextIndex = (-1,1);
            // _currentIndex = (-1,-1);
          });
        },
        onWillAcceptWithDetails: (DragTargetDetails<(int, int)> details) {
          final (int, int) toAccept = details.data;
          // If toAccept is the one we started dragging and its not the origin
          bool willAccept = _dragStartIndex == toAccept && toAccept != currentPos;

//          debugPrint('${DateTime.now().toString().substring(5, 22)} reorderable_flex.dart(609) $this._wrap: '
//            'onWillAccept: toAccept:$toAccept return:$willAccept _nextIndex:$_nextIndex index:$index _currentIndex:$_currentIndex _dragStartIndex:$_dragStartIndex');

          setState(() {
            if (willAccept) {
              // Its not the original position that we started dragging off from so we might need to shift!

              // currentPos == _dragStartIndex is never reached because of the willAccept check above

              // We need to check if we are in the same row as the last drop position (_currentIndex)
              if (currentPos.$1 == _currentIndex.$1) {
                // We are in the same row
                logger.i('In same row as last drop position');

                // Now we need to determine if we need to shift or not (Handles all indexes below _dragStartIndex)
                if (currentPos.$2 == _currentIndex.$2) {
                  _nextIndex = (currentPos.$1, currentPos.$2 + 1);
                } else {
                  _nextIndex = currentPos;
                }

                // We need to adjust for the missing _dragStartIndex widget however, only if we are in the same COL as the start widget
                if (_dragStartIndex.$1 == currentPos.$1 &&
                    currentPos.$2 >= _dragStartIndex.$2 &&
                    _lastShift?.$2 == _dragStartIndex.$2) {
                  _nextIndex = (_nextIndex.$1, _nextIndex.$2 + 1);
                } else if (_nextIndex == _dragStartIndex) {
                  _nextIndex = (_nextIndex.$1, _nextIndex.$2 + 1);
                }
              } else {
                // We are in a differnet row
                logger.i('In diff row as last drop position');
                if (currentPos.$2 == _currentIndex.$2) {
                  _nextIndex = (currentPos.$1, currentPos.$2 + 1);
                } else {
                  _nextIndex = currentPos;
                }
              }
            } else {
              _nextIndex = currentPos;
            }
            logger.i(
                'Will accept: $willAccept for ${toWrap.key} at $currentPos. _start: $_dragStartIndex, _ghost: $_ghostIndex, _current: $_currentIndex, _lastShift: $_lastShift, _next: $_nextIndex');
            _lastShift = currentPos;

            // if (_nextIndex != _currentIndex) {
            _requestAnimationToNextIndex(isAcceptingNewTarget: true);
            // }
          });
          // _scrollTo(context);
          // If the target is not the original starting point, then we will accept the drop.
          return willAccept; //_dragging == toAccept && toAccept != toWrap.key;
        },
        // onAccept: (int accepted) {},
        // onLeave: (Object? leaving) {},
      );

      dragTarget = KeyedSubtree(key: keyIndexGlobalKey, child: dragTarget);

      // Determine the size of the drop area to show under the dragging widget.
      Widget spacing = _draggingWidget == null
          ? SizedBox.fromSize(size: _dropAreaSize)
          : Opacity(opacity: widget.draggingWidgetOpacity, child: _draggingWidget);

      // debugPrint('${DateTime.now().toString().substring(5, 22)} reorderable_flex.dart(659) $this._wrap: '
      //   'pos:$currentPos shiftedIndex:$shiftedIndex _nextIndex:$_nextIndex _currentIndex:$_currentIndex _ghostIndex:$_ghostIndex _dragStartIndex:$_dragStartIndex');

      // Check if no Widget is currently being dragged. We can just build this DragTarget!
      if (_draggingWidget == null) return _buildContainerForMainAxis(children: [dragTarget]);

      // Correct the col num of next index to prevent out of bounds
      // final adjustedNextIndex = (_nextIndex.$1, _nextIndex.$2.clamp(0, widget.children[_nextIndex.$1].length - 1));

      // Check if the current widget is neither potentially the gost nor the new target
      var isLastInCol = currentPos == (_nextIndex.$1, widget.children[_nextIndex.$1].length - 1);
      if (currentPos != _ghostIndex && currentPos != _nextIndex && !isLastInCol) {
        return _buildContainerForMainAxis(children: [dragTarget]);
      }

      // The Appearing widget at the new target position
      Widget entranceSpacing = Container(color: Colors.greenAccent, child: _makeAppearingWidget(spacing));
      // The ghost/dissapearing widget at the old position
      Widget ghostSpacing = Container(color: Colors.red, child: _makeDisappearingWidget(spacing));

      logger.i(
          'Building space or ghost for tile $currentPos with _nextIndex: $_nextIndex, _currentIndex: $_currentIndex _ghostIndex: $_ghostIndex _dragStartIndex: $_dragStartIndex');

      if (currentPos.$1 != _nextIndex.$1) {
        // The target is dragged to a different col!
        // So from left to right or right to left

        if (currentPos == _ghostIndex) {
          // The ghost is
          return _buildContainerForMainAxis(children: [ghostSpacing, dragTarget]);
        }

        return _buildContainerForMainAxis(children: [entranceSpacing, dragTarget]);
      } else {
        // The target is dragged to the same col!
        if (isLastInCol) {
          // Is last entry special case as it needs to render stuff!

          if (currentPos == _dragStartIndex) {
            return _buildContainerForMainAxis(children: [dragTarget]);
          } else if (_nextIndex.$2 >= _ghostIndex.$2) {
            logger.i(
                'Building LAST item (${(_ghostIndex.$2 >= currentPos.$2) ? 'GHOST,' : ''} drag, APPEAR) ${toWrap.key} $currentPos');
            return _buildContainerForMainAxis(children: [ghostSpacing, dragTarget, entranceSpacing]);
          } else {
            logger.i('Building LAST item (APPEAR, drag, GHOST) ${toWrap.key} $currentPos');
            return _buildContainerForMainAxis(children: [entranceSpacing, dragTarget, ghostSpacing]);
          }
        } else
        // So either from top to bottom or bottom to top
        if (_nextIndex.$2 > _ghostIndex.$2) {
          //the ghost is moving down, i.e. the tile below the ghost is moving up

          if (currentPos == _ghostIndex && currentPos == _nextIndex) {
            // It seems like we are at the top of the list
            logger.i('Building ghost and entrance DOWN for ${toWrap.key} $currentPos');
            return _buildContainerForMainAxis(children: [ghostSpacing, dragTarget, entranceSpacing]);
          } else if (currentPos == _nextIndex) {
            logger.i('Building entrance DOWN for ${toWrap.key} $currentPos');
            return _buildContainerForMainAxis(children: [entranceSpacing, dragTarget]);
          } else {
            logger.i('Building ghost DOWN for ${toWrap.key} $currentPos');
            return _buildContainerForMainAxis(children: [ghostSpacing, dragTarget]);
          }
        } else if (_nextIndex.$2 < _ghostIndex.$2) {
          // the ghost is moving up, i.e. the tile above the ghost is moving down

          if (currentPos == _ghostIndex && currentPos == _nextIndex) {
            logger.i('Building ghost and entrance UP for ${toWrap.key} $currentPos');
            // It seems like we are at the top of the list
            return _buildContainerForMainAxis(children: [entranceSpacing, dragTarget, ghostSpacing]);
          } else if (currentPos == _nextIndex) {
            logger.i('Building entrance UP for ${toWrap.key} $currentPos');
            return _buildContainerForMainAxis(children: [entranceSpacing, dragTarget]);
          } else {
            logger.i('Building ghost UP for ${toWrap.key} $currentPos');
            return _buildContainerForMainAxis(children: [ghostSpacing, dragTarget]);
          }
        } else {
          // This is most likely the dragStart item
          return _buildContainerForMainAxis(children: [entranceSpacing, dragTarget]);
        }
      }
//
//       if (_currentIndex.$2 > _ghostIndex.$2) {
//         //the ghost is moving down, i.e. the tile below the ghost is moving up
// //          debugPrint('index:$index item moving up / ghost moving down');
//         if (shiftedIndex == _currentIndex && currentPos == _ghostIndex) {
//           return _buildContainerForMainAxis(children: [ghostSpacing, dragTarget, entranceSpacing]);
//         } else if (shiftedIndex == _currentIndex) {
//           return _buildContainerForMainAxis(children: [dragTarget, entranceSpacing]);
//         } else if (currentPos == _ghostIndex) {
//           return _buildContainerForMainAxis(
//               children: shiftedIndex.$2 <= currentPos.$2 ? [dragTarget, ghostSpacing] : [ghostSpacing, dragTarget]);
//         }
//       } else if (_currentIndex.$2 < _ghostIndex.$2) {
//         //the ghost is moving up, i.e. the tile above the ghost is moving down
// //          debugPrint('index:$index item moving down / ghost moving up');
//         if (shiftedIndex == _currentIndex && currentPos == _ghostIndex) {
//           return _buildContainerForMainAxis(children: [entranceSpacing, dragTarget, ghostSpacing]);
//         } else if (shiftedIndex == _currentIndex) {
//           return _buildContainerForMainAxis(children: [entranceSpacing, dragTarget]);
//         } else if (currentPos == _ghostIndex) {
//           return _buildContainerForMainAxis(
//               children: shiftedIndex.$2 >= currentPos.$2 ? [ghostSpacing, dragTarget] : [dragTarget, ghostSpacing]);
//         }
//       } else {
// //          debugPrint('index:$index using _entranceController: spacing on top:${!(_dragStartIndex < _currentIndex)}');
//         return _buildContainerForMainAxis(
//             children:
//                 _dragStartIndex.$2 < _currentIndex.$2 ? [dragTarget, entranceSpacing] : [entranceSpacing, dragTarget]);
//       }
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
      [Widget? header, Widget? footer]) {
    // It igornes header footer for now
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var colData in children) Expanded(child: Column(mainAxisSize: MainAxisSize.min, children: colData)),
      ],
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
