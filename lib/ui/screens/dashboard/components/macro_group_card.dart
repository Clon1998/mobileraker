/*
 * Copyright (c) 2023-2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:math';

import 'package:collection/collection.dart';
import 'package:common/data/dto/config/config_gcode_macro.dart';
import 'package:common/data/dto/machine/print_state_enum.dart';
import 'package:common/data/model/moonraker_db/settings/gcode_macro.dart';
import 'package:common/data/model/moonraker_db/settings/macro_group.dart';
import 'package:common/service/machine_service.dart';
import 'package:common/service/moonraker/klippy_service.dart';
import 'package:common/service/moonraker/printer_service.dart';
import 'package:common/service/setting_service.dart';
import 'package:common/service/ui/dialog_service_interface.dart';
import 'package:common/ui/animation/animated_size_and_fade.dart';
import 'package:common/ui/components/async_guard.dart';
import 'package:common/ui/components/skeletons/card_title_skeleton.dart';
import 'package:common/util/extensions/async_ext.dart';
import 'package:common/util/extensions/ref_extension.dart';
import 'package:common/util/logger.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:common/service/ui/bottom_sheet_service_interface.dart';
import 'package:mobileraker/service/ui/bottom_sheet_service_impl.dart';
import 'package:mobileraker/ui/components/bottomsheet/macros_bottom_sheet.dart';
import 'package:mobileraker/ui/components/dashboard_card.dart';
import 'package:mobileraker/ui/components/macro/macro_command.dart';
import 'package:mobileraker/ui/components/macro/sent_feedback_icon.dart';
import 'package:mobileraker/ui/components/macro/use_sent_feedback.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../service/ui/dialog_service_impl.dart';

part 'macro_group_card.freezed.dart';
part 'macro_group_card.g.dart';

class MacroGroupCard extends HookConsumerWidget {
  const MacroGroupCard({super.key, required this.machineUUID});

  static Widget preview() {
    return const _Preview();
  }

  final String machineUUID;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    useAutomaticKeepAlive();
    talker.info('Building MacroGroupCard for $machineUUID');
    return AsyncGuard(
      animate: true,
      debugLabel: 'MacroGroupCard-$machineUUID',
      toGuard: _macroGroupCardControllerProvider(machineUUID).selectAs((data) => data.showCard),
      childOnLoading: const _MacroGroupLoading(),
      childOnData: Card(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _CardTitle(machineUUID: machineUUID),
            _GroupChips(machineUUID: machineUUID),
            _SelectedGroup(machineUUID: machineUUID),
          ],
        ),
      ),
    );
  }
}

class _Preview extends HookWidget {
  static const String _machineUUID = 'preview';

  const _Preview({super.key});

  @override
  Widget build(BuildContext context) {
    useAutomaticKeepAlive();
    return ProviderScope(
      overrides: [
        _macroGroupCardControllerProvider(_machineUUID).overrideWith(_MacroGroupCardPreviewController.new),
      ],
      child: const MacroGroupCard(machineUUID: _machineUUID),
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
        highlightColor: themeData.colorScheme.surface,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CardTitleSkeleton.trailingText(),
            Padding(
              padding: const EdgeInsets.fromLTRB(15, 0, 15, 15),
              child: GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: _tileSpacing,
                crossAxisSpacing: _tileSpacing,
                childAspectRatio: 3.4,
                children: [
                  for (var i = 0; i < 4; i++)
                    DecoratedBox(
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(_tileRadius)),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

const double _tileHeight = 48;
const double _tileSpacing = 8;
const double _tileRadius = 14;
const int _maxRows = 3;

class _CardTitle extends ConsumerWidget {
  const _CardTitle({super.key, required this.machineUUID});

  final String machineUUID;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(_macroGroupCardControllerProvider(machineUUID).notifier);

    return ListTile(
      leading: const Icon(MaterialCommunityIcons.code_braces),
      title: const Text('pages.dashboard.control.macro_card.title').tr(),
      trailing: TextButton.icon(
        onPressed: () => controller.openSheet(null),
        icon: const Icon(Icons.apps, size: 18),
        label: const Text('pages.dashboard.control.macro_card.all').tr(),
      ),
    );
  }
}

/// Filter chips for the groups, only shown if there is more than one.
class _GroupChips extends ConsumerWidget {
  const _GroupChips({super.key, required this.machineUUID});

  final String machineUUID;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(_macroGroupCardControllerProvider(machineUUID).notifier);
    final model = ref.watch(_macroGroupCardControllerProvider(machineUUID)).requireValue;
    final selected = model.selected;
    final names = [for (final group in model.groups) group.name];

    return AnimatedSizeAndFade(
      child: names.length > 1
          ? SizedBox(
              height: 48,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(15, 0, 15, 8),
                itemCount: names.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) => ChoiceChip(
                  label: Text(names[index]),
                  selected: index == selected,
                  showCheckmark: false,
                  visualDensity: VisualDensity.compact,
                  onSelected: (_) => controller.onGroupSelected(index),
                ),
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}

class _SelectedGroup extends ConsumerWidget {
  const _SelectedGroup({super.key, required this.machineUUID});

  final String machineUUID;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(_macroGroupCardControllerProvider(machineUUID).notifier);
    final printState = ref.watch(
      _macroGroupCardControllerProvider(machineUUID).selectRequireValue((data) => data.printState),
    );
    final group = ref
        .watch(
          _macroGroupCardControllerProvider(
            machineUUID,
          ).selectAs((value) => value.groups.elementAtOrNull(value.selected)),
        )
        .value;

    if (group == null) return const SizedBox.shrink();

    final macros = group.filtered(printState);

    return AnimatedSizeAndFade(
      alignment: Alignment.topCenter,
      child: macros.isEmpty
          ? Padding(
              key: ValueKey('empty-${group.uuid}'),
              padding: const EdgeInsets.fromLTRB(15, 0, 15, 15),
              child: Text(
                'pages.dashboard.control.macro_card.no_macros',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ).tr(),
            )
          : Padding(
              key: ValueKey('group-${group.uuid}'),
              padding: const EdgeInsets.fromLTRB(15, 0, 15, 15),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final columns = (constraints.maxWidth / 150).floor().clamp(2, 4);
                  final maxTiles = columns * _maxRows;
                  // Keep the card compact, the rest is one tap away in the sheet
                  final overflow = macros.length > maxTiles;
                  final shown = overflow ? macros.take(maxTiles - 1).toList() : macros;

                  return GridView(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: EdgeInsets.zero,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      mainAxisExtent: _tileHeight,
                      mainAxisSpacing: _tileSpacing,
                      crossAxisSpacing: _tileSpacing,
                    ),
                    children: [
                      for (final macro in shown) _MacroTile(machineUUID: machineUUID, macro: macro),
                      if (overflow)
                        _MoreTile(count: macros.length - shown.length, onTap: () => controller.openSheet(group.uuid)),
                    ],
                  );
                },
              ),
            ),
    );
  }
}

class _MacroTile extends HookConsumerWidget {
  const _MacroTile({super.key, required this.machineUUID, required this.macro});

  final String machineUUID;
  final GCodeMacro macro;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(_macroGroupCardControllerProvider(machineUUID).notifier);

    final (configMacro, enabled) = ref.watch(
      _macroGroupCardControllerProvider(
        machineUUID,
      ).selectRequireValue((data) => (data.configMacros[macro.configName], data.klippyCanReceiveCommands)),
    );

    // The group already filters hidden/removed macros, but the printer might not know the macro (anymore)
    if (configMacro == null) return const SizedBox.shrink();

    final themeData = Theme.of(context);
    final colorScheme = themeData.colorScheme;
    final foreground = enabled ? colorScheme.onSecondaryContainer : themeData.disabledColor;
    final (sent, showSent) = useSentFeedback();

    return Tooltip(
      message: configMacro.userDescription ?? configMacro.macroName.toUpperCase(),
      waitDuration: const Duration(milliseconds: 600),
      child: Material(
        color: enabled ? colorScheme.secondaryContainer : colorScheme.surfaceContainerHighest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_tileRadius)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled
              ? () async {
                  if (await controller.onMacroPressed(configMacro) && context.mounted) showSent();
                }
              : null,
          onLongPress: enabled
              ? () {
                  controller.onMacroLongPressed(configMacro);
                  showSent();
                }
              : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    macro.codeName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: macroNameStyle(themeData.textTheme.labelLarge?.copyWith(color: foreground)),
                  ),
                ),
                const SizedBox(width: 4),
                SentFeedbackIcon(
                  sent: sent,
                  size: 18,
                  color: foreground,
                  // Only the send arrow flies off, the tune icon just fades
                  idleFlies: configMacro.params.isEmpty,
                  idle: Icon(configMacro.params.isEmpty ? Icons.send : Icons.tune, size: 18, color: foreground),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MoreTile extends StatelessWidget {
  const _MoreTile({super.key, required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final themeData = Theme.of(context);
    return Material(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_tileRadius),
        side: BorderSide(color: themeData.colorScheme.outlineVariant),
      ),
      color: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Center(
          child: Text(
            tr('pages.dashboard.control.macro_card.more', args: [count.toString()]),
            style: themeData.textTheme.labelLarge,
          ),
        ),
      ),
    );
  }
}

@Riverpod(dependencies: [dashboardCardUUID])
class _MacroGroupCardController extends _$MacroGroupCardController {
  SettingService get _settingService => ref.read(settingServiceProvider);

  DialogService get _dialogService => ref.read(dialogServiceProvider);

  BottomSheetService get _bottomSheetService => ref.read(bottomSheetServiceProvider);

  PrinterService get _printerService => ref.read(printerServiceProvider(machineUUID));

  KeyValueStoreKey get _settingsKey => CompositeKey.keyWithString(UtilityKeys.gCodeIndex, machineUUID + _componentUUID);

  String get _componentUUID => ref.read(dashboardCardUUIDProvider(machineUUID));

  @override
  FutureOr<_Model> build(String machineUUID) {
    ref.keepAliveFor();
    // Keep the printerService alive while this controller is alive
    ref.keepAliveExternally(printerServiceProvider(machineUUID));

    final initialIndex = _settingService.readInt(_settingsKey, 0);

    final klippyAsync = ref.watch(klipperProvider(machineUUID).selectAs((value) => value.klippyCanReceiveCommands));
    final printStateAsync = ref.watch(printerProvider(machineUUID).selectAs((data) => data.print.state));
    final groupsAsync = ref.watch(machineSettingsProvider(machineUUID).selectAs((data) => data.macroGroups));
    final configMacrosAsync = ref.watch(printerProvider(machineUUID).selectAs((data) => data.configFile.gcodeMacros));

    final klippyCanReceiveCommands = klippyAsync.requireValue;
    final printState = printStateAsync.requireValue;
    final groups = groupsAsync.requireValue;
    final configMacros = configMacrosAsync.requireValue;


    final idx = state.whenData((value) => value.selected).value ?? initialIndex;
    return _Model(
      klippyCanReceiveCommands: klippyCanReceiveCommands,
      printState: printState,
      groups: groups,
      selected: min(groups.length - 1, max(0, idx)),
      configMacros: configMacros,
    );
  }

  void onGroupSelected(int index) {
    state = state.whenData((value) => value.copyWith(selected: index));
    _settingService.writeInt(_settingsKey, index);
  }

  void openSheet(String? groupUUID) {
    _bottomSheetService.show(
      BottomSheetConfig(
        type: SheetType.macros,
        data: MacrosBottomSheetArgs(machineUUID: machineUUID, groupUUID: groupUUID),
      ),
    );
  }

  /// Runs [macro], asking for its params (or a confirmation) first if needed. Returns whether it was sent.
  Future<bool> onMacroPressed(ConfigGcodeMacro macro) async {
    var alwaysConfirm = _settingService.readBool(AppSettingKeys.confirmMacroExecution, false);

    if (macro.params.isNotEmpty || alwaysConfirm) {
      DialogResponse? response = await _dialogService.show(DialogRequest(type: DialogType.gcodeParams, data: macro));

      if (response?.confirmed != true || !ref.mounted) return false;
      final paramsMap = response!.data as Map<String, String>;
      _printerService.gCode(macroCommand(macro.macroName, paramsMap));
    } else {
      HapticFeedback.selectionClick();
      _printerService.gCode(macro.macroName);
    }
    return true;
  }

  void onMacroLongPressed(ConfigGcodeMacro macro) {
    HapticFeedback.vibrate();
    _printerService.gCode(macro.macroName);
  }
}

class _MacroGroupCardPreviewController extends _MacroGroupCardController {
  @override
  FutureOr<_Model> build(String machineUUID) {
    var model = _Model(
      klippyCanReceiveCommands: true,
      printState: PrintState.standby,
      groups: [
        MacroGroup(
          name: 'Preview Group',
          macros: [
            GCodeMacro(name: 'Preview Macros'),
            GCodeMacro(
              name: 'Home all',
            ),
            GCodeMacro(name: 'Clean nozzle'),
            GCodeMacro(name: 'M600'),
            GCodeMacro(name: 'Park Toolhead'),
          ],
        ),
      ],
      selected: 0,
      configMacros: {
        'home all': const ConfigGcodeMacro(macroName: 'Home all', gcode: ''),
        'clean nozzle': const ConfigGcodeMacro(macroName: 'Clean nozzle', gcode: ''),
        'm600': const ConfigGcodeMacro(macroName: 'M600', gcode: ''),
        'park toolhead': const ConfigGcodeMacro(macroName: 'Park Toolhead', gcode: ''),
        'preview macros': const ConfigGcodeMacro(macroName: 'Preview Macros', gcode: ''),
      },
    );
    state = AsyncValue.data(model);

    return model;
  }

  @override
  void onGroupSelected(int index) {
    // Do nothing preview
  }

  @override
  void openSheet(String? groupUUID) {
    // Do nothing preview
  }

  @override
  Future<bool> onMacroPressed(ConfigGcodeMacro macro) async {
    // Nothing is sent in the preview, but show the feedback
    return true;
  }

  @override
  void onMacroLongPressed(ConfigGcodeMacro macro) {
    HapticFeedback.vibrate();
    // Do nothing preview
  }
}

@freezed
sealed class _Model with _$Model {
  const _Model._();

  const factory _Model({
    required bool klippyCanReceiveCommands,
    required PrintState printState,
    required int selected,
    required List<MacroGroup> groups,
    required Map<String, ConfigGcodeMacro> configMacros, // Raw Macros available on the printer
  }) = __Model;

  bool get showCard => groups.isNotEmpty;
}
