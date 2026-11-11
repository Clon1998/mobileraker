/*
 * Copyright (c) 2024-2026. Patrick Schmidt.
 * All rights reserved.
 */

// ignore_for_file: avoid-missing-image-alt

import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:collection/collection.dart';
import 'package:common/data/dto/files/gcode_file.dart';
import 'package:common/data/dto/files/moonraker/file_action_response.dart';
import 'package:common/data/dto/history/historical_print_job.dart';
import 'package:common/data/dto/machine/print_state_enum.dart';
import 'package:common/data/enums/file_action_enum.dart';
import 'package:common/service/app_router.dart';
import 'package:common/service/date_format_service.dart';
import 'package:common/service/moonraker/file_service.dart';
import 'package:common/service/moonraker/history_service.dart';
import 'package:common/service/moonraker/klippy_service.dart';
import 'package:common/service/moonraker/printer_service.dart';
import 'package:common/service/selected_machine_service.dart';
import 'package:common/service/ui/bottom_sheet_service_interface.dart';
import 'package:common/service/ui/dialog_service_interface.dart';
import 'package:common/service/ui/snackbar_service_interface.dart';
import 'package:common/ui/animation/animated_size_and_fade.dart';
import 'package:common/ui/components/nav/nav_rail_view.dart';
import 'package:common/ui/components/warning_card.dart';
import 'package:common/util/extensions/async_ext.dart';
import 'package:common/util/extensions/build_context_extension.dart';
import 'package:common/util/extensions/gcode_file_extension.dart';
import 'package:common/util/extensions/historical_print_job_extension.dart';
import 'package:common/util/extensions/number_format_extension.dart';
import 'package:common/util/extensions/object_extension.dart';
import 'package:common/util/extensions/ref_extension.dart';
import 'package:common/util/logger.dart';
import 'package:common/util/path_utils.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/service/ui/file_interaction_service.dart';
import 'package:mobileraker/ui/screens/history/job_formatting.dart';
import 'package:mobileraker_pro/service/ui/pro_sheet_type.dart';
import 'package:mobileraker_pro/spoolman/dto/get_spool.dart';
import 'package:mobileraker_pro/spoolman/service/spoolman_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../routing/app_router.dart';

part 'gcode_file_details_page.freezed.dart';
part 'gcode_file_details_page.g.dart';

class GCodeFileDetailPage extends ConsumerWidget {
  const GCodeFileDetailPage({super.key, required this.gcodeFile, this.embedded = false});

  final GCodeFile gcodeFile;

  /// Whether the details are embedded in another page (e.g. the detail pane of the file manager on larger layouts)
  /// instead of being their own page: no back button, layout chosen by the available width, and no Hero animations
  /// (the file list shows the same file).
  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ProviderScope(
      overrides: [_gcodeProvider.overrideWithValue(gcodeFile)],
      child: embedded ? const _EmbeddedScope(child: _EmbeddedGCodeFileDetails()) : const _GCodeFileDetailPage(),
    );
  }
}

/// Marks [GCodeFileDetailPage.embedded] details.
class _EmbeddedScope extends InheritedWidget {
  const _EmbeddedScope({required super.child});

  static bool of(BuildContext context) => context.getInheritedWidgetOfExactType<_EmbeddedScope>() != null;

  @override
  bool updateShouldNotify(_EmbeddedScope oldWidget) => false;
}

class _EmbeddedGCodeFileDetails extends StatelessWidget {
  const _EmbeddedGCodeFileDetails();

  @override
  Widget build(BuildContext context) {
    return HeroMode(
      enabled: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 600;
          // A plain Scaffold, its host page owns the rail.
          return Scaffold(
            appBar: const _AppBar().unless(compact),
            body: compact ? const _CompactBody() : const _MediumBody(),
            floatingActionButton: const _Fab(),
            floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
          );
        },
      ),
    );
  }
}

class _GCodeFileDetailPage extends StatelessWidget {
  const _GCodeFileDetailPage();

