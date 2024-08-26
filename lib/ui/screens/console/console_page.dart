/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/dto/console/command.dart';
import 'package:common/data/dto/console/console_entry.dart';
import 'package:common/data/enums/console_entry_type_enum.dart';
import 'package:common/service/date_format_service.dart';
import 'package:common/service/moonraker/klippy_service.dart';
import 'package:common/service/moonraker/printer_service.dart';
import 'package:common/service/selected_machine_service.dart';
import 'package:common/ui/components/async_guard.dart';
import 'package:common/ui/components/nav/nav_drawer_view.dart';
import 'package:common/ui/components/nav/nav_rail_view.dart';
import 'package:common/ui/components/simple_error_widget.dart';
import 'package:common/ui/components/switch_printer_app_bar.dart';
import 'package:common/util/extensions/async_ext.dart';
import 'package:common/util/extensions/build_context_extension.dart';
import 'package:common/util/extensions/string_extension.dart';
import 'package:common/util/logger.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/ui/components/emergency_stop_button.dart';
import 'package:mobileraker/ui/components/machine_state_indicator.dart';
import 'package:mobileraker/util/extensions/datetime_extension.dart';
import 'package:mobileraker/util/extensions/text_editing_controller_extension.dart';
import 'package:pull_to_refresh_flutter3/pull_to_refresh_flutter3.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shimmer/shimmer.dart';

import '../../components/connection/machine_connection_guard.dart';

part 'console_page.freezed.dart';
part 'console_page.g.dart';

const int commandCacheSize = 25;

class ConsolePage extends ConsumerWidget {
  const ConsolePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget body = MachineConnectionGuard(onConnected: (_, machineUUID) => _ConsoleBody(machineUUID: machineUUID));
    if (context.isLargerThanCompact) {
      body = NavigationRailView(page: body);
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
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border.all(color: theme.colorScheme.primary, width: 0.5),
          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(10)),
        ),
        child: Column(
          children: [
            const _CardHeader(),
            Expanded(child: _CardBody(machineUUID: machineUUID, consoleTextEditor: consoleTextEditor)),
            const Divider(),
            _CardFooter(machineUUID: machineUUID, consoleTextEditor: consoleTextEditor),
          ],
        ),
      ),
    );
  }
}

