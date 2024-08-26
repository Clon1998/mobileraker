/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:async';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:common/data/dto/server/klipper_system_info.dart';
import 'package:common/data/dto/server/service_status.dart';
import 'package:common/exceptions/mobileraker_exception.dart';
import 'package:common/network/jrpc_client_provider.dart';
import 'package:common/network/json_rpc_client.dart';
import 'package:common/service/moonraker/klipper_system_service.dart';
import 'package:common/service/moonraker/klippy_service.dart';
import 'package:common/service/ui/bottom_sheet_service_interface.dart';
import 'package:common/ui/animation/animated_size_and_fade.dart';
import 'package:common/ui/components/async_button_.dart';
import 'package:common/ui/components/simple_error_widget.dart';
import 'package:common/ui/theme/theme_pack.dart';
import 'package:common/util/logger.dart';
import 'package:common/util/misc.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker_pro/service/ui/pro_sheet_type.dart';

class NonPrintingBottomSheet extends ConsumerStatefulWidget {
  const NonPrintingBottomSheet({super.key});

  @override
  ConsumerState<NonPrintingBottomSheet> createState() => _NonPrintingBottomSheetState();
}

typedef _ShowConfirmAction = void Function(String title, String body, VoidCallback action, [String? hint]);

class _NonPrintingBottomSheetState extends ConsumerState<NonPrintingBottomSheet> {
  final GlobalKey _homeKey = GlobalKey();

  final ValueNotifier<int> _page = ValueNotifier(0);

  double _sheetHeight = 300;

  bool _closing = false;

  String _confirmTitle = '';

  String _confirmBody = '';

  VoidCallback? _confirmAction;

