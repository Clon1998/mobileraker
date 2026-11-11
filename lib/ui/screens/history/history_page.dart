/*
 * Copyright (c) 2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:math';

import 'package:common/data/dto/history/historical_print_job.dart';
import 'package:common/data/dto/history/history_params.dart';
import 'package:common/data/dto/history/history_totals.dart';
import 'package:common/data/dto/machine/print_state_enum.dart';
import 'package:common/data/enums/history_job_sheet_action_enum.dart';
import 'package:common/data/enums/sort_kind_enum.dart';
import 'package:common/data/enums/sort_mode_enum.dart';
import 'package:common/data/model/sheet_action_mixin.dart';
import 'package:common/data/model/sort_configuration.dart';
import 'package:common/service/app_router.dart';
import 'package:common/service/date_format_service.dart';
import 'package:common/service/moonraker/history_service.dart';
import 'package:common/service/moonraker/klippy_service.dart';
import 'package:common/service/moonraker/printer_service.dart';
import 'package:common/service/selected_machine_service.dart';
import 'package:common/service/ui/bottom_sheet_service_interface.dart';
import 'package:common/service/ui/dialog_service_interface.dart';
import 'package:common/service/ui/snackbar_service_interface.dart';
import 'package:common/ui/animation/animated_size_and_fade.dart';
import 'package:common/ui/components/nav/nav_drawer_view.dart';
import 'package:common/ui/components/nav/nav_rail_view.dart';
import 'package:common/ui/components/simple_error_widget.dart';
import 'package:common/ui/components/switch_printer_app_bar.dart';
import 'package:common/ui/theme/theme_pack.dart';
import 'package:common/util/extensions/historical_print_job_extension.dart';
import 'package:common/util/extensions/object_extension.dart';
import 'package:common/util/logger.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/routing/app_router.dart';
import 'package:mobileraker/service/ui/bottom_sheet_service_impl.dart';
import 'package:mobileraker/service/ui/file_interaction_service.dart';
import 'package:mobileraker/ui/components/bottomsheet/action_bottom_sheet.dart';
import 'package:mobileraker/ui/components/bottomsheet/sort_mode_bottom_sheet.dart';
import 'package:mobileraker/ui/components/connection/machine_connection_guard.dart';
import 'package:mobileraker/ui/components/emergency_stop_button.dart';
import 'package:mobileraker/ui/components/machine_state_indicator.dart';
import 'package:mobileraker/ui/screens/files/components/remote_file_icon.dart';

/// The amount of jobs loaded per step, also Moonraker's default limit. Hence, the first step shares its request with
/// the dashboard's status card.
const int _pageSize = 50;

/// The max width of the content on larger screens.
const double _maxContentWidth = 720;

const _defaultSort = SortConfiguration(SortMode.startTime, SortKind.descending);

enum _HistoryFilter {
  all,
  completed,
  unfinished;

  bool accepts(HistoricalPrintJob job) => switch (this) {
    _HistoryFilter.all => true,
    _HistoryFilter.completed => job.outcome == JobOutcome.completed,
    _HistoryFilter.unfinished => job.outcome == JobOutcome.cancelled || job.outcome == JobOutcome.failed,
  };
}

class HistoryPage extends HookConsumerWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Null while the search is closed.
    final query = useState<String?>(null);
    final searchController = useTextEditingController();

    void closeSearch() {
      searchController.clear();
      query.value = null;
    }

    return RailScaffold(
      appBar: SwitchPrinterAppBar(
        title: 'pages.history.title'.tr(),
        status: ref.watch(selectedMachineProvider).value?.let(MachineStatusLabel.new),
        actions: [
          IconButton(
            tooltip: MaterialLocalizations.of(context).searchFieldLabel,
            icon: Icon(query.value == null ? Icons.search : Icons.search_off),
            onPressed: () => query.value == null ? query.value = '' : closeSearch(),
          ),
          const EmergencyStopButton(),
        ],
        bottom: query.value == null
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(56),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                  child: SearchBar(
                    controller: searchController,
                    autoFocus: true,
                    elevation: const WidgetStatePropertyAll(0),
                    constraints: const BoxConstraints(minHeight: 44, maxHeight: 44),
                    hintText: tr('pages.history.search_hint'),
                    leading: const Icon(Icons.search, size: 20),
                    trailing: [IconButton(icon: const Icon(Icons.close, size: 20), onPressed: closeSearch)],
                    onChanged: (value) => query.value = value,
                  ),
                ),
              ),
      ),
      drawer: const NavigationDrawerWidget(),
      body: MachineConnectionGuard(
        // The history is provided by Moonraker, Klipper is only required to start a print.
        skipKlipperReady: true,
        onConnected: (_, machineUUID) =>
            _HistoryBody(key: ValueKey(machineUUID), machineUUID: machineUUID, query: query.value?.trim() ?? ''),
      ),
    );
  }
}

class _HistoryBody extends HookConsumerWidget {
  const _HistoryBody({super.key, required this.machineUUID, required this.query});

  final String machineUUID;

  /// Only jobs whose file name contains it are shown.
  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = useState(_HistoryFilter.all);
    final sort = useState(_defaultSort);
    final limit = useState(_pageSize);
    // Moonraker only sorts by date. Everything else is sorted here, among the jobs loaded so far.
    final sortedByDate = sort.value.mode == SortMode.startTime;
    final order = sortedByDate ? sort.value.kind : SortKind.descending;
    final params = limit.value == _pageSize && order == SortKind.descending
        ? null
        : HistoryParams(start: 0, limit: limit.value, since: null, before: null, order: order);

    final jobsAsync = ref.watch(jobHistoryProvider(machineUUID, params));
    // Loading more jobs is a new request, the jobs we already got stay visible until it completed.
    final lastJobs = useRef<List<HistoricalPrintJob>?>(null);
    if (jobsAsync.hasValue) lastJobs.value = jobsAsync.value;
    final jobs = lastJobs.value;

    if (jobs == null) {
      return switch (jobsAsync) {
        AsyncError() => _ProviderError(onRetry: () => ref.invalidate(jobHistoryProvider(machineUUID, params))),
        _ => const Center(child: CircularProgressIndicator.adaptive()),
      };
    }

    final totals = ref.watch(historyTotalsProvider(machineUUID)).value;
    final needle = query.toLowerCase();
    final shown = jobs
        .where(filter.value.accepts)
        .where((job) => needle.isEmpty || job.displayName.toLowerCase().contains(needle))
        .toList();
    if (!sortedByDate) shown.sort(_comparator(sort.value));
    final hasMore = jobs.length >= limit.value;
    final isLoadingMore = jobsAsync.isLoading;

    Future<void> pickSort() async {
      final res = await ref
          .read(bottomSheetServiceProvider)
          .show(
            BottomSheetConfig(
              type: SheetType.sortMode,
              data: SortModeSheetArgs(toShow: SortMode.availableForHistory(), active: sort.value),
            ),
          );
      if (res.confirmed && res.data is SortConfiguration) sort.value = res.data as SortConfiguration;
    }

    // A flat list of the rows, so the jobs are built lazily.
    final rows = <Widget Function(BuildContext)>[
      if (totals != null && totals.totalJobs > 0) (_) => _TotalsCard(totals: totals),
      (_) => _FilterBar(
        selected: filter.value,
        onSelected: (f) => filter.value = f,
        sort: sort.value,
        onTapSort: pickSort,
      ),
      if (shown.isEmpty && !hasMore)
        (ctx) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 48, 16, 16),
          child: Text(
            jobs.isEmpty ? 'pages.history.empty' : 'pages.history.empty_filter',
            textAlign: TextAlign.center,
            style: Theme.of(ctx).textTheme.bodySmall,
          ).tr(),
        ),
      if (sortedByDate)
        for (final (day, dayJobs) in shown.groupedByDay()) ...[
          (_) => _DayHeader(day: day, jobs: dayJobs),
          // The attempts to print a file on that day are a single card.
          for (final (job, others) in dayJobs.groupedByFile())
            (_) => _JobCard(key: ValueKey(job.jobId), machineUUID: machineUUID, job: job, otherAttempts: others),
        ]
      else
        for (final job in shown)
          (_) => _JobCard(key: ValueKey(job.jobId), machineUUID: machineUUID, job: job, showDate: true),
      // Older jobs are loaded once the end of the list comes into view. Keyed, to also continue if a step did not add
      // a job that matches the filter.
      if (hasMore)
        (_) => _LoadMore(
          key: ValueKey(limit.value),
          onLoad: () {
            if (!isLoadingMore) limit.value += _pageSize;
          },
        ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontal = max(4.0, (constraints.maxWidth - _maxContentWidth) / 2);

        return RefreshIndicator.adaptive(
          onRefresh: () {
            ref.invalidate(historyTotalsProvider(machineUUID));
            return ref.refresh(jobHistoryProvider(machineUUID, params).future);
          },
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(horizontal, 4, horizontal, MediaQuery.viewPaddingOf(context).bottom + 16),
            itemCount: rows.length,
            itemBuilder: (context, index) => rows[index](context),
          ),
        );
      },
    );
  }

  static Comparator<HistoricalPrintJob> _comparator(SortConfiguration sort) {
    final Comparator<HistoricalPrintJob> ascending = switch (sort.mode) {
      SortMode.name => (a, b) => a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()),
      SortMode.printDuration => (a, b) => a.printDuration.compareTo(b.printDuration),
      SortMode.filamentUsed => (a, b) => a.filamentUsed.compareTo(b.filamentUsed),
      _ => (a, b) => a.startTime.compareTo(b.startTime),
    };
    return sort.kind == SortKind.ascending ? ascending : (a, b) => ascending(b, a);
  }
}

class _ProviderError extends StatelessWidget {
  const _ProviderError({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history_toggle_off, size: 48, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 16),
            SimpleErrorWidget(
              title: const Text('pages.history.provider_error.title').tr(),
              body: const Text('pages.history.provider_error.body').tr(),
              action: TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.restart_alt_outlined),
                label: const Text('general.retry').tr(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// `2h 5m`, `31m 41s`, `46s`
String _duration(num seconds) {
  final d = Duration(seconds: seconds.round());
  if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes.remainder(60)}m';
  if (d.inMinutes > 0) return '${d.inMinutes}m ${d.inSeconds.remainder(60)}s';
  return '${d.inSeconds}s';
}

/// `528 m`, `1.2 km`
String _filament(BuildContext context, double mm, {bool precise = true}) {
  final format = NumberFormat.decimalPatternDigits(locale: context.locale.toStringWithSeparator(), decimalDigits: 1);
  final meters = mm / 1000;
  if (meters >= 1000) return '${format.format(meters / 1000)} km';
  return precise ? '${format.format(meters)} m' : '${meters.round()} m';
}

/// The lifetime totals of the printer.
class _TotalsCard extends StatelessWidget {
  const _TotalsCard({super.key, required this.totals});

  final HistoryTotals totals;

  @override
  Widget build(BuildContext context) {
    final stats = [
      (tr('pages.history.stats.prints'), '${totals.totalJobs}'),
      (tr('pages.history.stats.print_time'), _hours(totals.totalPrintTime)),
      (tr('pages.history.stats.filament'), _filament(context, totals.totalFilamentUsed, precise: false)),
      (tr('pages.history.stats.longest_print'), _hours(totals.longestPrint)),
    ];
    final themeData = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: IntrinsicHeight(
          child: Row(
            children: [
              for (final (i, (label, value)) in stats.indexed) ...[
                if (i > 0) const VerticalDivider(width: 1, indent: 4, endIndent: 4),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            value,
                            style: themeData.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                        Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: themeData.textTheme.bodySmall),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// `86h`, `3h 12m`, `45m`: The totals do not need seconds.
  static String _hours(double seconds) {
    final d = Duration(seconds: seconds.round());
    if (d.inHours >= 10) return '${d.inHours}h';
    if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes.remainder(60)}m';
    return '${d.inMinutes}m';
  }
}

/// The result filter next to the button that opens the sort modes.
class _FilterBar extends StatelessWidget {
  const _FilterBar({
    super.key,
    required this.selected,
    required this.onSelected,
    required this.sort,
    required this.onTapSort,
  });

  final _HistoryFilter selected;
  final ValueChanged<_HistoryFilter> onSelected;
  final SortConfiguration sort;
  final VoidCallback onTapSort;

  @override
  Widget build(BuildContext context) {
    final themeData = Theme.of(context);
    final colorScheme = themeData.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 6, 4, 2),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 44,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: colorScheme.onSurface.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: colorScheme.outlineVariant),
              ),
              child: Row(
                children: [
                  for (final filter in _HistoryFilter.values)
                    Expanded(
                      child: Semantics(
                        button: true,
                        selected: filter == selected,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => onSelected(filter),
                          child: AnimatedContainer(
                            duration: kThemeAnimationDuration,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: filter == selected ? colorScheme.primaryContainer : Colors.transparent,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Text(
                              'pages.history.filter.${filter.name}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: themeData.textTheme.labelLarge?.copyWith(
                                color: filter == selected
                                    ? colorScheme.onPrimaryContainer
                                    : themeData.textTheme.bodySmall?.color,
                                fontWeight: filter == selected ? FontWeight.bold : null,
                              ),
                            ).tr(),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.outlined(
            tooltip: '${tr('pages.files.sort_by.sort_by')}: ${tr(sort.mode.translation)}',
            onPressed: onTapSort,
            // Highlighted if it is not the default.
            color: sort == _defaultSort ? null : colorScheme.primary,
            icon: const Icon(Icons.sort),
          ),
        ],
      ),
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({super.key, required this.day, required this.jobs});

  final DateTime day;

  /// The shown jobs of the day.
  final List<HistoricalPrintJob> jobs;

  @override
  Widget build(BuildContext context) {
    final themeData = Theme.of(context);
    final printTime = jobs.fold(0.0, (sum, job) => sum + job.printDuration);
    final filament = jobs.fold(0.0, (sum, job) => sum + job.filamentUsed);
    final summary = [
      plural('pages.history.day_prints', jobs.length),
      if (printTime >= 60) _duration(printTime),
      if (filament >= 10) _filament(context, filament),
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 14, 8, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Text(
              _label(),
              style: themeData.textTheme.labelLarge?.copyWith(
                color: themeData.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Text(summary, style: themeData.textTheme.bodySmall),
        ],
      ),
    );
  }

  /// `Today`, `Yesterday`, `Mon, Nov 9`, `Mar 12, 2025`
  String _label() {
    final now = DateTime.now();
    if (day == DateTime(now.year, now.month, now.day)) return tr('date.reference.today');
    if (day == DateTime(now.year, now.month, now.day - 1)) return tr('date.reference.yesterday');
    return (day.year == now.year ? DateFormat.MMMEd() : DateFormat.yMMMd()).format(day);
  }
}

/// Shown at the end of the list while there are older jobs, requests them as soon as it is built (comes into view).
class _LoadMore extends StatefulWidget {
  const _LoadMore({super.key, required this.onLoad});

  final VoidCallback onLoad;

  @override
  State<_LoadMore> createState() => _LoadMoreState();
}

class _LoadMoreState extends State<_LoadMore> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onLoad();
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 16),
      child: Center(child: SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))),
    );
  }
}

const _knownStatus = {
  'completed',
  'cancelled',
  'in_progress',
  'error',
  'klippy_shutdown',
  'klippy_disconnect',
  'server_exit',
  'interrupted',
};

String _statusLabel(HistoricalPrintJob job) =>
    tr('pages.history.status.${_knownStatus.contains(job.status) ? job.status : 'error'}');

(Color? color, IconData icon) _statusStyle(ThemeData themeData, HistoricalPrintJob job) {
  final customColors = themeData.extension<CustomColors>();
  return switch (job.outcome) {
    JobOutcome.completed => (customColors?.success ?? Colors.green, Icons.check_circle),
    JobOutcome.cancelled => (themeData.textTheme.bodySmall?.color, Icons.cancel),
    JobOutcome.failed => (themeData.colorScheme.error, Icons.error),
    JobOutcome.inProgress => (customColors?.info ?? themeData.colorScheme.primary, Icons.play_circle),
  };
}

Widget _thumbnail(ThemeData themeData, String machineUUID, HistoricalPrintJob job) => job.exists
    // No hero: A file is usually listed more than once.
    ? RemoteFileIcon(machineUUID: machineUUID, file: job.metadata, useHero: false)
    : Icon(Icons.insert_drive_file_outlined, color: themeData.disabledColor);

/// A job and, folded into an expandable section, the other attempts to print the same file on that day.
class _JobCard extends HookConsumerWidget {
  const _JobCard({
    super.key,
    required this.machineUUID,
    required this.job,
    this.otherAttempts = const [],
    this.showDate = false,
  });

  final String machineUUID;
  final HistoricalPrintJob job;
  final List<HistoricalPrintJob> otherAttempts;

  /// Whether the date is shown next to the time, for lists that are not grouped by day.
  final bool showDate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeData = Theme.of(context);
    final timeFormat = ref.watch(dateFormatServiceProvider).Hm();
    final expanded = useState(false);
    final (statusColor, statusIcon) = _statusStyle(themeData, job);
    final materials = job.materials;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: () => _showJobActions(ref, machineUUID, job),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: themeData.colorScheme.onSurface.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: _thumbnail(themeData, machineUUID, job),
                      ),
                      Positioned(
                        right: -5,
                        bottom: -5,
                        child: DecoratedBox(
                          decoration: BoxDecoration(color: themeData.cardColor, shape: BoxShape.circle),
                          child: Icon(statusIcon, size: 20, color: statusColor),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                job.displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: themeData.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              showDate
                                  ? '${DateFormat.MMMd().format(job.startTime)}, ${timeFormat.format(job.startTime)}'
                                  : timeFormat.format(job.startTime),
                              style: themeData.textTheme.bodySmall,
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: _statusLabel(job),
                                style: TextStyle(color: statusColor, fontWeight: FontWeight.w600),
                              ),
                              if (job.printDuration >= 1) TextSpan(text: '  ·  ${_duration(job.printDuration)}'),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: themeData.textTheme.bodySmall,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            if (job.filamentUsed >= 10) ...[
                              Text(_filament(context, job.filamentUsed), style: themeData.textTheme.bodySmall),
                              const SizedBox(width: 8),
                            ],
                            if (materials != null)
                              Flexible(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: themeData.colorScheme.onSurface.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    materials,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: themeData.textTheme.labelSmall,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (otherAttempts.isNotEmpty) ...[
            const Divider(height: 1),
            InkWell(
              onTap: () => expanded.value = !expanded.value,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    Icon(Icons.replay, size: 18, color: themeData.textTheme.bodySmall?.color),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        plural('pages.history.earlier_attempts', otherAttempts.length),
                        style: themeData.textTheme.bodyMedium,
                      ),
                    ),
                    AnimatedRotation(
                      turns: expanded.value ? 0.5 : 0,
                      duration: kThemeAnimationDuration,
                      child: Icon(Icons.expand_more, color: themeData.textTheme.bodySmall?.color),
                    ),
                  ],
                ),
              ),
            ),
            AnimatedSizeAndFade(
              sizeDuration: kThemeAnimationDuration,
              fadeDuration: kThemeAnimationDuration,
              alignment: Alignment.topCenter,
              child: expanded.value
                  ? Column(
                      key: const Key('attempts'),
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final attempt in otherAttempts)
                          _Attempt(key: ValueKey(attempt.jobId), machineUUID: machineUUID, job: attempt),
                        const SizedBox(height: 4),
                      ],
                    )
                  : const SizedBox(key: Key('noAttempts'), width: double.infinity),
            ),
          ],
        ],
      ),
    );
  }
}

/// Another attempt to print the file of a [_JobCard].
class _Attempt extends ConsumerWidget {
  const _Attempt({super.key, required this.machineUUID, required this.job});

  final String machineUUID;
  final HistoricalPrintJob job;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeData = Theme.of(context);
    final timeFormat = ref.watch(dateFormatServiceProvider).Hm();
    final (statusColor, statusIcon) = _statusStyle(themeData, job);

    return InkWell(
      onTap: () => _showJobActions(ref, machineUUID, job),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 6, 12, 6),
        child: Row(
          children: [
            Icon(statusIcon, size: 14, color: statusColor),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                [
                  _statusLabel(job),
                  if (job.printDuration >= 1) _duration(job.printDuration),
                  if (job.filamentUsed >= 10) _filament(context, job.filamentUsed),
                ].join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: themeData.textTheme.bodySmall,
              ),
            ),
            const SizedBox(width: 8),
            Text(timeFormat.format(job.startTime), style: themeData.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

/// Shows the actions of a job in a bottom sheet and executes the picked one.
Future<void> _showJobActions(WidgetRef ref, String machineUUID, HistoricalPrintJob job) async {
  // Everything is read up front, the page might be gone once the sheet is closed.
  final bottomSheetService = ref.read(bottomSheetServiceProvider);
  final dialogService = ref.read(dialogServiceProvider);
  final snackBarService = ref.read(snackBarServiceProvider);
  final historyService = ref.read(historyServiceProvider(machineUUID));
  final fileInteractionService = ref.read(fileInteractionServiceProvider(machineUUID));
  final goRouter = ref.read(goRouterProvider);
  final container = ProviderScope.containerOf(ref.context, listen: false);
  final themeData = Theme.of(ref.context);
  final startTime = ref.read(dateFormatServiceProvider).add_Hm(DateFormat.yMMMd(), ', ').format(job.startTime);

  final klippyReady = ref.read(klipperProvider(machineUUID)).value?.klippyCanReceiveCommands == true;
  final printState = ref.read(printerProvider(machineUUID)).value?.print.state;
  final canPrint =
      job.exists &&
      klippyReady &&
      printState != null &&
      printState != PrintState.printing &&
      printState != PrintState.paused;

  final res = await bottomSheetService.show(
    BottomSheetConfig(
      type: SheetType.actions,
      data: ActionBottomSheetArgs(
        title: Text(job.displayName, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          [_statusLabel(job), startTime, if (!job.exists) tr('pages.history.file_deleted')].join(' · '),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        leading: SizedBox.square(dimension: 33, child: _thumbnail(themeData, machineUUID, job)),
        actions: [
          HistoryJobSheetAction.printAgain.let((it) => canPrint ? it : it.disable),
          HistoryJobSheetAction.openFile.let((it) => job.exists ? it : it.disable),
          DividerSheetAction.divider,
          HistoryJobSheetAction.remove.let((it) => job.outcome != JobOutcome.inProgress ? it : it.disable),
        ],
      ),
    ),
  );
  if (!res.confirmed) return;

  switch (res.data) {
    case HistoryJobSheetAction.printAgain:
      // Starts the print and switches to the dashboard.
      await for (final event in fileInteractionService.submitJobAction(job.metadata)) {
        talker.info('[HistoryPage] Print again file-interaction-event: $event');
      }
    case HistoryJobSheetAction.openFile:
      goRouter.pushNamed(
        AppRoute.fileManager_exlorer_gcodeDetail.name,
        pathParameters: {'path': job.metadata.parentPath},
        extra: job.metadata,
      );
    case HistoryJobSheetAction.remove:
      final confirm = await dialogService.showDangerConfirm(
        title: tr('pages.history.remove_dialog.title'),
        body: tr('pages.history.remove_dialog.body', args: [job.displayName]),
        actionLabel: tr('general.remove'),
      );
      if (confirm?.confirmed != true) return;

      try {
        await historyService.deleteJob(job.jobId);
        // Moonraker does not notify about removed jobs.
        container.invalidate(jobHistoryProvider);
        container.invalidate(historyTotalsProvider(machineUUID));
      } catch (e, s) {
        talker.warning('[HistoryPage] Could not delete job ${job.jobId}', e, s);
        snackBarService.show(SnackBarConfig(type: SnackbarType.error, message: tr('pages.history.remove_failed')));
      }
  }
}
