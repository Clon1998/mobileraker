/*
 * Copyright (c) 2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:collection/collection.dart';
import 'package:common/data/dto/machine/printer.dart';
import 'package:common/data/model/moonraker_db/settings/machine_settings.dart';
import 'package:common/data/model/moonraker_db/settings/reordable_element.dart';
import 'package:common/service/moonraker/printer_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobileraker/ui/screens/printers/components/section_header.dart';

import '../../../components/async_value_widget.dart';
import 'orderding_form_field.dart';

typedef ElementsFinder = List<ReordableElement> Function(Printer printerData);
typedef OnOrderingChanged = void Function(List<ReordableElement> ordering);

class PrinterElementOrderingWidget extends ConsumerWidget {
  const PrinterElementOrderingWidget({
    super.key,
    required this.machineUUID,
    required this.machineSettings,
    required this.title,
    required this.helperText,
    required this.emptyMessage,
    required this.formFieldName,
    required this.elementsFinder,
    required this.onOrderingChanged,
  });

  final String machineUUID;
  final MachineSettings machineSettings;
  final String title;
  final String helperText;
  final String emptyMessage;
  final String formFieldName;
  final ElementsFinder elementsFinder;
  final OnOrderingChanged onOrderingChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SectionHeader(
          title: title,
          trailing: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
            child: Tooltip(
              showDuration: const Duration(seconds: 5),
              message: helperText,
              margin: const EdgeInsets.symmetric(horizontal: 16.0),
              triggerMode: TooltipTriggerMode.tap,
              child: Icon(
                Icons.help_outline,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ),
        AsyncValueWidget(
          value: ref.watch(printerProvider(machineUUID)),
          skipLoadingOnReload: true,
          data: (printer) {
            final elements = normalizedElements(printer);

            if (elements.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(emptyMessage),
              );
            }

            return OrderdingFormField(
              name: formFieldName,
              initialValue: elements,
              onChanged: (ordering) {
                if (ordering == null) return;
                onOrderingChanged(ordering);
              },
            );
          },
        ),
      ],
    );
  }

  /// Normalizes the settings to only include elements that are available in the printer and add missing elements
  List<ReordableElement> normalizedElements(Printer printerData) {
    final availableElements = elementsFinder(printerData);
    final settings = machineSettings.tempOrdering;
    final normalizedSettings = <ReordableElement>[];

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