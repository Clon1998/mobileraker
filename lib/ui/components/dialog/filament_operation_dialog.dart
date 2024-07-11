/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:math';

import 'package:common/data/dto/config/config_extruder.dart';
import 'package:common/data/model/moonraker_db/settings/machine_settings.dart';
import 'package:common/network/jrpc_client_provider.dart';
import 'package:common/network/json_rpc_client.dart';
import 'package:common/service/machine_service.dart';
import 'package:common/service/moonraker/printer_service.dart';
import 'package:common/service/ui/dialog_service_interface.dart';
import 'package:common/ui/animation/animated_size_and_fade.dart';
import 'package:common/ui/components/async_guard.dart';
import 'package:common/ui/dialog/mobileraker_dialog.dart';
import 'package:common/util/extensions/async_ext.dart';
import 'package:common/util/extensions/object_extension.dart';
import 'package:common/util/extensions/ref_extension.dart';
import 'package:common/util/logger.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/ui/components/range_edit_slider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'filament_operation_dialog.freezed.dart';
part 'filament_operation_dialog.g.dart';

enum _FilamentChangeSteps { setTemperature, heatUp, moveFilament, purgeFilament, tipForming }

const _loadingSteps = [
  _FilamentChangeSteps.setTemperature,
  _FilamentChangeSteps.heatUp,
  _FilamentChangeSteps.moveFilament,
  _FilamentChangeSteps.purgeFilament,
];

const _unloadingSteps = [
  _FilamentChangeSteps.setTemperature,
  _FilamentChangeSteps.heatUp,
  _FilamentChangeSteps.tipForming,
  _FilamentChangeSteps.moveFilament,
];

const Map<String, int> _presetMaterials = {
  'PLA': 210,
  'PETG': 230,
  'ABS': 245,
  'ASA': 260,
  'Nylon': 270,
  'PC': 280,
};

class FilamentOperationDialog extends HookWidget {
  final DialogRequest request;
  final DialogCompleter completer;

  const FilamentOperationDialog({
    super.key,
    required this.request,
    required this.completer,
  });

  FilamentOperationDialogArgs get args => request.data as FilamentOperationDialogArgs;

  @override
  Widget build(BuildContext context) {
    final themeData = Theme.of(context);
    return MobilerakerDialog(
      dismissText: tr('general.close'),
      onDismiss: () => completer(DialogResponse()),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            args.isLoad ? 'dialogs.filament_swtich.title_load' : 'dialogs.filament_swtich.title_unload',
            style: themeData.textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ).tr(),
          const SizedBox(height: 10),
          Flexible(
            child: AsyncGuard(
              animate: true,
              toGuard: _filamentOperationDialogControllerProvider(args, completer).selectAs((_) => true),
              childOnData: _Data(args: args, completer: completer),
              childOnLoading: const Center(child: CircularProgressIndicator.adaptive()),
            ),
          ),
        ],
      ),
    );
  }
}

class _Data extends ConsumerWidget {
  const _Data({super.key, required this.args, required this.completer});

  final FilamentOperationDialogArgs args;
  final DialogCompleter completer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final step =
        ref.watch(_filamentOperationDialogControllerProvider(args, completer).selectRequireValue((d) => d.step));
    final controller = ref.watch(_filamentOperationDialogControllerProvider(args, completer).notifier);

    final lookup = args.isLoad ? _loadingSteps : _unloadingSteps;

