/*
 * Copyright (c) 2024-2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/model/hive/machine.dart';
import 'package:common/util/extensions/number_format_extension.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../ui/components/machine_state_indicator.dart';
import '../components/remote_file_icon.dart';
import 'fleet_print_controller.dart';

class FleetPrintPage extends ConsumerWidget {
  const FleetPrintPage({super.key, required this.args});

  final FleetPrintArgs args;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(fleetPrintControllerProvider(args));

    final canPop = !state.started || state.isComplete;

    return PopScope(
      canPop: canPop,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('pages.files.fleet_print.title').tr(),
          automaticallyImplyLeading: canPop,
        ),
        body: SafeArea(
          child: state.started ? _ProgressBody(args: args) : _SetupBody(args: args),
        ),
        bottomNavigationBar: _BottomBar(args: args),
      ),
    );
  }
}


class _SetupBody extends ConsumerWidget {
  const _SetupBody({required this.args});

  final FleetPrintArgs args;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(fleetPrintControllerProvider(args));
    final controller = ref.read(fleetPrintControllerProvider(args).notifier);
    final themeData = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FileInfoCard(args: args),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Text('pages.files.fleet_print.select_hint', style: themeData.textTheme.bodyMedium).tr(),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: state.availableTargets.length,
            itemBuilder: (context, i) {
              final machine = state.availableTargets[i];
              final isSelected = state.selectedTargets.any((m) => m.uuid == machine.uuid);
              final isSource = machine.uuid == args.sourceMachineUUID;
              return CheckboxListTile(
                value: isSelected,
                onChanged: (_) => controller.toggleMachine(machine),
                title: Text(machine.name),
                subtitle: Text(
                  isSource
                      ? '${machine.httpUri.host} · ${'pages.files.fleet_print.source_printer'.tr()}'
                      : machine.httpUri.host,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                secondary: MachineStateIndicator(machine),
                controlAffinity: ListTileControlAffinity.leading,
              );
            },
          ),
        ),
      ],
    );
  }
}


class _ProgressBody extends ConsumerWidget {
  const _ProgressBody({required this.args});

  final FleetPrintArgs args;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(fleetPrintControllerProvider(args));

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        _FileInfoCard(args: args),
        if (state.downloadRequired) ...[
          const SizedBox(height: 4),
          _DownloadTile(args: args),
        ],
        const Divider(height: 1),
        ...state.selectedTargets.map((m) => _MachineProgressTile(args: args, machine: m)),
        if (state.isComplete) ...[
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _SummaryText(args: args),
          ),
        ],
      ],
    );
  }
}

class _DownloadTile extends ConsumerWidget {
  const _DownloadTile({required this.args});

  final FleetPrintArgs args;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(fleetPrintControllerProvider(args));
    final themeData = Theme.of(context);

    return ListTile(
      titleAlignment: ListTileTitleAlignment.center,
      leading: SizedBox.square(
        dimension: 24,
        child: state.downloadComplete
            ? Icon(Icons.check_circle, color: themeData.colorScheme.primary)
            : state.downloadError != null
                ? Icon(Icons.error, color: themeData.colorScheme.error)
                : const CircularProgressIndicator.adaptive(strokeWidth: 2),
      ),
      title: Text('pages.files.fleet_print.downloading').tr(namedArgs: {'name': args.sourceMachineName}),
      subtitle: state.downloadError != null
          ? Text(
              state.downloadError.toString(),
              style: TextStyle(color: themeData.colorScheme.error),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            )
          : !state.downloadComplete
              ? LinearProgressIndicator(value: state.downloadProgress > 0 ? state.downloadProgress : null)
              : null,
    );
  }
}

class _MachineProgressTile extends ConsumerWidget {
  const _MachineProgressTile({required this.args, required this.machine});

  final FleetPrintArgs args;
  final Machine machine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(fleetPrintControllerProvider(args));
    final targetState = state.targetStates[machine.uuid] ?? const FleetTargetPending();
    final themeData = Theme.of(context);

    return ListTile(
      titleAlignment: ListTileTitleAlignment.center,
      leading: SizedBox.square(
        dimension: 24,
        child: switch (targetState) {
          FleetTargetPending() => Icon(Icons.hourglass_empty, color: themeData.disabledColor),
          FleetTargetChecking() || FleetTargetUploading() => const CircularProgressIndicator.adaptive(strokeWidth: 2),
          FleetTargetSuccess() => Icon(Icons.check_circle, color: themeData.colorScheme.primary),
          FleetTargetFailed() => Icon(Icons.error, color: themeData.colorScheme.error),
        },
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(machine.name),
          Text(
            machine.httpUri.host,
            style: themeData.textTheme.bodySmall?.copyWith(color: themeData.colorScheme.secondary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
      subtitle: switch (targetState) {
        FleetTargetChecking() => Text('pages.files.fleet_print.checking').tr(),
        FleetTargetUploading(:final progress) =>
          LinearProgressIndicator(value: progress > 0 ? progress : null),
        FleetTargetSuccess() => Text(
            'pages.files.fleet_print.print_started',
            style: TextStyle(color: themeData.colorScheme.primary),
          ).tr(),
        FleetTargetFailed(:final reason) => Text(
            reason,
            style: TextStyle(color: themeData.colorScheme.error),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        _ => null,
      },
    );
  }
}

class _SummaryText extends ConsumerWidget {
  const _SummaryText({required this.args});

  final FleetPrintArgs args;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(fleetPrintControllerProvider(args));
    final themeData = Theme.of(context);

    final total = state.selectedTargets.length;
    final success = state.targetStates.values.whereType<FleetTargetSuccess>().length;
    final failed = total - success;

    final key =
        failed > 0 ? 'pages.files.fleet_print.summary_partial' : 'pages.files.fleet_print.summary_success';

    return Text(
      key,
      style: themeData.textTheme.bodyMedium,
    ).tr(namedArgs: {'success': '$success', 'total': '$total', 'failed': '$failed'});
  }
}


class _BottomBar extends ConsumerWidget {
  const _BottomBar({required this.args});

  final FleetPrintArgs args;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(fleetPrintControllerProvider(args));
    final controller = ref.read(fleetPrintControllerProvider(args).notifier);

    if (state.isComplete) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: context.pop,
              child: const Text('pages.files.fleet_print.done').tr(),
            ),
          ),
        ),
      );
    }

    if (!state.started) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: state.selectedTargets.isNotEmpty ? controller.startFleetPrint : null,
              child: const Text('pages.files.fleet_print.start_btn').tr(),
            ),
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}


class _FileInfoCard extends StatelessWidget {
  const _FileInfoCard({required this.args});

  final FleetPrintArgs args;

  @override
  Widget build(BuildContext context) {
    final themeData = Theme.of(context);
    final file = args.file;
    final numFormat =
    NumberFormat.decimalPatternDigits(locale: context.locale.toStringWithSeparator(), decimalDigits: 2);

    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox.square(
                dimension: 72,
                child: RemoteFileIcon(
                  machineUUID: args.sourceMachineUUID,
                  file: file,
                  useHero: true,
                  alignment: Alignment.center,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    file.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: themeData.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(numFormat.formatFileSize(file.size), style: themeData.textTheme.bodySmall),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(Icons.print_outlined, size: 12, color: themeData.colorScheme.secondary),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          args.sourceMachineName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: themeData.textTheme.bodySmall?.copyWith(color: themeData.colorScheme.secondary),
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
    );
  }
}
