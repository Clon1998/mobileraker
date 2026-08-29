/*
 * Copyright (c) 2023-2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:async';

import 'package:common/data/dto/machine/manual_probe.dart';
import 'package:common/service/moonraker/printer_service.dart';
import 'package:common/service/ui/dialog_service_interface.dart';
import 'package:common/service/ui/snackbar_service_interface.dart';
import 'package:common/util/extensions/ref_extension.dart';
import 'package:common/util/logger.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
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
    listenSelf((previous, next) {
      if (next.value?.isActive == false && !_completed) {
        talker.info('Dialog closed externally since manual_probe is not active anymore!');
        _complete(DialogResponse.confirmed());
        _onExternallyCompleted();
      }
    });

    return ref.watch(printerSelectedProvider.selectAsync((data) => data.manualProbe!));
  }

  void onOffsetPlusPressed(double step) {
    ref.read(printerServiceSelectedProvider).gCode('TESTZ Z=${step.abs().toStringAsFixed(3)}');
  }

  void onOffsetMinusPressed(double step) {
    ref.read(printerServiceSelectedProvider).gCode('TESTZ Z=-${step.abs().toStringAsFixed(3)}');
  }

  // ignore: avoid-unnecessary-futures
  Future<bool> onPopTriggered() async {
    onAbortPressed();
    return false;
  }

  void onAbortPressed() {
    _complete(DialogResponse.aborted());
    ref.read(printerServiceSelectedProvider).gCode('ABORT');
  }

  void onAcceptPressed() {
    ref.read(printerServiceSelectedProvider).gCode('ACCEPT');
  }

  void onHelpPressed() {
    String klipperPaperTest = 'https://www.klipper3d.org/Bed_Level.html#the-paper-test';
    launchUrlString(klipperPaperTest, mode: LaunchMode.externalApplication);
  }

  void _complete(DialogResponse response) {
    if (_completed == true) return;
    _completed = true;
    completer(response);
  }

  Future<void> _onExternallyCompleted() async {

    // Once the dialog above closes, nothing watches this controller anymore and it would
    // normally autodispose immediately - which would pause our keepAliveExternally
    // subscription below and let printerServiceSelectedProvider die right away, well before
    // the snackbar (and its "Save Config" button) actually closes. keepAliveFor keeps this
    // controller itself alive for the snackbar's duration so that doesn't happen.
    final ownLink = ref.keepAlive();
    ProviderSubscription<PrinterService>? printerServiceLink;
    try {
       printerServiceLink = ref.keepAliveExternally(printerServiceSelectedProvider);
      final printerService = printerServiceLink.read();

      final snackController = ref
          .read(snackBarServiceProvider)
          .show(
        SnackBarConfig(
          duration: const Duration(seconds: 30),
          title: tr('dialogs.manual_offset.snackbar_title'),
          message: tr('dialogs.manual_offset.snackbar_message'),
          mainButtonTitle: 'Save_Config',
          closeOnMainButtonTapped: true,
          onMainButtonTapped: printerService.saveConfig,
        ),
      );

      await snackController?.closed;
    } catch (e, st) {
      talker.error('Error while showing snackbar after manual offset dialog closed', e, st);
    } finally {
      printerServiceLink?.close();
      ownLink.close();
    }
  }
}