  @override
  Widget build(BuildContext context) {
    return RailScaffold(
      appBar: const _AppBar().only(context.isLargerThanCompact),
      body: context.isCompact ? const _CompactBody() : const _MediumBody(),
      floatingActionButton: const _Fab(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}

/// Space below the content, so the FABs never cover the last card.
const double _fabClearance = 96;

class _CompactBody extends ConsumerWidget {
  const _CompactBody();

  static const double _expandedHeight = 240;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(_gCodeFileDetailsControllerProvider.notifier);
    final file = ref.watch(_gCodeFileDetailsControllerProvider.select((value) => value.file));
    final machineUUID = ref.watch(_gCodeFileDetailsControllerProvider.select((value) => value.machineUUID));
    final themeData = Theme.of(context);

    final canPop = !_EmbeddedScope.of(context) && (ModalRoute.of(context)?.impliesAppBarDismissal ?? false);
    final backdrop = Color.alphaBlend(
      themeData.colorScheme.onSurface.withValues(alpha: 0.05),
      themeData.scaffoldBackgroundColor,
    );

    return CustomScrollView(
      slivers: [
        SliverLayoutBuilder(
          builder: (context, constraints) {
            // The preview scrolled (almost) out of view: the bar takes over and shows what file this is.
            final collapsed = constraints.scrollOffset > _expandedHeight - kToolbarHeight - 24;
            // On top of the preview the buttons need a scrim of their own to stay readable.
            final buttonStyle = collapsed
                ? null
                : IconButton.styleFrom(
                    backgroundColor: Colors.black.withValues(alpha: 0.35),
                    foregroundColor: Colors.white,
                  );

            return SliverAppBar(
              pinned: true,
              expandedHeight: _expandedHeight,
              automaticallyImplyLeading: false,
              leading: canPop ? Center(child: BackButton(style: buttonStyle)) : null,
              titleSpacing: canPop ? 0 : null,
              title: IgnorePointer(
                ignoring: !collapsed,
                child: AnimatedOpacity(
                  opacity: collapsed ? 1 : 0,
                  duration: kThemeAnimationDuration,
                  child: const _CollapsedTitle(),
                ),
              ),
              actions: [
                Builder(
                  builder: (context) => IconButton(
                    style: buttonStyle,
                    icon: const Icon(Icons.more_vert),
                    onPressed: () {
                      final box = context.findRenderObject() as RenderBox?;
                      if (box == null) return;
                      controller.onActionsTap(box.localToGlobal(Offset.zero) & box.size);
                    },
                  ),
                ),
                const SizedBox(width: 4),
              ],
              flexibleSpace: FlexibleSpaceBar(
                collapseMode: CollapseMode.pin,
                background: ColoredBox(
                  color: backdrop,
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      child: Hero(
                        transitionOnUserGestures: true,
                        tag: 'gCodeImage-${file.hashCode}',
                        child: _PreviewImage(file: file, machineUUID: machineUUID, iconSize: 72),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(4, 0, 4, _fabClearance + MediaQuery.paddingOf(context).bottom),
          sliver: const SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [_Header(), _SpoolWarnings(), _SummaryTiles(), _HistoryCard(), _DetailsCard()],
            ),
          ),
        ),
      ],
    );
  }
}

class _MediumBody extends StatelessWidget {
  const _MediumBody();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(4, 4, 4, _fabClearance + MediaQuery.paddingOf(context).bottom),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [_PreviewCard(), _Header(), _SummaryTiles()],
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [_SpoolWarnings(), _HistoryCard(), _DetailsCard()],
            ),
          ),
        ],
      ),
    );
  }
}

/// The big thumbnail of the file, or a file icon if it has none.
///
/// Takes the file instead of watching the page's (scoped) providers: as the child of a [Hero] it is built in the
/// navigator's overlay during the flight, outside of the page's [ProviderScope].
class _PreviewImage extends ConsumerWidget {
  const _PreviewImage({required this.file, required this.machineUUID, this.iconSize = 24});

  final GCodeFile file;

  final String machineUUID;

  final double iconSize;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bigImageUri = file.constructBigImageUri(ref.watch(previewImageUriProvider));

    final fallback = Center(
      child: Icon(Icons.insert_drive_file_outlined, size: iconSize, color: Theme.of(context).disabledColor),
    );
    if (bigImageUri == null) return fallback;

    return CachedNetworkImage(
      cacheManager: ref.watch(httpCacheManagerProvider(machineUUID)),
      imageUrl: bigImageUri.toString(),
      cacheKey: '${bigImageUri.hashCode}-${file.hashCode}',
      httpHeaders: ref.watch(previewImageHttpHeaderProvider),
      imageBuilder: (context, imageProvider) =>
          Image(image: imageProvider, fit: BoxFit.contain, width: double.infinity, height: double.infinity),
      placeholder: (context, url) => fallback,
      errorWidget: (context, url, error) => fallback,
    );
  }
}

/// The preview on larger layouts, where there is no collapsing app bar.
class _PreviewCard extends ConsumerWidget {
  const _PreviewCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final file = ref.watch(_gCodeFileDetailsControllerProvider.select((value) => value.file));
    final machineUUID = ref.watch(_gCodeFileDetailsControllerProvider.select((value) => value.machineUUID));

    return Card(
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: max(MediaQuery.sizeOf(context).height / 3, 250),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Hero(
            transitionOnUserGestures: true,
            tag: 'gCodeImage-${file.hashCode}',
            child: _PreviewImage(file: file, machineUUID: machineUUID, iconSize: 72),
          ),
        ),
      ),
    );
  }
}

