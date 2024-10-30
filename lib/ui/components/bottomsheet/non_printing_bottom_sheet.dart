/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:auto_size_text/auto_size_text.dart';
import 'package:common/service/app_router.dart';
import 'package:common/service/moonraker/klippy_service.dart';
import 'package:common/service/ui/bottom_sheet_service_interface.dart';
import 'package:common/ui/bottomsheet/confirmation_bottom_sheet.dart';
import 'package:common/ui/theme/theme_pack.dart';
import 'package:common/util/logger.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/service/ui/bottom_sheet_service_impl.dart';
import 'package:mobileraker_pro/service/ui/pro_sheet_type.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'non_printing_bottom_sheet.g.dart';

class NonPrintingBottomSheet extends ConsumerWidget {
  const NonPrintingBottomSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(_nonPrintingBottomSheetControllerProvider.notifier);

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
                      onPressed: () => controller.onPressButton('pi_shutdown'),
                      onLongPress: () => controller.onPressButton('pi_shutdown', false),
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
                      onPressed: () => controller.onPressButton('pi_restart'),
                      onLongPress: () => controller.onPressButton('pi_restart', false),
                      child: AutoSizeText(tr('general.restart'), maxLines: 1),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            OutlinedButton(
              onPressed: () => controller.onPressButton('fw_restart'),
              onLongPress: () => controller.onPressButton('fw_restart', false),
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
                  onPressed: () => context.pop(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

@riverpod
class _NonPrintingBottomSheetController extends _$NonPrintingBottomSheetController {
  GoRouter get router => ref.read(goRouterProvider);

  KlippyService get klippyService => ref.read(klipperServiceSelectedProvider);

  @override
  void build() {}

  void onPressButton(String type, [bool requireConfirm = true]) async {
    var performAction = !requireConfirm;
    if (requireConfirm) {
      final confirmed = await router.pushNamed(
        SheetType.confirm.name,
        extra: ConfirmationBottomSheetArgs(
          title: tr('bottom_sheets.non_printing.confirm_action.title'),
          description: tr('bottom_sheets.non_printing.confirm_action.body', gender: type),
          hint: tr('bottom_sheets.non_printing.confirm_action.hint.long_press'),
        ),
      );
      performAction = performAction || confirmed == true;
    }
    if (!performAction) return;
    switch (type) {
      case 'pi_shutdown':
        klippyService.shutdownHost();
        break;
      case 'pi_restart':
        klippyService.rebootHost();
        break;
      case 'fw_restart':
        klippyService.restartMCUs();
        break;
      default:
        logger.e('Unknown type: $type');
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => router.pop());
  }
}
