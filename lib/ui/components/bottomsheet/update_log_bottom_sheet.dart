/*
 * Copyright (c) 2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/service/date_format_service.dart';
import 'package:common/service/moonraker/update_manager_service.dart';
import 'package:common/service/ui/snackbar_service_interface.dart';
import 'package:common/ui/components/sheet_search_header.dart';
import 'package:common/ui/theme/theme_pack.dart';
import 'package:common/util/misc.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/ui/screens/updates/sudo_password_prompt.dart';
import 'package:smooth_sheets/smooth_sheets.dart';

/// The live log of the update, recover or rollback that runs on the machine (`notify_update_response`). Closing it
/// does not stop the update.
class UpdateLogBottomSheet extends ConsumerWidget {
  const UpdateLogBottomSheet({super.key, required this.machineUUID});

  final String machineUUID;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(updateProgressProvider(machineUUID));
    final sudoRequest = ref.watch(sudoRequestProvider(machineUUID)).value;
    final sudoRequested = sudoRequest?.sudoRequested == true;
    final themeData = Theme.of(context);
    final colorScheme = themeData.colorScheme;
    final customColors = themeData.extension<CustomColors>();
    final buttonSize = const Size.fromHeight(48);

    final phase = switch (progress.phase) {
      // Nothing was started yet, the first message is on its way.
      UpdatePhase.idle || UpdatePhase.running => 'running',
      UpdatePhase.finished => 'finished',
      UpdatePhase.failed => 'failed',
    };
    final current = progress.current;
    final name = current == null
        ? ''
        : (current == 'system' ? tr('pages.updates.system_packages') : beautifyName(current));

    return SheetContentScaffold(
      topBar: SheetSearchHeader(
        title: tr('bottom_sheets.update_log.title.$phase.${progress.action.name}', args: [name]).trim(),
        subtitle: progress.steps.length > 1
            ? tr(
                'bottom_sheets.update_log.step',
                args: ['${progress.currentStep + 1}', '${progress.steps.length}'],
              )
            : null,
        trailing: Padding(
          padding: const EdgeInsets.only(right: 12),
          child: AnimatedSwitcher(
            duration: kThemeAnimationDuration,
            transitionBuilder: (child, anim) => ScaleTransition(
              scale: Tween(begin: 0.8, end: 1.0).animate(anim),
              child: FadeTransition(opacity: anim, child: child),
            ),
            child: switch (progress.phase) {
              UpdatePhase.finished => Icon(
                Icons.check_circle,
                key: const Key('finished'),
                color: customColors?.success ?? Colors.green,
              ),
              UpdatePhase.failed => Icon(Icons.error, key: const Key('failed'), color: colorScheme.error),
              _ => const SizedBox.square(
                key: Key('running'),
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            },
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (progress.steps.length > 1) ...[_Steps(progress: progress), const SizedBox(height: 12)],
            _Log(log: progress.log),
            // The update does not continue until Moonraker got the sudo password.
            if (sudoRequested) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.key, size: 16, color: colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      sudoRequest!.requestMessages.isEmpty
                          ? tr('pages.updates.sudo.body')
                          : sudoRequest.requestMessages.join('\n'),
                      style: themeData.textTheme.bodySmall,
                    ),
                  ),
                  TextButton(
                    onPressed: () =>
                        promptSudoPassword(ProviderScope.containerOf(context, listen: false), machineUUID),
                    child: const Text('pages.updates.sudo.enter').tr(),
                  ),
                ],
              ),
            ] else if (progress.phase != UpdatePhase.finished && progress.phase != UpdatePhase.failed) ...[
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 16, color: colorScheme.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'bottom_sheets.update_log.hint',
                      style: themeData.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                    ).tr(),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
      bottomBarVisibility: BottomBarVisibility.always(),
      bottomBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(minimumSize: buttonSize),
                  onPressed: progress.log.isEmpty
                      ? null
                      : () {
                          Clipboard.setData(ClipboardData(text: progress.logText));
                          ref
                              .read(snackBarServiceProvider)
                              .show(SnackBarConfig(message: tr('bottom_sheets.update_log.copied')));
                        },
                  child: const Text('bottom_sheets.update_log.copy').tr(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(minimumSize: buttonSize),
                  onPressed: context.pop,
                  child: Text(progress.isRunning ? 'general.hide' : 'general.close').tr(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One segment per software that is updated: filled once it is done, running for the current one.
class _Steps extends StatelessWidget {
  const _Steps({super.key, required this.progress});

  final UpdateProgressState progress;

  @override
  Widget build(BuildContext context) {
    final themeData = Theme.of(context);
    final colorScheme = themeData.colorScheme;
    final currentStep = progress.currentStep;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (i, step) in progress.steps.indexed) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    minHeight: 4,
                    color: progress.phase == UpdatePhase.failed && i == currentStep ? colorScheme.error : null,
                    value: switch (progress.phase) {
                      UpdatePhase.finished => 1,
                      UpdatePhase.failed => i <= currentStep ? 1 : 0,
                      _ when i < currentStep => 1,
                      // Moonraker does not tell how far an update is.
                      _ when i == currentStep => null,
                      _ => 0,
                    },
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  step == 'system' ? tr('pages.updates.system_packages') : beautifyName(step),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: themeData.textTheme.labelSmall?.copyWith(
                    color: i <= currentStep ? null : colorScheme.onSurfaceVariant,
                    fontWeight: i == currentStep ? FontWeight.bold : null,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// The messages of Moonraker, following the newest one unless the user scrolled up.
class _Log extends HookConsumerWidget {
  const _Log({super.key, required this.log});

  final List<UpdateLogEntry> log;

  /// How close to the end the list has to be to keep following it.
  static const double _followThreshold = 48;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeData = Theme.of(context);
    final colorScheme = themeData.colorScheme;
    final timeFormat = ref.watch(dateFormatServiceProvider).Hms();
    final scrollController = useScrollController();

    useEffect(() {
      if (!scrollController.hasClients) return null;
      final position = scrollController.position;
      if (position.maxScrollExtent - position.pixels > _followThreshold) return null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (scrollController.hasClients) scrollController.jumpTo(scrollController.position.maxScrollExtent);
      });
      return null;
    }, [log.length]);

    final textStyle = themeData.textTheme.bodySmall?.copyWith(fontFamily: 'monospace', color: colorScheme.onSurface);

    return Container(
      height: (MediaQuery.sizeOf(context).height * 0.4).clamp(160.0, 360.0),
      decoration: BoxDecoration(
        color: colorScheme.onSurface.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: log.isEmpty
          ? Center(
              child: Text(
                'bottom_sheets.update_log.waiting',
                style: themeData.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
              ).tr(),
            )
          : SelectionArea(
              child: ListView.builder(
                controller: scrollController,
                padding: const EdgeInsets.all(12),
                itemCount: log.length,
                itemBuilder: (context, index) {
                  final entry = log[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '${timeFormat.format(entry.time)}  ',
                            style: TextStyle(color: colorScheme.onSurfaceVariant),
                          ),
                          TextSpan(text: entry.message),
                        ],
                      ),
                      style: textStyle,
                    ),
                  );
                },
              ),
            ),
    );
  }
}
