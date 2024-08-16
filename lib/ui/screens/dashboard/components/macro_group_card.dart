/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
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
import 'package:common/ui/components/mobileraker_icon_button.dart';
import 'package:common/ui/components/skeletons/card_title_skeleton.dart';
import 'package:common/util/extensions/async_ext.dart';
import 'package:common/util/extensions/ref_extension.dart';
import 'package:common/util/logger.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:extended_wrap/extended_wrap.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/ui/components/dashboard_card.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:rxdart/rxdart.dart';
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
    logger.i('Building MacroGroupCard for $machineUUID');
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              child: _SelectedGroup(machineUUID: machineUUID),
            ),
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
                  Chip(label: SizedBox(width: 29), backgroundColor: Colors.white),
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
      trailing: switch (model.groups.length) {
        == 1 => Tooltip(
            triggerMode: TooltipTriggerMode.tap,
            showDuration: const Duration(seconds: 5),
            message: tr('pages.dashboard.control.macro_card.add_grp_hint'),
            child: const Icon(Icons.help_outline),
          ),
        > 1 => DropdownButton(
            value: model.selected,
            items: model.groups
                .mapIndexed((index, element) => DropdownMenuItem(
                      value: index,
                      child: Text(element.name),
                    ))
                .toList(),
            onChanged: controller.onDropDownChanged,
          ),
        _ => null,
      },
    );
  }
}

class _SelectedGroup extends HookConsumerWidget {
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

    final hadMoreMacrosSettingKey = CompositeKey.keyWithString(UiKeys.hadMoreMacros, '${group.uuid}-$machineUUID');

    final showAll = useState(false);

    final hadShowAll = ref.read(boolSettingProvider(hadMoreMacrosSettingKey));
    final showAllAvailable = useState(hadShowAll);

    // Reset the showAll state when the group changes
    useEffect(() {
      showAll.value = false;
      // showAllAvailable.value = false;
    }, [group.uuid]);

    useEffect(() {
      final newVal = showAllAvailable.value || showAll.value;
      if (hadShowAll == newVal) return;
      logger.wtf('Setting showAllAvailable to $showAllAvailable || $showAll - LALALA');
      ref.read(settingServiceProvider).writeBool(hadMoreMacrosSettingKey, newVal);
    }, [group.uuid, showAllAvailable.value]);

    const dur = kThemeAnimationDuration;
    // final dur = const Duration(seconds: 5);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnimatedSizeAndFade(
          alignment: Alignment.topCenter,
          sizeDuration: dur,
          fadeDuration: dur,
          // The column is required to make it stretch
          child: group.hasMacros(isPrinting)
              ? Column(
                  key: ValueKey('group-${group.uuid}'),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ChipsWrap(
                      macros: group.filtered(isPrinting),
                      machineUUID: machineUUID,
                      showAll: showAll.value,
                      hasMoreMacros: (value) => showAllAvailable.value = value || showAll.value,
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
        ),
        AnimatedSizeAndFade(
          alignment: Alignment.topCenter,
          sizeDuration: dur,
          fadeDuration: dur,
          child: showAllAvailable.value && !showAll.value
              ? MobilerakerIconButton(
                  key: ValueKey('showAll-${group.uuid}'),
                  padding: EdgeInsets.all(8),
                  tooltip: tr('pages.dashboard.control.macro_card.show_all_tooltip'),
                  onPressed: () => showAll.value = true,
                  icon: const Icon(Icons.keyboard_arrow_down),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _ChipsWrap extends StatefulWidget {
  const _ChipsWrap({
    super.key,
    required this.macros,
    required this.machineUUID,
    required this.showAll,
    required this.hasMoreMacros,
  });

  final String machineUUID;

  final List<GCodeMacro> macros;

  final bool showAll;

  final Function(bool) hasMoreMacros;

  @override
  State<_ChipsWrap> createState() => _ChipsWrapState();
}

class _ChipsWrapState extends State<_ChipsWrap> {
  final GlobalKey<State<StatefulWidget>> _lastChildKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    checkVisibiltiy();
  }

  @override
  void didUpdateWidget(_ChipsWrap oldWidget) {
    if (const DeepCollectionEquality().equals(oldWidget.macros, widget.macros)) {
      checkVisibiltiy();
    }
  }

  @override
  Widget build(BuildContext context) {
    logger.i('Building _ChipsWrap - showAll: ${widget.showAll}');
    return ExtendedWrap(
      alignment: WrapAlignment.center,
      spacing: 5,
      maxLines: widget.showAll ? -1 >>> 1 : 3,
      children: _getChildren(),
    );
  }

  void checkVisibiltiy() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_lastChildKey.currentContext != null) {
        final RenderBox renderBox = _lastChildKey.currentContext!.findRenderObject()! as RenderBox;
        if (!renderBox.hasSize) return;
        final Size size = renderBox.size;
        widget.hasMoreMacros(size.width == 0 && size.height == 0);
      }
    });
  }

  List<Widget> _getChildren() {
    final List<Widget> children = <Widget>[];

    for (int i = 0; i < widget.macros.length; i++) {
      children.add(_MacroChip(
        key: (i == widget.macros.length - 1) ? _lastChildKey : null,
        machineUUID: widget.machineUUID,
        macro: widget.macros[i],
      ));
    }
    return children;
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
    //Note, the visibility is just an additional check. The group already filters out removed macros and the once that should not be shown while printing/are hidden
    return Visibility(
      visible: configMacro != null && macro.visible && (!isPrinting || macro.showWhilePrinting),
      child: GestureDetector(
        onLongPress: enabled ? () => controller.onMacroLongPressed(configMacro!) : null,
        child: ActionChip(
          onPressed: enabled ? () => controller.onMacroPressed(configMacro!) : null,
          label: Text(macro.beautifiedName),
          labelStyle: TextStyle(
            color: enabled ? themeData.colorScheme.onPrimary : themeData.disabledColor,
          ),
          backgroundColor: themeData.colorScheme.primary,
        ),
      ),
    );
  }
}

@Riverpod(dependencies: [dashboardCardUUID])
class _MacroGroupCardController extends _$MacroGroupCardController {
  SettingService get _settingService => ref.read(settingServiceProvider);

  DialogService get _dialogService => ref.read(dialogServiceProvider);

  PrinterService get _printerService => ref.read(printerServiceProvider(machineUUID));

  KeyValueStoreKey get _settingsKey => CompositeKey.keyWithString(UtilityKeys.gCodeIndex, machineUUID + _componentUUID);

  String get _componentUUID => ref.read(dashboardCardUUIDProvider(machineUUID));

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

class _MacroGroupCardPreviewController extends _MacroGroupCardController {
  @override
  Stream<_Model> build(String machineUUID) {
    state = AsyncValue.data(_Model(
      klippyCanReceiveCommands: true,
      isPrinting: false,
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
    ));

    return const Stream.empty();
  }

  @override
  void onDropDownChanged(int? index) {
    // Do nothing preview
  }

  @override
  onMacroPressed(ConfigGcodeMacro macro) async {
    // Do nothing preview
  }

  @override
  onMacroLongPressed(ConfigGcodeMacro macro) {
    HapticFeedback.vibrate();
    // Do nothing preview
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
