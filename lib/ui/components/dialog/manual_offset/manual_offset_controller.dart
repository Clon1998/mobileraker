/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/dto/machine/manual_probe.dart';
import 'package:common/service/moonraker/printer_service.dart';
import 'package:common/service/ui/dialog_service_interface.dart';
import 'package:common/service/ui/snackbar_service_interface.dart';
import 'package:common/util/logger.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:url_launcher/url_launcher_string.dart';

part 'manual_offset_controller.g.dart';

@riverpod
class ManualOffsetDialogController extends _$ManualOffsetDialogController {
  late DialogCompleter completer;

  bool _completed = false;

  @override
  Future<ManualProbe> build(DialogCompleter dialogCompleter) async {
    completer = dialogCompleter;
    // make sure we close the dialog once its resolved externally
    // also prevents opening the dialog by mistake!
    ref.listenSelf((previous, next) {
      if (next.valueOrNull?.isActive == false && !_completed) {
        logger.i(
          'Dialog closed externally since manual_probe is not active anymore!',
        );
        _complete(DialogResponse.confirmed());
        ref.read(snackBarServiceProvider).show(SnackBarConfig(
              duration: const Duration(seconds: 30),
              title: tr('dialogs.manual_offset.snackbar_title'),
              message: tr('dialogs.manual_offset.snackbar_message'),
              mainButtonTitle: 'Save_Config',
              closeOnMainButtonTapped: true,
              onMainButtonTapped: ref.read(printerServiceSelectedProvider).saveConfig,
            ));
      }
    });

    return ref.watch(
      printerSelectedProvider.selectAsync((data) => data.manualProbe!),
    );
  }

  onOffsetPlusPressed(double step) {
    ref
        .read(printerServiceSelectedProvider)
        .gCode('TESTZ Z=${step.abs().toStringAsFixed(3)}');
  }

  onOffsetMinusPressed(double step) {
    ref
        .read(printerServiceSelectedProvider)
        .gCode('TESTZ Z=-${step.abs().toStringAsFixed(3)}');
  }

  // ignore: avoid-unnecessary-futures
  Future<bool> onPopTriggered() async {
    onAbortPressed();
    return false;
  }

  onAbortPressed() {
    _complete(DialogResponse.aborted());
    ref.read(printerServiceSelectedProvider).gCode('ABORT');
  }

  onAcceptPressed() {
    ref.read(printerServiceSelectedProvider).gCode('ACCEPT');
  }

  onHelpPressed() {
    String klipperPaperTest =
        'https://www.klipper3d.org/Bed_Level.html#the-paper-test';
    launchUrlString(klipperPaperTest, mode: LaunchMode.externalApplication);
  }

  _complete(DialogResponse response) {
    if (_completed == true) return;
    _completed = true;
    completer(response);
  }
}
