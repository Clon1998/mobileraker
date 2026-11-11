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
import 'package:common/data/dto/machine/print_state_enum.dart';
import 'package:common/data/enums/file_action_enum.dart';
import 'package:common/service/app_router.dart';
import 'package:common/service/date_format_service.dart';
import 'package:common/service/moonraker/file_service.dart';
import 'package:common/service/moonraker/klippy_service.dart';
import 'package:common/service/moonraker/printer_service.dart';
import 'package:common/service/selected_machine_service.dart';
import 'package:common/service/ui/bottom_sheet_service_interface.dart';
import 'package:common/service/ui/dialog_service_interface.dart';
import 'package:common/service/ui/snackbar_service_interface.dart';
import 'package:common/ui/components/nav/nav_rail_view.dart';
import 'package:common/ui/components/warning_card.dart';
import 'package:common/ui/mobileraker_icons.dart';
import 'package:common/util/extensions/async_ext.dart';
import 'package:common/util/extensions/build_context_extension.dart';
import 'package:common/util/extensions/gcode_file_extension.dart';
import 'package:common/util/extensions/number_format_extension.dart';
import 'package:common/util/extensions/object_extension.dart';
import 'package:common/util/extensions/ref_extension.dart';
import 'package:common/util/logger.dart';
import 'package:common/util/path_utils.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/service/ui/file_interaction_service.dart';
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
      if (file.filamentTypes.isNotEmpty) file.filamentTypes.join(', '),
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
              if (file.filamentTypes.isNotEmpty)
                _Chip(label: file.filamentTypes.join(', '), dotColor: _filamentColor(file) ?? themeData.colorScheme.onSurface),
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
  const _Chip({required this.label, this.dotColor});

  final String label;

  final Color? dotColor;

  @override
  Widget build(BuildContext context) {
    return Chip(
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      avatar: dotColor == null ? null : Icon(Icons.circle, size: 10, color: dotColor),
      label: Text(label),
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
          ).tr(args: [model.file.filamentTypes.join(', '), model.materialMissmatch ?? '--']),
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
              alignment: AlignmentDirectional.centerStart,
              child: Text(value, style: themeData.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            ),
            if (hint != null) ...[
              const SizedBox(height: 2),
              Text(hint!, maxLines: 1, overflow: TextOverflow.ellipsis, style: muted),
            ],
          ],
        ),
      ),
    );
  }
}

/// The runs of this file. For now only whether (and when) it was printed, the list of runs is still to come.
class _HistoryCard extends ConsumerWidget {
  const _HistoryCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final file = ref.watch(_gCodeFileDetailsControllerProvider.select((value) => value.file));
    final printerName = ref.watch(selectedMachineProvider.select((data) => data.value?.name));
    final dateFormat = ref.watch(dateFormatServiceProvider).add_Hm(DateFormat.yMMMd());
    final themeData = Theme.of(context);
    final lastPrinted = file.lastPrintDate;

