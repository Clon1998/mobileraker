/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/dto/server/klipper_system_info.dart';
import 'package:common/data/dto/server/service_status.dart';
import 'package:common/exceptions/mobileraker_exception.dart';
import 'package:common/service/moonraker/klipper_system_service.dart';
import 'package:common/service/moonraker/klippy_service.dart';
import 'package:common/ui/animation/animated_size_and_fade.dart';
import 'package:common/ui/bottomsheet/confirmation_bottom_sheet.dart';
import 'package:common/ui/components/async_button_.dart';
import 'package:common/ui/components/simple_error_widget.dart';
import 'package:common/ui/theme/theme_pack.dart';
import 'package:common/util/misc.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:smooth_sheets/smooth_sheets.dart';

import '../../../service/ui/bottom_sheet_service_impl.dart';

class ManageServicesBottomSheet extends ConsumerWidget {
  const ManageServicesBottomSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var systemInfo = ref.watch(selectedKlipperSystemInfoProvider);

    if (systemInfo
        case (AsyncLoading(hasValue: false) ||
                AsyncValue(hasValue: true, value: KlipperSystemInfo(availableServices: []))) ||
            AsyncError()) {}

    final title = PreferredSize(
      preferredSize: const Size.fromHeight(kToolbarHeight),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // const Gap(10),
          ListTile(
            visualDensity: VisualDensity.compact,
            title: const Text('bottom_sheets.non_printing.manage_service.title').tr(),
          ),
        ],
      ),
    );

    final body = switch (systemInfo) {
      AsyncValue(hasValue: true, :final value?) => _ServiceList(
          key: const Key('systemInfoReady'),
          systemInfo: value,
        ),
      AsyncLoading() => const SizedBox(
          key: Key('systemInfoLoading'),
          height: 140,
          child: Center(child: CircularProgressIndicator.adaptive()),
        ),
      AsyncError(:final error) =>
        SheetDraggable(key: const Key('systemInfoError'), child: _SystemInfoProviderError(error: error)),
      _ => const SizedBox.shrink(),
    };

    return SheetContentScaffold(
      appBar: title,
      body: AnimatedSizeAndFade(child: body),
      bottomBar: StickyBottomBarVisibility(
        child: Theme(
          data: Theme.of(context).copyWith(useMaterial3: false),
          child: BottomAppBar(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (ModalRoute.of(context)?.impliesAppBarDismissal == true)
                  TextButton.icon(
                    label: Text(MaterialLocalizations.of(context).backButtonTooltip),
                    icon: const Icon(Icons.keyboard_arrow_left),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                if (ModalRoute.of(context)?.impliesAppBarDismissal != true)
                  TextButton.icon(
                    label: Text(MaterialLocalizations.of(context).closeButtonTooltip),
                    icon: const Icon(Icons.keyboard_arrow_down),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ServiceList extends ConsumerWidget {
  const _ServiceList({super.key, required this.systemInfo});

  final KlipperSystemInfo systemInfo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var themeData = Theme.of(context);
    if (systemInfo.serviceState.isEmpty) {
      return Center(
        child: Text('bottom_sheets.non_printing.manage_service.no_services', style: themeData.textTheme.bodySmall).tr(),
      );
    }
    var klippyService = ref.read(klipperServiceSelectedProvider);

    return ListView(
      restorationId: 'npMsList',
      padding: const EdgeInsets.symmetric(horizontal: 25),
      shrinkWrap: true,
      // mainAxisSize: MainAxisSize.min,
      children: [
        for (var entry in systemInfo.serviceState.entries)
          Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(beautifyName(entry.value.name), style: themeData.textTheme.labelLarge),
                  ],
                ),
              ),
              if (entry.value.activeState != ServiceState.active)
                AsyncIconButton(
                  onPressed: () => _confirmation(
                      context, () => klippyService.startService(entry.value.name), 'service_start', entry.value.name),
                  onLongPressed: () => klippyService.startService(entry.value.name),
                  icon: const Icon(Icons.play_arrow),
                  color: themeData.extension<CustomColors>()?.success ?? Colors.green,
                  tooltip: tr('general.start'),
                ),
              if (entry.value.activeState != ServiceState.inactive)
                AsyncIconButton(
                  onPressed: () => _confirmation(context, () => klippyService.restartService(entry.value.name),
                      'service_restart', entry.value.name),
                  onLongPressed: () => klippyService.restartService(entry.value.name),
                  icon: const Icon(Icons.restart_alt),
                  color: themeData.colorScheme.primary,
                  tooltip: tr('general.restart'),
                ),
              AsyncIconButton(
                onPressed: (entry.value.activeState != ServiceState.active)
                    ? null
                    : () => _confirmation(
                        context, () => klippyService.stopService(entry.value.name), 'service_stop', entry.value.name),
                onLongPressed: (entry.value.activeState != ServiceState.active)
                    ? null
                    : () => klippyService.stopService(entry.value.name),
                icon: const Icon(Icons.stop),
                color: themeData.extension<CustomColors>()?.danger ?? Colors.red,
                tooltip: tr('general.stop'),
              ),
            ],
          ),

        // ListTile(
        //   subtitle: Text('State: ${entry.value.activeState}, SubState: ${entry.value.subState}'),
        // ),
      ],
    );
  }

  Future<void> _confirmation(BuildContext context, VoidCallback toCall, String action, String serviceName) async {
    final result = await context.pushNamed(
      SheetType.confirm.name,
      extra: ConfirmationBottomSheetArgs(
        title: tr('bottom_sheets.non_printing.confirm_action.title'),
        description: tr('bottom_sheets.non_printing.confirm_action.body', gender: action, args: [serviceName]),
        hint: tr('bottom_sheets.non_printing.confirm_action.hint.long_press'),
      ),
    );

    if (result == true) {
      toCall();
      // if (context.mounted) context.pop();
    }
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
