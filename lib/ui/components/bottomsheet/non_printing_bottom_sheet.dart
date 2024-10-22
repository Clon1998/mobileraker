/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:async';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:common/service/moonraker/klippy_service.dart';
import 'package:common/service/ui/bottom_sheet_service_interface.dart';
import 'package:common/ui/bottomsheet/confirmation_bottom_sheet.dart';
import 'package:common/ui/theme/theme_pack.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/service/ui/bottom_sheet_service_impl.dart';
import 'package:mobileraker_pro/service/ui/pro_sheet_type.dart';

class NonPrintingBottomSheet extends ConsumerWidget {
  const NonPrintingBottomSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var klippyService = ref.watch(klipperServiceSelectedProvider);

    var themeData = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(25, 15, 25, 0),
        child: Column(
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
                      onPressed: () => _btnActionWithConfirm(context, klippyService.shutdownHost, 'pi_shutdown'),
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
                      onPressed: () => _btnActionWithConfirm(context, klippyService.rebootHost, 'pi_restart'),
                      onLongPress: _btnAction(context, klippyService.rebootHost),
                      child: AutoSizeText(tr('general.restart'), maxLines: 1),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            OutlinedButton(
              onPressed: () => _btnActionWithConfirm(context, klippyService.restartMCUs, 'fw_restart'),
              onLongPress: _btnAction(context, klippyService.restartMCUs),
              child: AutoSizeText('${tr('general.firmware')} ${tr('@.lower:general.restart')}', maxLines: 1),
            ),
            OutlinedButton(
              onPressed: () => context.pushNamed(SheetType.manageMachineServices.name),
              // onPressed: () => pageController.value = 1,
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
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Align(
                child: TextButton.icon(
                  label: Text(MaterialLocalizations.of(context).closeButtonTooltip),
                  icon: const Icon(Icons.keyboard_arrow_down),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _btnActionWithConfirm(BuildContext context, VoidCallback toCall, [String? gender]) async {
    final result = await context.pushNamed(
      SheetType.confirm.name,
      extra: ConfirmationBottomSheetArgs(
        title: tr('bottom_sheets.non_printing.confirm_action.title'),
        description: tr('bottom_sheets.non_printing.confirm_action.body', gender: gender),
        hint: tr('bottom_sheets.non_printing.confirm_action.hint.long_press'),
      ),
    );

    if (result == true) {
      _btnAction(context, toCall);
    }
  }

  VoidCallback _btnAction(BuildContext ctx, VoidCallback toCall) {
    return () {
      ctx.pop();
      toCall();
    };
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
