/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/dto/server/klipper_system_info.dart';
import 'package:common/data/dto/server/service_status.dart';
import 'package:common/exceptions/mobileraker_exception.dart';
import 'package:common/network/jrpc_client_provider.dart';
import 'package:common/network/json_rpc_client.dart';
import 'package:common/service/moonraker/klipper_system_service.dart';
import 'package:common/service/moonraker/klippy_service.dart';
import 'package:common/service/ui/bottom_sheet_service_interface.dart';
import 'package:common/ui/components/async_button_.dart';
import 'package:common/ui/components/simple_error_widget.dart';
import 'package:common/ui/theme/theme_pack.dart';
import 'package:common/util/misc.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker_pro/service/ui/pro_sheet_type.dart';

class NonPrintingBottomSheet extends StatefulHookConsumerWidget {
  const NonPrintingBottomSheet({super.key});

  @override
  ConsumerState<NonPrintingBottomSheet> createState() => _NonPrintingBottomSheetState();
}

class _NonPrintingBottomSheetState extends ConsumerState<NonPrintingBottomSheet> {
  final GlobalKey _homeKey = GlobalKey();

  double _sheetHeight = 300;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _sheetHeight = _determineHeight());
    ref.listenManual(jrpcClientStateSelectedProvider, (previous, next) {
      if (next.valueOrNull != ClientState.connected) {
        // Close the bottom sheet if the client is disconnected
        Navigator.of(context).pop();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    var page = useState(0);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(25, 15, 25, 10),
        child: AnimatedSize(
          duration: kThemeAnimationDuration,
          curve: Curves.easeInOut,
          alignment: Alignment.bottomCenter,
          child: (page.value == 0)
              ? _Home(key: _homeKey, pageController: page)
              : _ManageServices(key: const Key('npMs'), defaultHeight: _sheetHeight, pageController: page),
        ),
      ),
    );
  }

  double _determineHeight() {
    if (_homeKey.currentContext != null) {
      final RenderBox renderBox = _homeKey.currentContext!.findRenderObject() as RenderBox;
      return renderBox.size.height;
    }
    return _sheetHeight;
  }
}

class _Home extends HookConsumerWidget {
  const _Home({super.key, required this.pageController});

  final ValueNotifier<int> pageController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var klippyService = ref.read(klipperServiceSelectedProvider);

    var themeData = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              flex: 5,
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _btnAction(context, klippyService.shutdownHost),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: themeData.extension<CustomColors>()?.danger ?? Colors.red,
                    foregroundColor: themeData.extension<CustomColors>()?.onDanger ?? Colors.white,
                  ),
                  child: const Text('general.shutdown').tr(),
                ),
              ),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 10),
              child: Icon(
                FlutterIcons.raspberry_pi_faw5d,
                color: themeData.colorScheme.onBackground,
              ),
            ),
            Flexible(
              flex: 5,
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    backgroundColor: themeData.extension<CustomColors>()?.warning ?? Colors.red,
                    foregroundColor: themeData.extension<CustomColors>()?.onWarning ?? Colors.white,
                  ),
                  onPressed: _btnAction(context, klippyService.rebootHost),
                  child: const Text('general.restart').tr(),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        OutlinedButton(
          onPressed: _btnAction(context, klippyService.restartMCUs),
          child: Text(
            '${tr('general.firmware')} ${tr('@.lower:general.restart')}',
          ),
        ),
        OutlinedButton(
          onPressed: () => pageController.value = 1,
          child: const Text('bottom_sheets.non_printing.manage_service.title').tr(),
        ),
        // OutlinedButton(
        //   onPressed: _btnAction(context, klippyService.restartMoonraker),
        //   child: Text('Moonraker ${tr('@.lower:general.restart')}'),
        // ),
        OutlinedButton(
          onPressed: () => ref
              .read(bottomSheetServiceProvider)
              .show(BottomSheetConfig(type: ProSheetType.jobQueueMenu, isScrollControlled: true)),
          child: const Text('dialogs.supporter_perks.job_queue_perk.title').tr(),
        ),

        /// Dont strech the button
        Align(
          child: FilledButton.icon(
            label: Text(MaterialLocalizations.of(context).closeButtonTooltip),
            icon: const Icon(Icons.keyboard_arrow_down),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
      ],
    );
  }

  VoidCallback _btnAction(BuildContext ctx, VoidCallback toCall) {
    return () {
      Navigator.of(ctx).pop();
      toCall();
    };
  }
}

class _ManageServices extends ConsumerWidget {
  const _ManageServices({super.key, required this.defaultHeight, required this.pageController});

  final double defaultHeight;

  final ValueNotifier<int> pageController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var systemInfo = ref.watch(selectedKlipperSystemInfoProvider);

    var shouldConstraint = false;
    if (systemInfo
        case (AsyncLoading(hasValue: false) ||
                AsyncValue(hasValue: true, value: KlipperSystemInfo(availableServices: []))) ||
            AsyncError()) {
      shouldConstraint = true;
    }

    var column = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: switch (systemInfo) {
            AsyncValue(hasValue: true, :final value?) => _ServiceList(systemInfo: value),
            AsyncLoading() => const Center(
                child: CircularProgressIndicator.adaptive(),
              ),
            AsyncError(:final error) => Center(child: _SystemInfoProviderError(error: error)),
            _ => const SizedBox.shrink(),
          },
        ),
        FilledButton.icon(
          label: Text(MaterialLocalizations.of(context).backButtonTooltip),
          icon: const Icon(Icons.keyboard_arrow_left),
          onPressed: () => pageController.value = 0,
        ),
      ],
    );
    return shouldConstraint
        ? ConstrainedBox(
            constraints: BoxConstraints.tightFor(height: defaultHeight),
            child: column,
          )
        : column;
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

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('bottom_sheets.non_printing.manage_service.title',
                style: themeData.textTheme.titleLarge, textAlign: TextAlign.center)
            .tr(),
        Flexible(
          child: ListView(
            // key: const PageStorageKey('npMsList'),
            restorationId: 'npMsList',
            shrinkWrap: true,
            // mainAxisSize: MainAxisSize.min,
            children: [
              //
              // for (var i = 0; i < 10; i++)
              //   Row(
              //     children: [
              //       Expanded(child: Text('Test-$i', style: Theme.of(context).textTheme.labelLarge)),
              //       IconButton(onPressed: () => null, icon: Icon(Icons.restart_alt)),
              //       IconButton(onPressed: () => null, icon: Icon(Icons.stop)),
              //     ],
              //   ),

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
                        onPressed: () => klippyService.startService(entry.value.name),
                        icon: const Icon(Icons.play_arrow),
                        color: themeData.extension<CustomColors>()?.success ?? Colors.green,
                        tooltip: tr('general.start'),
                      ),
                    if (entry.value.activeState != ServiceState.inactive)
                      AsyncIconButton(
                        onPressed: () => klippyService.restartService(entry.value.name),
                        icon: const Icon(Icons.restart_alt),
                        color: themeData.colorScheme.primary,
                        tooltip: tr('general.restart'),
                      ),
                    AsyncIconButton(
                      onPressed: (entry.value.activeState != ServiceState.active)
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
          ),
        ),
      ],
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

class FullWidthButton extends StatelessWidget {
  final VoidCallback? onPressed;

  final Widget child;

  final ButtonStyle? buttonStyle;

  const FullWidthButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.buttonStyle,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onPressed,
        style: buttonStyle,
        child: child,
      ),
    );
  }
}
