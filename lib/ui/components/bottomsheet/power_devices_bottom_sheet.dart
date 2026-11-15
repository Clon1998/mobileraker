/*
 * Copyright (c) 2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/dto/machine/print_state_enum.dart';
import 'package:common/data/dto/power/power_device.dart';
import 'package:common/data/enums/power_state_enum.dart';
import 'package:common/service/moonraker/power_service.dart';
import 'package:common/service/moonraker/printer_service.dart';
import 'package:common/ui/animation/animated_size_and_fade.dart';
import 'package:common/ui/components/sheet_row.dart';
import 'package:common/ui/components/sheet_search_header.dart';
import 'package:common/ui/theme/theme_pack.dart';
import 'package:common/util/misc.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:smooth_sheets/smooth_sheets.dart';

/// The machine's power devices that are meant to be shown. Moonraker convention: devices starting with `_` are hidden.
List<PowerDevice> visiblePowerDevices(List<PowerDevice> devices) =>
    devices.where((d) => !d.name.startsWith('_')).toList();

/// Whether [device] can be switched right now (same rules as the dashboard's power card).
bool canSwitchPowerDevice(PowerDevice device, {required bool isPrinting}) =>
    !(device.status == PowerState.error ||
        device.status == PowerState.unknown ||
        device.status == PowerState.init ||
        device.lockedWhilePrinting && isPrinting);

/// The power devices of a machine with a switch each. Opened from the overview's printer card, e.g. to turn on a
/// printer that is powered off.
class PowerDevicesBottomSheet extends ConsumerWidget {
  const PowerDevicesBottomSheet({super.key, required this.machineUUID});

  final String machineUUID;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeData = Theme.of(context);
    final devices = ref.watch(powerDevicesProvider(machineUUID));
    // Not waiting for the printer: Klipper is usually not ready when this sheet is used
    final isPrinting = ref.watch(
      printerProvider(machineUUID).select((d) => d.value?.print.state == PrintState.printing),
    );

    final body = switch (devices) {
      AsyncValue(hasValue: true, :final value?) => ListView.separated(
        key: const Key('powerDevicesReady'),
        padding: SheetRow.listPadding(context),
        // Only a handful of devices: the sheet fits them instead of taking the full height
        shrinkWrap: true,
        itemCount: visiblePowerDevices(value).length,
        separatorBuilder: (context, _) => SheetRow.separator(context),
        itemBuilder: (context, index) {
          final device = visiblePowerDevices(value)[index];
          return _DeviceRow(
            key: ValueKey(device.name),
            machineUUID: machineUUID,
            device: device,
            isPrinting: isPrinting,
          );
        },
      ),
      AsyncError(:final error) => Padding(
        key: const Key('powerDevicesError'),
        padding: const EdgeInsets.all(32),
        child: Text(
          error.toString(),
          textAlign: TextAlign.center,
          style: themeData.textTheme.bodyMedium?.copyWith(color: themeData.colorScheme.error),
        ),
      ),
      _ => const Padding(
        key: Key('powerDevicesLoading'),
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator.adaptive()),
      ),
    };

    return SheetContentScaffold(
      topBar: SheetSearchHeader(title: tr('pages.dashboard.control.power_card.title')),
      body: AnimatedSizeAndFade(child: body),
    );
  }
}

class _DeviceRow extends ConsumerWidget {
  const _DeviceRow({super.key, required this.machineUUID, required this.device, required this.isPrinting});

  final String machineUUID;
  final PowerDevice device;
  final bool isPrinting;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeData = Theme.of(context);
    final customColors = themeData.extension<CustomColors>();
    final enabled = canSwitchPowerDevice(device, isPrinting: isPrinting);

    final stateColor = switch (device.status) {
      PowerState.on => customColors?.success ?? Colors.green,
      PowerState.error => themeData.colorScheme.error,
      _ => themeData.colorScheme.onSurfaceVariant,
    };

    void toggle(bool on) => ref
        .read(powerDevicesProvider(machineUUID).notifier)
        .setDeviceStatus(device.name, on ? PowerState.on : PowerState.off)
        .ignore();

    return SheetRow(
      onTap: enabled ? () => toggle(device.status != PowerState.on) : null,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(beautifyName(device.name), style: themeData.textTheme.titleMedium),
                Text(
                  device.status.name.capitalize,
                  style: themeData.textTheme.bodySmall?.copyWith(color: stateColor),
                ),
              ],
            ),
          ),
          Switch.adaptive(value: device.status == PowerState.on, onChanged: enabled ? toggle : null),
        ],
      ),
    );
  }
}
