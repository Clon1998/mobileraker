/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/dto/console/command.dart';
import 'package:common/data/dto/console/console_entry.dart';
import 'package:common/data/enums/console_entry_type_enum.dart';
import 'package:common/service/date_format_service.dart';
import 'package:common/service/moonraker/klippy_service.dart';
import 'package:common/service/selected_machine_service.dart';
import 'package:common/ui/components/nav/nav_drawer_view.dart';
import 'package:common/ui/components/nav/nav_rail_view.dart';
import 'package:common/ui/components/switch_printer_app_bar.dart';
import 'package:common/util/extensions/build_context_extension.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/ui/components/emergency_stop_button.dart';
import 'package:mobileraker/ui/components/machine_state_indicator.dart';
import 'package:mobileraker/ui/screens/console/console_controller.dart';
import 'package:mobileraker/util/extensions/datetime_extension.dart';
import 'package:mobileraker/util/extensions/text_editing_controller_extension.dart';
import 'package:progress_indicators/progress_indicators.dart';
import 'package:pull_to_refresh_flutter3/pull_to_refresh_flutter3.dart';

import '../../components/connection/machine_connection_guard.dart';

class ConsolePage extends ConsumerWidget {
  const ConsolePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget body = MachineConnectionGuard(onConnected: (_, __) => const _ConsoleBody());
    if (context.isLargerThanCompact) {
      body = Row(
        children: [const NavigationRailView(), Expanded(child: body)],
      );
    }

    return Scaffold(
      appBar: SwitchPrinterAppBar(
        title: 'pages.console.title'.tr(),
        actions: [
          MachineStateIndicator(ref.watch(selectedMachineProvider).valueOrNull),
          const EmergencyStopButton(),
        ],
      ),
      drawer: const NavigationDrawerWidget(),
      body: body,
    );
  }
}

class _ConsoleBody extends HookConsumerWidget {
  const _ConsoleBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var consoleTextEditor = useTextEditingController();
    var focusNode = useFocusNode();

    var klippyCanReceiveCommands = ref.watch(klipperSelectedProvider).valueOrNull?.klippyCanReceiveCommands ?? false;

