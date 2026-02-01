/*
 * Copyright (c) 2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/service/moonraker/klipper_system_service.dart';
import 'package:common/ui/components/async_guard.dart';
import 'package:common/util/extensions/async_ext.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/ui/components/tool_channel_selector/macro_tool_selector.dart';
import 'package:mobileraker/ui/components/tool_channel_selector/skeleton_tool_channel.dart';
import 'package:mobileraker/ui/components/tool_channel_selector/u1_tool_selector.dart';

class MachineToolChannelSelector extends ConsumerWidget {
  const MachineToolChannelSelector({super.key, required this.machineUUID});

  final String machineUUID;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncGuard(
      toGuard: klippySystemInfoProvider(machineUUID).selectAs((d) => true),
      childOnData: _MachineToolChannelSelector(machineUUID: machineUUID),
      childOnLoading: SkeletonToolChannel(),
    );
  }
}

class _MachineToolChannelSelector extends ConsumerWidget {
  const _MachineToolChannelSelector({super.key, required this.machineUUID});

  final String machineUUID;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSnapmakerU1 = ref.watch(
      klippySystemInfoProvider(machineUUID).selectRequireValue(((d) => d.productInfo?.machineType == 'Snapmaker U1')),
    );
    if (isSnapmakerU1) {
      return U1ToolSelector(machineUUID: machineUUID);
    }
    return MacroToolSelector(machineUUID: machineUUID);
  }
}
