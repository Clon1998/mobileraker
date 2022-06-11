import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:mobileraker/app/app_setup.locator.dart';
import 'package:mobileraker/app/app_setup.router.dart';
import 'package:mobileraker/data/dto/console/console_entry.dart';
import 'package:mobileraker/ui/components/connection/connection_state_view.dart';
import 'package:mobileraker/ui/components/drawer/nav_drawer_view.dart';
import 'package:mobileraker/ui/components/ease_in.dart';
import 'package:mobileraker/ui/views/console/console_viewmodel.dart';
import 'package:progress_indicators/progress_indicators.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:stacked/stacked.dart';

class ConsoleView extends ViewModelBuilderWidget<ConsoleViewModel> {
  const ConsoleView({Key? key}) : super(key: key);

  @override
  bool get disposeViewModel => false;

  @override
  bool get initialiseSpecialViewModelsOnce => true;

  @override
  Widget builder(BuildContext context, ConsoleViewModel model, Widget? child) {
    return Scaffold(
      appBar: _buildAppBar(context, model),
      drawer: NavigationDrawerWidget(curPath: Routes.consoleView),
      body: ConnectionStateView(
        onConnected: _buildBody(context, model),
      ),
    );
  }

  AppBar _buildAppBar(BuildContext context, ConsoleViewModel model) {
    return AppBar(
      title: Text(
        'pages.console.title',
        overflow: TextOverflow.fade,
      ).tr(),
      actions: <Widget>[
        IconButton(
          color: Colors.red,
          icon: Icon(
            Icons.dangerous_outlined,
            size: 30,
          ),
          tooltip: 'pages.dashboard.ems_btn'.tr(),
          onPressed: (model.canUseEms) ? model.onEmergencyPressed : null,
        )
      ],
    );
  }

  Widget _buildBody(BuildContext context, ConsoleViewModel model) {
    var theme = Theme.of(context);
    Color highlightColor = theme.colorScheme.primary;

    return Container(
      margin: const EdgeInsets.all(4.0),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(10)),
        boxShadow: [
          if (theme.brightness == Brightness.light)
            BoxShadow(
              color: Theme.of(context).colorScheme.shadow,
              offset: Offset(0.0, 4.0), //(x,y)
              blurRadius: 1.0,
            ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: highlightColor,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
              child: Text(
                'GCode Console - ${model.printerName}',
                style: theme.textTheme.subtitle1
                    ?.copyWith(color: theme.colorScheme.onPrimary),
              ),
            ),
          ),
          Expanded(flex: 14, child: _buildConsole(context, model)),
          Divider(),
          if (model.filteredSuggestions.isNotEmpty)
            SizedBox(
              height: 33,
              child: ChipTheme(
                data: ChipThemeData(
                    labelStyle: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimary),
                    deleteIconColor: Theme.of(context).colorScheme.onPrimary),
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  scrollDirection: Axis.horizontal,
                  itemCount: model.filteredSuggestions.length,
                  itemBuilder: (BuildContext context, int index) {
                    String cmd = model.filteredSuggestions[index];

                    return Container(
                      margin: EdgeInsets.symmetric(horizontal: 2),
                      child: ActionChip(
                        label: Text(cmd),
                        backgroundColor: highlightColor,
                        onPressed: () => (model.isConsoleHistoryAvailable)
                            ? model.onSuggestionChipTap(cmd)
                            : null,
                      ),
                    );
                  },
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: RawKeyboardListener(
              focusNode: FocusNode(),
              onKey: model.onKeyBoardInput,
              child: TextField(
                enableSuggestions: false,
                autocorrect: false,
                controller: model.textEditingController,
                enabled: model.isConsoleHistoryAvailable,
                decoration: InputDecoration(
                    suffixIcon: IconButton(
                      icon: Icon(Icons.send),
                      onPressed: model.onCommandSubmit,
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

    // if (model.isBusy)
    //   return buildBusyListView(context, model);
    // else if (model.isFolderContentAvailable &&
    //     model.isServerAvailable &&
    //     model.isMachineAvailable)
    //   return buildListView(context, model);
    // else
    //   return buildFetchingView();
  }

  Widget _buildConsole(BuildContext context, ConsoleViewModel model) {
    var themeData = Theme.of(context);
    if (!model.isConsoleHistoryAvailable) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SpinKitDoubleBounce(
              color: themeData.colorScheme.secondary,
              size: 100,
            ),
            SizedBox(
              height: 30,
            ),
            FadingText(tr('pages.console.fetching_console'))
          ],
        ),
      );
    }
    return EaseIn(
      child: SmartRefresher(
        controller: model.refreshController,
        onRefresh: model.onRefresh,
        child: _buildListView(context, model),
      ),
    );
  }

  Widget _buildListView(BuildContext context, ConsoleViewModel model) {
    if (model.filteredConsoleEntries.isEmpty)
      return ListTile(
          leading: Icon(Icons.browser_not_supported_sharp),
          title: Text('pages.console.no_entries').tr());

    return ListView.builder(
      reverse: true,
      // controller: model.scrollController,
      itemCount: model.filteredConsoleEntries.length,
      itemBuilder: (context, index) {
        int correctedIndex = model.filteredConsoleEntries.length - 1 - index;
        ConsoleEntry entry = model.filteredConsoleEntries[correctedIndex];
        if (entry.type == ConsoleEntryType.COMMAND)
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
            title: Text(entry.message,
                style: _commandTextStyle(
                    Theme.of(context), ListTileTheme.of(context))),
            subtitle: Text(DateFormat.Hms().format(entry.timestamp)),
            onTap: () => model.onConsoleCommandTap(entry),
          );

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
          title: Text(entry.message),
          subtitle: Text(DateFormat.Hms().format(entry.timestamp)),
        );
      },
    );
  }

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
  ConsoleViewModel viewModelBuilder(BuildContext context) =>
      locator<ConsoleViewModel>();
}
