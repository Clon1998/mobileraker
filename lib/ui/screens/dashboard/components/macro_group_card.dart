/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:math';

import 'package:collection/collection.dart';
import 'package:common/data/dto/config/config_gcode_macro.dart';
import 'package:common/data/dto/machine/print_state_enum.dart';
import 'package:common/data/model/moonraker_db/gcode_macro.dart';
import 'package:common/data/model/moonraker_db/macro_group.dart';
import 'package:common/service/machine_service.dart';
import 'package:common/service/moonraker/klippy_service.dart';
import 'package:common/service/moonraker/printer_service.dart';
import 'package:common/service/setting_service.dart';
import 'package:common/service/ui/dialog_service_interface.dart';
import 'package:common/ui/components/skeletons/card_title_skeleton.dart';
import 'package:common/util/extensions/async_ext.dart';
import 'package:common/util/extensions/ref_extension.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:rxdart/rxdart.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../service/ui/dialog_service_impl.dart';
import '../../../animation/SizeAndFadeTransition.dart';

part 'macro_group_card.freezed.dart';
part 'macro_group_card.g.dart';

class MacroGroupCard extends ConsumerWidget {
  const MacroGroupCard({super.key, required this.machineUUID});

  final String machineUUID;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var showCard = ref.watch(_macroGroupCardControllerProvider(machineUUID).selectAs((data) => data.showCard));
    var showLoading = showCard.isLoading && !showCard.isReloading;

    if (showLoading) return const _MacroGroupLoading();
    if (showCard.valueOrNull != true) return const SizedBox.shrink();

    return Card(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _CardTitle(machineUUID: machineUUID),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15),
            child: _SelectedGroup(machineUUID: machineUUID),
          ),
        ],
      ),
    );
  }
}

class _MacroGroupLoading extends StatelessWidget {
  const _MacroGroupLoading({super.key});

  @override
  Widget build(BuildContext context) {
    var themeData = Theme.of(context);
    return Card(
      child: Shimmer.fromColors(
        baseColor: Colors.grey,
        highlightColor: themeData.colorScheme.background,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CardTitleSkeleton.trailingText(),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 15),
              child: Wrap(
                spacing: 5,
                alignment: WrapAlignment.spaceEvenly,
                children: [
                  Chip(label: SizedBox(width: 40), backgroundColor: Colors.white),
                  Chip(label: SizedBox(width: 58), backgroundColor: Colors.white),
                  Chip(label: SizedBox(width: 76), backgroundColor: Colors.white),
                  Chip(label: SizedBox(width: 94), backgroundColor: Colors.white),
                  Chip(label: SizedBox(width: 12), backgroundColor: Colors.white),
                  Chip(label: SizedBox(width: 30), backgroundColor: Colors.white),
                  Chip(label: SizedBox(width: 48), backgroundColor: Colors.white),
                  Chip(label: SizedBox(width: 66), backgroundColor: Colors.white),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CardTitle extends ConsumerWidget {
  const _CardTitle({super.key, required this.machineUUID});

  final String machineUUID;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var controller = ref.watch(_macroGroupCardControllerProvider(machineUUID).notifier);
    var model = ref.watch(_macroGroupCardControllerProvider(machineUUID)).requireValue;

    return ListTile(
      leading: const Icon(FlutterIcons.code_braces_mco),
      title: const Text('pages.dashboard.control.macro_card.title').tr(),
      trailing: (model.groups.length > 1)
          ? DropdownButton(
              value: model.selected,
              items: model.groups
                  .mapIndexed((index, element) => DropdownMenuItem(
                        value: index,
                        child: Text(element.name),
                      ))
                  .toList(),
              onChanged: controller.onDropDownChanged,
            )
          : null,
    );
  }
}

class _SelectedGroup extends ConsumerWidget {
  const _SelectedGroup({super.key, required this.machineUUID});

  final String machineUUID;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var isPrinting =
        ref.watch(_macroGroupCardControllerProvider(machineUUID).selectAs((data) => data.isPrinting)).valueOrNull ==
            true;
    var groupProvider = _macroGroupCardControllerProvider(machineUUID)
        .selectAs((value) => value.groups.elementAtOrNull(value.selected));
    var group = ref.watch(groupProvider).valueOrNull;

    if (group == null) return const Text('No group found');

    return AnimatedSwitcher(
      // duration: Duration(seconds: 2),
      duration: kThemeAnimationDuration,
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, anim) => SizeAndFadeTransition(
        sizeAxisAlignment: 1,
        sizeAndFadeFactor: anim,
        child: child,
      ),
      // The column is required to make it stretch
      child: group.hasMacros(isPrinting)
          ? Column(
              key: ValueKey(group.uuid),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceEvenly,
                  spacing: 5,
                  children: [
                    for (var macro in group.macros) _MacroChip(machineUUID: machineUUID, macro: macro),
                  ],
                ),
              ],
            )
          : Center(
              key: ValueKey(group.uuid),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 10.0),
                child: Text(
                  'pages.dashboard.control.macro_card.no_macros',
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ).tr(),
              ),
            ),
    );
  }
}

