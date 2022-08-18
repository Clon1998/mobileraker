import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/data/dto/console/console_entry.dart';
import 'package:mobileraker/logger.dart';
import 'package:mobileraker/service/moonraker/klippy_service.dart';
import 'package:mobileraker/service/selected_machine_service.dart';
import 'package:mobileraker/ui/components/connection/connection_state_view.dart';
import 'package:mobileraker/ui/components/drawer/nav_drawer_view.dart';
import 'package:mobileraker/ui/components/ease_in.dart';
import 'package:mobileraker/ui/components/ems_button.dart';
import 'package:mobileraker/ui/screens/console/console_controller.dart';
import 'package:mobileraker/util/extensions/async_ext.dart';
import 'package:progress_indicators/progress_indicators.dart';
import 'package:pull_to_refresh_flutter3/pull_to_refresh_flutter3.dart';

class ConsoleView extends ConsumerWidget {
  const ConsoleView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'pages.console.title',
          overflow: TextOverflow.fade,
        ).tr(),
        actions: const [EmergencyStopBtn()],
      ),
      drawer: const NavigationDrawerWidget(),
      body: const ConnectionStateView(
        onConnected: _ConsoleBody(),
      ),
    );
  }
}

class _ConsoleBody extends ConsumerWidget {
  const _ConsoleBody({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var theme = Theme.of(context);

    var klippyCanReceiveCommands = ref
        .watch(klipperSelectedProvider)
        .valueOrFullNull!
        .klippyCanReceiveCommands;
    return Container(
      margin: const EdgeInsets.all(4.0),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(10)),
        boxShadow: [
          if (theme.brightness == Brightness.light)
            BoxShadow(
              color: theme.colorScheme.shadow,
              offset: const Offset(0.0, 4.0), //(x,y)
              blurRadius: 1.0,
            ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
              child: Text(
                'GCode Console - ${ref.watch(selectedMachineProvider).maybeWhen(orElse: () => '', data: (d) => '- ${d?.name}')}',
                style: theme.textTheme.subtitle1
                    ?.copyWith(color: theme.colorScheme.onPrimary),
              ),
            ),
          ),
          const Expanded(
            flex: 1,
            child: _Console(),
          ),
          const Divider(),
          const GCodeSuggestionBar(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: RawKeyboardListener(
              focusNode: FocusNode(),
              onKey: klippyCanReceiveCommands
                  ? ref
                      .watch(consoleListControllerProvider.notifier)
                      .onKeyBoardInput
                  : null,
              child: TextField(
                enableSuggestions: false,
                autocorrect: false,
                controller: ref.watch(consoleTextEditProvider),
                enabled: klippyCanReceiveCommands,
                decoration: InputDecoration(
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.send),
                      onPressed: klippyCanReceiveCommands
                          ? ref
                              .watch(consoleListControllerProvider.notifier)
                              .onCommandSubmit
                          : null,
                    ),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                    hintText: tr('pages.console.command_input.hint')),
              ),
            ),
          )
        ],
      ),
    );
  }
}

class GCodeSuggestionBar extends ConsumerWidget {
  const GCodeSuggestionBar({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var themeData = Theme.of(context);
    var highlightColor = themeData.colorScheme.primary;

    var suggestions = ref.watch(suggestedMacroProvider).valueOrFullNull ?? [];
    if (suggestions.isEmpty) return const SizedBox.shrink();
    var canSend = ref
        .watch(klipperSelectedProvider)
        .valueOrFullNull!
        .klippyCanReceiveCommands;
    return SizedBox(
      height: 33,
      child: ChipTheme(
        data: ChipThemeData(
            labelStyle: TextStyle(color: themeData.colorScheme.onPrimary),
            deleteIconColor: themeData.colorScheme.onPrimary),
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
                backgroundColor:
                    canSend ? highlightColor : themeData.disabledColor,
                onPressed: canSend
                    ? () => ref.read(consoleTextEditProvider).text = cmd
                    : null,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Console extends ConsumerWidget {
  const _Console({Key? key}) : super(key: key);

  TextStyle _commandTextStyle(ThemeData theme, ListTileThemeData tileTheme) {
    final TextStyle textStyle;
    switch (
        tileTheme.style ?? theme.listTileTheme.style ?? ListTileStyle.list) {
      case ListTileStyle.drawer:
        textStyle = theme.textTheme.bodyText1!;
        break;
      case ListTileStyle.list:
        textStyle = theme.textTheme.subtitle1!;
        break;
    }

    return textStyle.copyWith(color: theme.colorScheme.primary);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var themeData = Theme.of(context);
    var canSend = ref
        .watch(klipperSelectedProvider)
        .valueOrFullNull!
        .klippyCanReceiveCommands;
    return ref.watch(consoleListControllerProvider).when(
        data: (entries) {
          if (entries.isEmpty) {
            return ListTile(
                leading: const Icon(Icons.browser_not_supported_sharp),
                title: const Text('pages.console.no_entries').tr());
          }

          return SmartRefresher(
              header: ClassicHeader(
                textStyle: TextStyle(color: themeData.colorScheme.onBackground),
                idleIcon: Icon(
                  Icons.arrow_upward,
                  color: themeData.colorScheme.onBackground,
                ),
                completeIcon:
                    Icon(Icons.done, color: themeData.colorScheme.onBackground),
                releaseIcon: Icon(Icons.refresh,
                    color: themeData.colorScheme.onBackground),
                idleText: tr('components.pull_to_refresh.pull_up_idle'),
              ),
              controller: ref.watch(consoleRefreshController),
              onRefresh: () => ref.refresh(consoleListControllerProvider),
              child: ListView.builder(
                  reverse: true,
                  itemCount: entries.length,
                  itemBuilder: (context, index) {
                    int correctedIndex = entries.length - 1 - index;
                    ConsoleEntry entry = entries[correctedIndex];

                    if (entry.type == ConsoleEntryType.COMMAND) {
                      return ListTile(
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 8),
                        title: Text(entry.message,
                            style: _commandTextStyle(
                                themeData, ListTileTheme.of(context))),
                        subtitle:
                            Text(DateFormat.Hms().format(entry.timestamp)),
                        onTap: canSend
                            ? () => ref.read(consoleTextEditProvider).text =
                                entry.message
                            : null,
                      );
                    }

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                      title: Text(entry.message),
                      subtitle: Text(DateFormat.Hms().format(entry.timestamp)),
                    );
                  }));
        },
        loading: () => Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SpinKitFoldingCube(
                    color: themeData.colorScheme.secondary,
                    size: 100,
                  ),
                  const SizedBox(
                    height: 30,
                  ),
                  FadingText(tr('pages.console.fetching_console'))
                ],
              ),
            ),
        error: (e, s) => Text('Error while fetching History, $e'));
  }
}
