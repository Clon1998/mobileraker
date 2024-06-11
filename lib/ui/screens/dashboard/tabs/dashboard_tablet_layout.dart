/*
 * Copyright (c) 2024. Patrick Schmidt.
 * All rights reserved.
 */

// ignore_for_file: avoid-passing-async-when-sync-expected

import 'package:common/data/model/hive/dashboard_component.dart';
import 'package:common/data/model/hive/dashboard_tab.dart';
import 'package:common/util/logger.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import '../../../components/dashboard_card.dart';
import '../components/editing_dashboard_card.dart';
import '../test2.dart';

class DashboardTabletLayout extends HookWidget {
  const DashboardTabletLayout({
    super.key,
    required this.machineUUID,
    required this.tabs,
    required this.isEditing,
    this.staticWidgets = const [],
    this.onReorder,
    this.onAddComponent,
    this.onRemoveComponent,
    this.onRemove,
    required this.onRequestedEdit,
  });

  final String machineUUID;

  final bool isEditing;

  final List<Widget> staticWidgets;

  final List<DashboardTab> tabs;

  /// Callback when a component of the tab should be reordered
  final void Function(DashboardTab oldTab, DashboardTab newTab, int oldIndex, int newIndex)? onReorder;

  /// Callback when the add widget button is pressed
  final void Function(DashboardTab tab)? onAddComponent;

  /// Callback when a component of the tab should be removed
  final void Function(DashboardTab tab, DashboardComponent component)? onRemoveComponent;

  /// Callback when the tab should be removed
  final void Function(DashboardTab tab)? onRemove;

  final void Function() onRequestedEdit;

  @override
  Widget build(BuildContext context) {
    final sc = useScrollController(debugLabel: 'DashboardTabletLayout');

    final Widget body;
    if (isEditing) {
      body = ReorderableFlexi(
        scrollController: sc,
        reorderAnimationDuration: const Duration(milliseconds: 2000),
        onReorder: (oldIndex, newIndex) {
          logger.i('On Reorder: $oldIndex -> $newIndex');
          if (onReorder != null) {
            onReorder!(tabs[oldIndex.$1], tabs[newIndex.$1], oldIndex.$2, newIndex.$2);
          }
        },
        direction: null,
        children: [
          for (var tab in tabs)
            [
              //TODO: Add info cards here only for index = 0
              for (var component in tab.components)
                EditingDashboardCard(
                  key: Key('ED-${tab.uuid}:${component.type.name}:${component.uuid}'),
                  child: DasboardCard.preview(type: component.type),
                  onRemovedTap: () {
                    if (onRemoveComponent != null) {
                      onRemoveComponent!(tab, component);
                    }
                  },
                ),
            ],
        ],
        buildDraggableFeedback: (BuildContext context, BoxConstraints constraints, Widget child) {
          return Material(
            // elevation: 10.0,
            color: Colors.transparent,
            // borderRadius: BorderRadius.zero,
            child: ConstrainedBox(constraints: constraints, child: child),
          );

          // return AnimatedBuilder(
          //   animation: animation,
          //   builder: (BuildContext ctx, Widget? c) {
          //     final double animValue = Curves.easeInOut.transform(animation.value);
          //     final double elevation = lerpDouble(1, 0.85, animValue)!;
          //     return Transform.scale(scale: elevation, child: c);
          //   },
          //   child: child,
          // );
        },
      );
    } else {
      body = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < tabs.length; i++)
            Expanded(
              child: Column(
                children: [
                  if (i == 0) ...staticWidgets,
                  for (var component in tabs[i].components)
                    KeyedSubtree(
                      key: Key('NE-$i:${component.uuid}'),
                      child: GestureDetector(
                        onLongPress: onRequestedEdit,
                        child: DasboardCard(
                          type: component.type,
                          machineUUID: machineUUID,
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      );
    }

    return SingleChildScrollView(
      // primary: true,
      controller: sc,
      physics: const ClampingScrollPhysics(),
      child: body,
    );

    //
    // return ReorderableColumns(
    //     data: [
    //       [
    //         // for (var e in [...left]) DasboardCard(key: Key(e.name), type: e, machineUUID: machineUUID),
    //         for (var e in [...left])
    //           Card(
    //               key: Key(e.name),
    //               child: SizedBox(
    //                 child: Text(e.name),
    //                 height: 250,
    //                 width: double.infinity,
    //               )),
    //       ],
    //       [
    //         // for (var e in [...right]) DasboardCard(key: Key(e.name), type: e, machineUUID: machineUUID),
    //         for (var e in [...right])
    //           Card(
    //               key: Key(e.name),
    //               child: SizedBox(
    //                 child: Text(e.name),
    //                 height: 250,
    //                 width: double.infinity,
    //               )),
    //       ]
    //     ],
    //     onReorder: (oldColumnIndex, oldItemIndex, newColumnIndex, newItemIndex) {
    //       logger.i('On Reorder: $oldColumnIndex, $oldItemIndex, $newColumnIndex, $newItemIndex');
    //     });
    //
    // // return ReorderableBuilder(
    //   children: comb,
    //   onReorder: (updated) {
    //     logger.i('On Reorder: updated');
    //   },
    //   builder: (ele) {
    //     return GridView(
    //       key: _gridViewKey,
    //       // controller: _scrollController,
    //       children: comb,
    //       gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
    //         crossAxisCount: 2,
    //         mainAxisSpacing: 4,
    //         crossAxisSpacing: 8,
    //       ),
    //     );
    //   },
    // );

    // return KanbanBoard([
    //   BoardListsData(
    //     items: [
    //       for (var type in left) DasboardCard(type: type, machineUUID: machineUUID),
    //     ],
    //   ),
    //   BoardListsData(
    //     items: [
    //       for (var type in right) DasboardCard(type: type, machineUUID: machineUUID),
    //     ],
    //   ),
    // ]);

    // return PullToRefreshPrinter(
    //   child: SingleChildScrollView(
    //     child: Row(
    //       crossAxisAlignment: CrossAxisAlignment.start,
    //       children: [
    //         Flexible(
    //           child: Column(
    //             mainAxisSize: MainAxisSize.min,
    //             children: [
    //               ..._staticWidgets,
    //               for (var type in left)
    //                 DasboardCard(
    //                   type: type,
    //                   machineUUID: machineUUID,
    //                 ),
    //             ],
    //           ),
    //         ),
    //         Flexible(
    //           child: Column(
    //             mainAxisSize: MainAxisSize.min,
    //             children: [
    //               for (var type in right)
    //                 DasboardCard(
    //                   type: type,
    //                   machineUUID: machineUUID,
    //                 ),
    //             ],
    //           ),
    //         ),
    //       ],
    //     ),
    //   ),
    // );
  }
}

class _EditingSuffix extends StatelessWidget {
  const _EditingSuffix({super.key, required this.onAddComponent});

  final void Function() onAddComponent;

  @override
  Widget build(BuildContext context) {
    final themeData = Theme.of(context);

    return InkWell(
      borderRadius: BorderRadius.circular(8.0),
      onTap: onAddComponent,
      child: Container(
        // width: MediaQuery.sizeOf(context).width - 32,
        height: 128,
        padding: const EdgeInsets.all(8.0),
        decoration: BoxDecoration(
          color: themeData.colorScheme.primaryContainer.withOpacity(0.25),
          border: Border.all(color: themeData.colorScheme.primary, width: 1.5),
          borderRadius: BorderRadius.circular(8.0),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Icon(Icons.add),
            const SizedBox(width: 8.0),
            const Text('pages.customizing_dashboard.add_card').tr(),
          ],
        ),
      ),
    );
  }
}
