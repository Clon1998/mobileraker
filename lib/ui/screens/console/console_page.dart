/*
 * Copyright (c) 2023-2025. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/service/selected_machine_service.dart';
import 'package:common/ui/components/nav/nav_drawer_view.dart';
import 'package:common/ui/components/nav/nav_rail_view.dart';
import 'package:common/ui/components/switch_printer_app_bar.dart';
import 'package:common/util/extensions/build_context_extension.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/ui/components/console/command_input.dart';
import 'package:mobileraker/ui/components/console/command_suggestions.dart';
import 'package:mobileraker/ui/components/console/console_history.dart';
import 'package:mobileraker/ui/components/console/console_settings_button.dart';
import 'package:mobileraker/ui/components/emergency_stop_button.dart';
import 'package:mobileraker/ui/components/machine_state_indicator.dart';
import 'package:mobileraker/util/extensions/text_editing_controller_extension.dart';

import '../../components/connection/machine_connection_guard.dart';

const int commandCacheSize = 25;

class ConsolePage extends ConsumerWidget {
  const ConsolePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget body = MachineConnectionGuard(
      onConnected: (_, machineUUID) => _ConsoleBody(machineUUID: machineUUID),
      skipKlipperReady: true,
    );
    if (context.isLargerThanCompact) {
      body = NavigationRailView(page: body);
    }

    return Scaffold(
      appBar: SwitchPrinterAppBar(
        title: 'pages.console.title'.tr(),
        actions: [MachineStateIndicator(ref.watch(selectedMachineProvider).valueOrNull), const EmergencyStopButton()],
      ),
      drawer: const NavigationDrawerWidget(),
      body: body,
    );
  }
}

class _ConsoleBody extends HookConsumerWidget {
  const _ConsoleBody({super.key, required this.machineUUID});

  final String machineUUID;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final consoleTextEditor = useTextEditingController();

    final theme = Theme.of(context);
    return SafeArea(
      left: false,
      right: false,
      child: Container(
        margin: const EdgeInsets.all(4.0),
        // decoration: BoxDecoration(
        //   color: theme.colorScheme.surface,
        //   border: Border.all(color: theme.colorScheme.primary, width: 0.5),
        //   borderRadius: const BorderRadius.vertical(bottom: Radius.circular(10)),
        // ),
        child: Column(
          children: [
            Expanded(
              child: _CardBody(machineUUID: machineUUID, consoleTextEditor: consoleTextEditor),
            ),
            const Divider(),
            _CardFooter(machineUUID: machineUUID, consoleTextEditor: consoleTextEditor),
          ],
        ),
      ),
    );
  }
}

class _CardBody extends StatelessWidget {
  const _CardBody({super.key, required this.machineUUID, required this.consoleTextEditor});

  final String machineUUID;
  final TextEditingController consoleTextEditor;

  @override
  Widget build(BuildContext context) {
    final console = ConsoleHistory(
      machineUUID: machineUUID,
      onCommandTap: (s) => consoleTextEditor.textAndMoveCursor = s,
    );
    if (context.isSmallerThanMedium) {
      return console;
    }

    return Row(
      children: [
        Flexible(flex: 2, child: console),
        const VerticalDivider(),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('@:pages.console.macro_suggestions:').tr(),
              Flexible(
                child: CommandSuggestions(
                  machineUUID: machineUUID,
                  onSuggestionTap: (s) => consoleTextEditor.textAndMoveCursor = s,
                  textNotifier: consoleTextEditor,
                  verticalLayout: context.isLargerThanCompact,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CardFooter extends HookConsumerWidget {
  const _CardFooter({super.key, required this.machineUUID, required this.consoleTextEditor});

  final String machineUUID;
  final TextEditingController consoleTextEditor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (context.isSmallerThanMedium)
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
    );
  }
}
