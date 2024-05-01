/*
 * Copyright (c) 2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:ui';

import 'package:common/data/model/hive/dashboard_component.dart';
import 'package:common/data/model/hive/dashboard_tab.dart';
import 'package:common/ui/components/warning_card.dart';
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

    var cards = widget.tab.components.map((e) {
      if (widget.isEditing) {
        return DasboardCard.preview(type: e.type);
      }
      return DasboardCard(type: e.type, machineUUID: widget.machineUUID);
    }).toList();

    var themeData = Theme.of(context);

    var scroll = PullToRefreshPrinter(
      child: CustomScrollView(
        key: PageStorageKey<String>(widget.tab.uuid),
        slivers: <Widget>[
          if (widget.isEditing)
            const SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              sliver: SliverToBoxAdapter(
                child: WarningCard(
                  leadingIcon: Icon(Icons.dashboard_customize),
                  margin: EdgeInsets.zero,
                  title: Text('Editing Mode'),
                  subtitle: Text('You can now reorder, add and remove cards and pages.'),
                ),
              ),
            ),
          if (!widget.isEditing)
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
          if (widget.isEditing)
            SliverPadding(
              padding: const EdgeInsets.only(left: 4.0, right: 4.0, bottom: 40),
              sliver: SliverToBoxAdapter(
                child: _EditingSuffix(widget: widget, themeData: themeData),
              ),
            ),
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

class _EditingSuffix extends StatelessWidget {
  const _EditingSuffix({
    super.key,
    required this.widget,
    required this.themeData,
  });

  //TODO.... dont pass widget
  final DashboardTabPage widget;
  final ThemeData themeData;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(8.0),
          onTap: () => widget.onAddComponent!(widget.tab),
          child: Container(
            // width: MediaQuery.sizeOf(context).width - 32,
            height: 128,
            padding: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              color: themeData.colorScheme.primaryContainer.withOpacity(0.25),
              border: Border.all(color: themeData.colorScheme.primary, width: 1.5),
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
        const SizedBox(height: 8.0),
        Column(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                FilledButton(onPressed: () => null, child: const Text('<<')),
                FilledButton(onPressed: () => null, child: const Text('>>')),
              ],
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: themeData.colorScheme.error,
                foregroundColor: themeData.colorScheme.onError,
              ),
              onPressed: () => widget.onRemove!(widget.tab),
              child: const Text('Remove Page'),
            ),
          ],
        ),
      ],
    );
  }
}
