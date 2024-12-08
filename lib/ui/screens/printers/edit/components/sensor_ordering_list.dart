/*
 * Copyright (c) 2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:ui';

import 'package:collection/collection.dart';
import 'package:common/data/dto/config/config_file_object_identifiers_enum.dart';
import 'package:common/data/dto/machine/fans/temperature_fan.dart';
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

part 'sensor_ordering_list.g.dart';

class SensorOrderingList extends ConsumerWidget {
  const SensorOrderingList({super.key, required this.machineUuid});

  final String machineUuid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var controller = ref.read(sensorOrderingListControllerProvider(machineUuid).notifier);
    var model = ref.watch(sensorOrderingListControllerProvider(machineUuid));
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SectionHeader(
          title: tr('pages.printer_edit.temp_ordering.title'),
          trailing: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
            child: Tooltip(
                showDuration: const Duration(seconds: 5),
                message: tr('pages.printer_edit.temp_ordering.helper'),
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
                child: const Text('pages.printer_edit.temp_ordering.no_sensors').tr(),
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
class SensorOrderingListController extends _$SensorOrderingListController {
  @override
  FutureOr<List<ReordableElement>> build(String machineUUID) async {
    var settings = await ref.read(machineSettingsProvider(machineUUID).selectAsync((v) => v.tempOrdering));
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

    for (var element in printerData.extruders) {
      availableElements.add(ReordableElement(name: element.name, kind: ConfigFileObjectIdentifiers.extruder));
    }

    if (printerData.heaterBed != null) {
      availableElements
          .add(ReordableElement(name: printerData.heaterBed!.name, kind: ConfigFileObjectIdentifiers.heater_bed));
    }

    for (var element in printerData.genericHeaters.values) {
      availableElements.add(ReordableElement(name: element.name, kind: ConfigFileObjectIdentifiers.heater_generic));
    }

    for (var element in printerData.temperatureSensors.values) {
      availableElements.add(ReordableElement(name: element.name, kind: ConfigFileObjectIdentifiers.temperature_sensor));
    }

    for (var element in printerData.fans.values.whereType<TemperatureFan>()) {
      availableElements.add(ReordableElement(name: element.name, kind: ConfigFileObjectIdentifiers.temperature_fan));
    }

    return availableElements;
  }

  /// Normalizes the settings to only include elements that are available in the printer and add missing elements
  List<ReordableElement> _normalizeSettings(List<ReordableElement> settings, List<ReordableElement> availableElements) {
    var normalizedSettings = <ReordableElement>[];

    // Only include elements that are available in the printer
    for (var setting in settings) {
      if (availableElements.any((e) => e.kind == setting.kind && e.name == setting.name)) {
        normalizedSettings.add(setting);
      }
    }

    // Add missing elements from the printer
    for (var element in availableElements) {
      if (!normalizedSettings.any((e) => e.kind == element.kind && e.name == element.name)) {
        normalizedSettings.add(element);
      }
    }

    return normalizedSettings.whereNot((e) => e.name.startsWith('_')).toList();
  }
}
