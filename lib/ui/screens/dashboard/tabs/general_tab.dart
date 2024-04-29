/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:ui';

import 'package:common/service/ui/bottom_sheet_service_interface.dart';
import 'package:common/util/logger.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/ui/components/machine_deletion_warning.dart';
import 'package:mobileraker/ui/components/pull_to_refresh_printer.dart';
import 'package:mobileraker/ui/components/supporter_ad.dart';
import 'package:mobileraker/ui/screens/dashboard/components/control_xyz_card.dart';
import 'package:mobileraker/ui/screens/dashboard/components/machine_status_card.dart';
import 'package:mobileraker/ui/screens/dashboard/components/webcam_card.dart';
import 'package:mobileraker_pro/ui/components/spoolman/spoolman_card.dart';

import '../../../../service/ui/bottom_sheet_service_impl.dart';
import '../../../components/dashboard_card.dart';
import '../../../components/remote_announcements.dart';
import '../../../components/remote_connection_active_card.dart';
import '../components/temperature_card/temperature_sensor_preset_card.dart';
import '../components/z_offset_card.dart';

class GeneralTab extends ConsumerWidget {
  const GeneralTab(this.machineUUID, {super.key});

  final String machineUUID;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _POC(machineUUID: machineUUID);
  }
}

class _POC extends ConsumerStatefulWidget {
  const _POC({super.key, required this.machineUUID});

  final String machineUUID;

  @override
  ConsumerState<_POC> createState() => _POCState();
}

class _POCState extends ConsumerState<_POC> {
  late final List<Widget> cards;

  int? _selectedIndex;

  @override
  void initState() {
    super.initState();
    cards = [
      RemoteConnectionActiveCard(machineId: widget.machineUUID, key: const ValueKey('RemoteConnectionActiveCard')),
      MachineStatusCard(machineUUID: widget.machineUUID, key: const ValueKey('MachineStatusCard')),
      TemperatureSensorPresetCard(machineUUID: widget.machineUUID, key: const ValueKey('TemperatureSensorPresetCard')),
      WebcamCard(machineUUID: widget.machineUUID, key: const ValueKey('WebcamCard')),
      ControlXYZCard(machineUUID: widget.machineUUID, key: const ValueKey('ControlXYZCard')),
      ZOffsetCard(machineUUID: widget.machineUUID, key: const ValueKey('ZOffsetCard')),
      SpoolmanCard(machineUUID: widget.machineUUID, key: const ValueKey('SpoolmanCard')),
    ];
  }

  @override
  Widget build(BuildContext context) {
    var scroll = CustomScrollView(
      slivers: <Widget>[
        const SliverToBoxAdapter(
          child: RemoteAnnouncements(key: ValueKey('RemoteAnnouncements')),
        ),
        const SliverToBoxAdapter(
          child: MachineDeletionWarning(key: ValueKey('MachineDeletionWarning')),
        ),
        const SliverToBoxAdapter(
          child: SupporterAd(key: ValueKey('SupporterAd')),
        ),
        SliverReorderableList(
          onReorderStart: _onReorderStart,
          onReorderEnd: _onReorderEnd,
          onReorder: _onReorder,
          proxyDecorator: (child, index, animation) {
            logger.i('Proxy Decorator: $index, $animation');
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
                onTap: _onAdd,
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
      ],
    );

    return PullToRefreshPrinter(
      child: scroll,
    );
  }

  Widget _buildListItem(Widget child, int index) {
    return ReorderableDelayedDragStartListener(
      key: ValueKey('$index-aa'),
      index: index,
      child: AbsorbPointer(child: child), // Drag handle icon,
    );

    return Row(
      key: ValueKey('$index-aa'),
      children: [
        ReorderableDragStartListener(
          index: index,
          child: const Icon(Icons.drag_handle), // Drag handle icon,
        ),
        Expanded(child: child),
      ],
    );
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final item = cards.removeAt(oldIndex);
      cards.insert(newIndex, item);
    });
  }

  void _onReorderStart(int index) {
    logger.i('Reorder Start: $index');
    _selectedIndex = index;
  }

  void _onReorderEnd(int newIndex) {
    logger.i('Reorder End: $newIndex');
    _selectedIndex = null;
  }

  void _onAdd() async {
    logger.i('Add Widget');
    var result = await ref
        .read(bottomSheetServiceProvider)
        .show(BottomSheetConfig(type: SheetType.dashboardCards, data: widget.machineUUID, isScrollControlled: true));

    if (result.confirmed) {
      logger.i('Selected ${result.data}');
      // Add widget to list
      setState(() {
        cards.add(DasboardCard(type: result.data, machineUUID: widget.machineUUID));
      });
    }

    // Open dialog or sheet to choose widgets
    // You can use showDialog() or showModalBottomSheet() here
  }
}