  String? _confirmHint;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _sheetHeight = _determineHeight());
    ref.listenManual(jrpcClientStateSelectedProvider, (previous, next) {
      if (next.valueOrNull != ClientState.connected) {
        // Close the bottom sheet if the client is disconnected
        if (mounted && !_closing) {
          logger.i('Closing bottom sheet because client is disconnected');
          Navigator.of(context).pop();
          _closing = true;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    const animDuration = kThemeAnimationDuration;
    // final animDuration = const Duration(milliseconds: 5000);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(25, 15, 25, 10),
        child: ValueListenableBuilder(
          valueListenable: _page,
          builder: (ctx, value, _) => AnimatedSizeAndFade(
            sizeDuration: animDuration,
            fadeDuration: animDuration,
            sizeCurve: Curves.easeInOut,
            fadeInCurve: Curves.easeInOut,
            fadeOutCurve: Curves.easeInOut,
            alignment: Alignment.bottomCenter,
            child: switch (value) {
              1 => _ManageServices(
                  key: const Key('npMs'),
                  defaultHeight: _sheetHeight,
                  pageController: _page,
                  showConfirm: _showConfirm,
                ),
              2 => _Confirm(
                  key: const Key('npConfirm'),
                  pageController: _page,
                  title: _confirmTitle,
                  body: _confirmBody,
                  hint: _confirmHint,
                  action: _confirmAction!,
                ),
              _ => _Home(key: _homeKey, pageController: _page, showConfirm: _showConfirm),
            },
          ),
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

  void _showConfirm(String title, String body, VoidCallback action, [String? hint]) {
    setState(() {
      _confirmTitle = title;
      _confirmBody = body;
      _confirmHint = hint;
      _confirmAction = action;
      _page.value = 2;
    });
  }

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }
}

class _Home extends ConsumerWidget {
  const _Home({super.key, required this.pageController, required _ShowConfirmAction showConfirm})
      : _showConfirm = showConfirm;

  final ValueNotifier<int> pageController;

  final _ShowConfirmAction _showConfirm;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var klippyService = ref.watch(klipperServiceSelectedProvider);

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
                  onPressed: () => _btnActionWithConfirm(klippyService.shutdownHost, 'pi_shutdown'),
                  onLongPress: _btnAction(context, klippyService.shutdownHost),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: themeData.extension<CustomColors>()?.danger ?? Colors.red,
                    foregroundColor: themeData.extension<CustomColors>()?.onDanger ?? Colors.white,
                  ),
                  child: AutoSizeText(tr('general.shutdown'), maxLines: 1),
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
                  onPressed: () => _btnActionWithConfirm(klippyService.rebootHost, 'pi_restart'),
                  onLongPress: _btnAction(context, klippyService.rebootHost),
                  child: AutoSizeText(tr('general.restart'), maxLines: 1),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        OutlinedButton(
          onPressed: () => _btnActionWithConfirm(klippyService.restartMCUs, 'fw_restart'),
          onLongPress: _btnAction(context, klippyService.restartMCUs),
          child: AutoSizeText('${tr('general.firmware')} ${tr('@.lower:general.restart')}', maxLines: 1),
        ),
        OutlinedButton(
          onPressed: () => pageController.value = 1,
          child: AutoSizeText(
            tr('bottom_sheets.non_printing.manage_service.title'),
            maxLines: 1,
          ),
        ),
        // OutlinedButton(
        //   onPressed: _btnAction(context, klippyService.restartMoonraker),
        //   child: Text('Moonraker ${tr('@.lower:general.restart')}'),
        // ),
        OutlinedButton(
          onPressed: () => ref
              .read(bottomSheetServiceProvider)
              .show(BottomSheetConfig(type: ProSheetType.jobQueueMenu, isScrollControlled: true)),
          child: AutoSizeText(
            tr('dialogs.supporter_perks.job_queue_perk.title'),
            maxLines: 1,
          ),
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

  Future<void> _btnActionWithConfirm(VoidCallback toCall, [String? gender]) async {
    _showConfirm(
      tr('bottom_sheets.non_printing.confirm_action.title'),
      tr('bottom_sheets.non_printing.confirm_action.body', gender: gender),
      toCall,
      tr('bottom_sheets.non_printing.confirm_action.hint.long_press'),
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
  const _ManageServices(
      {super.key, required this.defaultHeight, required this.pageController, required _ShowConfirmAction showConfirm})
      : _showConfirm = showConfirm;

  final double defaultHeight;

  final ValueNotifier<int> pageController;

  final _ShowConfirmAction _showConfirm;

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
            AsyncValue(hasValue: true, :final value?) => _ServiceList(
                systemInfo: value,
                showConfirm: _showConfirm,
              ),
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
  const _ServiceList({super.key, required this.systemInfo, required _ShowConfirmAction showConfirm})
      : _showConfirm = showConfirm;

  final KlipperSystemInfo systemInfo;

  final _ShowConfirmAction _showConfirm;

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

  void _confirmation(String service, String kind, VoidCallback action) {
    _showConfirm(
      tr('bottom_sheets.non_printing.confirm_action.title'),
      tr('bottom_sheets.non_printing.confirm_action.body', gender: 'service_$kind', args: [service]),
      action,
      tr('bottom_sheets.non_printing.confirm_action.hint.long_press'),
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

class _Confirm extends ConsumerWidget {
  const _Confirm({
    super.key,
    required this.pageController,
    required this.title,
    required this.body,
    required this.action,
    this.hint,
  });

  final ValueNotifier<int> pageController;

  final String title;

  final String body;

  final String? hint;

  final VoidCallback action;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var themeData = Theme.of(context);
    var cc = themeData.extension<CustomColors>();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: themeData.textTheme.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 5),
        Text(body, style: themeData.textTheme.titleSmall),
        const SizedBox(height: 10),
        if (hint != null) Text(hint!, style: themeData.textTheme.bodySmall, textAlign: TextAlign.center),

        /// Dont strech the button
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            FilledButton.icon(
              onPressed: () => pageController.value = 0,
              label: Text(MaterialLocalizations.of(context).cancelButtonLabel),
              icon: const Icon(Icons.keyboard_arrow_left),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: cc?.danger, foregroundColor: cc?.onDanger),
              onPressed: () => _onConfirm(context),
              child: const Text('general.confirm').tr(),
            ),
          ],
        ),
      ],
    );
  }

  _onConfirm(BuildContext ctx) {
    action();
    ctx.pop();
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
