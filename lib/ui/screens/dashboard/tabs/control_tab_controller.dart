/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:math';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/data/dto/config/config_gcode_macro.dart';
import 'package:mobileraker/data/dto/config/config_output.dart';
import 'package:mobileraker/data/dto/config/led/config_dumb_led.dart';
import 'package:mobileraker/data/dto/config/led/config_led.dart';
import 'package:mobileraker/data/dto/machine/fans/named_fan.dart';
import 'package:mobileraker/data/dto/machine/fans/print_fan.dart';
import 'package:mobileraker/data/dto/machine/leds/dumb_led.dart';
import 'package:mobileraker/data/dto/machine/leds/led.dart';
import 'package:mobileraker/data/dto/machine/output_pin.dart';
import 'package:mobileraker/service/moonraker/printer_service.dart';
import 'package:mobileraker/service/setting_service.dart';
import 'package:mobileraker/service/ui/dialog_service.dart';
import 'package:mobileraker/ui/components/dialog/edit_form/num_edit_form_controller.dart';
import 'package:mobileraker/ui/components/dialog/led_rgbw/led_rgbw_dialog_controller.dart';
import 'package:mobileraker/ui/screens/dashboard/dashboard_controller.dart';
import 'package:mobileraker/util/extensions/async_ext.dart';
import 'package:mobileraker/util/misc.dart';

final controlTabControllerProvider =
    StateNotifierProvider.autoDispose<ControlTabController, void>(
        (ref) => ControlTabController(ref));

class ControlTabController extends StateNotifier<void> {
  ControlTabController(this.ref)
      : printerService = ref.watch(printerServiceSelectedProvider),
        super(null);

  final AutoDisposeRef ref;
  final PrinterService printerService;

  onEditedSpeedMultiplier(double perc) {
    printerService.speedMultiplier((perc * 100).toInt());
  }

  onEditedFlowMultiplier(double perc) {
    printerService.flowMultiplier((perc * 100).toInt());
  }

  onEditedPressureAdvanced(double perc) {
    printerService.pressureAdvance(perc);
  }

  onEditedSmoothTime(double perc) {
    printerService.smoothTime(perc);
  }

  onEditedMaxVelocity(double vel) {
    printerService.setVelocityLimit(vel.toInt());
  }

  onEditedMaxAccel(double accel) {
    printerService.setAccelerationLimit(accel.toInt());
  }

  onEditedMaxAccelToDecel(double accelToDecel) {
    printerService.setAccelToDecel(accelToDecel.toInt());
  }

  onEditedMaxSquareCornerVelocity(double scv) {
    printerService.setSquareCornerVelocityLimit(scv);
  }

  onExtruderSelected(int? idx) {
    if (idx != null) printerService.activateExtruder(idx);
  }

  onMacroPressed(String name, ConfigGcodeMacro? configGcodeMacro) async {
    if (configGcodeMacro != null && configGcodeMacro.params.isNotEmpty) {
      DialogResponse? response = await ref.read(dialogServiceProvider).show(
          DialogRequest(type: DialogType.gcodeParams, data: configGcodeMacro));

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

  onMacroLongPressed(String name) async {
    HapticFeedback.vibrate();
    printerService.gCode(name);
  }

  onEditPartFan(PrintFan d) {
    ref
        .read(dialogServiceProvider)
        .show(DialogRequest(
            type:
                ref.read(settingServiceProvider).readBool(useTextInputForNumKey)
                    ? DialogType.numEdit
                    : DialogType.rangeEdit,
            title: 'Edit Part Cooling fan %',
            cancelBtn: tr('general.cancel'),
            confirmBtn: tr('general.confirm'),
            data: NumberEditDialogArguments(
                current: d.speed * 100.round(), min: 0, max: 100)))
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
            type:
                ref.read(settingServiceProvider).readBool(useTextInputForNumKey)
                    ? DialogType.numEdit
                    : DialogType.rangeEdit,
            title: 'Edit ${beautifyName(namedFan.name)} %',
            cancelBtn: tr('general.cancel'),
            confirmBtn: tr('general.confirm'),
            data: NumberEditDialogArguments(
                current: namedFan.speed * 100.round(), min: 0, max: 100)))
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
            type:
                ref.read(settingServiceProvider).readBool(useTextInputForNumKey)
                    ? DialogType.numEdit
                    : DialogType.rangeEdit,
            title: 'Edit ${beautifyName(pin.name)} value!',
            cancelBtn: tr('general.cancel'),
            confirmBtn: tr('general.confirm'),
            data: NumberEditDialogArguments(
                current: pin.value * (configOutput?.scale ?? 1),
                min: 0,
                max: configOutput?.scale.toInt() ?? 1,
                fraction: fractionToShow)))
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
              type: ref
                      .read(settingServiceProvider)
                      .readBool(useTextInputForNumKey)
                  ? DialogType.numEdit
                  : DialogType.rangeEdit,
              title: '${tr('general.edit')} $name %',
              cancelBtn: tr('general.cancel'),
              confirmBtn: tr('general.confirm'),
              data: NumberEditDialogArguments(
                  current:
                      (led as DumbLed).color.asList().reduce(max) * 100.round(),
                  min: 0,
                  max: 100)))
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
            data: LedRGBWDialogArgument(
              configLed,
              led,
            )))
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
          white
        ]);


        printerService.led(led.name, pixel);
      }
    });
  }
}