class _CardHeader extends StatelessWidget {
  const _CardHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final themeData = Theme.of(context);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(color: themeData.colorScheme.primary),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
        child: Text(
          'pages.console.card_title',
          style: themeData.textTheme.titleMedium?.copyWith(color: themeData.colorScheme.onPrimary),
        ).tr(),
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
    final console = _Console(
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
                child: _GCodeSuggestions(
                  machineUUID: machineUUID,
                  onMacroTap: (s) => consoleTextEditor.textAndMoveCursor = s,
                  consoleInputNotifier: consoleTextEditor,
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
    final focusNode = useFocusNode();
    final klippyCanReceiveCommands = ref
            .watch(_consoleListControllerProvider(machineUUID).selectAs((data) => data.klippyCanReceiveCommands))
            .valueOrNull ==
        true;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (context.isSmallerThanMedium)
          _GCodeSuggestions(
            machineUUID: machineUUID,
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
                      ref
                          .read(_consoleListControllerProvider(machineUUID).notifier)
                          .onCommandSubmit(consoleTextEditor.text);
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
                              .read(_consoleListControllerProvider(machineUUID).notifier)
                              .onCommandSubmit(consoleTextEditor.text);
                          consoleTextEditor.clear();
                        }
                      : null,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                hintText: klippyCanReceiveCommands
                    ? tr('pages.console.command_input.hint')
                    : tr('pages.console.fetching_console'),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _GCodeSuggestions extends HookConsumerWidget {
  const _GCodeSuggestions(
      {super.key, required this.machineUUID, required this.onMacroTap, required this.consoleInputNotifier});

  final String machineUUID;
  final ValueChanged<String> onMacroTap;
  final ValueNotifier<TextEditingValue> consoleInputNotifier;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeData = Theme.of(context);
    final consoleInput = useValueListenable(consoleInputNotifier).text;
    final scrollController = useScrollController();

    final model = ref.watch(_consoleListControllerProvider(machineUUID)
        .selectAs((data) => (data.klippyCanReceiveCommands, data.availableCommands, data.commandHistory)));
    if (model.isLoading && context.isLargerThanCompact) {
      return LayoutBuilder(
        builder: (context, constraints) {
          // Calculate the approximate count of chips to show for all screen sizes
          final aproxCount = ((constraints.maxHeight / 33).ceil() * (constraints.maxWidth / 96)).ceil();

          return Shimmer.fromColors(
            baseColor: Colors.grey,
            highlightColor: themeData.colorScheme.background,
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 8,
                alignment: WrapAlignment.spaceEvenly,
                children: List.generate(aproxCount, (index) {
                  final labelWidth = 30 +
                      ((index % 10) *
                          7); // This will create a pattern for label width: 30, 37, 44, ..., 93, 30, 37, ...
                  return Chip(label: SizedBox(width: labelWidth.toDouble()), backgroundColor: Colors.white);
                }),
              ),
            ),
          );
        },
      );
    }
    if (!model.hasValue) return const SizedBox.shrink();

    final (bool canSend, List<Command> available, List<String> history) = model.requireValue;
    final suggestions = _calculateSuggestedMacros(consoleInput, history, available);

    final chips = suggestions
        .map(
          (cmd) => ActionChip(
            label: Text(cmd),
            onPressed: canSend ? () => onMacroTap(cmd) : null,
            backgroundColor: canSend ? themeData.colorScheme.primary : themeData.disabledColor,
            labelStyle: TextStyle(
              color: canSend ? themeData.colorScheme.onPrimary : themeData.disabledColor,
            ),
          ),
        )
        .toList();

    if (context.isLargerThanCompact) {
      if (chips.isEmpty) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: SvgPicture.asset('assets/vector/undraw_void_-3-ggu.svg'),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'pages.console.no_suggestions',
                style: Theme.of(context).textTheme.labelLarge,
              ).tr(),
            ],
          ),
        );
      }

      return Padding(
        padding: const EdgeInsets.only(left: 8, right: 8),
        child: SingleChildScrollView(
          controller: scrollController,
          child: Wrap(
            spacing: 8,
            alignment: WrapAlignment.spaceEvenly,
            children: chips,
          ),
        ),
      );
    }
    if (suggestions.isEmpty) {
      return SizedBox(
        height: 33,
        child: Center(
          child: Text(
            'pages.console.no_suggestions',
            style: Theme.of(context).textTheme.labelLarge,
          ).tr(),
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
          controller: scrollController,
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          scrollDirection: Axis.horizontal,
          itemCount: suggestions.length,
          itemBuilder: (BuildContext context, int index) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: chips[index],
            );
          },
        ),
      ),
    );
  }

  /// This function calculates the suggested macros based on the user's input.
  /// It takes three parameters: `currentInput`, `history`, and `available`.
  /// The `currentInput` is the text entered by the user, `history` is a list of previously entered commands,
  /// and `available` is a list of available commands.
  ///
  /// The function first adds all the commands from the `history` to the `potential` list and `seen` set.
  /// Then it adds all the available commands that are not starting with an underscore and are not already in the `seen` set to the `potential` list.
  ///
  /// The function then calculates a score for each command in the `potential` list based on how well it matches the `currentInput`.
  /// The scoring system is as follows: an exact match gets a score of 100, a command that starts with the `currentInput` gets a score of 50,
  /// a command that contains the `currentInput` gets a score of 25, and a command that contains any term in the `currentInput` gets a score of 10.
  /// The score is then reduced by the Levenshtein distance between the command and the `currentInput`.
  ///
  /// Finally, the function returns the commands in the `potential` list sorted by their scores in descending order.

  List<String> _calculateSuggestedMacros(
    String currentInput,
    List<String> history,
    List<Command> available,
  ) {
    List<String> potential = [...history, ...additionalCmds];
    Set<String> seen = <String>{...history};

    // Add available commands that are not in the potential list yet
    Iterable<String> filteredAvailable = available.map((e) => e.cmd).where(
          (element) => !element.startsWith('_') && !seen.contains(element),
        );
    potential.addAll(filteredAvailable);

    String text = currentInput.toLowerCase();
    if (text.isEmpty) return potential;

    List<String> terms = text.split(RegExp(r'\W+'));

    // Create a map to score the suggestions
    Map<String, int> scoredSuggestions = {};

    for (var suggestion in potential) {
      int score = 0;
      String lowerSuggestion = suggestion.toLowerCase();

      // Exact match
      if (lowerSuggestion == text) {
        score += 100;
      }

      // Partial matches
      if (lowerSuggestion.startsWith(text)) {
        score += 50;
      } else if (lowerSuggestion.contains(text)) {
        score += 25;
      }

      // Check each term in the split input
      for (var term in terms) {
        if (lowerSuggestion.contains(term)) {
          score += 10;
        }
      }

      // Apply Levenshtein distance for additional similarity check
      int levenshteinScore = lowerSuggestion.levenshteinDistance(text);
      score -= levenshteinScore;

      // Assign score to the suggestion
      if (score > 0) {
        scoredSuggestions[suggestion] = score;
      }
    }

    // Sort by score descending and return the keys
    List<String> sortedSuggestions = scoredSuggestions.keys.toList()
      ..sort((a, b) => scoredSuggestions[b]!.compareTo(scoredSuggestions[a]!));

    return sortedSuggestions;
  }

}