    return Stepper(
      currentStep: lookup.indexOf(step),
      controlsBuilder: (context, details) => _controlsBuilder(context, details, controller),
      steps: [
        for (final s in args.isLoad ? _loadingSteps : _unloadingSteps) _stepBuilder(currentStep: step, step: s),
      ],
    );
  }

  Widget _controlsBuilder(
      BuildContext context, ControlsDetails details, _FilamentOperationDialogController controller) {
    // Convert the current step to the enum to get the correct footer
    final stepEnum = args.isLoad ? _loadingSteps[details.stepIndex] : _unloadingSteps[details.stepIndex];

    return switch (stepEnum) {
      _FilamentChangeSteps.setTemperature => Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
                onPressed: details.isActive ? () => controller.moveToStep(_FilamentChangeSteps.heatUp) : null,
                child: const Text('Heat-Up')),
          ],
        ),
      _FilamentChangeSteps.heatUp => Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
                onPressed: details.isActive ? () => controller.moveToStep(_FilamentChangeSteps.setTemperature) : null,
                child: const Text('Change Temp')),
          ],
        ),
      _FilamentChangeSteps.moveFilament => Consumer(builder: (context, ref, child) {
          final movingFila = ref.watch(
              _filamentOperationDialogControllerProvider(args, completer).selectRequireValue((d) => d.movingFilament));

          Widget w = switch (movingFila) {
            false || true => Row(
                key: const Key('footer-moving-done'),
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                      onPressed: controller.moveFilament.only(details.isActive && movingFila != true),
                      child: Text(args.isLoad ? 'Repeat Load' : 'Repeat Unload')),
                  if (args.isLoad)
                    TextButton(
                        onPressed: details.isActive && movingFila == false
                            ? () => controller.moveToStep(_FilamentChangeSteps.purgeFilament)
                            : null,
                        child: const Text('Purge')),
                  if (!args.isLoad)
                    TextButton(
                        onPressed: details.isActive && movingFila == false
                            ? () => completer(DialogResponse.confirmed())
                            : null,
                        child: const Text('Finish')),
                ],
              ),
            _ => Row(
                key: const Key('footer-moving-init'),
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (args.isLoad)
                    TextButton(
                        onPressed: details.isActive && movingFila != true
                            ? () => controller.moveToStep(_FilamentChangeSteps.setTemperature)
                            : null,
                        child: const Text('Change Temp')),
                  TextButton(
                      onPressed: controller.moveFilament.only(details.isActive && movingFila != true),
                      child: Text(args.isLoad ? 'Load' : 'Unload')),
                ],
              ),
          };

          return AnimatedSizeAndFade(
            alignment: Alignment.centerRight,
            fadeDuration: kThemeAnimationDuration,
            sizeDuration: kThemeAnimationDuration,
            child: w,
          );
        }),
      _FilamentChangeSteps.purgeFilament => Consumer(builder: (context, ref, child) {
          final purging = ref.watch(
              _filamentOperationDialogControllerProvider(args, completer).selectRequireValue((d) => d.purgingFilament));

          return Row(
            key: const Key('footer-purging-done'),
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                  onPressed: controller.purgeFilament.only(details.isActive && purging != true),
                  child: const Text('Repeat Purge')),
              TextButton(
                  onPressed: details.isActive && purging == false ? () => completer(DialogResponse.confirmed()) : null,
                  child: const Text('Finish')),
            ],
          );
        }),
      _FilamentChangeSteps.tipForming => const LinearProgressIndicator(),
      _ => const SizedBox.shrink(),
    };
  }

  Step _stepBuilder({
    required _FilamentChangeSteps currentStep,
    required _FilamentChangeSteps step,
  }) {
    final lookup = args.isLoad ? _loadingSteps : _unloadingSteps;

    StepState state;
    if (step == currentStep) {
      state = StepState.editing;
    } else if (lookup.indexOf(currentStep) > lookup.indexOf(step)) {
      state = StepState.complete;
    } else {
      state = StepState.indexed;
    }

    return switch (step) {
      _FilamentChangeSteps.setTemperature => Step(
          title: const Text('Filament Temperature'),
          subtitle: const Text('Select target temperature'),
          state: state,
          content: _StepSetTemperature(args: args, completer: completer),
        ),
      _FilamentChangeSteps.heatUp => Step(
          title: const Text('Toolhead Heating'),
          subtitle: const Text('Heating up to target temperature'),
          state: state,
          content: _StepWaitHeatup(args: args, completer: completer),
        ),
      _FilamentChangeSteps.moveFilament => Step(
          title: Text(args.isLoad ? 'Load Filament' : 'Unload Filament'),
          subtitle: _subtitleMoving(),
          state: state,
          content: _StepMoveFilament(args: args, completer: completer),
        ),
      _FilamentChangeSteps.purgeFilament => Step(
          title: const Text('Purge Filament'),
          subtitle: _subtitlePurging(),
          state: state,
          content: _StepPurgeFilament(args: args, completer: completer),
        ),
      _FilamentChangeSteps.tipForming => Step(
          title: const Text('Tip Forming'),
          subtitle: const Text('Forming the tip of the filament'),
          state: state,
          content: const SizedBox(),
        ),
    };
  }

  Widget _subtitleMoving() {
    return Consumer(builder: (context, ref, child) {
      final movingFila = ref.watch(
          _filamentOperationDialogControllerProvider(args, completer).selectRequireValue((d) => d.movingFilament));
      Widget w = switch (movingFila) {
        true when args.isLoad => const Text('Loading filament...'),
        true => const Text('Unloading filament...'),
        false when args.isLoad => const Text('Did the filament reach the nozzle? Repeat if necessary.'),
        false => const Text('Did the filament come out of the extruder? Repeat if necessary.'),
        _ when args.isLoad => const Text('Insert filament into extruder'),
        _ => const Text('Move filament out of extruder'),
      };

      w = SizedBox(
        key: Key('movFila-$movingFila'),
        width: double.infinity,
        child: w,
      );

      const dur = kThemeAnimationDuration;
      return AnimatedSizeAndFade(
        alignment: Alignment.bottomLeft,
        fadeDuration: dur,
        sizeDuration: dur,
        child: w,
      );
    });
  }

  Widget _subtitlePurging() {
    return Consumer(builder: (context, ref, child) {
      final purgingFilament = ref.watch(
          _filamentOperationDialogControllerProvider(args, completer).selectRequireValue((d) => d.purgingFilament));
      Widget w = switch (purgingFilament) {
        true => const Text('Purging filament...'),
        false => const Text('Verify purged material is clean. Repeat if necessary.'),
        _ => const Text('Load filament into Nozzle'),
      };

      w = SizedBox(
        key: Key('purgFila-$purgingFilament'),
        width: double.infinity,
        child: w,
      );

      const dur = kThemeAnimationDuration;
      return AnimatedSizeAndFade(
        alignment: Alignment.bottomLeft,
        fadeDuration: dur,
        sizeDuration: dur,
        child: w,
      );
    });
  }
}

