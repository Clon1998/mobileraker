/*
 * Copyright (c) 2025. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:async';

import 'package:common/data/dto/console/command.dart';
import 'package:common/data/dto/console/gcode_store_entry.dart';
import 'package:common/data/dto/files/gcode_file.dart';
import 'package:common/data/dto/machine/exclude_object.dart';
import 'package:common/data/dto/machine/leds/led.dart';
import 'package:common/data/dto/machine/printer.dart';
import 'package:common/data/dto/machine/printer_axis_enum.dart';
import 'package:common/data/dto/machine/printer_builder.dart';
import 'package:common/data/dto/server/klipper.dart';
import 'package:common/data/dto/server/moonraker_version.dart';
import 'package:common/service/moonraker/klippy_service.dart';
import 'package:common/service/moonraker/printer_service.dart';
import 'package:common/util/extensions/build_context_extension.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/ui/components/console/console_history.dart';
import 'package:mobileraker/util/extensions/text_editing_controller_extension.dart';

import 'command_input.dart';
import 'command_suggestions.dart';
import 'console_settings_button.dart';

class ConsoleCard extends HookWidget {
  const ConsoleCard({super.key, required this.machineUUID});

  final String machineUUID;

  static Widget preview() {
    return const _Preview();
  }

  @override
  Widget build(BuildContext context) {
    final consoleTextEditor = useTextEditingController();
    final scrollController = useScrollController();

    return Card(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(FlutterIcons.console_line_mco),
              title: const Text('pages.console.card_title').tr(),
              // trailing: IconButton(onPressed: () => context.pushNamed(AppRoute.console.name), icon: Icon(Icons.fullscreen)),
              trailing: HookBuilder(
                builder: (BuildContext context) {
                  bool hasOffset = useListenableSelector(
                    scrollController,
                    () => scrollController.hasClients && scrollController.offset > 0,
                  );

                  return AnimatedSwitcher(
                    duration: kThemeAnimationDuration,
                    child: hasOffset
                        ? IconButton(
                            key: Key('console_scroll_to_bottom'),
                            onPressed: () => scrollController.animateTo(
                              0,
                              duration: kThemeAnimationDuration,
                              curve: Curves.easeOutCubic,
                            ),
                            icon: Icon(Icons.arrow_downward),
                          )
                        : const SizedBox.shrink(key: Key('hide_console_scroll_to_bottom')),
                  );
                },
              ),
            ),
            Flexible(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: context.isLargerThanCompact ? 300 : 200),
                child: ConsoleHistory(
                  machineUUID: machineUUID,
                  onCommandTap: (s) => consoleTextEditor.textAndMoveCursor = s,
                  scrollController: scrollController,
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                ),
              ),
            ),
            Divider(),
            CommandSuggestions(
              machineUUID: machineUUID,
              onSuggestionTap: (s) => consoleTextEditor.textAndMoveCursor = s,
              textNotifier: consoleTextEditor,
            ),
            Padding(
              padding: EdgeInsets.all(8),
              child: CommandInput(
                machineUUID: machineUUID,
                consoleTextEditor: consoleTextEditor,
                emptyInputSuffix: ConsoleSettingsButton(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Preview extends HookWidget {
  static const String _machineUUID = 'preview';

  const _Preview({super.key});

  @override
  Widget build(BuildContext context) {
    useAutomaticKeepAlive();
    return ProviderScope(
      overrides: [
        printerAvailableCommandsProvider(_machineUUID).overrideWith((_) {
          return Future.value([
            Command('RESTART', 'Reload config file and restart host software'),
            Command('FIRMWARE_RESTART', 'Restart firmware, host, and reload config'),
            Command('STATUS', 'Report the printer status'),
          ]);
        }),
        printerGCodeStoreProvider(_machineUUID).overrideWith(() => _PreviewGcodeStore()),
        printerServiceProvider(_machineUUID).overrideWith((_) => _PreviewPrinterService()),
        klipperProvider(_machineUUID).overrideWith((_) async* {
          yield KlipperInstance(
            klippyConnected: true,
            klippyState: KlipperState.ready,
            moonrakerVersion: MoonrakerVersion(major: 1, minor: 0, patch: 0, commits: 0, commitHash: ''),
          );
        }),
      ],
      child: const ConsoleCard(machineUUID: _machineUUID),
    );
  }
}

class _PreviewGcodeStore extends PrinterGCodeStore {
  @override
  FutureOr<List<GCodeStoreEntry>> build(String machineUUID) {
    return [
      GCodeStoreEntry.command('FIRMWARE_RESTART'),
      GCodeStoreEntry.response('Klippy reported ready state'),
      GCodeStoreEntry.command('G1 X10 Y10 F3000'),
      GCodeStoreEntry.response('Must home axis first'),
      GCodeStoreEntry.command('G28'),
      GCodeStoreEntry.response('Axis homed'),
      GCodeStoreEntry.response('Mobileraker - Your 3D Printer App'),
    ];
  }

  @override
  void appendCommand(String command) {
    // Do nothing
  }
}

class _PreviewPrinterService implements PrinterService {
  @override
  Printer current = PrinterBuilder.preview().build();

  @override
  Future<void> activateExtruder([int extruderIndex = 0]) {
    throw UnimplementedError();
  }

  @override
  Future<bool> bedMeshLevel() {
    throw UnimplementedError();
  }

  @override
  Future<bool> bedScrewsAdjust() {
    throw UnimplementedError();
  }

  @override
  cancelPrint() {
    throw UnimplementedError();
  }

  @override
  Future<void> clearBedMeshProfile() {
    throw UnimplementedError();
  }

  @override
  Printer? get currentOrNull => current;

  @override
  void dispose() {
    // No-op for preview
  }

  @override
  bool get disposed => false;

  @override
  void excludeObject(ParsedObject objToExc) {
    // No-op for preview
  }

  @override
  Future<void> filamentSensor(String sensorName, bool enable) {
    throw UnimplementedError();
  }

  @override
  firmwareRetraction({
    double? retractLength,
    double? retractSpeed,
    double? unretractExtraLength,
    double? unretractSpeed,
  }) {
    throw UnimplementedError();
  }

  @override
  flowMultiplier(int flow) {
    throw UnimplementedError();
  }

  @override
  Future<bool> gCode(String script, {bool throwOnError = false, bool showSnackOnErr = true}) {
    return Future.value(true);
  }

  @override
  gCodeMacro(String macro) {
    throw UnimplementedError();
  }

  @override
  Stream<String> get gCodeResponseStream => Stream.empty();

  @override
  Future<List<Command>> gcodeHelp() {
    throw UnimplementedError();
  }

  @override
  Future<List<GCodeStoreEntry>> gcodeStore() {
    throw UnimplementedError();
  }

  @override
  genericFanFan(String fanName, double perc) {
    throw UnimplementedError();
  }

  @override
  bool get hasCurrent => true;

  @override
  Future<bool> homePrintHead(Set<PrinterAxis> axis) {
    throw UnimplementedError();
  }

  @override
  Future<void> led(String ledName, Pixel pixel) {
    throw UnimplementedError();
  }

  @override
  Future<void> loadBedMeshProfile(String profileName) {
    throw UnimplementedError();
  }

  @override
  Future<bool> m117([String? msg]) {
    throw UnimplementedError();
  }

  @override
  Future<bool> m84() {
    throw UnimplementedError();
  }

  @override
  Future<void> moveExtruder(num length, [num velocity = 5, bool waitMove = false]) {
    throw UnimplementedError();
  }

  @override
  Future<void> movePrintHead({double? x, double? y, double? z, double feedRate = 100}) {
    throw UnimplementedError();
  }

  @override
  Future<void> outputPin(String pinName, double value) {
    throw UnimplementedError();
  }

  @override
  String get ownerUUID => 'preview';

  @override
  partCoolingFan(double perc) {
    throw UnimplementedError();
  }

  @override
  pausePrint() {
    throw UnimplementedError();
  }

  @override
  pressureAdvance(double pa) {
    throw UnimplementedError();
  }

  @override
  Stream<Printer> get printerStream => Stream.value(current);

  @override
  Future<bool> probeCalibrate() {
    throw UnimplementedError();
  }

  @override
  Future<bool> quadGantryLevel() {
    throw UnimplementedError();
  }

  @override
  Ref<Object?> get ref => throw UnimplementedError();

  @override
  Future<void> refreshPrinter() {
    // No-op for preview
    return Future.value();
  }

  @override
  reprintCurrentFile() {
    throw UnimplementedError();
  }

  @override
  resetPrintStat() {
    throw UnimplementedError();
  }

  @override
  resumePrint() {
    throw UnimplementedError();
  }

  @override
  Future<bool> saveConfig() {
    throw UnimplementedError();
  }

  @override
  Future<bool> screwsTiltCalculate() {
    throw UnimplementedError();
  }

  @override
  Future<bool> selectBeaconModel(String model) {
    throw UnimplementedError();
  }

  @override
  setAccelToDecel(int accelDecel) {
    throw UnimplementedError();
  }

  @override
  setAccelerationLimit(int accel) {
    throw UnimplementedError();
  }

  @override
  setGcodeOffset({double? x, double? y, double? z, int? move}) {
    throw UnimplementedError();
  }

  @override
  setHeaterTemperature(String heater, int target) {
    throw UnimplementedError();
  }

  @override
  setSquareCornerVelocityLimit(double sqVel) {
    throw UnimplementedError();
  }

  @override
  setTemperatureFanTarget(String fan, int target) {
    throw UnimplementedError();
  }

  @override
  setVelocityLimit(int vel) {
    throw UnimplementedError();
  }

  @override
  smoothTime(double st) {
    throw UnimplementedError();
  }

  @override
  speedMultiplier(int speed) {
    throw UnimplementedError();
  }

  @override
  startPrintFile(GCodeFile file) {
    throw UnimplementedError();
  }

  @override
  Future<void> updateCurrentFile(String? file) {
    throw UnimplementedError();
  }

  @override
  Future<bool> zEndstopCalibrate() {
    throw UnimplementedError();
  }

  @override
  Future<bool> zTiltAdjust() {
    throw UnimplementedError();
  }

  @override
  Future<void> forceMovePrintHead({required String stepper, required distance, double feedRate = 100}) {
    throw UnimplementedError();
  }
}