class _Console extends ConsumerWidget {
  const _Console({super.key, required this.machineUUID, required this.onCommandTap});

  final String machineUUID;
  final ValueChanged<String> onCommandTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncGuard(
      debugLabel: 'console-$machineUUID',
      toGuard: _consoleListControllerProvider(machineUUID).selectAs((_) => true),
      childOnLoading: const _ConsoleLoading(),
      childOnError: (error, _) => _ConsoleProviderError(error: error),
      childOnData: _ConsoleData(machineUUID: machineUUID, onCommandTap: onCommandTap),
    );
  }
}

class _ConsoleLoading extends StatelessWidget {
  const _ConsoleLoading({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Shimmer.fromColors(
      baseColor: Colors.grey,
      highlightColor: theme.colorScheme.background,
      child: ListView.builder(
        itemBuilder: (context, index) {
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
            title: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: double.infinity,
                  height: 16.0,
                  margin: const EdgeInsets.only(right: 5),
                  color: Colors.white,
                ),
              ],
            ),
            isThreeLine: true,
            subtitle: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 5),
                Container(
                  width: double.infinity,
                  height: 16.0,
                  margin: const EdgeInsets.only(right: 5),
                  color: Colors.white,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Flexible(
                      child: Container(
                        width: double.infinity,
                        height: 10.0,
                        color: Colors.white,
                      ),
                    ),
                    const Spacer(flex: 2),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ConsoleProviderError extends ConsumerWidget {
  const _ConsoleProviderError({super.key, required this.error});

  final Object error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final message = error.toString();

    return Center(
      child: SimpleErrorWidget(
        title: const Text('pages.console.provider_error.title').tr(),
        body: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('pages.console.provider_error.body').tr(),
            Text(
              message,
              maxLines: 4,
            ),
          ],
        ),
        action: TextButton.icon(
          onPressed: () {
            logger.i('Retrying console provider');
            ref.invalidate(_consoleListControllerProvider);
          },
          icon: const Icon(Icons.restart_alt_outlined),
          label: const Text('general.retry').tr(),
        ),
      ),
    );
  }
}

class _ConsoleData extends ConsumerStatefulWidget {
  const _ConsoleData({super.key, required this.machineUUID, required this.onCommandTap});

  final String machineUUID;
  final ValueChanged<String> onCommandTap;

  @override
  ConsumerState<_ConsoleData> createState() => _ConsoleDataState();
}

class _ConsoleDataState extends ConsumerState<_ConsoleData> {
  final RefreshController _refreshController = RefreshController();

  @override
  void initState() {
    super.initState();
    // Sync UI refresher with Riverpod provider
    ref.listenManual(_consoleListControllerProvider(widget.machineUUID), (previous, next) {
      if (next case AsyncData() when _refreshController.isRefresh) {
        _refreshController.refreshCompleted();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final count = ref
        .watch(_consoleListControllerProvider(widget.machineUUID).selectRequireValue((d) => d.consoleEntries.length));

    if (count == 0) {
      return ListTile(
        leading: const Icon(Icons.browser_not_supported_sharp),
        title: const Text('pages.console.no_entries').tr(),
      );
    }

    final themeData = Theme.of(context);
    final dateFormatService = ref.read(dateFormatServiceProvider);

    logger.e('Rebuilding console list. Count: $count');

    return SmartRefresher(
      header: ClassicHeader(
        textStyle: TextStyle(color: themeData.colorScheme.onSurface),
        idleIcon: Icon(
          Icons.arrow_upward,
          color: themeData.colorScheme.onSurface,
        ),
        completeIcon: Icon(Icons.done, color: themeData.colorScheme.onSurface),
        releaseIcon: Icon(
          Icons.refresh,
          color: themeData.colorScheme.onSurface,
        ),
        idleText: tr('components.pull_to_refresh.pull_up_idle'),
      ),
      controller: _refreshController,
      onRefresh: () => ref.invalidate(_consoleListControllerProvider),
      child: ListView.builder(
        reverse: true,
        itemCount: count,
        itemBuilder: (context, index) {
          if (index >= count) return null; // Prevents index out of bounds error
          final correctedIndex = count - index - 1;

          final (ConsoleEntry? entry, bool canSend) = ref.watch(_consoleListControllerProvider(widget.machineUUID)
              .selectRequireValue(
                  (data) => (data.consoleEntries.elementAtOrNull(correctedIndex), data.klippyCanReceiveCommands)));

          if (entry == null) return null;

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
              onTap: canSend ? () => widget.onCommandTap(entry.message) : null,
              subtitle: Text(dateFormat.format(entry.timestamp)),
              subtitleTextStyle: themeData.textTheme.bodySmall,
            );
          }

          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
            title: Text(entry.message),
            subtitle: Text(dateFormat.format(entry.timestamp)),
            subtitleTextStyle: themeData.textTheme.bodySmall,
          );
        },
      ),
    );
  }

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
  void dispose() {
    _refreshController.dispose();
    super.dispose();
  }
}