/// Thumbnail, name and the key facts of the file, shown in the app bar once the preview is scrolled away.
class _CollapsedTitle extends ConsumerWidget {
  const _CollapsedTitle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final file = ref.watch(_gCodeFileDetailsControllerProvider.select((value) => value.file));
    final machineUUID = ref.watch(_gCodeFileDetailsControllerProvider.select((value) => value.machineUUID));
    final titleStyle = DefaultTextStyle.of(context).style;
    final facts = [
      if (file.filamentTypes.isNotEmpty) file.usedMaterials.keys.join(', '),
      if (file.estimatedTime != null) _durationText(file.estimatedTime!),
    ];

    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: (titleStyle.color ?? Colors.white).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: _PreviewImage(file: file, machineUUID: machineUUID, iconSize: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _displayName(file),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: titleStyle.copyWith(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              if (facts.isNotEmpty)
                Text(
                  facts.join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: titleStyle.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.normal,
                    color: titleStyle.color?.withValues(alpha: 0.7),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Name of the file and its most important properties as chips.
class _Header extends ConsumerWidget {
  const _Header();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final file = ref.watch(_gCodeFileDetailsControllerProvider.select((value) => value.file));
    final themeData = Theme.of(context);
    final slicer = [?file.slicer, ?file.slicerVersion].join(' ');
    // What the Tooltip itself uses for its text.
    final tooltipForeground =
        TooltipTheme.of(context).textStyle?.color ??
        (themeData.brightness == Brightness.dark ? Colors.black : Colors.white);
    final weightFormat = NumberFormat.decimalPatternDigits(
      locale: context.locale.toStringWithSeparator(),
      decimalDigits: 1,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _displayName(file),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: themeData.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Text(file.name, style: themeData.textTheme.bodySmall),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              // One chip per material. Multi material prints list a filament per tool, often the same material in
              // different colors.
              for (final MapEntry(key: material, value: filaments) in file.usedMaterials.entries)
                _Chip(
                  label: filaments.length > 1 ? '${filaments.length}× $material' : material,
                  dotColors: [
                    for (final filament in filaments.take(_Chip.maxDots))
                      filament.color ?? themeData.colorScheme.onSurface,
                  ],
                  // Which filaments these are: the slicer profile and what the print uses of each.
                  tooltip: filaments.any((filament) => filament.name != null)
                      ? TextSpan(
                          children: [
                            for (final (i, filament) in filaments.indexed) ...[
                              if (i > 0) const TextSpan(text: '\n'),
                              WidgetSpan(
                                alignment: PlaceholderAlignment.middle,
                                child: Padding(
                                  padding: const EdgeInsetsDirectional.only(end: 6),
                                  child: _FilamentDot(
                                    color: filament.color ?? tooltipForeground,
                                    outline: tooltipForeground,
                                  ),
                                ),
                              ),
                              TextSpan(
                                text: [
                                  filament.name ?? material,
                                  ?filament.weight?.let(weightFormat.formatGrams),
                                ].join(' · '),
                              ),
                            ],
                          ],
                        )
                      : null,
                ),
              if (file.nozzleDiameter.isNotEmpty)
                _Chip(
                  label: tr(
                    'pages.files.details.header.nozzle_chip',
                    args: [_nozzleDiameterText(context, file.nozzleDiameter)],
                  ),
                ),
              if (slicer.isNotEmpty) _Chip(label: slicer),
            ],
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, this.dotColors = const [], this.tooltip});

  /// More dots than this do not tell more, the label has the count.
  static const int maxDots = 4;

  final String label;

  /// The colors of the filaments the chip stands for, shown as overlapping dots in front of the label.
  final List<Color> dotColors;

  /// More about what the chip stands for, shown when the chip is tapped.
  final InlineSpan? tooltip;

  @override
  Widget build(BuildContext context) {
    final themeData = Theme.of(context);
    const double dot = 10;
    const double step = 7;

    final chip = Chip(
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dotColors.isNotEmpty) ...[
            SizedBox(
              width: dot + step * (dotColors.length - 1),
              height: dot,
              child: Stack(
                children: [
                  for (final (i, color) in dotColors.indexed)
                    PositionedDirectional(
                      start: step * i,
                      child: _FilamentDot(color: color, outline: themeData.colorScheme.onSurface, size: dot),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 6),
          ],
          Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
    if (tooltip == null) return chip;

    return Tooltip(
      richMessage: tooltip,
      triggerMode: TooltipTriggerMode.tap,
      showDuration: const Duration(seconds: 4),
      child: chip,
    );
  }
}

/// The color of a filament as a dot. Its outline keeps overlapping dots apart and a filament in the color of the
/// background visible.
class _FilamentDot extends StatelessWidget {
  const _FilamentDot({required this.color, required this.outline, this.size = 10});

  final Color color;

  /// The color the outline is derived from, i.e. the foreground color of what the dot is shown on.
  final Color outline;

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: outline.withValues(alpha: 0.6)),
      ),
    );
  }
}

/// Warnings about the active Spoolman spool not fitting the file.
class _SpoolWarnings extends ConsumerWidget {
  const _SpoolWarnings();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(_gCodeFileDetailsControllerProvider.notifier);
    final model = ref.watch(_gCodeFileDetailsControllerProvider);
    final numFormat = NumberFormat.decimalPatternDigits(
      locale: context.locale.toStringWithSeparator(),
      decimalDigits: 2,
    );
    final onChangeSpool = model.canStartPrint ? controller.changeActiveSpool : null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        WarningCard(
          show: model.materialMissmatch != null,
          onTap: onChangeSpool,
          actionLabel: const Text('pages.files.details.spoolman_warnings.change_spool').tr(),
          margin: const EdgeInsets.all(4),
          leadingIcon: const Icon(Icons.layers_clear),
          title: const Text('pages.files.details.spoolman_warnings.material_mismatch_title').tr(),
          subtitle: const Text(
            'pages.files.details.spoolman_warnings.material_mismatch_body',
          ).tr(args: [model.file.filamentTypes.toSet().join(', '), model.materialMissmatch ?? '--']),
        ),
        WarningCard(
          show: model.insufficientFilament != null,
          onTap: onChangeSpool,
          actionLabel: const Text('pages.files.details.spoolman_warnings.change_spool').tr(),
          margin: const EdgeInsets.all(4),
          leadingIcon: const Icon(Icons.scale),
          title: const Text('pages.files.details.spoolman_warnings.insufficient_filament_title').tr(),
          subtitle: const Text(
            'pages.files.details.spoolman_warnings.insufficient_filament_body',
          ).tr(args: [model.insufficientFilament?.let(numFormat.formatGrams) ?? '--']),
        ),
      ],
    );
  }
}

