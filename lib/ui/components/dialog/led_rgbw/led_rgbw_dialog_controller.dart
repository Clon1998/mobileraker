/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/dto/config/led/config_led.dart';
import 'package:common/data/dto/machine/leds/addressable_led.dart';
import 'package:common/data/dto/machine/leds/dumb_led.dart';
import 'package:common/data/dto/machine/leds/led.dart';
import 'package:common/service/setting_service.dart';
import 'package:common/service/ui/dialog_service_interface.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:mobileraker/service/ui/dialog_service_impl.dart';
import 'package:mobileraker/util/extensions/pixel_extension.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'led_rgbw_dialog_controller.freezed.dart';
part 'led_rgbw_dialog_controller.g.dart';

class LedRGBWDialogArgument {
  final ConfigLed configLed;
  final Led ledData;

  const LedRGBWDialogArgument(this.configLed, this.ledData);
}

final dialogArgsProvider = Provider.autoDispose<LedRGBWDialogArgument>(
  name: 'LedRGBWDialogArgumentProvider',
  (ref) {
    throw UnimplementedError();
  },
);

@freezed
class LedRGBWDialogState with _$LedRGBWDialogState {
  const LedRGBWDialogState._();

  const factory LedRGBWDialogState({
    required Color selectedColor,
    required List<Color> recentColors,
    required ConfigLed ledConfig,
  }) = _LedRGBWDialogState;
}

@riverpod
class LedRGBWDialogController extends _$LedRGBWDialogController {
  @override
  LedRGBWDialogState build() {
    LedRGBWDialogArgument args = ref.watch(dialogArgsProvider);

    Led ledData = args.ledData;
    Pixel pixel;
    if (ledData is AddressableLed) {
      pixel = (ledData.pixels.isEmpty) ? const Pixel() : ledData.pixels.first;
    } else if (ledData is DumbLed) {
      pixel = ledData.color;
    } else {
      throw ArgumentError(
        'Unknown Led data type provided: ${ledData.runtimeType}',
      );
    }
    SettingService settingService = ref.watch(settingServiceProvider);
    List<Color> recentColors = settingService
        .readList<String>(UtilityKeys.recentColors)
        .map((e) => colorFromHex(e, enableAlpha: false))
        .whereType<Color>()
        .toList(); // Removes null values
    if (recentColors.isEmpty) {
      recentColors = [Colors.white, Colors.black];
    }

    return LedRGBWDialogState(
      selectedColor: pixel.rgbColor,
      recentColors: recentColors,
      ledConfig: args.configLed,
    );
  }

  onColorChange(Color c) {
    return state = state.copyWith(selectedColor: c);
  }

  onCancel() {
    return ref.read(dialogCompleterProvider)(DialogResponse.aborted());
  }

  onSubmit() {
    SettingService settingService = ref.watch(settingServiceProvider);
    var recentColors =
        state.recentColors.where((element) => element != state.selectedColor);
    var list = [state.selectedColor, ...recentColors.take(9)]
        .map((e) => e.hexCode)
        .toList();
    settingService.writeList(UtilityKeys.recentColors, list);

    ref.read(dialogCompleterProvider)(
      DialogResponse.confirmed(state.selectedColor),
    );
  }
}