const List<String> additionalCmds = [
  'ABORT',
  'ACCEPT',
  'ADJUSTED',
  'GET_POSITION',
  'SET_RETRACTION',
  'TESTZ',
];

// @riverpod
// RefreshController consoleRefreshController(ConsoleRefreshControllerRef ref) {
//   var refreshController = RefreshController();
//   ref.onDispose(refreshController.dispose);
//   return refreshController;
// }

@riverpod
class _ConsoleListController extends _$ConsoleListController {
  /// Pattern to ignore
  final RegExp _tempPattern = RegExp(r'^(?:ok\s+)?(B|C|T\d*):', caseSensitive: false);

  PrinterService get _printerService => ref.read(printerServiceSelectedProvider);

  @override
  FutureOr<_Model> build(String machineUUID) async {
    final klippyCanReceiveCommandsFuture =
        ref.watch(klipperProvider(machineUUID).selectAsync((data) => data.klippyCanReceiveCommands));

    final availableCommandsFuture = ref.watch(printerAvailableCommandsProvider(machineUUID).future);

    final results = await Future.wait([klippyCanReceiveCommandsFuture, _commandHistory(), availableCommandsFuture]);

    final klippyCanReceiveCommands = results[0] as bool;
    final consoleEntries = results[1] as List<ConsoleEntry>;
    final availableCommands = results[2] as List<Command>;

    final sub = _printerService.gCodeResponseStream.listen((event) {
      if (_tempPattern.hasMatch(event)) return;

      final consoleEntry = ConsoleEntry(
        event,
        ConsoleEntryType.response,
        DateTime.now().millisecondsSinceEpoch / 1000,
      );

      state = state.whenData((value) => value.copyWith(consoleEntries: [...value.consoleEntries, consoleEntry]));
    });

    ref.onDispose(() => sub.cancel());

    final history = ref.watch(_macroHistoryProvider(machineUUID));

    return _Model(
      klippyCanReceiveCommands: klippyCanReceiveCommands,
      consoleEntries: consoleEntries,
      availableCommands: availableCommands,
      commandHistory: history,
    );
  }

  Future<List<ConsoleEntry>> _commandHistory() async {
    final raw = await _printerService.gcodeStore();
    return raw.where((element) => !_tempPattern.hasMatch(element.message)).toList(growable: false);
  }

  void onCommandSubmit(String command) {
    if (command.isEmpty || state.isLoading) return;

    state = state.whenData((value) => value.copyWith(consoleEntries: [
          ...value.consoleEntries,
          ConsoleEntry(
            command,
            ConsoleEntryType.command,
            DateTime.now().millisecondsSinceEpoch / 1000,
          ),
        ]));
    _printerService.gCode(command).whenComplete(() => addToHistory(command));
  }

  void addToHistory(String command) => ref.read(_macroHistoryProvider(machineUUID).notifier).addToHistory(command);
}

@riverpod
class _MacroHistory extends _$MacroHistory {
  @override
  List<String> build(String machineUUID) {
    // We keep this for the lifetime of the app
    ref.keepAlive();
    return [];
  }

  void addToHistory(String command) {
    final tmp = state.toList();
    tmp.remove(command);
    tmp.insert(0, command);
    state = tmp.sublist(0, tmp.length.clamp(0, commandCacheSize));
  }
}

@freezed
class _Model with _$Model {
  const factory _Model({
    required bool klippyCanReceiveCommands,
    required List<ConsoleEntry> consoleEntries,
    required List<Command> availableCommands,
    @Default([]) List<String> commandHistory,
  }) = __Model;
}
