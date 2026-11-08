/*
 * Copyright (c) 2023-2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:collection/collection.dart';
import 'package:common/data/dto/machine/heaters/extruder.dart';
import 'package:common/data/dto/machine/heaters/heater_bed.dart';
import 'package:common/data/dto/machine/print_state_enum.dart';
import 'package:common/data/dto/machine/temperature_sensor_mixin.dart';
import 'package:common/data/model/hive/machine.dart';
import 'package:common/data/model/moonraker_db/webcam_info.dart';
import 'package:common/network/jrpc_client_provider.dart';
import 'package:common/service/moonraker/printer_service.dart';
import 'package:common/service/moonraker/webcam_service.dart';
import 'package:common/service/setting_service.dart';
import 'package:common/service/ui/bottom_sheet_service_interface.dart';
import 'package:common/ui/components/webcam_status_view.dart';
import 'package:common/util/extensions/async_ext.dart';
import 'package:common/util/extensions/object_extension.dart';
import 'package:common/util/extensions/printer_extension.dart';
import 'package:common/util/logger.dart';
import 'package:common/util/misc.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/service/ui/bottom_sheet_service_impl.dart';
import 'package:mobileraker/ui/components/bottomsheet/selection_bottom_sheet.dart';
import 'package:mobileraker/ui/components/connection/client_type_indicator.dart';
import 'package:mobileraker/ui/components/double_tap_zoom_viewer.dart';
import 'package:mobileraker/ui/components/webcam/webcam.dart';
import 'package:mobileraker/ui/screens/fullcam/full_cam_controller.dart';
import 'package:mobileraker/util/extensions/temperature_sensor_extension.dart';

class FullCamPage extends ConsumerWidget {
  final Machine machine;
  final WebcamInfo initialCam;

  const FullCamPage(this.machine, this.initialCam, {super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ProviderScope(
      overrides: [
        fullCamMachineProvider.overrideWithValue(machine),
        initialCamProvider.overrideWithValue(initialCam),
        // fullCamPageControllerProvider,
      ],
      child: const _FullCamView(),
    );
  }
}

class _FullCamView extends ConsumerWidget {
  const _FullCamView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var machine = ref.watch(fullCamMachineProvider);
    var clientType = ref.watch(jrpcClientTypeProvider(machine.uuid));
    var selectedCam = ref.watch(fullCamPageControllerProvider);

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            DoubleTapZoomViewer(
              child: SizedBox.expand(
                child: Center(
                  child: Webcam(
                    machine: machine,
                    webcamInfo: selectedCam,
                    stackContent: const [_StackContent()],
                    showFpsIfAvailable: true,
                    showRemoteIndicator: false,
                    statusStyle: WebcamStatusStyle.fullscreen,
                  ),
                ),
              ),
            ),
            const _CamSelector(),
            Align(
              alignment: Alignment.bottomRight,
              child: IconButton(
                icon: const Icon(Icons.close_fullscreen_outlined),
                tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            Align(
              alignment: Alignment.bottomLeft,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: MachineActiveClientTypeIndicator(machineId: machine.uuid),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Formats a reading as `current/target`, the target is omitted if the sensor has none or is turned off.
String _formatTemperature(double temperature, double target, NumberFormat numFormat) =>
    '${numFormat.format(temperature)}${target > 0 ? '/${numFormat.format(target)}' : ''}';

class _StackContent extends ConsumerWidget {
  const _StackContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var machine = ref.watch(fullCamMachineProvider);
    var printer = ref.watch(printerProvider(machine.uuid));

    final sensorsKey = CompositeKey.keyWithString(UtilityKeys.fullCamSensors, machine.uuid);
    // Watched to rebuild once the selection changes
    final selectedSensors = ref.watch(stringListSettingProvider(sensorsKey));
    final settingService = ref.watch(settingServiceProvider);

    var numFormat = NumberFormat.decimalPatternDigits(locale: context.locale.toStringWithSeparator(), decimalDigits: 1);

    return Positioned.fill(
      child: Stack(
        children: printer.maybeWhen(
          orElse: () => [],
          data: (d) {
            // If the user never picked sensors, show the tool(s), the bed and the auto-detected chamber sensor
            final selectedEntries = settingService.containsKey(sensorsKey)
                ? selectedSensors
                : [
                    for (final extruder in d.extruders) extruder.configEntry,
                    ?d.heaterBed?.configEntry,
                    ?d.chamberSensor?.configEntry,
                  ];
            final activeIndex = d.toolhead.activeExtruderIndex;

            final info = [
              for (final sensor in d.visibleTemperatureSensors)
                if (selectedEntries.contains(sensor.configEntry))
                  _sensorSpan(sensor, d.extruderCount, activeIndex, numFormat),
            ];

            return [
              Positioned.fill(
                child: Align(
                  alignment: Alignment.topLeft,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () =>
                        _selectSensors(ref, machine.uuid, d.visibleTemperatureSensors, d.extruderCount, selectedEntries),
                    child: Container(
                      padding: const EdgeInsets.only(top: 5, left: 2, right: 8, bottom: 4),
                      // Without any sensor selected, an icon is shown to still be able to open the selection
                      child: info.isEmpty
                          ? const Icon(Icons.thermostat, size: 18, color: Colors.white70)
                          : Text.rich(
                              TextSpan(
                                children: [
                                  for (final (i, span) in info.indexed) ...[if (i > 0) const TextSpan(text: '\n'), span],
                                ],
                              ),
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70),
                            ),
                    ),
                  ),
                ),
              ),
              if (d.print.state == PrintState.printing)
                Positioned.fill(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: LinearProgressIndicator(value: d.printProgress),
                  ),
                ),
            ];
          },
        ),
      ),
    );
  }

  TextSpan _sensorSpan(TemperatureSensorMixin sensor, int extruderCount, int? activeExtruder, NumberFormat numFormat) {
    final temp = _formatTemperature(sensor.temperature, sensor.targetTemperature, numFormat);

    return switch (sensor) {
      Extruder() when extruderCount == 1 => TextSpan(
          text: tr('pages.dashboard.general.temp_preset_card.h_temp', args: [temp]),
        ),
      Extruder(:final num) => TextSpan(
          text: 'T$num: $temp °C',
          style: num == activeExtruder ? const TextStyle(fontWeight: FontWeight.bold) : null,
        ),
      HeaterBed() => TextSpan(text: tr('pages.dashboard.general.temp_preset_card.b_temp', args: [temp])),
      _ => TextSpan(text: '${sensor.displayName()} $temp°C'),
    };
  }

  Future<void> _selectSensors(
    WidgetRef ref,
    String machineUUID,
    List<TemperatureSensorMixin> sensors,
    int extruderCount,
    List<String> selected,
  ) async {
    if (sensors.isEmpty) return;

    final res = await ref.read(bottomSheetServiceProvider).show(
          BottomSheetConfig(
            type: SheetType.selections,
            data: SelectionBottomSheetArgs<String>(
              options: [
                for (final sensor in sensors)
                  SelectionOption(
                    value: sensor.configEntry,
                    label: sensor.displayName(extruderCount: extruderCount),
                    leading: Icon(sensor.kindIcon),
                    // The options are only built once, therefore the reading needs its own reactive widget
                    trailing: _LiveTemperature(machineUUID: machineUUID, configEntry: sensor.configEntry),
                    horizontalTitleGap: 8,
                    selected: selected.contains(sensor.configEntry),
                  ),
              ],
              title: const Text('pages.full_cam.shown_sensors').tr(),
              multiSelect: true,
              showSearch: false,
            ),
          ),
        );

    if (!res.confirmed) return;
    talker.info('[FullCamPage($machineUUID)] Selected sensors: ${res.data}');
    await ref.read(settingServiceProvider).writeList(
          CompositeKey.keyWithString(UtilityKeys.fullCamSensors, machineUUID),
          (res.data as List).cast<String>(),
        );
  }
}

/// Current reading of a sensor, updates with the printer state.
class _LiveTemperature extends ConsumerWidget {
  const _LiveTemperature({required this.machineUUID, required this.configEntry});

  final String machineUUID;

  final String configEntry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reading = ref
        .watch(printerProvider(machineUUID).selectAs((d) => d.visibleTemperatureSensors
            .firstWhereOrNull((s) => s.configEntry == configEntry)
            ?.let((s) => (s.temperature, s.targetTemperature))))
        .value;
    if (reading == null) return const SizedBox.shrink();

    final numFormat =
        NumberFormat.decimalPatternDigits(locale: context.locale.toStringWithSeparator(), decimalDigits: 1);
    return Text('${_formatTemperature(reading.$1, reading.$2, numFormat)} °C',
        style: Theme.of(context).textTheme.bodySmall);
  }
}

class _CamSelector extends ConsumerWidget {
  const _CamSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var machine = ref.watch(fullCamMachineProvider);

    var webcams = ref.watch(allSupportedWebcamInfosProvider(machine.uuid)).value ?? [];

    if (webcams.length <= 1) return const SizedBox.shrink();

    return Align(
      alignment: Alignment.bottomCenter,
      child: DropdownButton<WebcamInfo>(
        value: ref.watch(fullCamPageControllerProvider),
        onChanged: ref.watch(fullCamPageControllerProvider.notifier).selectCam,
        items: webcams.map((c) => DropdownMenuItem(value: c, child: Text(beautifyName(c.name)))).toList(),
      ),
    );
  }
}
