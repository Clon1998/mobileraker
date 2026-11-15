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
import 'package:common/ui/components/skeletons/skeleton_box.dart';
import 'package:common/ui/components/switch_printer_app_bar.dart';
import 'package:common/util/extensions/async_ext.dart';
import 'package:common/util/extensions/historical_print_job_extension.dart';
import 'package:common/util/extensions/object_extension.dart';
import 'package:common/util/logger.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
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
import 'package:mobileraker/ui/screens/history/job_formatting.dart';
import 'package:pull_to_refresh_flutter3/pull_to_refresh_flutter3.dart';
import 'package:shimmer/shimmer.dart';

/// The amount of jobs loaded per step, also Moonraker's default limit. Hence, the first step shares its request with
/// the dashboard's status card.
const int _pageSize = 50;

/// The max width of the content on larger screens.
const double _maxContentWidth = 720;

/// Min. width of the history's body for the list-detail layout.
///
/// Wider than the one of the file manager and Spoolman: the list needs [_minListWidth] for its filters/buttons, and
/// portrait tablets are better off with the full-width list than with two cramped panes.
const double _listDetailMinWidth = 840;

/// Min. width of the list in the list-detail layout.
const double _minListWidth = 360;

/// Max. width of the list in the list-detail layout, the details take the rest.
const double _maxListWidth = 400;

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
    final refreshController = useMemoized(() => RefreshController(), const []);
    useEffect(() => refreshController.dispose, const []);
    // The list moves between the single and the list-detail layout (e.g. rotating a tablet) instead of being rebuilt:
    // its controller only supports a single refresher at a time, and the scroll position is kept.
    final listKey = useMemoized(GlobalKey.new, const []);
    final filter = useState(_HistoryFilter.all);
    final sort = useState(_defaultSort);
    final limit = useState(_pageSize);
    // The job shown in the detail pane of the list-detail layout.
    final selectedId = useState<String?>(null);
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
        _ => const _HistorySkeleton(),
      };
    }

    final totals = ref.watch(historyTotalsProvider(machineUUID)).value;
    final needle = query.toLowerCase();
    final shown = jobs
        .where(filter.value.accepts)
        .where((job) => needle.isEmpty || job.displayName.toLowerCase().contains(needle))
        .toList();
    if (!sortedByDate) shown.sort(_comparator(sort.value));
    // A step is a new request (the jobs we got so far stay visible), a refresh reloads the current one.
    final isLoading = jobsAsync.isLoading;
    final hasMore = jobsAsync.hasValue ? jobs.length >= limit.value : isLoading;
    final loadFailed = jobsAsync.hasError && !isLoading;

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

    // Tells what is beyond the last job: older ones (that are being loaded), a failed request or nothing.
    final Widget? footer;
    if (loadFailed) {
      footer = _LoadMoreFailed(onRetry: () => ref.invalidate(jobHistoryProvider(machineUUID, params)));
    } else if (hasMore) {
      // Older jobs are loaded once the end of the list comes into view. This continues for as long as it stays in
      // view, e.g. if a step did not add a job that matches the filter.
      footer = _LoadMore(loading: isLoading, onLoad: () => limit.value += _pageSize);
    } else if (shown.isNotEmpty) {
      footer = const _EndReached();
    } else {
      footer = null;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final split = constraints.maxWidth >= _listDetailMinWidth;
        // In the list-detail layout, a tap shows the job in the detail pane instead of its actions.
        final selected = split ? selectedId.value?.let((id) => jobs.where((job) => job.jobId == id).firstOrNull) : null;
        void onTapJob(HistoricalPrintJob job) =>
            split ? selectedId.value = job.jobId : _openJob(ref, machineUUID, job, jobs);
        void onLongPressJob(HistoricalPrintJob job) => _showJobActions(ref, machineUUID, job);

        // A flat list of the job rows, so they are built lazily.
        final rows = <Widget Function(BuildContext)>[
          if (sortedByDate)
            for (final (day, dayJobs) in shown.groupedByDay()) ...[
              (_) => _DayHeader(day: day, jobs: dayJobs),
              // The attempts to print a file on that day are a single card.
              for (final (job, others) in dayJobs.groupedByFile())
                (_) => _JobCard(
                  key: ValueKey(job.jobId),
                  machineUUID: machineUUID,
                  job: job,
                  otherAttempts: others,
                  selectedId: selected?.jobId,
                  onTap: onTapJob,
                  onLongPress: onLongPressJob,
                ),
            ]
          else
            for (final job in shown)
              (_) => _JobCard(
                key: ValueKey(job.jobId),
                machineUUID: machineUUID,
                job: job,
                showDate: true,
                selectedId: selected?.jobId,
                onTap: onTapJob,
                onLongPress: onLongPressJob,
              ),
        ];

        final horizontal = split ? 4.0 : max(4.0, (constraints.maxWidth - _maxContentWidth) / 2);

        final list = SmartRefresher(
          key: listKey,
          controller: refreshController,
          onRefresh: () {
            ref.invalidate(historyTotalsProvider(machineUUID));
            ref
                .refresh(jobHistoryProvider(machineUUID, params).future)
                .then(
                  (_) => refreshController.refreshCompleted(),
                  onError: (_, _) => refreshController.refreshFailed(),
                );
          },
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(horizontal, 4, horizontal, MediaQuery.viewPaddingOf(context).bottom + 16),
                sliver: SliverMainAxisGroup(
                  slivers: [
                    if (totals != null && totals.totalJobs > 0) SliverToBoxAdapter(child: _TotalsCard(totals: totals)),
                    SliverToBoxAdapter(
                      child: _FilterBar(
                        selected: filter.value,
                        onSelected: (f) => filter.value = f,
                        sort: sort.value,
                        onTapSort: pickSort,
                      ),
                    ),
                    if (shown.isEmpty && !hasMore && !loadFailed)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 48, 16, 16),
                          child: Text(
                            jobs.isEmpty ? 'pages.history.empty' : 'pages.history.empty_filter',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodySmall,
                          ).tr(),
                        ),
                      ),
                    // The footer is the last item of the lazy list: It is only built (which loads the older jobs) once
                    // it comes into view. A sliver of its own would always be built.
                    SliverList.builder(
                      itemCount: rows.length + (footer != null ? 1 : 0),
                      itemBuilder: (context, index) => index < rows.length ? rows[index](context) : footer,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
        if (!split) return list;

        // List-detail on larger layouts (tablets, foldables): the details of a job are shown next to the list.
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(width: (constraints.maxWidth * 0.4).clamp(_minListWidth, _maxListWidth), child: list),
            const VerticalDivider(width: 1),
            Expanded(
              child: AnimatedSwitcher(
                duration: kThemeAnimationDuration,
                child: selected == null
                    ? const _DetailPanePlaceholder()
                    : _JobDetails(
                        key: ValueKey(selected.jobId),
                        machineUUID: machineUUID,
                        job: selected,
                        fileJobs: jobs.where((job) => job.filename == selected.filename).toList(),
                        onSelect: onTapJob,
                      ),
              ),
            ),
          ],
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

/// The lifetime totals of the printer.
class _TotalsCard extends StatelessWidget {
  const _TotalsCard({super.key, required this.totals});

  final HistoryTotals totals;

  @override
  Widget build(BuildContext context) {
    final stats = [
      (tr('pages.history.stats.prints'), '${totals.totalJobs}'),
      (tr('pages.history.stats.print_time'), _hours(totals.totalPrintTime)),
      (tr('pages.history.stats.filament'), jobFilamentText(context, totals.totalFilamentUsed, precise: false)),
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
      if (printTime >= 60) jobDurationText(printTime),
      if (filament >= 10) jobFilamentText(context, filament),
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

/// Shown at the end of the list while there are older jobs, requests them as soon as it is built (comes into view) and
/// again whenever a step completed while it is still there.
class _LoadMore extends StatefulWidget {
  const _LoadMore({super.key, required this.loading, required this.onLoad});

  /// Whether jobs are being loaded right now, no further ones are requested meanwhile.
  final bool loading;

  final VoidCallback onLoad;

  @override
  State<_LoadMore> createState() => _LoadMoreState();
}

class _LoadMoreState extends State<_LoadMore> {
  @override
  void initState() {
    super.initState();
    _requestMore();
  }

  @override
  void didUpdateWidget(_LoadMore oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.loading && !widget.loading) _requestMore();
  }

  void _requestMore() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !widget.loading) widget.onLoad();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2)),
          const SizedBox(width: 12),
          Text('pages.history.loading_more', style: Theme.of(context).textTheme.bodySmall).tr(),
        ],
      ),
    );
  }
}