    return Card(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(leading: const Icon(Icons.history), title: const Text('pages.history.title').tr()),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: themeData.colorScheme.onSurface.withValues(alpha: 0.2)),
                  ),
                  child: Icon(
                    lastPrinted == null ? Icons.hourglass_empty : Icons.event_available,
                    size: 20,
                    color: themeData.textTheme.bodySmall?.color,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lastPrinted == null
                            ? tr('pages.files.details.history_card.not_printed_title')
                            : tr('pages.files.details.general_card.last_printed'),
                        style: themeData.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        lastPrinted == null
                            ? tr(
                                'pages.files.details.history_card.not_printed_body',
                                args: [printerName ?? '--'],
                              )
                            : dateFormat.format(lastPrinted),
                        style: themeData.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
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

    String mm(double value) => '${numFormat.format(value)} mm';
    String celsius(double value) => '${value.toStringAsFixed(0)} °C';
    const meta = 'pages.files.details.meta_card';

    final sections = <(String, List<(String, String?)>)>[
      (
        tr('$meta.filament'),
        [
          (tr('$meta.filament_type'), file.filamentTypes.isEmpty ? null : file.filamentTypes.join(', ')),
          (tr('$meta.filament_name'), file.filamentNames.isEmpty ? null : file.filamentNames.join(', ')),
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

/// The actions of the file: Print as the main FAB, preheat as its smaller companion.
class _Fab extends ConsumerWidget {
  const _Fab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(_gCodeFileDetailsControllerProvider.notifier);
    final canStartPrint = ref.watch(_gCodeFileDetailsControllerProvider.select((value) => value.canStartPrint));
    final file = ref.watch(_gCodeFileDetailsControllerProvider.select((value) => value.file));
    // Same rule as the file's action menu: the bed temperature of the file is what gets preheated.
    final canPreheat = canStartPrint && file.firstLayerTempBed != null;

    final themeData = Theme.of(context);
    final disabledColor = themeData.disabledColor;
    final printLabel = tr(file.printStartTime != null ? 'pages.history.actions.print_again' : 'general.print');
    final preheatLabel = tr('pages.files.gcode_file_actions.preheat');
    const printIcon = Icon(MaterialCommunityIcons.printer_3d_nozzle);
    const preheatIcon = Icon(MobilerakerIcons.nozzle_heat);
    final preheatBackground = canPreheat ? themeData.colorScheme.secondaryContainer : disabledColor;
    final preheatForeground = themeData.colorScheme.onSecondaryContainer.only(canPreheat);

    // Has to fit the width of the rail/the fold strip (iPhone Duo).
    if (!_EmbeddedScope.of(context) && RailScaffold.showsRailOf(context)) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            key: const Key('printFab'),
            backgroundColor: disabledColor.unless(canStartPrint),
            onPressed: controller.onStartPrintTap.only(canStartPrint),
            tooltip: printLabel,
            child: printIcon,
          ),
          const SizedBox(height: 8),
          FloatingActionButton.small(
            key: const Key('preheatFab'),
            heroTag: null,
            backgroundColor: preheatBackground,
            foregroundColor: preheatForeground,
            onPressed: controller.onPreheatTap.only(canPreheat),
            tooltip: preheatLabel,
            child: preheatIcon,
          ),
        ],
      );
    }

    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.extended(
            key: const Key('preheatFab'),
            heroTag: null,
            backgroundColor: preheatBackground,
            foregroundColor: preheatForeground,
            onPressed: controller.onPreheatTap.only(canPreheat),
            icon: preheatIcon,
            label: Text(preheatLabel),
          ),
          const SizedBox(width: 12),
          FloatingActionButton.extended(
            key: const Key('printFab'),
            backgroundColor: disabledColor.unless(canStartPrint),
            onPressed: controller.onStartPrintTap.only(canStartPrint),
            icon: printIcon,
            label: Text(printLabel),
          ),
        ],
      ),
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

/// The slicer's color (`#RRGGBB`) of the first filament of the file, if it is known.
Color? _filamentColor(GCodeFile file) {
  final hex = file.filamentColors?.firstOrNull?.replaceFirst('#', '');
  if (hex == null || hex.length != 6) return null;
  return int.tryParse(hex, radix: 16)?.let((it) => Color(0xFF000000 | it));
}

/// The nozzle diameter(s) of a file, e.g. "0.4 mm" or "0.4, 0.6 mm" for multiple tools.
String _nozzleDiameterText(BuildContext context, List<double> diameters) {
  if (diameters.isEmpty) return tr('general.unknown');
  final format = NumberFormat.decimalPattern(context.locale.toStringWithSeparator());
  return '${diameters.map(format.format).join(', ')} mm';
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

  Future<void> onPreheatTap() async {
    // The service is auto disposed and reads other providers after its confirm dialog, so it is kept alive meanwhile.
    final service = ref.listen(fileInteractionServiceProvider(machineUUID), (_, _) {});
    try {
      await for (var event in service.read().preheatAction(state.file)) {
        talker.info('[GCodeFileDetailsController] onPreheatTap File-interaction-event: $event');
      }
    } finally {
      service.close();
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
