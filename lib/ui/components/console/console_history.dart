/*
 * Copyright (c) 2025. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/dto/console/gcode_store_entry.dart';
import 'package:common/data/enums/console_entry_type_enum.dart';
import 'package:common/service/date_format_service.dart';
import 'package:common/service/moonraker/printer_service.dart';
import 'package:common/service/setting_service.dart';
import 'package:common/ui/components/async_guard.dart';
import 'package:common/ui/components/simple_error_widget.dart';
import 'package:common/util/extensions/async_ext.dart';
import 'package:common/util/extensions/date_time_extension.dart';
import 'package:common/util/extensions/object_extension.dart';
import 'package:common/util/logger.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:pull_to_refresh_flutter3/pull_to_refresh_flutter3.dart';
import 'package:shimmer/shimmer.dart';

class ConsoleHistory extends StatelessWidget {
  const ConsoleHistory({
    super.key,
    required this.machineUUID,
    this.onCommandTap,
    this.scrollController,
    this.keyboardDismissBehavior,
  });

  final String machineUUID;
  final ValueChanged<String>? onCommandTap;
  final ScrollController? scrollController;
  final ScrollViewKeyboardDismissBehavior? keyboardDismissBehavior;

  @override
  Widget build(BuildContext context) {
    return AsyncGuard(
      debugLabel: 'console-history-$machineUUID',
      toGuard: printerGCodeStoreProvider(machineUUID).selectAs((_) => true),
      childOnLoading: const _ConsoleLoading(),
      childOnError: (error, _) => _ConsoleProviderError(error: error),
      childOnData: _ConsoleData(
        machineUUID: machineUUID,
        onCommandTap: onCommandTap,
        scrollController: scrollController,
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
          children: [const Text('pages.console.provider_error.body').tr(), Text(message, maxLines: 4)],
        ),
        action: TextButton.icon(
          onPressed: () {
            talker.info('Retrying console provider');
            ref.invalidate(printerGCodeStoreProvider);
          },
          icon: const Icon(Icons.restart_alt_outlined),
          label: const Text('general.retry').tr(),
        ),
      ),
    );
  }
}

class _ConsoleData extends ConsumerStatefulWidget {
  const _ConsoleData({
    super.key,
    required this.machineUUID,
    required this.onCommandTap,
    this.scrollController,
    this.keyboardDismissBehavior,
  });

  final String machineUUID;
  final ValueChanged<String>? onCommandTap;
  final ScrollController? scrollController;
  final ScrollViewKeyboardDismissBehavior? keyboardDismissBehavior;

  @override
  ConsumerState<_ConsoleData> createState() => _ConsoleDataState();
}

class _ConsoleDataState extends ConsumerState<_ConsoleData> {
  final RefreshController _refreshController = RefreshController();

  @override
  void initState() {
    super.initState();
    // Sync UI refresher with Riverpod provider
    ref.listenManual(printerGCodeStoreProvider(widget.machineUUID), (previous, next) {
      if (next case AsyncData() when _refreshController.isRefresh) {
        talker.info('Console data refreshed, completing refresher');
        _refreshController.refreshCompleted();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final count = ref.watch(printerGCodeStoreProvider(widget.machineUUID).selectRequireValue((d) => d.length));

    if (count == 0) {
      return ListTile(
        leading: const Icon(Icons.browser_not_supported_sharp),
        title: const Text('pages.console.no_entries').tr(),
      );
    }

    final themeData = Theme.of(context);
    final dateFormatService = ref.read(dateFormatServiceProvider);

    talker.error('Rebuilding console list. Count: $count');

    final showTimeStamp = ref.watch(boolSettingProvider(AppSettingKeys.consoleShowTimestamp));

    var newestAtTop = ref.watch(boolSettingProvider(AppSettingKeys.reverseConsole));
    return SmartRefresher(
      scrollController: widget.scrollController,
      header: ClassicHeader(
        idleText: tr(
          newestAtTop ? 'components.pull_to_refresh.pull_down_idle' : 'components.pull_to_refresh.pull_up_idle',
        ),
        idleIcon: Icon(newestAtTop ? Icons.arrow_downward : Icons.arrow_upward, color: Colors.grey),
      ),
      controller: _refreshController,
      onRefresh: () => ref.invalidate(printerGCodeStoreProvider),
      child: ListView.builder(
        keyboardDismissBehavior: widget.keyboardDismissBehavior,
        controller: widget.scrollController,
        reverse: !newestAtTop,
        itemCount: count,
        itemBuilder: (context, index) {
          if (index >= count) return null; // Prevents index out of bounds error
          final correctedIndex = count - index - 1;

          final GCodeStoreEntry? entry = ref.watch(
            printerGCodeStoreProvider(
              widget.machineUUID,
            ).selectRequireValue((data) => data.elementAtOrNull(correctedIndex)),
          );

          if (entry == null) return null;

          DateFormat dateFormat = dateFormatService.Hms();
          if (entry.timestamp.isNotToday()) {
            dateFormat.addPattern('MMMd', ', ');
          }

          return switch (entry.type) {
            ConsoleEntryType.command || ConsoleEntryType.batchCommand => Material(
              type: MaterialType.transparency,
              child: ListTile(
                key: ValueKey(index),
                dense: true,
                visualDensity: VisualDensity.compact,
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                title: Text(entry.message, style: _commandTextStyle(themeData)),
                onTap: () => widget.onCommandTap?.call(entry.message),
                subtitle: Text(dateFormat.format(entry.timestamp)).only(showTimeStamp),
                subtitleTextStyle: themeData.textTheme.bodySmall,
                minTileHeight: 0,
              ),
            ),
            ConsoleEntryType.temperatureResponse
                when ref.watch(boolSettingProvider(AppSettingKeys.filterTemperatureResponse)) =>
              SizedBox.shrink(),
            _ => ListTile(
              key: ValueKey(index),
              visualDensity: VisualDensity.compact,
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              title: Text(entry.message),
              titleTextStyle: _messageTextStyle(themeData),
              subtitle: Text(dateFormat.format(entry.timestamp)).only(showTimeStamp),
              subtitleTextStyle: themeData.textTheme.bodySmall,
              minTileHeight: 0,
            ),
          };
        },
      ),
    );
  }

  TextStyle _commandTextStyle(ThemeData theme) {
    TextStyle? textStyle = theme.listTileTheme.titleTextStyle;
    if (textStyle == null && theme.useMaterial3) {
      textStyle = theme.textTheme.bodyLarge!.copyWith(color: theme.colorScheme.onSurface);
    } else if (textStyle == null) {
      switch (theme.listTileTheme.style ?? ListTileStyle.list) {
        case ListTileStyle.drawer:
          textStyle = theme.textTheme.bodyLarge!;
          break;
        case ListTileStyle.list:
          textStyle = theme.textTheme.titleMedium!;
          break;
      }
    }

    return textStyle.copyWith(color: theme.colorScheme.primary, fontFamily: 'monospace');
  }

  TextStyle _messageTextStyle(ThemeData theme) {
    /// The text style for ListTile's [title].
    ///
    /// If this property is null, then [ListTileThemeData.titleTextStyle] is used.
    /// If that is also null and [ThemeData.useMaterial3] is true, [TextTheme.bodyLarge]
    /// with [ColorScheme.onSurface] will be used. Otherwise, If ListTile style is
    /// [ListTileStyle.list], [TextTheme.titleMedium] will be used and if ListTile style
    /// is [ListTileStyle.drawer], [TextTheme.bodyLarge] will be used.
    TextStyle? textStyle = theme.listTileTheme.titleTextStyle;
    if (textStyle == null && theme.useMaterial3) {
      textStyle = theme.textTheme.bodyLarge!.copyWith(color: theme.colorScheme.onSurface);
    } else if (textStyle == null) {
      switch (theme.listTileTheme.style ?? ListTileStyle.list) {
        case ListTileStyle.drawer:
          textStyle = theme.textTheme.bodyLarge!;
          break;
        case ListTileStyle.list:
          textStyle = theme.textTheme.titleMedium!;
          break;
      }
    }

    return textStyle.copyWith(fontFamily: 'monospace');
  }

  @override
  void dispose() {
    _refreshController.dispose();
    super.dispose();
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
        reverse: true,
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
                      child: Container(width: double.infinity, height: 10.0, color: Colors.white),
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