class _MacroChip extends ConsumerWidget {
  const _MacroChip({super.key, required this.machineUUID, required this.macro});

  final String machineUUID;
  final GCodeMacro macro;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var controller = ref.watch(_macroGroupCardControllerProvider(machineUUID).notifier);

    // Test if the macro is available on the printer
    ConfigGcodeMacro? configMacro = ref
        .watch(_macroGroupCardControllerProvider(machineUUID).selectAs((data) => data.configMacros[macro.configName]))
        .valueOrNull;

    var klippyCanReceiveCommands = ref
            .watch(_macroGroupCardControllerProvider(machineUUID).selectAs((data) => data.klippyCanReceiveCommands))
            .valueOrNull ??
        false;

    var isPrinting =
        ref.watch(_macroGroupCardControllerProvider(machineUUID).selectAs((data) => data.isPrinting)).valueOrNull ??
            false;

    var themeData = Theme.of(context);
    var enabled = klippyCanReceiveCommands;
    return Visibility(
      visible: configMacro != null && macro.visible && (!isPrinting || macro.showWhilePrinting),
      child: GestureDetector(
        onLongPress: enabled ? () => controller.onMacroLongPressed(configMacro!) : null,
        child: ActionChip(
          onPressed: enabled ? () => controller.onMacroPressed(configMacro!) : null,
          label: Text(macro.beautifiedName),
          labelStyle: TextStyle(
            color: enabled ? themeData.colorScheme.onPrimary : themeData.colorScheme.onSurface.withOpacity(0.38),
          ),
          backgroundColor: themeData.colorScheme.primary,
        ),
      ),
    );
  }
}

@riverpod
class _MacroGroupCardController extends _$MacroGroupCardController {
  SettingService get _settingService => ref.read(settingServiceProvider);

  DialogService get _dialogService => ref.read(dialogServiceProvider);

  PrinterService get _printerService => ref.read(printerServiceProvider(machineUUID));

  KeyValueStoreKey get _settingsKey => CompositeKey.keyWithString(UtilityKeys.gCodeIndex, machineUUID);

  @override
  Stream<_Model> build(String machineUUID) async* {
    ref.keepAliveFor();
    // Keep the printerService alive while this controller is alive
    ref.keepAliveExternally(printerServiceProvider(machineUUID));

    var klippyCanReceiveCommands = ref.watchAsSubject(
      klipperProvider(machineUUID).selectAs((value) => value.klippyCanReceiveCommands),
    );
    var isPrinting = ref.watchAsSubject(
      printerProvider(machineUUID).selectAs((data) => data.print.state == PrintState.printing),
    );

    var groups = ref.watchAsSubject(
      machineSettingsProvider(machineUUID).selectAs((data) => data.macroGroups),
    );

    var configMacros = ref.watchAsSubject(
      printerProvider(machineUUID).selectAs((data) => data.configFile.gcodeMacros),
    );

    var initialIndex = _settingService.readInt(_settingsKey, 0);

    yield* Rx.combineLatest4(klippyCanReceiveCommands, groups, configMacros, isPrinting, (a, b, c, d) {
      var idx = state.whenData((value) => value.selected).valueOrNull ?? initialIndex;
      return _Model(
        klippyCanReceiveCommands: a,
        isPrinting: d,
        groups: b,
        selected: min(b.length - 1, max(0, idx)),
        configMacros: c,
      );
    });
  }

  void onDropDownChanged(int? index) {
    if (index == null) return;
    state = state.whenData((value) => value.copyWith(selected: index));
    _settingService.writeInt(_settingsKey, index);
  }

  onMacroPressed(ConfigGcodeMacro macro) async {
    var alwaysConfirm = _settingService.readBool(AppSettingKeys.confirmMacroExecution, false);

    if (macro.params.isNotEmpty || alwaysConfirm) {
      DialogResponse? response = await _dialogService.show(
        DialogRequest(type: DialogType.gcodeParams, data: macro),
      );

      if (response?.confirmed == true) {
        var paramsMap = response!.data as Map<String, String>;

        var paramStr = paramsMap.keys
            .where((e) => paramsMap[e]!.trim().isNotEmpty)
            .map((e) => '${e.toUpperCase()}=${paramsMap[e]}')
            .join(' ');
        _printerService.gCode('${macro.macroName} $paramStr');
      }
    } else {
      HapticFeedback.selectionClick();
      _printerService.gCode(macro.macroName);
    }
  }

  onMacroLongPressed(ConfigGcodeMacro macro) {
    HapticFeedback.vibrate();
    _printerService.gCode(macro.macroName);
  }
}

@freezed
class _Model with _$Model {
  const _Model._();

  const factory _Model({
    required bool klippyCanReceiveCommands,
    required bool isPrinting,
    required int selected,
    required List<MacroGroup> groups,
    required Map<String, ConfigGcodeMacro> configMacros, // Raw Macros available on the printer
  }) = __Model;

  bool get showCard => groups.isNotEmpty;
}