class _StepSetTemperature extends HookConsumerWidget {
  const _StepSetTemperature({super.key, required this.args, required this.completer});

  final FilamentOperationDialogArgs args;
  final DialogCompleter completer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final model = ref.watch(_filamentOperationDialogControllerProvider(args, completer).requireValue());
    final controller = ref.watch(_filamentOperationDialogControllerProvider(args, completer).notifier);

    final presets = _presetMaterials.entries
        .where((e) => e.value >= model.extruderConfig.minExtrudeTemp && e.value <= model.extruderConfig.maxTemp);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        RangeEditSlider(
          value: model.targetTemperature ?? 200,
          lowerLimit: model.extruderConfig.minExtrudeTemp,
          upperLimit: model.extruderConfig.maxTemp,
          onChanged: controller.updateTargetTemp,
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final material in presets) ...[
                ActionChip(
                  visualDensity: VisualDensity.compact,
                  onPressed: () => controller.updateTargetTemp(material.value),
                  label: Text(material.key),
                ),
                if (material != presets.last) const SizedBox(width: 8)
              ]
            ],
          ),
        ),
      ],
    );
  }
}

class _StepWaitHeatup extends ConsumerWidget {
  const _StepWaitHeatup({super.key, required this.args, required this.completer});

  final FilamentOperationDialogArgs args;
  final DialogCompleter completer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final model = ref.watch(_filamentOperationDialogControllerProvider(args, completer).requireValue());

