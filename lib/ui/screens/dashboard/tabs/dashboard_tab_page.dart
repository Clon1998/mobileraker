/*
 * Copyright (c) 2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:ui';

import 'package:common/data/model/hive/dashboard_component.dart';
import 'package:common/data/model/hive/dashboard_tab.dart';
import 'package:common/util/logger.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../components/dashboard_card.dart';
import '../../../components/pull_to_refresh_printer.dart';

class DashboardTabPage extends ConsumerStatefulWidget {
  const DashboardTabPage({
    super.key,
    required this.machineUUID,
    required this.tab,
    this.staticWidgets = const [],
    this.isEditing = false,
    this.onReorder,
    this.onAddComponent,
    this.onRemoveComponent,
    this.onRemove,
  }) : assert(
            !isEditing || onReorder != null && onAddComponent != null && onRemoveComponent != null && onRemove != null,
            'If editing is enabled, all callbacks must be provided');

  final String machineUUID;

  final DashboardTab tab;

  final bool isEditing;

  final List<Widget> staticWidgets;

  /// Callback when a component of the tab should be reordered
  final void Function(DashboardTab tab, int oldIndex, int newIndex)? onReorder;

  /// Callback when the add widget button is pressed
  final void Function(DashboardTab tab)? onAddComponent;

  /// Callback when a component of the tab should be removed
  final void Function(DashboardTab tab, DashboardComponent component)? onRemoveComponent;

  /// Callback when the tab should be removed
  final void Function(DashboardTab tab)? onRemove;

  @override
  ConsumerState<DashboardTabPage> createState() => DashboardTabPageState();
}

class DashboardTabPageState extends ConsumerState<DashboardTabPage> {
  @override
  Widget build(BuildContext context) {
    logger.i('Rebuilding tab card page for ${widget.tab.name} (${widget.tab.uuid})');

    var cards = widget.tab.components.map((e) => DasboardCard(type: e.type, machineUUID: widget.machineUUID)).toList();

    var scroll = PullToRefreshPrinter(
      child: CustomScrollView(
        key: PageStorageKey<String>(widget.tab.uuid),
        slivers: <Widget>[
          for (var widget in widget.staticWidgets) SliverToBoxAdapter(child: widget),
          SliverReorderableList(
            onReorderStart: _onReorderStart,
            onReorderEnd: _onReorderEnd,
            onReorder: (oldIndex, newIndex) {
              if (!widget.isEditing) return;
              widget.onReorder!(widget.tab, oldIndex, newIndex);
            },
            proxyDecorator: (child, index, animation) {
              // logger.i('Proxy Decorator: $index, $animation');
              return AnimatedBuilder(
                animation: animation,
                builder: (BuildContext ctx, Widget? c) {
                  final double animValue = Curves.easeInOut.transform(animation.value);
                  final double elevation = lerpDouble(1, 0.85, animValue)!;
                  return Transform.scale(
                    scale: elevation,
                    child: c,
                  );
                },
                child: child,
              );
            },
            itemBuilder: (BuildContext context, int index) {
              // return childs[index];
              return _buildListItem(cards[index], index);
            },
            itemCount: cards.length,
          ),
          if (widget.isEditing) ...[
            SliverToBoxAdapter(
              child: Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                decoration: const BoxDecoration(
                  color: Colors.white,
                ),
                child: Material(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8.0),
                    onTap: () => widget.onAddComponent!(widget.tab),
                    child: Container(
                      width: MediaQuery.sizeOf(context).width - 32,
                      height: 128,
                      padding: const EdgeInsets.all(8.0),
                      decoration: BoxDecoration(
                        // color: Colors.white30,
                        border: Border.all(color: Colors.grey, width: 1.5),
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Icon(Icons.add),
                          SizedBox(width: 8.0),
                          Text('Add Widget'),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  mainAxisSize: MainAxisSize.max,
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: Colors.red),
                      onPressed: () => widget.onRemove!(widget.tab),
                      child: Text('Remove Page'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );

    return scroll;
  }

  Widget _buildListItem(Widget child, int index) {
    return ReorderableDelayedDragStartListener(
      key: ValueKey('$index-aa'),
      index: index,
      enabled: widget.isEditing,
      child: AbsorbPointer(absorbing: widget.isEditing, child: child),
    );
  }

  void _onReorderStart(int index) {
    logger.i('Reorder Start: $index');
    // _selectedIndex = index;
  }

  void _onReorderEnd(int newIndex) {
    logger.i('Reorder End: $newIndex');
    // _selectedIndex = null;
  }
}