/// Shown at the end of the list if the older jobs could not be loaded.
class _LoadMoreFailed extends StatelessWidget {
  const _LoadMoreFailed({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final themeData = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 18, color: themeData.colorScheme.error),
          const SizedBox(width: 10),
          Expanded(child: Text('pages.history.load_more_failed', style: themeData.textTheme.bodySmall).tr()),
          TextButton(onPressed: onRetry, child: const Text('general.retry').tr()),
        ],
      ),
    );
  }
}

/// Shown at the end of the list once all jobs of the history are loaded.
class _EndReached extends StatelessWidget {
  const _EndReached({super.key});

  @override
  Widget build(BuildContext context) {
    final themeData = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
      child: Row(
        children: [
          const Expanded(child: Divider()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text('pages.history.end_reached', style: themeData.textTheme.bodySmall).tr(),
          ),
          const Expanded(child: Divider()),
        ],
      ),
    );
  }
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
    this.selectedId,
    required this.onTap,
    this.onLongPress,
  });

  final String machineUUID;
  final HistoricalPrintJob job;
  final List<HistoricalPrintJob> otherAttempts;

  /// Whether the date is shown next to the time, for lists that are not grouped by day.
  final bool showDate;

  /// The id of the job shown in the detail pane, it is highlighted.
  final String? selectedId;

  final ValueChanged<HistoricalPrintJob> onTap;
  final ValueChanged<HistoricalPrintJob>? onLongPress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeData = Theme.of(context);
    final timeFormat = ref.watch(dateFormatServiceProvider).Hm();
    final expanded = useState(false);
    final (statusColor, statusIcon) = jobStatusStyle(themeData, job);
    final materials = job.materials;
    // An attempt shown in the detail pane (e.g. picked there) is revealed.
    final attemptSelected = otherAttempts.any((it) => it.jobId == selectedId);
    useEffect(() {
      if (attemptSelected) expanded.value = true;
      return null;
    }, [attemptSelected]);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: _selectedColor(themeData, job.jobId == selectedId),
            child: InkWell(
              onTap: () => onTap(job),
              onLongPress: onLongPress != null ? () => onLongPress!(job) : null,
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
                                  text: jobStatusLabel(job),
                                  style: TextStyle(color: statusColor, fontWeight: FontWeight.w600),
                                ),
                                if (job.printDuration >= 1)
                                  TextSpan(text: '  ·  ${jobDurationText(job.printDuration)}'),
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
                                Text(jobFilamentText(context, job.filamentUsed), style: themeData.textTheme.bodySmall),
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
                          _Attempt(
                            key: ValueKey(attempt.jobId),
                            job: attempt,
                            selected: attempt.jobId == selectedId,
                            onTap: onTap,
                            onLongPress: onLongPress,
                          ),
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
  const _Attempt({
    super.key,
    required this.job,
    this.selected = false,
    this.showDate = false,
    required this.onTap,
    this.onLongPress,
  });

  final HistoricalPrintJob job;

  /// Whether it is shown in the detail pane.
  final bool selected;

  /// Whether the date is shown next to the time.
  final bool showDate;

  final ValueChanged<HistoricalPrintJob> onTap;
  final ValueChanged<HistoricalPrintJob>? onLongPress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeData = Theme.of(context);
    final timeFormat = ref.watch(dateFormatServiceProvider).Hm();
    final (statusColor, statusIcon) = jobStatusStyle(themeData, job);

    return Material(
      color: _selectedColor(themeData, selected),
      child: InkWell(
        onTap: () => onTap(job),
        onLongPress: onLongPress != null ? () => onLongPress!(job) : null,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 6, 12, 6),
          child: Row(
            children: [
              Icon(statusIcon, size: 14, color: statusColor),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  [
                    jobStatusLabel(job),
                    if (job.printDuration >= 1) jobDurationText(job.printDuration),
                    if (job.filamentUsed >= 10) jobFilamentText(context, job.filamentUsed),
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: themeData.textTheme.bodySmall,
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
        ),
      ),
    );
  }
}