    NumberFormat numberFormat = NumberFormat('0', context.locale.toStringWithSeparator());

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const Icon(FlutterIcons.printer_3d_nozzle_mco),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${numberFormat.format(model.extruderTemp)}/${numberFormat.format(model.targetTemperature)} °C'),
              SizedBox(height: 2),
              LinearProgressIndicator(
                value: model.extruderTemp / model.targetTemperature,
              )
            ],
          ),
        ),
      ],
    );
  }
}

class _StepMoveFilament extends ConsumerWidget {
  const _StepMoveFilament({super.key, required this.args, required this.completer});

  final FilamentOperationDialogArgs args;
  final DialogCompleter completer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final model = ref.watch(_filamentOperationDialogControllerProvider(args, completer).requireValue());
    final controller = ref.watch(_filamentOperationDialogControllerProvider(args, completer).notifier);

    return switch (model.movingFilament) {
      true => const LinearProgressIndicator(),
      _ => const LinearProgressIndicator(value: 0),
    };
  }
}

class _StepPurgeFilament extends ConsumerWidget {
  const _StepPurgeFilament({super.key, required this.args, required this.completer});

  final FilamentOperationDialogArgs args;
  final DialogCompleter completer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final model = ref.watch(
        _filamentOperationDialogControllerProvider(args, completer).selectRequireValue((d) => d.purgingFilament));

    return switch (model) {
      true => const LinearProgressIndicator(),
      _ => const LinearProgressIndicator(value: 0),
    };
  }
}

@riverpod
class _FilamentOperationDialogController extends _$FilamentOperationDialogController {
  PrinterService get _printerService => ref.read(printerServiceProvider(args.machineUUID));

  bool _closing = false;

  @override
  Stream<_Model> build(FilamentOperationDialogArgs args, DialogCompleter completer) async* {
    // Lets keep the provider for 30 sec
    // ref.keepAliveFor();

    final machineUUID = args.machineUUID;
    final extruderIndex = int.tryParse(args.extruder) ?? 0;

    ref.listen(
      jrpcClientStateProvider(machineUUID),
      (previous, next) {
        if (next.valueOrNull != ClientState.connected && !_closing) {
          logger.i('Lost connection to machine, will close filament dialog.');
          _closing = true;
          completer(DialogResponse.aborted());
        }
      },
    );

    ref.listenSelf((previous, next) {
      final modelPrevious = previous?.valueOrNull;
      final modelNext = next.valueOrNull;

      if (modelNext == null) return;

      if (modelPrevious?.step != modelNext.step && modelNext.step == _FilamentChangeSteps.heatUp) {
        logger.i('Set target temperature to ${next.valueOrNull!.targetTemperature}');
        _printerService.setHeaterTemperature(args.extruder, next.valueOrNull!.targetTemperature);
      } else if (modelNext.targetReached && modelNext.step == _FilamentChangeSteps.heatUp) {
        logger.i('Target reached, next step');
        if (args.isLoad) {
          moveToStep(_FilamentChangeSteps.moveFilament);
        } else {
          moveToStep(_FilamentChangeSteps.tipForming);
        }
      } else if (!args.isLoad &&
          modelPrevious?.step != _FilamentChangeSteps.tipForming &&
          modelNext.step == _FilamentChangeSteps.tipForming) {
        formTip();
      }
    });

    // await Future.delayed(Duration(seconds: 1));

    final settings = await ref.watch(machineSettingsProvider(machineUUID).future);

    final printerStream = ref.watchAsSubject(printerProvider(machineUUID));

    await for (final printer in printerStream) {
      final extruderConfig = printer.configFile.extruders[args.extruder];
      final extruderTemp = printer.extruders[extruderIndex].temperature;

      final model = state.valueOrNull;

      if (model == null) {
        yield _Model(extruderConfig: extruderConfig!, extruderTemp: extruderTemp, settings: settings);
      } else {
        yield model.copyWith(extruderConfig: extruderConfig!, extruderTemp: extruderTemp);
      }
    }
  }