final extruderControlCardControllerProvider =
    StateNotifierProvider.autoDispose<ExtruderControlCardController, int>(
        (ref) {
  ref.keepAlive();
  return ExtruderControlCardController(ref);
});

class ExtruderControlCardController extends StateNotifier<int> {
  ExtruderControlCardController(this.ref)
      : printerService = ref.watch(printerServiceSelectedProvider),
        super(0);

  final AutoDisposeRef ref;
  final PrinterService printerService;

  List<int> get steps => ref
      .watch(machinePrinterKlippySettingsProvider
          .selectAs((value) => value.settings.extrudeSteps))
      .valueOrFullNull!;

  double get extruderFeedrate => ref
      .watch(machinePrinterKlippySettingsProvider
          .selectAs((value) => value.settings.extrudeFeedrate.toDouble()))
      .valueOrFullNull!;

  stepChanged(int idx) => state = idx;

  onRetractBtn() {
    printerService.moveExtruder(steps[state].toDouble() * -1, extruderFeedrate);
  }

  onExtrudeBtn() {
    printerService.moveExtruder(steps[state].toDouble(), extruderFeedrate);
  }
}

// class ControlTabViewModel extends MultipleStreamViewModel
//     with SelectedMachineMixin, PrinterMixin, KlippyMixin, MachineSettingsMixin {
//   final _dialogService = locator<DialogService>();
//   final _settingService = locator<SettingService>();
//
//
//   bool multipliersLocked = true;
//
//   bool limitsLocked = true;
//
//   int selectedIndexRetractLength = 0;
//
//   int get activeExtruder {
//     String? activeIdx = printerData.toolhead.activeExtruder?.substring(8);
//     if (activeIdx != null) return int.tryParse(activeIdx) ?? 0;
//     return 0;
//   }
//
//   MacroGroup? _selectedGrp;
//
//   MacroGroup? get selectedGrp {
//     if (machineSettings.macroGroups.isNotEmpty) {
//       int idx = min(machineSettings.macroGroups.length - 1,
//           max(0, _settingService.readInt(selectedGCodeGrpIndex, 0)));
//       _selectedGrp = machineSettings.macroGroups[idx];
//       return _selectedGrp;
//     }
//     return null;
//   }
//
//   set selectedGrp(MacroGroup? grp) => _selectedGrp = grp;
//
//   ScrollController get fansScrollController => _fansScrollController;
//   ScrollController _fansScrollController = new ScrollController(
//     keepScrollOffset: true,
//   );
//
//   ScrollController get outputsScrollController => _outputsScrollController;
//   ScrollController _outputsScrollController = new ScrollController(
//     keepScrollOffset: true,
//   );
//
//   List<int> get retractLengths => machineSettings.extrudeSteps;
//
//   int get fansSteps => 1 + printerData.fans.length;
//
//   int get outputSteps => printerData.outputPins.length;
//
//   List<MacroGroup> get macroGroups => machineSettings.macroGroups;
//
//   double get flowMultiplier => printerData.gCodeMove.extrudeFactor;
//
//   double get speedMultiplier => printerData.gCodeMove.speedFactor;
//
//   double get pressureAdvanced => printerData.extruder.pressureAdvance;
//
//   double get smoothTime => printerData.extruder.smoothTime;
//
//   double get maxVelocity => printerData.toolhead.maxVelocity ?? 0;
//
//   double get maxAccel => printerData.toolhead.maxAccel ?? 0;
//
//   double get maxAccelToDecel => printerData.toolhead.maxAccelToDecel ?? 0;
//
//   double get squareCornerVelocity =>
//       printerData.toolhead.squareCornerVelocity ?? 0;
//
//   double get extruderMinTemp => (printerData.configFile
//           .extruderForIndex(activeExtruder)
//           ?.minExtrudeTemp ??
//       170);
//
//   bool get extruderCanExtrude =>
//       printerData.extruderFromIndex(activeExtruder).temperature >=
//       extruderMinTemp;
//
//   Set<NamedFan> get filteredFans => printerData.fans
//       .where((NamedFan element) => !element.name.startsWith('_'))
//       .toSet();
//
//   Set<OutputPin> get filteredPins => printerData.outputPins
//       .where((OutputPin element) => !element.name.startsWith('_'))
//       .toSet();
//
//   bool get isDataReady =>
//       isSelectedMachineReady &&
//       isPrinterDataReady &&
//       isKlippyInstanceReady &&
//       isMachineSettingsReady;
//
//   ConfigOutput? configForOutput(String name) {
//     return printerData.configFile.outputs[name];
//   }
//
//   onToggleMultipliersLock() {
//     multipliersLocked = !multipliersLocked;
//     notifyListeners();
//   }
//
//   onToggleLimitLock() {
//     limitsLocked = !limitsLocked;
//     notifyListeners();
//   }
//
//   onEditPin(OutputPin pin, ConfigOutput? configOutput) {
//     int fractionToShow = (configOutput == null || !configOutput.pwm) ? 0 : 2;
//
//     numberOrRangeDialog(
//             dialogService: _dialogService,
//             settingService: _settingService,
//             title: 'Edit ${beautifyName(pin.name)} value!',
//             mainButtonTitle: 'Confirm',
//             secondaryButtonTitle: 'Cancel',
//             data: NumberEditDialogArguments(
//                 max: configOutput?.scale.toInt() ?? 1,
//                 currentLayer: pin.value * (configOutput?.scale ?? 1),
//                 fraction: fractionToShow))
//         .then((value) {
//       if (value != null && value.confirmed && value.data != null) {
//         num v = value.data;
//         printerService.outputPin(pin.name, v.toDouble());
//       }
//     });
//   }
//
//   onEditPartFan() {
//     numberOrRangeDialog(
//             dialogService: _dialogService,
//             settingService: _settingService,
//             title: 'Edit Part Cooling fan %',
//             mainButtonTitle: 'Confirm',
//             secondaryButtonTitle: 'Cancel',
//             data: NumberEditDialogArguments(
//                 max: 100, currentLayer: printerData.printFan.speed * 100.round()))
//         .then((value) {
//       if (value != null && value.confirmed && value.data != null) {
//         num v = value.data;
//         printerService.partCoolingFan(v.toDouble() / 100);
//       }
//     });
//   }
//
//   onEditGenericFan(NamedFan namedFan) {
//     numberOrRangeDialog(
//             dialogService: _dialogService,
//             settingService: _settingService,
//             title: 'Edit ${beautifyName(namedFan.name)} %',
//             mainButtonTitle: 'Confirm',
//             secondaryButtonTitle: 'Cancel',
//             data: NumberEditDialogArguments(
//                 max: 100, currentLayer: namedFan.speed * 100.round()))
//         .then((value) {
//       if (value != null && value.confirmed && value.data != null) {
//         num v = value.data;
//         printerService.genericFanFan(namedFan.name, v.toDouble() / 100);
//       }
//     });
//   }
//
//   onSelectedRetractChanged(int index) {
//     selectedIndexRetractLength = index;
//   }
//
//   onRetractBtn() {
//     var double = (retractLengths[selectedIndexRetractLength] * -1).toDouble();
//
//     printerService.moveExtruder(
//         double, machineSettings.extrudeFeedrate.toDouble());
//   }
//
//   onDeRetractBtn() {
//     var double = (retractLengths[selectedIndexRetractLength]).toDouble();
//     printerService.moveExtruder(
//         double, machineSettings.extrudeFeedrate.toDouble());
//   }
//
//   onMacroPressed(GCodeMacro macro) {
//     printerService.gCode(macro.name);
//   }
//
//   onMacroGroupSelected(MacroGroup? macroGroup) {
//     if (macroGroup != null)
//       _settingService.writeInt(
//           selectedGCodeGrpIndex, macroGroups.indexOf(macroGroup));
//     selectedGrp = macroGroup;
//   }
//
//   onExtruderSelected(int? idx) {
//     if (idx != null) printerService.activateExtruder(idx);
//   }
//
//   @override
//   dispose() {
//     super.dispose();
//     _fansScrollController.dispose();
//     _outputsScrollController.dispose();
//   }
// }