    var theme = Theme.of(context);
    var borderSize = BorderSide(width: 0.5, color: theme.colorScheme.primary);

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(4.0),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border.all(color: theme.colorScheme.primary, width: 0.5),
          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(10)),
          // boxShadow: [
          //   if (theme.brightness == Brightness.light)
          //     BoxShadow(
          //       color: theme.colorScheme.shadow,
          //       offset: const Offset(0.0, 0.0), //(x,y)
          //       blurRadius: 0.5,
          //     ),
          // ],
        ),
        child: Flexible(
          flex: 2,
          child: Column(
            children: [
              Container(
                width: double.infinity,
                decoration: BoxDecoration(color: theme.colorScheme.primary),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                  child: Text(
                    'pages.console.card_title',
                    style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onPrimary),
                  ).tr(),
                ),
              ),
              Expanded(
                flex: 1,
                child: Row(
                  children: [
                    Flexible(
                      flex: 2,
                      child: _Console(
                        onCommandTap: (s) => consoleTextEditor.textAndMoveCursor = s,
                      ),
                    ),
                    if (context.isLargerThanCompact) ...[
                      VerticalDivider(),
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text('@:pages.console.macro_suggestions:').tr(),
                            Flexible(
                              child: _GCodeSuggestions(
                                onMacroTap: (s) => consoleTextEditor.textAndMoveCursor = s,
                                consoleInputNotifier: consoleTextEditor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Divider(),
              if (context.isSmallerThanMedium)
                _GCodeSuggestions(
                  onMacroTap: (s) => consoleTextEditor.textAndMoveCursor = s,
                  consoleInputNotifier: consoleTextEditor,
                ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: RawKeyboardListener(
                  focusNode: focusNode,
                  onKey: klippyCanReceiveCommands
                      ? (event) {
                          if (event.isKeyPressed(LogicalKeyboardKey.enter)) {
                            ref.read(consoleListControllerProvider.notifier).onCommandSubmit(consoleTextEditor.text);
                            consoleTextEditor.clear();
                          }
                        }
                      : null,
                  child: TextField(
                    enableSuggestions: false,
                    autocorrect: false,
                    controller: consoleTextEditor,
                    enabled: klippyCanReceiveCommands,
                    decoration: InputDecoration(
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.send),
                        onPressed: klippyCanReceiveCommands
                            ? () {
                                ref
                                    .read(
                                      consoleListControllerProvider.notifier,
                                    )
                                    .onCommandSubmit(consoleTextEditor.text);
                                consoleTextEditor.clear();
                              }
                            : null,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      hintText: tr('pages.console.command_input.hint'),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GCodeSuggestions extends StatefulHookConsumerWidget {
  const _GCodeSuggestions({
    super.key,
    required this.onMacroTap,
    required this.consoleInputNotifier,
  });

  final ValueChanged<String> onMacroTap;

  final ValueNotifier<TextEditingValue> consoleInputNotifier;

  @override
  ConsumerState createState() => _GCodeSuggestionBarState();
}

class _GCodeSuggestionBarState extends ConsumerState<_GCodeSuggestions> {
  List<String> calculateSuggestedMacros(
    String currentInput,
    List<String> history,
    List<Command> available,
  ) {
    List<String> potential = [];
    potential.addAll(history);

    Iterable<String> filteredAvailable = available.map((e) => e.cmd).where(
          (element) => !element.startsWith('_') && !potential.contains(element),
        );
    potential.addAll(additionalCmds);
    potential.addAll(filteredAvailable);
    String text = currentInput.toLowerCase();
    if (text.isEmpty) return potential;

    List<String> terms = text.split(RegExp(r'\W+'));

    return potential
        .where(
          (element) => terms.every((t) => element.toLowerCase().contains(t)),
        )
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final themeData = Theme.of(context);

    final consoleInput = useValueListenable(widget.consoleInputNotifier).text;

    final history = ref.watch(commandHistoryProvider);
    final available = ref.watch(availableMacrosProvider).valueOrNull ?? [];
    final suggestions = calculateSuggestedMacros(consoleInput, history, available);
    if (suggestions.isEmpty) return const SizedBox.shrink();
    final canSend = ref.watch(klipperSelectedProvider).valueOrNull?.klippyCanReceiveCommands ?? false;

    final chips = suggestions
        .map(
          (cmd) => ActionChip(
            label: Text(cmd),
            onPressed: canSend ? () => widget.onMacroTap(cmd) : null,
            backgroundColor: canSend ? themeData.colorScheme.primary : themeData.disabledColor,
            labelStyle: TextStyle(
              color: canSend ? themeData.colorScheme.onPrimary : themeData.disabledColor,
            ),
          ),
        )
        .toList();

    if (context.isLargerThanCompact) {
      return Padding(
        padding: const EdgeInsets.only(left: 8, right: 8),
        child: SingleChildScrollView(
          child: Wrap(
            spacing: 8,
            alignment: WrapAlignment.spaceEvenly,
            children: chips,
          ),
        ),
      );
    }

    return SizedBox(
      height: 33,
      child: ChipTheme(
        data: ChipThemeData(
          labelStyle: TextStyle(color: themeData.colorScheme.onPrimary),
          deleteIconColor: themeData.colorScheme.onPrimary,
        ),
        child: ListView.builder(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          scrollDirection: Axis.horizontal,
          itemCount: suggestions.length,
          itemBuilder: (BuildContext context, int index) {
            return chips[index];
          },
        ),
      ),
    );
  }
}

class _Console extends ConsumerWidget {
  const _Console({super.key, required this.onCommandTap});

  final ValueChanged<String> onCommandTap;

  TextStyle _commandTextStyle(ThemeData theme, ListTileThemeData tileTheme) {
    final TextStyle textStyle;
    switch (tileTheme.style ?? theme.listTileTheme.style ?? ListTileStyle.list) {
      case ListTileStyle.drawer:
        textStyle = theme.textTheme.bodyLarge!;
        break;
      case ListTileStyle.list:
        textStyle = theme.textTheme.titleMedium!;
        break;
    }

    return textStyle.copyWith(color: theme.colorScheme.primary);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var themeData = Theme.of(context);
    var canSend = ref.watch(klipperSelectedProvider).valueOrNull?.klippyCanReceiveCommands ?? false;
    var dateFormatService = ref.read(dateFormatServiceProvider);

    return ref.watch(consoleListControllerProvider).when(
          data: (entries) {
            if (entries.isEmpty) {
              return ListTile(
                leading: const Icon(Icons.browser_not_supported_sharp),
                title: const Text('pages.console.no_entries').tr(),
              );
            }
            return SmartRefresher(
              header: ClassicHeader(
                textStyle: TextStyle(color: themeData.colorScheme.onBackground),
                idleIcon: Icon(
                  Icons.arrow_upward,
                  color: themeData.colorScheme.onBackground,
                ),
                completeIcon: Icon(Icons.done, color: themeData.colorScheme.onBackground),
                releaseIcon: Icon(
                  Icons.refresh,
                  color: themeData.colorScheme.onBackground,
                ),
                idleText: tr('components.pull_to_refresh.pull_up_idle'),
              ),
              controller: ref.watch(consoleRefreshControllerProvider),
              onRefresh: () => ref.invalidate(consoleListControllerProvider),
              child: ListView.builder(
                reverse: true,
                itemCount: entries.length,
                itemBuilder: (context, index) {
                  int correctedIndex = entries.length - 1 - index;
                  ConsoleEntry entry = entries[correctedIndex];

                  DateFormat dateFormat = dateFormatService.Hms();
                  if (entry.timestamp.isNotToday()) {
                    dateFormat.addPattern('MMMd', ', ');
                  }

                  if (entry.type == ConsoleEntryType.command) {
                    return ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                      title: Text(
                        entry.message,
                        style: _commandTextStyle(
                          themeData,
                          ListTileTheme.of(context),
                        ),
                      ),
                      subtitle: Text(dateFormat.format(entry.timestamp)),
                      onTap: canSend ? () => onCommandTap(entry.message) : null,
                    );
                  }

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    title: Text(entry.message),
                    subtitle: Text(dateFormat.format(entry.timestamp)),
                  );
                },
              ),
            );
          },
          loading: () => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SpinKitFoldingCube(
                  color: themeData.colorScheme.secondary,
                  size: 100,
                ),
                const SizedBox(height: 30),
                FadingText(tr('pages.console.fetching_console')),
              ],
            ),
          ),
          error: (e, s) => Text('Error while fetching History, $e'),
        );
  }
}