/// The background of a job (row) shown in the detail pane.
Color _selectedColor(ThemeData themeData, bool selected) =>
    selected ? themeData.colorScheme.primary.withValues(alpha: 0.12) : Colors.transparent;

/// Whether the file of [job] can be printed again right now: it still exists and the printer is idle.
bool _watchCanPrint(WidgetRef ref, String machineUUID, HistoricalPrintJob job) {
  final klippyReady = ref.watch(klipperProvider(machineUUID).selectAs((d) => d.klippyCanReceiveCommands)).value;
  final printState = ref.watch(printerProvider(machineUUID).selectAs((d) => d.print.state)).value;
  return job.exists &&
      klippyReady == true &&
      printState != null &&
      printState != PrintState.printing &&
      printState != PrintState.paused;
}

/// Shows the actions of a job in a bottom sheet and executes the picked one.
Future<void> _showJobActions(WidgetRef ref, String machineUUID, HistoricalPrintJob job) async {
  // Everything is read up front, the page might be gone once the sheet is closed.
  final bottomSheetService = ref.read(bottomSheetServiceProvider);
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
  final run = _jobActionRunner(ref, machineUUID, job);

  final res = await bottomSheetService.show(
    BottomSheetConfig(
      type: SheetType.actions,
      data: ActionBottomSheetArgs(
        title: Text(job.displayName, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          [jobStatusLabel(job), startTime, if (!job.exists) tr('pages.history.file_deleted')].join(' · '),
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
  if (res.confirmed && res.data is HistoryJobSheetAction) await run(res.data as HistoryJobSheetAction);
}

/// Executes an action on [job]. Everything is read up front: the page might be gone by the time it runs (e.g. a sheet
/// was closed). [onRemoved] is called once the job was removed from the history.
Future<void> Function(HistoryJobSheetAction action) _jobActionRunner(
  WidgetRef ref,
  String machineUUID,
  HistoricalPrintJob job, {
  VoidCallback? onRemoved,
}) {
  final dialogService = ref.read(dialogServiceProvider);
  final snackBarService = ref.read(snackBarServiceProvider);
  final historyService = ref.read(historyServiceProvider(machineUUID));
  final fileInteractionService = ref.read(fileInteractionServiceProvider(machineUUID));
  final goRouter = ref.read(goRouterProvider);
  final container = ProviderScope.containerOf(ref.context, listen: false);

  return (action) async {
    switch (action) {
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
          onRemoved?.call();
        } catch (e, s) {
          talker.warning('[HistoryPage] Could not delete job ${job.jobId}', e, s);
          snackBarService.show(SnackBarConfig(type: SnackbarType.error, message: tr('pages.history.remove_failed')));
        }
    }
  };
}

/// Opens the [HistoryJobPage] of [job]. [jobs] are the loaded ones, it lists the other prints of the file.
void _openJob(WidgetRef ref, String machineUUID, HistoricalPrintJob job, List<HistoricalPrintJob> jobs) {
  ref
      .read(goRouterProvider)
      .pushNamed(
        AppRoute.history_job.name,
        extra: [machineUUID, job, jobs.where((it) => it.filename == job.filename).toList()],
      );
}

/// The details of a job as their own page, on phones and other layouts without the detail pane of the history.
class HistoryJobPage extends HookConsumerWidget {
  const HistoryJobPage({super.key, required this.machineUUID, required this.job, this.fileJobs = const []});

  final String machineUUID;
  final HistoricalPrintJob job;

  /// The jobs of the same file the history had loaded, most recent first.
  final List<HistoricalPrintJob> fileJobs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Another print of the file can be picked on the page.
    final selected = useState(job);
    // The latest state of the jobs (e.g. one was removed), the first page of the history is kept alive by the
    // dashboard and the history page.
    final latest = ref.watch(jobHistoryProvider(machineUUID, null)).value;
    final byId = {
      for (final it in fileJobs) it.jobId: it,
      for (final it in latest ?? const <HistoricalPrintJob>[])
        if (it.filename == job.filename) it.jobId: it,
    };
    final shown = byId[selected.value.jobId] ?? selected.value;
    final others = byId.values.toList()..sort((a, b) => b.startTime.compareTo(a.startTime));

    return Scaffold(
      appBar: AppBar(title: const Text('pages.history.details.title').tr()),
      body: AnimatedSwitcher(
        duration: kThemeAnimationDuration,
        child: _JobDetails(
          key: ValueKey(shown.jobId),
          machineUUID: machineUUID,
          job: shown,
          fileJobs: others.isEmpty ? [shown] : others,
          onSelect: (it) => selected.value = it,
          onRemoved: () {
            if (context.mounted) context.pop();
          },
        ),
      ),
    );
  }
}

/// Shown in the detail pane of the list-detail layout until a job is picked.
class _DetailPanePlaceholder extends StatelessWidget {
  const _DetailPanePlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    final themeData = Theme.of(context);
    final color = themeData.textTheme.bodySmall?.color;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.history, size: 48, color: color),
          const SizedBox(height: 8),
          Text(
            tr('pages.history.detail_pane_hint'),
            textAlign: TextAlign.center,
            style: themeData.textTheme.bodyMedium?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

/// The details of a job and its actions: in the detail pane of the list-detail layout (tablets, foldables) and as the
/// body of the [HistoryJobPage] (phones).
class _JobDetails extends ConsumerWidget {
  const _JobDetails({
    super.key,
    required this.machineUUID,
    required this.job,
    required this.fileJobs,
    required this.onSelect,
    this.onRemoved,
  });

  final String machineUUID;
  final HistoricalPrintJob job;

  /// The loaded jobs of the same file, most recent first. Includes [job].
  final List<HistoricalPrintJob> fileJobs;

  /// Shows another job in the pane.
  final ValueChanged<HistoricalPrintJob> onSelect;

  /// Called once [job] was removed from the history.
  final VoidCallback? onRemoved;

  /// The max. amount of other prints of the file that are listed.
  static const int _maxListedPrints = 10;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeData = Theme.of(context);
    final dateFormat = ref.watch(dateFormatServiceProvider).add_Hm(DateFormat.yMMMEd(), ', ');
    final canPrint = _watchCanPrint(ref, machineUUID, job);
    final (statusColor, statusIcon) = jobStatusStyle(themeData, job);
    final file = job.metadata;
    final materials = job.materials;
    final slicer = [?file.slicer, ?file.slicerVersion].join(' ');
    final completedRuns = fileJobs.where((it) => it.outcome == JobOutcome.completed).length;

    // How the print went compared to the estimate of the slicer, only meaningful if it completed.
    String? estimateHint;
    if (file.estimatedTime case final estimate? when job.outcome == JobOutcome.completed && estimate > 0) {
      final diff = job.printDuration - estimate;
      if (diff.abs() >= 60) {
        estimateHint = tr(
          diff > 0
              ? 'pages.files.details.history_card.longer_than_estimate'
              : 'pages.files.details.history_card.shorter_than_estimate',
          args: [jobDurationText(diff.abs())],
        );
      }
    }

    void run(HistoryJobSheetAction action) => _jobActionRunner(ref, machineUUID, job, onRemoved: onRemoved)(action);

    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontal = max(4.0, (constraints.maxWidth - _maxContentWidth) / 2);

        // Wide panes have the preview next to the title, the pane is short in landscape.
        final wide = constraints.maxWidth - 2 * horizontal >= 600;
        final previewSize = wide ? 220.0 : (constraints.maxHeight / 3).clamp(160.0, 280.0);
        final preview = Card(
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            height: previewSize,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: job.exists
                  ? RemoteFileIcon(
                      machineUUID: machineUUID,
                      file: file,
                      useHero: false,
                      imageBuilder: (_, image) => Image(image: image, fit: BoxFit.contain),
                    )
                  : Icon(Icons.insert_drive_file_outlined, size: 72, color: themeData.disabledColor),
            ),
          ),
        );
        final header = Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                job.displayName,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: themeData.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 2),
              Text(
                [job.filename, if (!job.exists) tr('pages.history.file_deleted')].join(' · '),
                style: themeData.textTheme.bodySmall,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(statusIcon, size: 18, color: statusColor),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      jobStatusLabel(job),
                      style: themeData.textTheme.titleSmall?.copyWith(color: statusColor, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
        final actions = Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: canPrint ? () => run(HistoryJobSheetAction.printAgain) : null,
                icon: Icon(HistoryJobSheetAction.printAgain.icon),
                label: Text(HistoryJobSheetAction.printAgain.labelTranslationKey).tr(),
              ),
              OutlinedButton.icon(
                onPressed: job.exists ? () => run(HistoryJobSheetAction.openFile) : null,
                icon: Icon(HistoryJobSheetAction.openFile.icon),
                label: Text(HistoryJobSheetAction.openFile.labelTranslationKey).tr(),
              ),
              TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: themeData.colorScheme.error),
                onPressed: job.outcome != JobOutcome.inProgress ? () => run(HistoryJobSheetAction.remove) : null,
                icon: Icon(HistoryJobSheetAction.remove.icon),
                label: Text(HistoryJobSheetAction.remove.labelTranslationKey).tr(),
              ),
            ],
          ),
        );

        return ListView(
          padding: EdgeInsets.fromLTRB(horizontal, 4, horizontal, MediaQuery.viewPaddingOf(context).bottom + 16),
          children: [
            if (wide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(width: previewSize, child: preview),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [header, actions]),
                  ),
                ],
              )
            else ...[
              preview,
              header,
              actions,
            ],
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _StatTile(
                      icon: Icons.timer_outlined,
                      label: tr('pages.history.stats.print_time'),
                      value: jobDurationText(job.printDuration),
                      hint: estimateHint,
                    ),
                  ),
                  Expanded(
                    child: _StatTile(
                      icon: Icons.hourglass_empty,
                      label: tr('pages.history.details.total_time'),
                      value: jobDurationText(job.totalDuration),
                    ),
                  ),
                  Expanded(
                    child: _StatTile(
                      icon: Icons.album_outlined,
                      label: tr('pages.history.stats.filament'),
                      value: jobFilamentText(context, job.filamentUsed),
                      hint: materials,
                    ),
                  ),
                ],
              ),
            ),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.play_circle_outline),
                    title: const Text('pages.history.details.started').tr(),
                    subtitle: Text(dateFormat.format(job.startTime)),
                  ),
                  if (job.endTime case final end?)
                    ListTile(
                      leading: const Icon(Icons.stop_circle_outlined),
                      title: const Text('pages.history.details.ended').tr(),
                      subtitle: Text(dateFormat.format(end)),
                    ),
                  if (slicer.isNotEmpty)
                    ListTile(
                      leading: const Icon(Icons.layers_outlined),
                      title: const Text('pages.files.details.meta_card.slicer').tr(),
                      subtitle: Text([slicer, if (file.layerHeight case final height?) '${height}mm'].join(' · ')),
                    ),
                ],
              ),
            ),
            if (fileJobs.length > 1)
              Card(
                clipBehavior: Clip.antiAlias,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      leading: const Icon(Icons.history),
                      title: const Text('pages.history.details.file_prints').tr(),
                      subtitle: const Text(
                        'pages.history.details.file_prints_completed',
                      ).tr(args: ['$completedRuns', '${fileJobs.length}']),
                    ),
                    const Divider(height: 1),
                    for (final it in fileJobs.take(_maxListedPrints))
                      _Attempt(
                        key: ValueKey(it.jobId),
                        job: it,
                        showDate: true,
                        selected: it.jobId == job.jobId,
                        onTap: onSelect,
                      ),
                    const SizedBox(height: 4),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

