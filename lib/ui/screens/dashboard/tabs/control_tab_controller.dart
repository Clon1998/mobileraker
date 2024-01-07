/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:math';

import 'package:common/data/dto/config/config_gcode_macro.dart';
import 'package:common/data/dto/config/config_output.dart';
import 'package:common/data/dto/config/led/config_dumb_led.dart';
import 'package:common/data/dto/config/led/config_led.dart';
import 'package:common/data/dto/machine/fans/named_fan.dart';
import 'package:common/data/dto/machine/fans/print_fan.dart';
import 'package:common/data/dto/machine/leds/dumb_led.dart';
import 'package:common/data/dto/machine/leds/led.dart';
import 'package:common/data/dto/machine/output_pin.dart';
import 'package:common/service/moonraker/printer_service.dart';
import 'package:common/service/setting_service.dart';
import 'package:common/service/ui/dialog_service_interface.dart';
import 'package:common/util/misc.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/service/ui/dialog_service_impl.dart';
import 'package:mobileraker/ui/components/dialog/edit_form/num_edit_form_controller.dart';
import 'package:mobileraker/ui/components/dialog/led_rgbw/led_rgbw_dialog_controller.dart';

final controlTabControllerProvider = StateNotifierProvider.autoDispose<ControlTabController, void>(
  (ref) => ControlTabController(ref),
);

class ControlTabController extends StateNotifier<void> {
  ControlTabController(this.ref)
      : printerService = ref.watch(printerServiceSelectedProvider),
        super(null);

  final AutoDisposeRef ref;
  final PrinterService printerService;

  onExtruderSelected(int? idx) {
    if (idx != null) printerService.activateExtruder(idx);
  }

  onMacroPressed(String name, ConfigGcodeMacro? configGcodeMacro) async {
    if (configGcodeMacro != null && configGcodeMacro.params.isNotEmpty) {
      DialogResponse? response = await ref.read(dialogServiceProvider).show(
            DialogRequest(type: DialogType.gcodeParams, data: configGcodeMacro),
          );

      if (response?.confirmed == true) {
        var paramsMap = response!.data as Map<String, String>;

        var paramStr = paramsMap.keys
            .where((e) => paramsMap[e]!.trim().isNotEmpty)
            .map((e) => '${e.toUpperCase()}=${paramsMap[e]}')
            .join(" ");
        printerService.gCode('$name $paramStr');
      }
    } else {
      HapticFeedback.selectionClick();
      printerService.gCode(name);
    }
  }

  onMacroLongPressed(String name) {
    HapticFeedback.vibrate();
    printerService.gCode(name);
  }

  onEditPartFan(PrintFan d) {
    ref
        .read(dialogServiceProvider)
        .show(DialogRequest(
          type: ref.read(settingServiceProvider).readBool(AppSettingKeys.defaultNumEditMode)
              ? DialogType.numEdit
              : DialogType.rangeEdit,
          title: 'Edit Part Cooling fan %',
          cancelBtn: tr('general.cancel'),
          confirmBtn: tr('general.confirm'),
          data: NumberEditDialogArguments(
            current: d.speed * 100.round(),
            min: 0,
            max: 100,
          ),
        ))
        .then((value) {
      if (value != null && value.confirmed && value.data != null) {
        num v = value.data;
        printerService.partCoolingFan(v.toDouble() / 100);
      }
    });
  }

  onEditGenericFan(NamedFan namedFan) {
    ref
        .read(dialogServiceProvider)
        .show(DialogRequest(
          type: ref.read(settingServiceProvider).readBool(AppSettingKeys.defaultNumEditMode)
              ? DialogType.numEdit
              : DialogType.rangeEdit,
          title: 'Edit ${beautifyName(namedFan.name)} %',
          cancelBtn: tr('general.cancel'),
          confirmBtn: tr('general.confirm'),
          data: NumberEditDialogArguments(
            current: namedFan.speed * 100.round(),
            min: 0,
            max: 100,
          ),
        ))
        .then((value) {
      if (value != null && value.confirmed && value.data != null) {
        num v = value.data;
        printerService.genericFanFan(namedFan.name, v.toDouble() / 100);
      }
    });
  }

  onEditPin(OutputPin pin, ConfigOutput? configOutput) {
    int fractionToShow = (configOutput == null || !configOutput.pwm) ? 0 : 2;

    ref
        .read(dialogServiceProvider)
        .show(DialogRequest(
          type: ref.read(settingServiceProvider).readBool(AppSettingKeys.defaultNumEditMode)
              ? DialogType.numEdit
              : DialogType.rangeEdit,
          title: 'Edit ${beautifyName(pin.name)} value!',
          cancelBtn: tr('general.cancel'),
          confirmBtn: tr('general.confirm'),
          data: NumberEditDialogArguments(
            current: pin.value * (configOutput?.scale ?? 1),
            min: 0,
            max: configOutput?.scale.toInt() ?? 1,
            fraction: fractionToShow,
          ),
        ))
        .then((value) {
      if (value != null && value.confirmed && value.data != null) {
        num v = value.data;
        printerService.outputPin(pin.name, v.toDouble());
      }
    });
  }

  onUpdateBinaryPin(OutputPin pin, bool uValue) {
    printerService.outputPin(pin.name, uValue ? 1 : 0);
  }

  onEditLed(Led led, ConfigLed? configLed) {
    if (configLed == null) return;

    String name = beautifyName(led.name);
    if (configLed.isSingleColor == true && configLed is ConfigDumbLed) {
      ref
          .read(dialogServiceProvider)
          .show(DialogRequest(
            type: ref.read(settingServiceProvider).readBool(AppSettingKeys.defaultNumEditMode)
                ? DialogType.numEdit
                : DialogType.rangeEdit,
            title: '${tr('general.edit')} $name %',
            cancelBtn: tr('general.cancel'),
            confirmBtn: tr('general.confirm'),
            data: NumberEditDialogArguments(
              current: (led as DumbLed).color.asList().reduce(max) * 100.round(),
              min: 0,
              max: 100,
            ),
          ))
          .then((value) {
        if (value != null && value.confirmed && value.data != null) {
          double v = (value.data as num).toInt() / 100;
          List<double> rgbw = [0, 0, 0, 0];
          if (configLed.hasRed) {
            rgbw[0] = v;
          } else if (configLed.hasGreen) {
            rgbw[1] = v;
          } else if (configLed.hasBlue) {
            rgbw[2] = v;
          } else if (configLed.hasWhite) {
            rgbw[3] = v;
          }

          printerService.led(led.name, Pixel.fromList(rgbw));
        }
      });
      return;
    }

    ref
        .read(dialogServiceProvider)
        .show(DialogRequest(
          type: DialogType.ledRGBW,
          data: LedRGBWDialogArgument(configLed, led),
        ))
        .then((value) {
      if (value != null && value.confirmed && value.data != null) {
        Color selectedColor = value.data;

        double white = 0;
        if (configLed.hasWhite && selectedColor.value == 0xFFFFFFFF) {
          white = 1;
        }

        Pixel pixel = Pixel.fromList([
          selectedColor.red / 255,
          selectedColor.green / 255,
          selectedColor.blue / 255,
          white,
        ]);

        printerService.led(led.name, pixel);
      }
    });
  }
}