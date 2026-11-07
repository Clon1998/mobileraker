/*
 * Copyright (c) 2023-2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/dto/server/klipper_system_info.dart';
import 'package:common/data/dto/server/service_status.dart';
import 'package:common/exceptions/mobileraker_exception.dart';
import 'package:common/service/moonraker/klipper_system_service.dart';
import 'package:common/service/moonraker/klippy_service.dart';
import 'package:common/service/ui/bottom_sheet_service_interface.dart';
import 'package:common/ui/animation/animated_size_and_fade.dart';
import 'package:common/ui/bottomsheet/confirmation_bottom_sheet.dart';
import 'package:common/ui/components/async_button_.dart';
import 'package:common/ui/components/sheet_row.dart';
import 'package:common/ui/components/sheet_search_header.dart';
import 'package:common/ui/components/simple_error_widget.dart';
import 'package:common/ui/theme/theme_pack.dart';
import 'package:common/util/misc.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shimmer/shimmer.dart';
import 'package:smooth_sheets/smooth_sheets.dart';

import '../../../service/ui/bottom_sheet_service_impl.dart';

/// Services of the machine's host (Klipper, Moonraker, …) with their state and start/restart/stop. The actions ask for
/// confirmation, a long press skips it.
class ManageServicesBottomSheet extends ConsumerWidget {
  const ManageServicesBottomSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final systemInfo = ref.watch(selectedKlipperSystemInfoProvider);
    final count = systemInfo.value?.serviceState.length;

    final body = switch (systemInfo) {
      AsyncValue(hasValue: true, :final value?) => _ServiceList(key: const Key('systemInfoReady'), systemInfo: value),
      AsyncLoading() => const _ServiceListShimmer(key: Key('systemInfoLoading')),
      AsyncError(:final error) => _SystemInfoProviderError(key: const Key('systemInfoError'), error: error),
      _ => const SizedBox.shrink(),
    };

    return SheetContentScaffold(
      topBar: SheetSearchHeader(
        // Opened from the printer actions sheet: back to it
        leading: ModalRoute.of(context)?.impliesAppBarDismissal == true
            ? IconButton(
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                icon: const BackButtonIcon(),
                onPressed: context.pop,
              )
            : null,
        title: tr('bottom_sheets.non_printing.manage_service.title'),
        subtitle: count == null ? null : plural('bottom_sheets.non_printing.manage_service.available', count),
      ),
      body: AnimatedSizeAndFade(child: body),
    );
  }
}

class _ServiceList extends ConsumerWidget {
  const _ServiceList({super.key, required this.systemInfo});

  final KlipperSystemInfo systemInfo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeData = Theme.of(context);
    if (systemInfo.serviceState.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          'bottom_sheets.non_printing.manage_service.no_services',
          textAlign: TextAlign.center,
          style: themeData.textTheme.bodyMedium?.copyWith(color: themeData.colorScheme.onSurfaceVariant),
        ).tr(),
      );
    }
    final services = systemInfo.serviceState.values.toList();

    return ListView.separated(
      restorationId: 'npMsList',
      padding: SheetRow.listPadding(context),
      // Only a handful of services: the sheet fits them instead of taking the full height
      shrinkWrap: true,
      itemCount: services.length,
      separatorBuilder: (context, _) => SheetRow.separator(context),
      itemBuilder: (context, index) => _ServiceRow(key: ValueKey(services[index].name), service: services[index]),
    );
  }
}

class _ServiceRow extends ConsumerWidget {
  const _ServiceRow({super.key, required this.service});

  final ServiceStatus service;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeData = Theme.of(context);
    final colorScheme = themeData.colorScheme;
    final customColors = themeData.extension<CustomColors>();
    final klippyService = ref.watch(klipperServiceSelectedProvider);
    final name = service.name;
    final state = service.activeState;
    final failed = service.subState == 'failed';

    final (stateLabel, stateColor) = switch (state) {
      _ when failed => (tr('bottom_sheets.non_printing.manage_service.state.failed'), customColors?.danger ?? Colors.red),
      ServiceState.active => (
        tr('bottom_sheets.non_printing.manage_service.state.active'),
        customColors?.success ?? Colors.green,
      ),
      ServiceState.deactivating => (
        tr('bottom_sheets.non_printing.manage_service.state.deactivating'),
        customColors?.warning ?? Colors.orange,
      ),
      ServiceState.inactive => (
        tr('bottom_sheets.non_printing.manage_service.state.inactive'),
        colorScheme.onSurfaceVariant,
      ),
      ServiceState.unknown => (service.subState, colorScheme.onSurfaceVariant),
    };

    return SheetRow(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(beautifyName(name), style: themeData.textTheme.titleMedium),
                Text(stateLabel, style: themeData.textTheme.bodySmall?.copyWith(color: stateColor)),
              ],
            ),
          ),
          if (state != ServiceState.active)
            AsyncIconButton(
              onPressed: () => _confirmation(context, () => klippyService.startService(name), 'service_start', name),
              onLongPressed: () => klippyService.startService(name),
              icon: const Icon(Icons.play_arrow),
              color: customColors?.success ?? Colors.green,
              tooltip: tr('general.start'),
            ),
          if (state != ServiceState.inactive)
            AsyncIconButton(
              onPressed: () => _confirmation(context, () => klippyService.restartService(name), 'service_restart', name),
              onLongPressed: () => klippyService.restartService(name),
              icon: const Icon(Icons.restart_alt),
              color: colorScheme.primary,
              tooltip: tr('general.restart'),
            ),
          AsyncIconButton(
            onPressed: state != ServiceState.active
                ? null
                : () => _confirmation(context, () => klippyService.stopService(name), 'service_stop', name),
            onLongPressed: state != ServiceState.active ? null : () => klippyService.stopService(name),
            icon: const Icon(Icons.stop),
            color: customColors?.danger ?? Colors.red,
            tooltip: tr('general.stop'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmation(BuildContext context, VoidCallback toCall, String action, String serviceName) async {
    final result = await context.pushNamed<BottomSheetResult>(
      SheetType.confirm.name,
      extra: ConfirmationBottomSheetArgs(
        title: tr('bottom_sheets.non_printing.confirm_action.title'),
        description: tr('bottom_sheets.non_printing.confirm_action.body', gender: action, args: [serviceName]),
        hint: tr('bottom_sheets.non_printing.confirm_action.hint.long_press'),
      ),
    );

    if (result?.confirmed == true) toCall();
  }
}

class _ServiceListShimmer extends StatelessWidget {
  const _ServiceListShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    final themeData = Theme.of(context);
    return Shimmer.fromColors(
      baseColor: Colors.grey,
      highlightColor: themeData.colorScheme.background,
      child: Padding(
        padding: SheetRow.listPadding(context) + SheetRow.contentPadding(context).copyWith(top: 0, bottom: 0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 4; i++)
              SizedBox(
                height: 48,
                child: Row(
                  children: [
                    Expanded(
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: 0.4,
                        child: DecoratedBox(
                          decoration: const BoxDecoration(color: Colors.white),
                          child: Text(' ', style: themeData.textTheme.labelLarge),
                        ),
                      ),
                    ),
                    for (var j = 0; j < 2; j++)
                      const Padding(
                        padding: EdgeInsets.all(13),
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: DecoratedBox(decoration: BoxDecoration(color: Colors.white)),
                        ),
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

class _SystemInfoProviderError extends ConsumerWidget {
  const _SystemInfoProviderError({super.key, required this.error});

  final Object error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    String message = error.toString();
    var e = error;
    if (e is MobilerakerException) {
      // title = e.message;
      if (e.parentException != null) {
        message = e.parentException.toString();
      }
    }

    return SimpleErrorWidget(
      title: const Text('bottom_sheets.non_printing.manage_service.provider_error').tr(),
      body: Text(message),
      action: TextButton.icon(
        onPressed: () {
          ref.invalidate(selectedKlipperSystemInfoProvider);
        },
        icon: const Icon(Icons.restart_alt_outlined),
        label: const Text('general.retry').tr(),
      ),
    );
  }
}
