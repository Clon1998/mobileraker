/*
 * Copyright (c) 2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:ui';

import 'package:collection/collection.dart';
import 'package:common/data/dto/config/config_file_object_identifiers_enum.dart';
import 'package:common/data/dto/machine/filament_sensors/filament_motion_sensor.dart';
import 'package:common/data/dto/machine/filament_sensors/filament_switch_sensor.dart';
import 'package:common/data/dto/machine/printer.dart';
import 'package:common/data/model/moonraker_db/settings/reordable_element.dart';
import 'package:common/service/machine_service.dart';
import 'package:common/service/moonraker/printer_service.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../components/async_value_widget.dart';
import '../../components/section_header.dart';

part 'misc_ordering_list.g.dart';

class MiscOrderingList extends ConsumerWidget {
  const MiscOrderingList({super.key, required this.machineUuid});

  final String machineUuid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var controller = ref.read(miscOrderingListControllerProvider(machineUuid).notifier);
    var model = ref.watch(miscOrderingListControllerProvider(machineUuid));
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SectionHeader(
          title: tr('pages.printer_edit.misc_ordering.title'),
          trailing: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
            child: Tooltip(
                showDuration: const Duration(seconds: 5),
                message: tr('pages.printer_edit.misc_ordering.helper'),
                margin: const EdgeInsets.symmetric(horizontal: 16.0),
                triggerMode: TooltipTriggerMode.tap,
                child: Icon(Icons.help_outline, color: Theme.of(context).colorScheme.primary)),
          ),
        ),
        AsyncValueWidget(
          skipLoadingOnReload: true,
          value: model,
          data: (items) {
            if (items.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(8.0),
                child: const Text('pages.printer_edit.misc_ordering.no_controls').tr(),
              );
            }

            return ReorderableListView(
              buildDefaultDragHandles: true,
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              onReorder: controller.onReorder,
              onReorderStart: (i) {
                FocusScope.of(context).unfocus();
              },
              proxyDecorator: (child, _, animation) {
                return AnimatedBuilder(
                  animation: animation,
                  builder: (BuildContext ctx, Widget? c) {
                    final double animValue = Curves.easeInOut.transform(animation.value);
                    final double elevation = lerpDouble(0, 6, animValue)!;
                    return Material(
                      type: MaterialType.transparency,
                      elevation: elevation,
                      child: c,
                    );
                  },
                  child: child,
                );
              },
              children: List.generate(
                items.length,
                (index) {
                  var item = items[index];
                  return Card(
                    key: ValueKey(item.uuid),
                    child: ListTile(
                      leading: ReorderableDragStartListener(
                        index: index,
                        child: const Icon(Icons.drag_handle),
                      ),
                      title: Text(item.beautifiedName),
                      // leading: Icon(
                      //   ConfigFileObjectIdentifiers.iconForKind(item.kind),
                      //   color: Theme.of(context).colorScheme.secondary,
                      // ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }
}

@riverpod
class MiscOrderingListController extends _$MiscOrderingListController {
  @override
  FutureOr<List<ReordableElement>> build(String machineUUID) async {
    var settings = await ref.read(machineSettingsProvider(machineUUID).selectAsync((v) => v.miscOrdering));
    var printerData = await ref.read(printerProvider(machineUUID).future);

    // Gather all available elements from Printer
    var availableElements = _extractAvailableElements(printerData);

    return _normalizeSettings(settings, availableElements);
  }

  void onReorder(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }

    var settings = state.requireValue.toList();
    var element = settings.removeAt(oldIndex);
    settings.insert(newIndex, element);
    state = AsyncValue.data(settings);
  }

  /// Extracts all available elements from the printer data
  List<ReordableElement> _extractAvailableElements(Printer printerData) {
    var availableElements = <ReordableElement>[];

    for (var led in printerData.leds.values) {
      availableElements.add(ReordableElement(
        kind: ConfigFileObjectIdentifiers.led,
        name: led.name,
      ));
    }

    for (var pin in printerData.outputPins.values) {
      availableElements.add(ReordableElement(
        kind: ConfigFileObjectIdentifiers.output_pin,
        name: pin.name,
      ));
    }

    for (var sensor in printerData.filamentSensors.values) {
      var kind = switch (sensor) {
        FilamentMotionSensor() => ConfigFileObjectIdentifiers.filament_motion_sensor,
        FilamentSwitchSensor() => ConfigFileObjectIdentifiers.filament_switch_sensor,
        _ => throw UnimplementedError('Unknown sensor type: $sensor'),
      };

      availableElements.add(ReordableElement(
        kind: kind,
        name: sensor.name,
      ));
    }
    return availableElements;
  }

  /// Normalizes the settings to only include elements that are available in the printer and add missing elements
  List<ReordableElement> _normalizeSettings(List<ReordableElement> settings, List<ReordableElement> availableElements) {
    var normalizedSettings = <ReordableElement>[];

    // Only include elements that are available in the printer
    for (var setting in settings) {
      if (availableElements.any((e) => e.kindName == setting.kindName)) {
        normalizedSettings.add(setting);
      }
    }

    // Add missing elements from the printer
    for (var element in availableElements) {
      if (!normalizedSettings.any((e) => e.kindName == element.kindName)) {
        normalizedSettings.add(element);
      }
    }

    return normalizedSettings.whereNot((e) => e.name.startsWith('_')).toList();
  }
}
