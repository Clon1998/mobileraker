/*
 * Copyright (c) 2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:async';
import 'dart:math';

import 'package:common/data/dto/machine/print_state_enum.dart';
import 'package:common/data/dto/update_manager/update_commit.dart';
import 'package:common/data/dto/update_manager/update_status.dart';
import 'package:common/data/dto/update_manager/updater_info.dart';
import 'package:common/data/enums/updater_sheet_action_enum.dart';
import 'package:common/data/model/sheet_action_mixin.dart';
import 'package:common/network/json_rpc_client.dart';
import 'package:common/service/moonraker/klippy_service.dart';
import 'package:common/service/moonraker/printer_service.dart';
import 'package:common/service/moonraker/update_manager_service.dart';
import 'package:common/service/payment_service.dart';
import 'package:common/service/selected_machine_service.dart';
import 'package:common/service/ui/bottom_sheet_service_interface.dart';
import 'package:common/service/ui/dialog_service_interface.dart';
import 'package:common/service/ui/snackbar_service_interface.dart';
import 'package:common/ui/animation/animated_size_and_fade.dart';
import 'package:common/ui/components/async_button_.dart';
import 'package:common/ui/components/nav/nav_drawer_view.dart';
import 'package:common/ui/components/nav/nav_rail_view.dart';
import 'package:common/ui/components/simple_error_widget.dart';
import 'package:common/ui/components/switch_printer_app_bar.dart';
import 'package:common/ui/components/warning_card.dart';
import 'package:common/ui/theme/theme_pack.dart';
import 'package:common/util/extensions/async_ext.dart';
import 'package:common/util/extensions/object_extension.dart';
import 'package:common/util/extensions/updater_info_extension.dart';
import 'package:common/util/logger.dart';
import 'package:common/util/misc.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/service/ui/bottom_sheet_service_impl.dart';
import 'package:mobileraker/service/ui/dialog_service_impl.dart';
import 'package:mobileraker/ui/components/bottomsheet/action_bottom_sheet.dart';
import 'package:mobileraker/ui/components/connection/machine_connection_guard.dart';
import 'package:mobileraker/ui/components/machine_state_indicator.dart';
import 'package:mobileraker/ui/screens/updates/sudo_password_prompt.dart';
import 'package:url_launcher/url_launcher.dart';

/// The max width of the content on larger screens.
const double _maxContentWidth = 720;

/// A host that was not updated for a while has hundreds of packages to update.
const int _maxListedPackages = 40;

/// The name of [updater] as shown to the user.
String updaterDisplayName(UpdaterInfo updater) =>
    updater.isSystem ? tr('pages.updates.system_packages') : beautifyName(updater.name);

/// Whether Moonraker refuses updates and refreshes right now: while printing and while an update runs.
({bool printing, bool busy}) _watchBlockers(WidgetRef ref, String machineUUID) {
  final printing =
      ref.watch(printerProvider(machineUUID).selectAs((d) => d.print.state == PrintState.printing)).value ?? false;
  final statusBusy = ref.watch(updateManagerStatusProvider(machineUUID).selectAs((d) => d.busy)).value ?? false;
  final running = ref.watch(updateProgressProvider(machineUUID).select((d) => d.isRunning));
  return (printing: printing, busy: statusBusy || running);
}

/// Moonraker's update manager: the software registered on the machine with its installed and available version,
/// updating it, and repairing or rolling it back.
class UpdateManagerPage extends ConsumerWidget {
  const UpdateManagerPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final machine = ref.watch(selectedMachineProvider).value;

    return RailScaffold(
      appBar: SwitchPrinterAppBar(
        title: 'pages.updates.title'.tr(),
        status: machine?.let(MachineStatusLabel.new),
        actions: [if (machine != null) _CheckForUpdatesButton(machineUUID: machine.uuid)],
      ),
      drawer: const NavigationDrawerWidget(),
      body: MachineConnectionGuard(
        // The update manager is provided by Moonraker and is what brings a broken Klipper back.
        skipKlipperReady: true,
        onConnected: (_, machineUUID) => _Body(key: ValueKey(machineUUID), machineUUID: machineUUID),
      ),
    );
  }
}

/// Lets Moonraker look for new versions. Unlike pulling to refresh, which only reads what Moonraker already knows.
class _CheckForUpdatesButton extends ConsumerWidget {
  const _CheckForUpdatesButton({super.key, required this.machineUUID});

  final String machineUUID;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasStatus = ref.watch(updateManagerStatusProvider(machineUUID).select((d) => d.hasValue));
    final blockers = _watchBlockers(ref, machineUUID);
    final enabled = hasStatus && !blockers.printing && !blockers.busy;

    return AsyncIconButton(
      tooltip: tr('pages.updates.check_for_updates'),
      icon: const Icon(Icons.refresh),
      onPressed: enabled ? () => _refresh(_containerOf(ref), machineUUID) : null,
    );
  }
}

/// The actions outlive the widget that triggered them (e.g. a card that moved to another section while its sheet was
/// open), hence they work on the container.
ProviderContainer _containerOf(WidgetRef ref) => ProviderScope.containerOf(ref.context, listen: false);

Future<void> _refresh(ProviderContainer container, String machineUUID, [String? name]) async {
  final snackBarService = container.read(snackBarServiceProvider);
  try {
    await container.read(updateManagerStatusProvider(machineUUID).notifier).refresh(name);
  } catch (e, s) {
    talker.warning('[UpdateManagerPage] Could not check for updates', e, s);
    snackBarService.show(
      SnackBarConfig(
        type: SnackbarType.error,
        title: tr('pages.updates.check_failed'),
        message: e is JRpcError ? e.message : e.toString(),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({super.key, required this.machineUUID});

  final String machineUUID;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configured =
        ref.watch(klipperProvider(machineUUID).selectAs((d) => d.hasUpdateManagerComponent)).value ?? true;
    final statusAsync = ref.watch(updateManagerStatusProvider(machineUUID));
    final blockers = _watchBlockers(ref, machineUUID);
    final isSupporter = ref.watch(isSupporterProvider);
    final sudoRequest = ref.watch(sudoRequestProvider(machineUUID)).value;
    // The software Moonraker is working on right now, it offers the live log.
    final updating = ref.watch(updateProgressProvider(machineUUID).select((d) => d.isRunning ? d.current : null));

    if (!configured) {
      return const _Message(
        icon: Icons.system_update_alt,
        title: 'pages.updates.not_configured.title',
        body: 'pages.updates.not_configured.body',
      );
    }

    final status = statusAsync.value;
    if (status == null) {
      return switch (statusAsync) {
        AsyncError() => _Message(
          icon: Icons.sync_problem,
          isError: true,
          title: 'pages.updates.provider_error.title',
          body: 'pages.updates.provider_error.body',
          onRetry: () => ref.invalidate(updateManagerStatusProvider(machineUUID)),
        ),
        _ => const Center(child: CircularProgressIndicator.adaptive()),
      };
    }

    final blocked = blockers.printing || blockers.busy;
    final updaters = status.sortedUpdaters;
    final attention = updaters.where((it) => it.issue != null).toList();
    final available = updaters.where((it) => it.issue == null && it.updateAvailable).toList();
    final upToDate = updaters.where((it) => it.issue == null && !it.updateAvailable).toList();

    Widget card(UpdaterInfo it) => _UpdaterCard(
      key: ValueKey(it.name),
      machineUUID: machineUUID,
      updater: it,
      blocked: blocked,
      isSupporter: isSupporter,
      updating: it.name == updating,
    );

    final rows = <Widget>[
      // Moonraker waits for the sudo password, e.g. in the middle of an update.
      AnimatedSizeAndFade(
        alignment: Alignment.topCenter,
        child: sudoRequest?.sudoRequested == true
            ? _Banner(
                key: const Key('sudo'),
                icon: Icons.key,
                title: 'pages.updates.sudo.title',
                body: sudoRequest!.requestMessages.isEmpty ? 'pages.updates.sudo.body' : null,
                bodyText: sudoRequest.requestMessages.join('\n'),
                actionLabel: 'pages.updates.sudo.enter',
                onAction: () => promptSudoPassword(_containerOf(ref), machineUUID),
              )
            : const SizedBox(key: Key('noSudo'), width: double.infinity),
      ),
      // Animated, both come and go while the page is open.
      AnimatedSizeAndFade(
        alignment: Alignment.topCenter,
        child: switch (blockers) {
          (printing: true, busy: _) => const _Banner(
            key: Key('printing'),
            icon: Icons.pause_circle_outline,
            title: 'pages.updates.printing.title',
            body: 'pages.updates.printing.body',
          ),
          (printing: _, busy: true) => _Banner(
            key: const Key('busy'),
            icon: Icons.downloading,
            title: 'pages.updates.busy.title',
            body: 'pages.updates.busy.body',
            actionLabel: 'pages.updates.busy.show_log',
            onAction: () => _showLog(_containerOf(ref), machineUUID),
          ),
          _ => const SizedBox(key: Key('none'), width: double.infinity),
        },
      ),
      _SummaryCard(machineUUID: machineUUID, status: status, blocked: blocked, isSupporter: isSupporter),
      if (attention.isNotEmpty) ...[
        _SectionHeader(
          label: 'pages.updates.sections.attention',
          color: Theme.of(context).extension<CustomColors>()?.warning,
        ),
        ...attention.map(card),
      ],
      if (available.isNotEmpty) ...[
        const _SectionHeader(label: 'pages.updates.sections.available'),
        ...available.map(card),
      ],
      if (upToDate.isNotEmpty) ...[
        const _SectionHeader(label: 'pages.updates.sections.up_to_date'),
        _UpToDateCard(
          machineUUID: machineUUID,
          updaters: upToDate,
          blocked: blocked,
          isSupporter: isSupporter,
          updating: updating,
        ),
      ],
      if (status.githubRateLimit != null && status.githubRequestsRemaining != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Text(
            'pages.updates.github_rate',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ).tr(args: ['${status.githubRequestsRemaining}', '${status.githubRateLimit}']),
        ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontal = max(4.0, (constraints.maxWidth - _maxContentWidth) / 2);

        return RefreshIndicator.adaptive(
          onRefresh: () => ref.refresh(updateManagerStatusProvider(machineUUID).future),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(horizontal, 4, horizontal, MediaQuery.viewPaddingOf(context).bottom + 16),
            children: rows,
          ),
        );
      },
    );
  }
}

/// Shown instead of the list: the update manager is not available or could not be read.
class _Message extends StatelessWidget {
  const _Message({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.isError = false,
    this.onRetry,
  });

  final IconData icon;
  final String title;
  final String body;
  final bool isError;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: isError ? colorScheme.error : colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            SimpleErrorWidget(
              title: Text(title).tr(),
              body: Text(body).tr(),
              action: onRetry?.let(
                (it) => TextButton.icon(
                  onPressed: it,
                  icon: const Icon(Icons.restart_alt_outlined),
                  label: const Text('general.retry').tr(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tells why the actions of the page are disabled right now.
class _Banner extends StatelessWidget {
  const _Banner({
    super.key,
    required this.icon,
    required this.title,
    this.body,
    this.bodyText = '',
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;

  /// The translation key of the body, [bodyText] is shown without it.
  final String? body;
  final String bodyText;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      color: colorScheme.secondaryContainer,
      child: ListTile(
        iconColor: colorScheme.onSecondaryContainer,
        textColor: colorScheme.onSecondaryContainer,
        leading: Icon(icon),
        title: Text(title).tr(),
        subtitle: Text(body?.tr() ?? bodyText),
        trailing: actionLabel?.let((it) => TextButton(onPressed: onAction, child: Text(it).tr())),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({super.key, required this.label, this.color});

  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final themeData = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 14, 8, 4),
      child: Text(
        label,
        style: themeData.textTheme.labelLarge?.copyWith(
          color: color ?? themeData.colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ).tr(),
    );
  }
}

/// How many updates there are, and updating all of them at once.
class _SummaryCard extends ConsumerWidget {
  const _SummaryCard({
    super.key,
    required this.machineUUID,
    required this.status,
    required this.blocked,
    required this.isSupporter,
  });

  final String machineUUID;
  final UpdateStatus status;
  final bool blocked;
  final bool isSupporter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeData = Theme.of(context);
    final colorScheme = themeData.colorScheme;
    final customColors = themeData.extension<CustomColors>();
    final plan = status.updateAllPlan;
    final hasUpdates = plan.isNotEmpty;
    // A single update has its own button right below.
    final offerUpdateAll = plan.length > 1;

    final names = [
      for (final it in status.sortedUpdaters.where((it) => it.canUpdate))
        it.isSystem ? plural('pages.updates.packages', it.packageCount) : updaterDisplayName(it),
    ].join(', ');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                AnimatedContainer(
                  duration: kThemeAnimationDuration,
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: hasUpdates
                        ? colorScheme.primaryContainer
                        : (customColors?.success ?? Colors.green).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: AnimatedSwitcher(
                    duration: kThemeAnimationDuration,
                    transitionBuilder: (child, anim) => ScaleTransition(
                      scale: Tween(begin: 0.8, end: 1.0).animate(anim),
                      child: FadeTransition(opacity: anim, child: child),
                    ),
                    child: hasUpdates
                        ? Icon(Icons.download, key: const Key('updates'), color: colorScheme.onPrimaryContainer)
                        : Icon(Icons.check, key: const Key('upToDate'), color: customColors?.success ?? Colors.green),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hasUpdates
                            ? plural('pages.updates.summary.available', plan.length)
                            : tr('pages.updates.summary.up_to_date'),
                        style: themeData.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        hasUpdates ? names : tr('pages.updates.summary.up_to_date_body'),
                        style: themeData.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (offerUpdateAll) ...[
              const SizedBox(height: 14),
              if (isSupporter)
                FilledButton.icon(
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                  onPressed: blocked ? null : () => _start(_containerOf(ref), machineUUID, (it) => it.upgrade()),
                  icon: const Icon(Icons.download),
                  label: const Text('pages.updates.update_all').tr(),
                )
              else ...[
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                  onPressed: () => _showSupporterOnly(_containerOf(ref), 'components.supporter_only_feature.update_all'),
                  icon: const Icon(Icons.lock_outline, size: 18),
                  label: const Text('pages.updates.update_all_one_tap').tr(),
                ),
                const SizedBox(height: 8),
                Text(
                  'pages.updates.update_all_hint',
                  textAlign: TextAlign.center,
                  style: themeData.textTheme.bodySmall,
                ).tr(),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

/// The initials of the software in a tile, tinted if it needs attention.
class _Avatar extends StatelessWidget {
  const _Avatar({super.key, required this.updater, this.size = 44});

  final UpdaterInfo updater;
  final double size;

  @override
  Widget build(BuildContext context) {
    final themeData = Theme.of(context);
    final colorScheme = themeData.colorScheme;
    final warning = themeData.extension<CustomColors>()?.warning ?? Colors.orange;
    final hasIssue = updater.issue != null;
    final foreground = hasIssue ? warning : colorScheme.onPrimaryContainer;

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: hasIssue ? warning.withValues(alpha: 0.15) : colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(size / 4),
      ),
      child: updater.isSystem
          ? Icon(Icons.developer_board, size: size / 2, color: foreground)
          : Text(
              _initials(updater.name),
              style: themeData.textTheme.titleSmall?.copyWith(
                color: foreground,
                fontWeight: FontWeight.bold,
                fontSize: size / 3,
              ),
            ),
    );
  }

  /// `klipper` -> `K`, `moonraker-timelapse` -> `MT`, `KlipperScreen` -> `KS`
  static String _initials(String name) {
    final words = name
        .replaceAllMapped(RegExp(r'([a-z0-9])([A-Z])'), (m) => '${m[1]} ${m[2]}')
        .split(RegExp(r'[^A-Za-z0-9]+'))
        .where((it) => it.isNotEmpty);
    return words.take(2).map((it) => it[0].toUpperCase()).join();
  }
}

/// `git · dev`: How the software is updated and which channel it follows.
class _TypeLabel extends StatelessWidget {
  const _TypeLabel({super.key, required this.updater});

  final UpdaterInfo updater;

  static String? text(UpdaterInfo updater) {
    final type = switch (updater.configuredType) {
      UpdaterType.gitRepo => 'git',
      UpdaterType.web => 'web',
      UpdaterType.zip => 'zip',
      UpdaterType.python => 'python',
      UpdaterType.system || UpdaterType.unknown => null,
    };
    final parts = [?type, ?updater.channel];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final themeData = Theme.of(context);
    final label = text(updater);
    if (label == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: themeData.colorScheme.onSurface.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label, maxLines: 1, style: themeData.textTheme.labelSmall),
    );
  }
}

/// The installed version and, if there is an update, the available one.
(String installed, String? available) _versions(UpdaterInfo updater) {
  if (updater.isSystem) {
    final text = updater.updateAvailable
        ? plural('pages.updates.packages_short', updater.packageCount)
        : tr('pages.updates.no_packages');
    return (text, null);
  }
  final version = updater.version.isEmpty ? '?' : updater.version;
  if (!updater.updateAvailable) return (version, null);
  // A git repo on the dev channel can be behind without a new version tag.
  final remote = updater.remoteVersion.isEmpty || updater.remoteVersion == updater.version
      ? UpdaterInfoExtension.shortHash(updater.remoteHash)
      : updater.remoteVersion;
  return (version, remote.isEmpty ? null : remote);
}

/// A software that has an update or needs attention.
class _UpdaterCard extends HookConsumerWidget {
  const _UpdaterCard({
    super.key,
    required this.machineUUID,
    required this.updater,
    required this.blocked,
    required this.isSupporter,
    this.updating = false,
  });

  final String machineUUID;
  final UpdaterInfo updater;
  final bool blocked;
  final bool isSupporter;

  /// Whether Moonraker is updating, recovering or rolling it back right now.
  final bool updating;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeData = Theme.of(context);
    final expanded = useState(false);
    final issue = updater.issue;
    final (installed, available) = _versions(updater);

    final detailsLabel = switch (updater) {
      _ when updater.commitsBehindTotal > 0 => plural('pages.updates.commits_behind', updater.commitsBehindTotal),
      _ when updater.packageList.isNotEmpty => tr('pages.updates.show_packages'),
      _ when updater.anomalies.isNotEmpty => tr('general.details'),
      _ => null,
    };

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => _showUpdaterActions(_containerOf(ref), machineUUID, updater, blocked: blocked, isSupporter: isSupporter),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  _Avatar(updater: updater),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                updaterDisplayName(updater),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: themeData.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 8),
                            _TypeLabel(updater: updater),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(text: installed),
                              if (available != null) ...[
                                WidgetSpan(
                                  alignment: PlaceholderAlignment.middle,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 4),
                                    child: Icon(
                                      Icons.arrow_forward,
                                      size: 12,
                                      color: themeData.textTheme.bodySmall?.color,
                                    ),
                                  ),
                                ),
                                TextSpan(text: available),
                              ],
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: themeData.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  if (updating || updater.canUpdate) ...[
                    const SizedBox(width: 8),
                    AnimatedSwitcher(
                      duration: kThemeAnimationDuration,
                      child: updating
                          ? _ShowLogButton(key: const Key('showLog'), machineUUID: machineUUID)
                          : FilledButton.tonal(
                              key: const Key('update'),
                              onPressed: blocked
                                  ? null
                                  : () => _start(_containerOf(ref), machineUUID, (it) => it.upgrade(updater.name)),
                              child: const Text('pages.updates.update').tr(),
                            ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (issue != null)
            WarningCard(
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              leadingIcon: const Icon(Icons.warning_amber),
              title: Text('pages.updates.issue.${issue.name}.title').tr(),
              subtitle: Text(_issueBody(updater, issue)),
              // Only git repos can be repaired from here.
              onTap: updater.canRecover && !blocked
                  ? () => _recover(_containerOf(ref), machineUUID, updater, isSupporter: isSupporter)
                  : null,
              actionLabel: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!isSupporter) ...[const Icon(Icons.lock_outline, size: 16), const SizedBox(width: 6)],
                  const Text('pages.updates.recover').tr(),
                ],
              ),
            ),
          if (detailsLabel != null) ...[
            const Divider(height: 1),
            InkWell(
              onTap: () => expanded.value = !expanded.value,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    Expanded(child: Text(detailsLabel, style: themeData.textTheme.bodyMedium)),
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
                  ? _UpdaterDetails(key: const Key('details'), updater: updater)
                  : const SizedBox(key: Key('noDetails'), width: double.infinity),
            ),
          ],
        ],
      ),
    );
  }

  static String _issueBody(UpdaterInfo updater, UpdaterIssue issue) => switch (issue) {
    UpdaterIssue.invalid when updater.warnings.isNotEmpty => updater.warnings.join('\n'),
    UpdaterIssue.error => updater.lastError,
    _ => tr('pages.updates.issue.${issue.name}.body'),
  };
}

/// What an update brings: the commits or the packages, and the anomalies Moonraker found.
class _UpdaterDetails extends ConsumerWidget {
  const _UpdaterDetails({super.key, required this.updater});

  final UpdaterInfo updater;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeData = Theme.of(context);
    final notListed = updater.commitsBehindTotal - updater.commitsBehind.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final anomaly in updater.anomalies)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 16, color: themeData.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Expanded(child: Text(anomaly, style: themeData.textTheme.bodySmall)),
                ],
              ),
            ),
          for (final commit in updater.commitsBehind) _Commit(commit: commit),
          if (notListed > 0 && updater.commitsBehind.isNotEmpty)
            Text(plural('pages.updates.more_commits', notListed), style: themeData.textTheme.bodySmall),
          if (updater.packageList.isNotEmpty)
            Text(
              [
                updater.packageList.take(_maxListedPackages).join(', '),
                if (updater.packageList.length > _maxListedPackages)
                  plural('pages.updates.more_packages', updater.packageList.length - _maxListedPackages),
              ].join(' '),
              style: themeData.textTheme.bodySmall,
            ),
        ],
      ),
    );
  }
}

class _Commit extends StatelessWidget {
  const _Commit({super.key, required this.commit});

  final UpdateCommit commit;

  @override
  Widget build(BuildContext context) {
    final themeData = Theme.of(context);
    final meta = [
      if (commit.author.isNotEmpty) commit.author,
      if (commit.date case final date?) DateFormat.yMMMd().format(date),
      if (commit.sha.isNotEmpty) UpdaterInfoExtension.shortHash(commit.sha),
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              children: [
                if (commit.tag case final tag?)
                  TextSpan(
                    text: '$tag  ',
                    style: TextStyle(color: themeData.colorScheme.primary, fontWeight: FontWeight.bold),
                  ),
                TextSpan(text: commit.subject),
              ],
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: themeData.textTheme.bodyMedium,
          ),
          Text(meta, maxLines: 1, overflow: TextOverflow.ellipsis, style: themeData.textTheme.bodySmall),
        ],
      ),
    );
  }
}

/// Everything that is on its latest version, as one compact list.
class _UpToDateCard extends ConsumerWidget {
  const _UpToDateCard({
    super.key,
    required this.machineUUID,
    required this.updaters,
    required this.blocked,
    required this.isSupporter,
    this.updating,
  });

  final String machineUUID;
  final List<UpdaterInfo> updaters;
  final bool blocked;
  final bool isSupporter;

  /// The name of the software Moonraker is working on right now, e.g. one that is rolled back.
  final String? updating;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeData = Theme.of(context);
    final success = themeData.extension<CustomColors>()?.success ?? Colors.green;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (i, it) in updaters.indexed) ...[
            if (i > 0) const Divider(height: 1, indent: 12 + 36 + 14),
            ListTile(
              key: ValueKey(it.name),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              horizontalTitleGap: 14,
              leading: _Avatar(updater: it, size: 36),
              title: Text(updaterDisplayName(it), maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(
                [_versions(it).$1, ?_TypeLabel.text(it)].join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: AnimatedSwitcher(
                duration: kThemeAnimationDuration,
                child: it.name == updating
                    ? _ShowLogButton(key: const Key('showLog'), machineUUID: machineUUID)
                    : Icon(Icons.check_circle, key: const Key('upToDate'), size: 20, color: success),
              ),
              onTap: () => _showUpdaterActions(_containerOf(ref), machineUUID, it, blocked: blocked, isSupporter: isSupporter),
            ),
          ],
        ],
      ),
    );
  }
}

/// In place of a software's update button while Moonraker works on it: reopens the live log.
class _ShowLogButton extends ConsumerWidget {
  const _ShowLogButton({super.key, required this.machineUUID});

  final String machineUUID;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FilledButton.tonalIcon(
      onPressed: () => _showLog(_containerOf(ref), machineUUID),
      icon: const SizedBox.square(dimension: 14, child: CircularProgressIndicator(strokeWidth: 2)),
      label: const Text('pages.updates.busy.show_log').tr(),
    );
  }
}

/// Starts an update, recover or rollback and shows its live log.
void _start(
  ProviderContainer container,
  String machineUUID,
  Future<void> Function(UpdateProgress progress) action,
) {
  // Failures end up in the log.
  unawaited(action(container.read(updateProgressProvider(machineUUID).notifier)));
  _showLog(container, machineUUID);
}

void _showLog(ProviderContainer container, String machineUUID) {
  container.read(bottomSheetServiceProvider).show(BottomSheetConfig(type: SheetType.updateLog, data: machineUUID));
}

void _showSupporterOnly(ProviderContainer container, String bodyKey) {
  container.read(dialogServiceProvider).show(DialogRequest(type: DialogType.supporterOnlyFeature, body: tr(bodyKey)));
}

/// Asks how to repair the repo of [updater] and does it.
Future<void> _recover(
  ProviderContainer container,
  String machineUUID,
  UpdaterInfo updater, {
  required bool isSupporter,
}) async {
  final res = await container
      .read(bottomSheetServiceProvider)
      .show(BottomSheetConfig(type: SheetType.updateRecover, data: updater));
  // Free users only get to see the options.
  if (!res.confirmed || res.data is! bool || !isSupporter) return;

  _start(container, machineUUID, (it) => it.recover(updater.name, hard: res.data as bool));
}

/// Shows the actions of a software in a bottom sheet and executes the picked one.
Future<void> _showUpdaterActions(
  ProviderContainer container,
  String machineUUID,
  UpdaterInfo updater, {
  required bool blocked,
  required bool isSupporter,
}) async {
  final dialogService = container.read(dialogServiceProvider);
  final name = updaterDisplayName(updater);
  final repoUri = updater.repoUri;

  BottomSheetAction when(UpdaterSheetAction action, bool enabled) => enabled ? action : action.disable;

  final res = await container
      .read(bottomSheetServiceProvider)
      .show(
        BottomSheetConfig(
          type: SheetType.actions,
          data: ActionBottomSheetArgs(
            title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(
              [
                if (updater.fullVersionString.isNotEmpty) updater.fullVersionString else _versions(updater).$1,
                ?updater.branch,
              ].join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            leading: _Avatar(updater: updater, size: 33),
            actions: [
              when(UpdaterSheetAction.update, updater.canUpdate && !blocked),
              when(UpdaterSheetAction.refresh, !blocked),
              if (!updater.isSystem) ...[
                DividerSheetAction.divider,
                when(UpdaterSheetAction.rollback, updater.canRollback && !blocked),
                if (updater.canRecover) when(UpdaterSheetAction.recover, !blocked),
              ],
              if (repoUri != null) ...[DividerSheetAction.divider, UpdaterSheetAction.openRepo],
            ],
          ),
        ),
      );
  if (!res.confirmed) return;

  switch (res.data) {
    case UpdaterSheetAction.update:
      _start(container, machineUUID, (it) => it.upgrade(updater.name));
    case UpdaterSheetAction.refresh:
      await _refresh(container, machineUUID, updater.name);
    case UpdaterSheetAction.rollback:
      if (!isSupporter) return _showSupporterOnly(container, 'components.supporter_only_feature.update_rollback');
      final confirm = await dialogService.showConfirm(
        title: tr('pages.updates.rollback_dialog.title', args: [name]),
        body: tr('pages.updates.rollback_dialog.body', args: [name, updater.rollbackVersion]),
        actionLabel: tr('pages.updates.actions.rollback'),
      );
      if (confirm?.confirmed != true) return;
      _start(container, machineUUID, (it) => it.rollback(updater.name));
    case UpdaterSheetAction.recover:
      await _recover(container, machineUUID, updater, isSupporter: isSupporter);
    case UpdaterSheetAction.openRepo:
      if (repoUri != null) await launchUrl(repoUri, mode: LaunchMode.externalApplication);
  }
}