/// The two numbers one wants to know before starting a print: how long it takes and how much filament it needs.
class _SummaryTiles extends ConsumerWidget {
  const _SummaryTiles();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final file = ref.watch(_gCodeFileDetailsControllerProvider.select((value) => value.file));
    final dateFormatService = ref.watch(dateFormatServiceProvider);
    final locale = context.locale.toStringWithSeparator();
    final numFormat = NumberFormat.decimalPatternDigits(locale: locale, decimalDigits: 1);
    final lengthFormat = NumberFormat.decimalPatternDigits(locale: locale, decimalDigits: 2);

    String? doneAround;
    if (file.estimatedTime != null) {
      final now = DateTime.now();
      final eta = now.add(Duration(seconds: file.estimatedTime!.toInt()));
      final sameDay = eta.year == now.year && eta.month == now.month && eta.day == now.day;
      final format = sameDay ? dateFormatService.Hm() : dateFormatService.add_Hm(DateFormat.MMMEd());
      doneAround = tr('pages.files.details.summary.done_around', args: [format.format(eta)]);
    }

    final weight = file.filamentWeightTotal?.let(numFormat.formatGrams);
    final length = file.filamentTotal?.let(lengthFormat.formatMillimeters);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _SummaryTile(
              icon: Icons.timer_outlined,
              label: tr('pages.files.details.summary.est_time'),
              value: file.estimatedTime?.let(_durationText) ?? tr('general.unknown'),
              hint: doneAround,
            ),
          ),
          Expanded(
            child: _SummaryTile(
              icon: Icons.album_outlined,
              label: tr('pages.files.details.meta_card.filament'),
              value: weight ?? length ?? tr('general.unknown'),
              hint: weight != null ? length : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({required this.icon, required this.label, required this.value, this.hint});

  final IconData icon;
  final String label;
  final String value;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final themeData = Theme.of(context);
    final muted = themeData.textTheme.bodySmall;

    return Tooltip(
      message: [label, value, ?hint].join('\n'),
      child: Card(
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
                alignment: AlignmentDirectional.centerStart,
                child: Text(value, style: themeData.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              ),
              // Wraps instead of being cut off: an ETA on another day includes the date.
              if (hint != null) ...[
                const SizedBox(height: 2),
                Text(hint!, style: muted),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The recent runs of this file (see [fileJobHistoryProvider]): how many of them completed, what they used and how
/// each of them went.
class _HistoryCard extends HookConsumerWidget {
  const _HistoryCard();

  /// The runs shown before the older ones have to be expanded.
  static const int _collapsedRuns = 3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final file = ref.watch(_gCodeFileDetailsControllerProvider.select((value) => value.file));
    final machineUUID = ref.watch(_gCodeFileDetailsControllerProvider.select((value) => value.machineUUID));
    final history = ref.watch(
      fileJobHistoryProvider(
        machineUUID,
        file.pathForPrint,
        since: file.modifiedDate,
        lastPrinted: file.lastPrintDate,
      ),
    );
    final printerName = ref.watch(selectedMachineProvider.select((data) => data.value?.name));
    final dateFormat = ref.watch(dateFormatServiceProvider).add_Hm(DateFormat.yMMMd());
    final expanded = useState(false);
    final themeData = Theme.of(context);
    final runs = history.value;
    final lastPrinted = file.lastPrintDate;

    final Widget body;
    if (runs != null && runs.isNotEmpty) {
      final older = runs.skip(_collapsedRuns).toList();
      body = Column(
        key: const Key('runs'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _RunTotals(runs: runs),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final (i, job) in runs.take(_collapsedRuns).indexed)
                  _Run(
                    key: ValueKey(job.jobId),
                    job: job,
                    file: file,
                    isLast: i == runs.length - 1 || (!expanded.value && i == _collapsedRuns - 1),
                  ),
                AnimatedSizeAndFade(
                  sizeDuration: kThemeAnimationDuration,
                  fadeDuration: kThemeAnimationDuration,
                  alignment: Alignment.topCenter,
                  child: expanded.value
                      ? Column(
                          key: const Key('olderRuns'),
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (final (i, job) in older.indexed)
                              _Run(key: ValueKey(job.jobId), job: job, file: file, isLast: i == older.length - 1),
                          ],
                        )
                      : const SizedBox(key: Key('noOlderRuns'), width: double.infinity),
                ),
              ],
            ),
          ),
          if (older.isNotEmpty)
            InkWell(
              onTap: () => expanded.value = !expanded.value,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    Icon(Icons.replay, size: 18, color: themeData.textTheme.bodySmall?.color),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        plural('pages.history.earlier_attempts', older.length),
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
          const Divider(height: 1),
          InkWell(
            onTap: () => context.goNamed(AppRoute.history.name),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'pages.files.details.history_card.open_history',
                    style: themeData.textTheme.labelLarge?.copyWith(color: themeData.colorScheme.primary),
                  ).tr(),
                  Icon(Icons.chevron_right, size: 18, color: themeData.colorScheme.primary),
                ],
              ),
            ),
          ),
        ],
      );
    } else if (runs != null) {
      body = _HistoryHint(
        key: const Key('notPrinted'),
        icon: const Icon(Icons.hourglass_empty, size: 20),
        title: tr('pages.files.details.history_card.not_printed_title'),
        body: tr('pages.files.details.history_card.not_printed_body', args: [printerName ?? '--']),
      );
    } else if (history.hasError && lastPrinted != null) {
      // Without the history (e.g. the component is disabled) the file still knows when it was printed last.
      body = _HistoryHint(
        key: const Key('lastPrinted'),
        icon: const Icon(Icons.event_available, size: 20),
        title: tr('pages.files.details.general_card.last_printed'),
        body: dateFormat.format(lastPrinted),
      );
    } else if (history.hasError) {
      body = _HistoryHint(
        key: const Key('historyError'),
        icon: const Icon(Icons.history_toggle_off, size: 20),
        title: tr('pages.history.provider_error.title'),
        body: tr('pages.history.provider_error.body'),
      );
    } else {
      body = _HistoryHint(
        key: const Key('historyLoading'),
        icon: const SizedBox.square(dimension: 18, child: CircularProgressIndicator.adaptive(strokeWidth: 2)),
        title: tr('general.loading'),
        body: tr('pages.history.title'),
      );
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.history),
            title: const Text('pages.history.title').tr(),
            trailing: runs == null || runs.isEmpty
                ? null
                : Text(
                    plural('pages.files.details.history_card.runs', runs.length),
                    style: themeData.textTheme.bodySmall,
                  ),
          ),
          const Divider(height: 1),
          AnimatedSizeAndFade(
            sizeDuration: kThemeAnimationDuration,
            fadeDuration: kThemeAnimationDuration,
            alignment: Alignment.topCenter,
            child: body,
          ),
        ],
      ),
    );
  }
}