  void moveToStep(_FilamentChangeSteps step) {
    final model = state.valueOrNull;
    if (model == null) return;
    state = AsyncValue.data(model.copyWith(step: step));

    if (step == _FilamentChangeSteps.purgeFilament) purgeFilament();
  }

  void updateTargetTemp(num temp) {
    final model = state.valueOrNull;
    if (model == null) return;
    state = AsyncValue.data(model.copyWith(targetTemperature: temp.toInt()));
  }

  void moveFilament() async {
    final model = state.valueOrNull;
    if (model == null) return;
    state = AsyncValue.data(model.copyWith(movingFilament: true));
    //TODO: Make this configurable
    final move = min(150, model.extruderConfig.maxExtrudeOnlyDistance);
    final veloc = min(15, model.extruderConfig.maxExtrudeOnlyVelocity);

    if (args.isLoad) {
      await _printerService.moveExtruder(move, veloc, true);
    } else {
      await _printerService.moveExtruder(-move, veloc, true);
    }

    state = AsyncValue.data(state.requireValue.copyWith(movingFilament: false));
  }

  void purgeFilament() async {
    final model = state.valueOrNull;
    if (model == null) return;
    state = AsyncValue.data(model.copyWith(purgingFilament: true));
    final move = min(15, model.extruderConfig.maxExtrudeOnlyDistance);
    final veloc = min(2.5, model.extruderConfig.maxExtrudeOnlyVelocity);
    await _printerService.moveExtruder(move, veloc, true);

    state = AsyncValue.data(state.requireValue.copyWith(purgingFilament: false));
  }

  Future<void> formTip() async {
    final model = state.valueOrNull;
    if (model == null) return;
    logger.i('Forming tip');

    final tipRetract = 18;

    //TODO: Speed should be configurable
    final endSpeed = 20 * 60;

    final gcode = '''
      SAVE_GCODE_STATE NAME=mr_unload_state
      M220 S100
	    G91
      G92 E0
      G1 E-${0.7 * tipRetract} F${(1.0 * endSpeed) ~/ 1}
      G1 E-${0.2 * tipRetract} F${(0.5 * endSpeed) ~/ 1}
      G1 E-${0.1 * tipRetract} F${(0.3 * endSpeed) ~/ 1}
      
      G92 E0
      G1 E${0.5 * tipRetract} F${(0.3 * endSpeed) ~/ 1}
      G1 E-${0.5 * tipRetract} F${(1 * endSpeed) ~/ 1}
      G1 E${0.5 * tipRetract} F${(0.3 * endSpeed) ~/ 1}
      G1 E-${0.5 * tipRetract} F${(1 * endSpeed) ~/ 1}
      
      M400
      RESTORE_GCODE_STATE NAME=mr_unload_state
    ''';
    await _printerService.gCode(gcode);
    await Future.delayed(const Duration(milliseconds: 1600));

    // Automatically move to next step
    state = AsyncValue.data(state.requireValue.copyWith(step: _FilamentChangeSteps.moveFilament));
    moveFilament();
  }
}

@freezed
class FilamentOperationDialogArgs with _$FilamentOperationDialogArgs {
  const factory FilamentOperationDialogArgs({
    required String machineUUID,
    required bool isLoad,
    required String extruder,
  }) = _FilamentOperationDialogArgs;
}

@freezed
class _Model with _$Model {
  const _Model._();

  const factory _Model({
    @Default(_FilamentChangeSteps.setTemperature) _FilamentChangeSteps step,
    required MachineSettings settings,
    required ConfigExtruder extruderConfig,
    @Default(200) int targetTemperature,
    required double extruderTemp,
    bool? movingFilament,
    bool? purgingFilament,
  }) = __Model;

  bool get targetReached => (extruderTemp + 1) >= targetTemperature;
}
