/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/dto/config/config_file.dart';
import 'package:common/data/dto/machine/bed_screw.dart';
import 'package:common/service/moonraker/printer_service.dart';
import 'package:common/service/ui/dialog_service_interface.dart';
import 'package:flutter/foundation.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:mobileraker/service/ui/dialog_service_impl.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'bed_screw_adjust_dialog_controller.freezed.dart';
part 'bed_screw_adjust_dialog_controller.g.dart';

@riverpod
class BedScrewAdjustDialogController extends _$BedScrewAdjustDialogController {
  bool _completed = false;

  @override
  Future<BedScrewAndConfig> build() async {
    // make sure we close the dialog once its resolved externally
    // also prevents opening the dialog by mistake!
    ref.listenSelf((previous, next) {
      if (next.valueOrNull?.bedScrew.isActive == false && !_completed) {
        _complete(DialogResponse.aborted());
      }
    });

    var bedScrew = await ref
        .watch(printerSelectedProvider.selectAsync((data) => data.bedScrew!));
    var config = await ref
        .watch(printerSelectedProvider.selectAsync((data) => data.configFile));

    // await Future.delayed(Duration(seconds: 4));

    return BedScrewAndConfig(bedScrew: bedScrew, config: config);
  }

  // ignore: avoid-unnecessary-futures
  Future<bool> onPopTriggered() async {
    onAbortPressed();
    return false;
  }

  onAbortPressed() {
    ref.read(printerServiceSelectedProvider).gCode('ABORT');
    _complete(DialogResponse.aborted());
  }

  onAcceptPressed() {
    ref.read(printerServiceSelectedProvider).gCode('ACCEPT');
  }

  onAdjustedPressed() {
    ref.read(printerServiceSelectedProvider).gCode('ADJUSTED');
  }

  _complete(DialogResponse response) {
    if (_completed == true) return;
    _completed = true;
    ref.read(dialogCompleterProvider)(response);
  }
}

@freezed
class BedScrewAndConfig with _$BedScrewAndConfig {
  const factory BedScrewAndConfig({
    required BedScrew bedScrew,
    required ConfigFile config,
  }) = _BedScrewAndConfig;
}