/// A single line about the history while there are no runs to show.
class _HistoryHint extends StatelessWidget {
  const _HistoryHint({super.key, required this.icon, required this.title, required this.body});

  final Widget icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final themeData = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: themeData.colorScheme.onSurface.withValues(alpha: 0.2)),
            ),
            child: IconTheme.merge(
              data: IconThemeData(color: themeData.textTheme.bodySmall?.color),
              child: icon,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: themeData.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(body, style: themeData.textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// What all runs of the file add up to.
class _RunTotals extends StatelessWidget {
  const _RunTotals({required this.runs});

  final List<HistoricalPrintJob> runs;

  @override
  Widget build(BuildContext context) {
    final themeData = Theme.of(context);
    final completed = runs.where((job) => job.outcome == JobOutcome.completed).length;
    final stats = [
      (tr('pages.history.filter.completed'), '$completed / ${runs.length}'),
      (tr('pages.history.stats.print_time'), jobDurationText(runs.fold(0.0, (sum, job) => sum + job.printDuration))),
      (
        tr('pages.history.stats.filament'),
        jobFilamentText(context, runs.fold(0.0, (sum, job) => sum + job.filamentUsed)),
      ),
    ];

    return Padding(
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
    );
  }
}

/// A single run of the file in the timeline of the [_HistoryCard].
class _Run extends ConsumerWidget {
  const _Run({super.key, required this.job, required this.file, required this.isLast});

  final HistoricalPrintJob job;

  final GCodeFile file;

  /// Whether this is the last run shown, i.e. the timeline ends here.
  final bool isLast;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeData = Theme.of(context);
    final muted = themeData.textTheme.bodySmall;
    final dateFormatService = ref.watch(dateFormatServiceProvider);
    final (statusColor, statusIcon) = jobStatusStyle(themeData, job);

    final start = job.startTime;
    final date = start.year == DateTime.now().year
        ? '${DateFormat.MMMEd().format(start)} · ${dateFormatService.Hm().format(start)}'
        : dateFormatService.add_Hm(DateFormat.yMMMd()).format(start);

    final usage = [
      if (job.printDuration >= 1) jobDurationText(job.printDuration),
      if (job.filamentUsed >= 10) jobFilamentText(context, job.filamentUsed),
    ].join(' · ');

    // Each job keeps the metadata the file had when it was printed.
    final estimate = job.metadata.estimatedTime ?? file.estimatedTime;
    String? comparedToEstimate;
    double? progress;
    switch (job.outcome) {
      case JobOutcome.completed when estimate != null:
        final diff = job.printDuration - estimate;
        if (diff.abs() >= 1) {
          comparedToEstimate = tr(
            'pages.files.details.history_card.${diff > 0 ? 'longer' : 'shorter'}_than_estimate',
            args: [jobDurationText(diff.abs())],
          );
        }
      case JobOutcome.cancelled || JobOutcome.failed:
        // The filament tells how far a print got, the time also covers heating up and pauses.
        final filamentTotal = job.metadata.filamentTotal ?? file.filamentTotal;
        if (filamentTotal != null && filamentTotal > 0) {
          progress = job.filamentUsed / filamentTotal;
        } else if (estimate != null && estimate > 0) {
          progress = job.printDuration / estimate;
        }
        progress = progress?.clamp(0, 1).toDouble();
        // Runs that were stopped before they really started have nothing to show.
        if (progress != null && progress < 0.01) progress = null;
      default:
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              Icon(statusIcon, size: 22, color: statusColor),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 2),
                    color: themeData.colorScheme.onSurface.withValues(alpha: 0.15),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          jobStatusLabel(job),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: themeData.textTheme.titleSmall?.copyWith(
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(date, style: muted),
                    ],
                  ),
                  if (usage.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(usage, style: themeData.textTheme.bodyMedium),
                  ],
                  if (comparedToEstimate != null) ...[
                    const SizedBox(height: 2),
                    Text(comparedToEstimate, style: muted),
                  ],
                  if (progress != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 4,
                            borderRadius: BorderRadius.circular(2),
                            color: statusColor,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text('~${(progress * 100).round()}%', style: muted),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Everything the slicer and Moonraker know about the file, grouped. Unknown values are left out.
class _DetailsCard extends ConsumerWidget {
  const _DetailsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final file = ref.watch(_gCodeFileDetailsControllerProvider.select((value) => value.file));
    final dateFormat = ref.watch(dateFormatServiceProvider).add_Hm(DateFormat.yMMMd());
    final numFormat = NumberFormat.decimalPatternDigits(
      locale: context.locale.toStringWithSeparator(),
      decimalDigits: 2,
    );
    final themeData = Theme.of(context);
    final machineUUID = ref.watch(_gCodeFileDetailsControllerProvider.select((value) => value.machineUUID));
    // Files opened from the history do not know when they were printed last, the history does.
    final lastPrinted =
        file.lastPrintDate ??
        ref.watch(
          fileJobHistoryProvider(
            machineUUID,
            file.pathForPrint,
            since: file.modifiedDate,
            lastPrinted: file.lastPrintDate,
          ).select((value) => value.value?.firstOrNull?.startTime),
        );

    String mm(double value) => '${numFormat.format(value)} mm';
    String celsius(double value) => '${value.toStringAsFixed(0)} °C';
    const meta = 'pages.files.details.meta_card';

    final sections = <(String, List<(String, String?)>)>[
      (
        tr('$meta.filament'),
        [
          (tr('$meta.filament_type'), file.filamentTypes.isEmpty ? null : file.usedMaterials.keys.join(', ')),
          (tr('$meta.filament_name'), file.filamentNames.isEmpty ? null : file.usedFilamentNames.join(', ')),
          (tr('$meta.filament_weight'), file.filamentWeightTotal?.let(numFormat.formatGrams)),
          (tr('$meta.filament_length'), file.filamentTotal?.let(numFormat.formatMillimeters)),
          (tr('$meta.filament_changes'), file.filamentChangeCount?.let((it) => it > 0 ? '$it' : null)),
        ],
      ),
      (
        tr('$meta.slicing'),
        [
          (tr('$meta.slicer'), file.slicer == null ? null : file.slicerAndVersion),
          (
            tr('$meta.nozzle_diameter'),
            file.nozzleDiameter.isEmpty ? null : _nozzleDiameterText(context, file.nozzleDiameter),
          ),
          (tr('$meta.first_layer'), file.firstLayerHeight?.let(mm)),
          (tr('$meta.layer_higher'), file.layerHeight?.let(mm)),
          (tr('$meta.layer_count'), file.layerCount?.toString()),
          (tr('$meta.object_height'), file.objectHeight?.let(mm)),
        ],
      ),
      (
        tr('$meta.first_layer_temps'),
        [
          (tr('pages.dashboard.general.temp_card.hotend'), file.firstLayerTempExtruder?.let(celsius)),
          (tr('pages.dashboard.general.temp_card.bed'), file.firstLayerTempBed?.let(celsius)),
          (tr('$meta.chamber'), file.chamberTemp?.let((it) => it > 0 ? celsius(it) : null)),
        ],
      ),
      (
        tr('$meta.file'),
        [
          (tr('pages.files.details.general_card.path'), file.absolutPath),
          (tr('pages.files.sort_by.file_size'), numFormat.formatFileSize(file.size)),
          (tr('pages.files.details.general_card.last_mod'), file.modifiedDate?.let(dateFormat.format)),
          (tr('pages.files.details.general_card.last_printed'), lastPrinted?.let(dateFormat.format)),
        ],
      ),
    ];

    final known = [
      for (final (title, rows) in sections)
        (
          title,
          [
            for (final (label, value) in rows)
              if (value != null) (label, value),
          ],
        ),
    ].where((section) => section.$2.isNotEmpty).toList();
    final fieldCount = known.fold(0, (sum, section) => sum + section.$2.length);

    return Card(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            leading: const Icon(Icons.sell_outlined),
            title: const Text('general.details').tr(),
            trailing: Text(plural('$meta.fields', fieldCount), style: themeData.textTheme.bodySmall),
          ),
          const Divider(height: 1),
          for (final (title, rows) in known) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 2),
              child: Text(
                title.toUpperCase(),
                style: themeData.textTheme.labelMedium?.copyWith(
                  color: themeData.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.6,
                ),
              ),
            ),
            for (final (i, (label, value)) in rows.indexed) ...[
              if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16),
              _DetailRow(label: label, value: value),
            ],
          ],
          const SizedBox(height: 6),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: textTheme.bodyMedium?.copyWith(color: textTheme.bodySmall?.color)),
          const SizedBox(width: 24),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