/// A key figure of a job in the [_JobDetails].
class _StatTile extends StatelessWidget {
  const _StatTile({super.key, required this.icon, required this.label, required this.value, this.hint});

  final IconData icon;
  final String label;
  final String value;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final themeData = Theme.of(context);
    final muted = themeData.textTheme.bodySmall;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 14, color: muted?.color),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: muted),
                ),
              ],
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value, style: themeData.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            ),
            if (hint != null) Text(hint!, maxLines: 2, overflow: TextOverflow.ellipsis, style: muted),
          ],
        ),
      ),
    );
  }
}

/// Shown while the first jobs are loaded, it mirrors the layout of the list.
class _HistorySkeleton extends StatelessWidget {
  const _HistorySkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final themeData = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final split = constraints.maxWidth >= _listDetailMinWidth;
        final horizontal = split ? 4.0 : max(4.0, (constraints.maxWidth - _maxContentWidth) / 2);

        final list = Shimmer.fromColors(
          baseColor: Colors.grey,
          highlightColor: themeData.colorScheme.surface,
          child: ListView(
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(horizontal, 4, horizontal, 16),
            children: [
              // Totals
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: [
                      for (var i = 0; i < 4; i++)
                        const Expanded(
                          child: Column(
                            children: [SkeletonBox(width: 40, height: 18), SizedBox(height: 6), SkeletonBox(width: 56, height: 10)],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              // Filter bar
              const Padding(
                padding: EdgeInsets.fromLTRB(4, 6, 4, 2),
                child: Row(
                  children: [
                    Expanded(child: SkeletonBox(height: 44, radius: 22)),
                    SizedBox(width: 8),
                    SkeletonBox(width: 40, height: 40, radius: 20),
                  ],
                ),
              ),
              for (var day = 0; day < 2; day++) ...[
                const Padding(
                  padding: EdgeInsets.fromLTRB(8, 16, 8, 6),
                  child: Row(children: [SkeletonBox(width: 90, height: 14), Spacer(), SkeletonBox(width: 110, height: 10)]),
                ),
                for (var i = 0; i < 3; i++) const _JobCardSkeleton(),
              ],
            ],
          ),
        );
        if (!split) return list;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(width: (constraints.maxWidth * 0.4).clamp(_minListWidth, _maxListWidth), child: list),
            const VerticalDivider(width: 1),
            const Expanded(child: _DetailPanePlaceholder()),
          ],
        );
      },
    );
  }
}

class _JobCardSkeleton extends StatelessWidget {
  const _JobCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SkeletonBox(width: 56, height: 56, radius: 10),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: FractionallySizedBox(alignment: Alignment.centerLeft, widthFactor: 0.7, child: SkeletonBox(height: 14))),
                      SizedBox(width: 8),
                      SkeletonBox(width: 36, height: 10),
                    ],
                  ),
                  SizedBox(height: 8),
                  SkeletonBox(width: 120, height: 10),
                  SizedBox(height: 8),
                  SkeletonBox(width: 80, height: 10),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
