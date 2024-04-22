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
import 'package:common/ui/components/drawer/nav_drawer_view.dart';
import 'package:common/ui/components/switch_printer_app_bar.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/ui/components/connection/connection_state_view.dart';
import 'package:mobileraker/ui/components/ems_button.dart';
import 'package:mobileraker/ui/components/machine_state_indicator.dart';
import 'package:mobileraker/ui/screens/console/console_controller.dart';
import 'package:mobileraker/util/extensions/datetime_extension.dart';
import 'package:mobileraker/util/extensions/text_editing_controller_extension.dart';
import 'package:progress_indicators/progress_indicators.dart';
import 'package:pull_to_refresh_flutter3/pull_to_refresh_flutter3.dart';

class ConsolePage extends ConsumerWidget {
  const ConsolePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: SwitchPrinterAppBar(
        title: 'pages.console.title'.tr(),
        actions: [
          MachineStateIndicator(ref.watch(selectedMachineProvider).valueOrNull),
          const EmergencyStopBtn(),
        ],
      ),
      drawer: const NavigationDrawerWidget(),
      body: ConnectionStateView(onConnected: (_, __) => const _ConsoleBody()),
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
              child: _Console(
                onCommandTap: (s) => consoleTextEditor.textAndMoveCursor = s,
              ),
            ),
            const Divider(),
            GCodeSuggestionBar(
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
    );
  }
}

class GCodeSuggestionBar extends StatefulHookConsumerWidget {
  const GCodeSuggestionBar({
    super.key,
    required this.onMacroTap,
    required this.consoleInputNotifier,
  });

  final ValueChanged<String> onMacroTap;

  final ValueNotifier<TextEditingValue> consoleInputNotifier;

  @override
  ConsumerState createState() => _GCodeSuggestionBarState();
}

class _GCodeSuggestionBarState extends ConsumerState<GCodeSuggestionBar> {
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
    var themeData = Theme.of(context);

    var consoleInput = useValueListenable(widget.consoleInputNotifier).text;

    var history = ref.watch(commandHistoryProvider);
    var available = ref.watch(availableMacrosProvider).valueOrNull ?? [];
    var suggestions = calculateSuggestedMacros(consoleInput, history, available);
    if (suggestions.isEmpty) return const SizedBox.shrink();
    var canSend = ref.watch(klipperSelectedProvider).valueOrNull?.klippyCanReceiveCommands ?? false;
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
            String cmd = suggestions[index];

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              child: RawChip(
                label: Text(cmd),
                backgroundColor: canSend ? themeData.colorScheme.primary : themeData.disabledColor,
                onPressed: canSend ? () => widget.onMacroTap(cmd) : null,
              ),
            );
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