class _AppBar extends ConsumerWidget implements PreferredSizeWidget {
  const _AppBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final model = ref.watch(_gCodeFileDetailsControllerProvider);
    final controller = ref.read(_gCodeFileDetailsControllerProvider.notifier);

    return AppBar(
      automaticallyImplyLeading: !_EmbeddedScope.of(context),
      title: Text(model.file.name),
      actions: [
        IconButton(
          icon: const Icon(Icons.more_vert),
          onPressed: () {
            final box = context.findRenderObject() as RenderBox?;
            final pos = box!.localToGlobal(Offset.zero) & box.size;

            controller.onActionsTap(pos);
          },
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

/// Starts the print, the main action of the page. Everything else is in the menu of the app bar.
class _Fab extends ConsumerWidget {
  const _Fab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(_gCodeFileDetailsControllerProvider.notifier);
    final canStartPrint = ref.watch(_gCodeFileDetailsControllerProvider.select((value) => value.canStartPrint));
    final file = ref.watch(_gCodeFileDetailsControllerProvider.select((value) => value.file));
    final machineUUID = ref.watch(_gCodeFileDetailsControllerProvider.select((value) => value.machineUUID));
    // The file only knows about its last print if Moonraker listed it, not if it was opened from the history.
    final printedBefore =
        file.printStartTime != null ||
        ref.watch(
          fileJobHistoryProvider(
            machineUUID,
            file.pathForPrint,
            since: file.modifiedDate,
            lastPrinted: file.lastPrintDate,
          ).select((value) => value.value?.isNotEmpty ?? false),
        );
    final printLabel = tr(printedBefore ? 'pages.history.actions.print_again' : 'general.print');
    final backgroundColor = Theme.of(context).disabledColor.unless(canStartPrint);
    const icon = Icon(MaterialCommunityIcons.printer_3d_nozzle);

    // Has to fit the width of the rail/the fold strip (iPhone Duo).
    if (!_EmbeddedScope.of(context) && RailScaffold.showsRailOf(context)) {
      return FloatingActionButton(
        backgroundColor: backgroundColor,
        onPressed: controller.onStartPrintTap.only(canStartPrint),
        tooltip: printLabel,
        child: icon,
      );
    }

    return FloatingActionButton.extended(
      backgroundColor: backgroundColor,
      onPressed: controller.onStartPrintTap.only(canStartPrint),
      icon: icon,
      label: Text(printLabel),
    );
  }
}

/// The name of the file without its G-Code extension: `Voron_cube_PLA.gcode` -> `Voron_cube_PLA`
String _displayName(GCodeFile file) {
  final name = file.name;
  final dot = name.lastIndexOf('.');
  if (dot <= 0) return name;
  return const {'.gcode', '.g', '.gc', '.gco', '.ufp'}.contains(name.substring(dot).toLowerCase())
      ? name.substring(0, dot)
      : name;
}

/// `2d 3h`, `1h 34m`, `35m 3s`, `42s`
String _durationText(num seconds) {
  final d = Duration(seconds: seconds.round());
  if (d.inDays > 0) return '${d.inDays}d ${d.inHours.remainder(24)}h';
  if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes.remainder(60)}m';
  if (d.inMinutes > 0) return '${d.inMinutes}m ${d.inSeconds.remainder(60)}s';
  return '${d.inSeconds}s';
}

/// The nozzle diameter(s) of a file, e.g. "0.4 mm" or "0.4, 0.6 mm" for tools with different nozzles.
String _nozzleDiameterText(BuildContext context, List<double> diameters) {
  if (diameters.isEmpty) return tr('general.unknown');
  final format = NumberFormat.decimalPattern(context.locale.toStringWithSeparator());
  return '${diameters.toSet().map(format.format).join(', ')} mm';
}

@Riverpod(dependencies: [])
GCodeFile _gcode(Ref ref) => throw UnimplementedError();

@Riverpod(dependencies: [_gcode])
class _GCodeFileDetailsController extends _$GCodeFileDetailsController {
  FileInteractionService get _fileInteractionService => ref.read(fileInteractionServiceProvider(machineUUID));

  PrinterService get _printerService => ref.read(printerServiceSelectedProvider);

  BottomSheetService get _bottomSheetService => ref.read(bottomSheetServiceProvider);

  DialogService get _dialogService => ref.read(dialogServiceProvider);

  SnackBarService get _snackBarService => ref.read(snackBarServiceProvider);

  GoRouter get _goRouter => ref.read(goRouterProvider);

  /// Whether the details are their own page (the top-most route), not embedded in the file manager's detail pane. Only
  /// then they close/reopen themselves on file changes, the file manager handles it for embedded ones.
  bool get _isOwnPage => _goRouter.state.name == AppRoute.fileManager_exlorer_gcodeDetail.name;

  String get machineUUID => ref.read(selectedMachineProvider.selectRequireValue((value) => value!.uuid));

  @override
  _Model build() {
    ref.keepAliveFor();
    talker.info('Buildign GCodeFileDetailsController');
    final gCodeFile = ref.watch(_gcodeProvider);
    final klippy = ref.watch(klipperProvider(machineUUID)).value;
    // Klipper is watched (a change rebuilds), the print state is listened to; both decide.
    canPrintCalc(PrintState? d) =>
        klippy?.klippyCanReceiveCommands == true && d != null && d != PrintState.printing && d != PrintState.paused;
    final printer = ref.read(printerProvider(machineUUID)).value;
    ref.listen(printerProvider(machineUUID), (previous, next) {
      if (previous?.value?.print.state != next.value?.print.state) {
        state = state.copyWith(canStartPrint: canPrintCalc(next.value?.print.state));
      }
    });

    ref.listen(fileNotificationsProvider(machineUUID, gCodeFile.absolutPath), _onFileNotification,
        fireImmediately: true);

    (double?, String?) spoolCalc(GetSpool spool) {
      double? insufficientFilament;
      String? materialMissmatch;
      if (spool.filament.material != null &&
          gCodeFile.filamentTypes.isNotEmpty &&
          // For multi material prints the spool has to match one of the materials.
          gCodeFile.filamentTypes.none((type) => equalsIgnoreAsciiCase(type, spool.filament.material!.trim()))) {
        materialMissmatch = spool.filament.material?.trim();
      }

      if (gCodeFile.filamentWeightTotal != null &&
          spool.remainingWeight != null &&
          spool.remainingWeight! < gCodeFile.filamentWeightTotal!) {
        insufficientFilament = spool.remainingWeight!;
      }
      return (insufficientFilament, materialMissmatch);
    }

    double? insufficientFilament;
    String? materialMissmatch;
    if (klippy?.hasSpoolmanComponent == true) {
      final spool = ref.read(activeSpoolProvider(machineUUID)).value;

      ref.listen(activeSpoolProvider(machineUUID), (previous, next) {
        if (previous?.value != next.value) {
          final nextSpool = next.value;
          // Without an active spool there is nothing to warn about.
          final res = nextSpool == null ? (null, null) : spoolCalc(nextSpool);
          state = state.copyWith(
            insufficientFilament: res.$1,
            materialMissmatch: res.$2,
          );
        }
      });

      if (spool != null) {
        final res = spoolCalc(spool);
        insufficientFilament = res.$1;
        materialMissmatch = res.$2;
      }
    }
    // ref.listen(fileNotificationsProvider, listener)

    return _Model(
      file: gCodeFile,
      canStartPrint: canPrintCalc(printer?.print.state),
      machineUUID: machineUUID,
      insufficientFilament: insufficientFilament,
      materialMissmatch: materialMissmatch,
    );
  }

  void changeActiveSpool() {
    _bottomSheetService.show(BottomSheetConfig(
      type: ProSheetType.selectSpoolman,
      data: state.machineUUID,
    ));
  }

  Future<void> onStartPrintTap() async {
    await for (var event in _fileInteractionService.submitJobAction(state.file)) {
      talker.info('[GCodeFileDetailsController] onStartPrintTap File-interaction-event: $event');
    }
  }

  Future<void> onActionsTap(Rect position) async {
    await for (var event
        in _fileInteractionService.showFileActionMenu(state.file, position, machineUUID, null, false)) {
      talker.info('[GCodeFileDetailsController] File-interaction-event: $event');
    }
  }

  void _onFileNotification(AsyncValue<FileActionResponse>? prev, AsyncValue<FileActionResponse> next) {
    final notification = next.value;
    if (notification == null) return;
    talker.info('[GCodeFileDetailsController] File-notification: $notification');

    switch (notification.action) {
      case FileAction.delete_file:
        talker.info('[GCodeFileDetailsController] File deleted: ${notification.item.fullPath}, will close view');

        if (_isOwnPage) _goRouter.pop();
        WidgetsBinding.instance.addPostFrameCallback((_) => ref.invalidateSelf());
        break;
      case FileAction.move_file when !_isOwnPage:
        break;
      case FileAction.move_file:
        final filePath = state.file.absolutPath;
        final movedFile = state.file.copyWith(parentPath: notification.item.parentPath, name: notification.item.name);
        // The currently active path in the UI (represents the old location)
        final currentUIPathSegments = filePath.split('/').toList();
        // The destination path where the file was moved to
        final destinationPathSegments = movedFile.absolutPath.split('/').toList();

        talker.info('''
          [GCodeFileDetailsController($machineUUID, $filePath)] 
            File move detected:
            - From: $filePath
            - To: ${movedFile.absolutPath}
        ''');

        // Calculate how much of the path structure needs to change
        final int sharedPathDepth = findCommonPathLength(currentUIPathSegments, destinationPathSegments);
        final viewsToClose = currentUIPathSegments.length - sharedPathDepth;
        final newPathSegmentsToAdd = destinationPathSegments.sublist(sharedPathDepth);

        // Close views back to the common root path
        for (var i = 0; i < viewsToClose; i++) {
          final segmentToClose = currentUIPathSegments[currentUIPathSegments.length - 1 - i];
          final remainingPath = currentUIPathSegments.sublist(0, currentUIPathSegments.length - i).join('/');

          talker.info(
              '[GCodeFileDetailsController($machineUUID, $filePath)] Closing view for path segment: $segmentToClose');
          _goRouter.pop();

          // Invalidate references only for affected paths
          if (remainingPath == filePath) {
            WidgetsBinding.instance.addPostFrameCallback((_) => ref.invalidateSelf());
          }
        }

        // Rebuild the path with new segments
        String reconstructedPath = destinationPathSegments.sublist(0, sharedPathDepth).join('/');

        // Push new views for each path segment
        for (final pathSegment in newPathSegmentsToAdd) {
          final isLast = pathSegment == newPathSegmentsToAdd.last;

          if (isLast) {
            talker.info(
                '[GCodeFileDetailsController($machineUUID, $filePath)] Opening new GCodeDetails view for path: ${movedFile.absolutPath}');
            _goRouter.pushNamed(
              AppRoute.fileManager_exlorer_gcodeDetail.name,
              pathParameters: {'path': reconstructedPath},
              extra: movedFile,
            );
          } else {
            reconstructedPath = '$reconstructedPath/$pathSegment';

            talker.info(
                '[GCodeFileDetailsController($machineUUID, $filePath)] Opening new Folder view for path: $reconstructedPath');

            _goRouter.pushNamed(
              AppRoute.fileManager_explorer.name,
              pathParameters: {'path': reconstructedPath},
              // Only pass the folder object if we're at its exact path
              extra: movedFile.only(reconstructedPath == movedFile.absolutPath),
            );
          }
        }

        talker.info('''
          [GCodeFileDetailsController($machineUUID, $filePath)]
            Path reconstruction completed:
            - Final path: $reconstructedPath
            - Total views modified: ${viewsToClose + newPathSegmentsToAdd.length}
        ''');
      default:
        // Do Nothing!
        break;
    }
  }
}

@freezed
sealed class _Model with _$Model {
  const factory _Model({
    required GCodeFile file,
    required bool canStartPrint,
    required String machineUUID,
    required String? materialMissmatch,
    required double? insufficientFilament,
  }) = __Model;
}
