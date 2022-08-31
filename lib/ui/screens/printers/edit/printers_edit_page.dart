import 'package:easy_localization/easy_localization.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/data/dto/config/config_extruder.dart';
import 'package:mobileraker/data/dto/config/config_heater_bed.dart';
import 'package:mobileraker/data/model/hive/machine.dart';
import 'package:mobileraker/data/model/hive/webcam_mode.dart';
import 'package:mobileraker/data/model/hive/webcam_setting.dart';
import 'package:mobileraker/data/model/moonraker_db/macro_group.dart';
import 'package:mobileraker/data/model/moonraker_db/temperature_preset.dart';
import 'package:mobileraker/service/moonraker/printer_service.dart';
import 'package:mobileraker/util/extensions/async_ext.dart';
import 'package:progress_indicators/progress_indicators.dart';
import 'package:reorderables/reorderables.dart';
import 'package:stringr/stringr.dart';

import 'printers_edit_controller.dart';

class PrinterEdit extends ConsumerWidget {
  const PrinterEdit({Key? key, required this.machine}) : super(key: key);
  final Machine machine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ProviderScope(
      overrides: [
        currentlyEditing.overrideWithValue(machine),
        printerEditControllerProvider,
        remoteMachineSettingProvider,
        webcamListControllerProvider,
        macroGroupListControllerProvider,
        temperaturePresetListControllerProvider,
        moveStepStateProvider,
        babyStepStateProvider,
        extruderStepStateProvider
      ],
      child: _PrinterEdit(),
    );
  }
}

class _PrinterEdit extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var canShowImport = ref.watch(
        importMachines.select((value) => (value.valueOrNull?.length ?? 0) > 1));

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'pages.printer_edit.title',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ).tr(args: [ref.watch(currentlyEditing).name]),
        actions: [
          if (canShowImport)
            IconButton(
              icon: const Icon(
                FlutterIcons.import_mco,
              ),
              tooltip: 'pages.printer_edit.import_settings'.tr(),
              onPressed: ref
                  .watch(printerEditControllerProvider.notifier)
                  .openImportSettings,
              // onPressed: () =>                    model.onImportSettings(MaterialLocalizations.of(context))
            ),
        ],
      ),
      floatingActionButton: ref.watch(isSavingProvider)
          ? const FloatingActionButton(
              onPressed: null, child: CircularProgressIndicator())
          : FloatingActionButton(
              onPressed:
                  ref.read(printerEditControllerProvider.notifier).saveForm,
              child: const Icon(Icons.save_outlined),
            ),
      body: const PrinterSettingScrollView(),
    );
  }
}

class PrinterSettingScrollView extends ConsumerWidget {
  const PrinterSettingScrollView({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var machine = ref.watch(currentlyEditing);

    return SingleChildScrollView(
      child: FormBuilder(
        enabled: !ref.watch(isSavingProvider),
        autoFocusOnValidationFailure: true,
        key: ref.watch(editPrinterformKeyProvider),
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Padding(
          padding: const EdgeInsets.all(10.0),
          child: Column(
            children: <Widget>[
              _SectionHeader(title: 'pages.setting.general.title'.tr()),
              FormBuilderTextField(
                decoration: InputDecoration(
                  labelText: 'pages.printer_edit.general.displayname'.tr(),
                ),
                name: 'printerName',
                initialValue: machine.name,
                validator: FormBuilderValidators.compose(
                    [FormBuilderValidators.required()]),
              ),
              FormBuilderTextField(
                decoration: InputDecoration(
                  labelText: 'pages.printer_edit.general.printer_addr'.tr(),
                  hintText: 'pages.printer_edit.general.full_url'.tr(),
                ),
                name: 'printerUrl',
                initialValue: machine.httpUrl,
                validator: FormBuilderValidators.compose([
                  FormBuilderValidators.required(),
                  FormBuilderValidators.url(
                      protocols: ['http', 'https'], requireProtocol: true)
                ]),
              ),
              FormBuilderTextField(
                decoration: InputDecoration(
                  labelText: 'pages.printer_edit.general.ws_addr'.tr(),
                  hintText: 'pages.printer_edit.general.full_url'.tr(),
                ),
                name: 'wsUrl',
                initialValue: machine.wsUrl,
                validator: FormBuilderValidators.compose([
                  FormBuilderValidators.required(),
                  FormBuilderValidators.url(
                      protocols: ['ws', 'wss'], requireProtocol: true)
                ]),
              ),
              FormBuilderTextField(
                decoration: InputDecoration(
                    labelText:
                        'pages.printer_edit.general.moonraker_api_key'.tr(),
                    suffix: IconButton(
                      icon: const Icon(Icons.qr_code_sharp),
                      onPressed: ref
                          .watch(printerEditControllerProvider.notifier)
                          .openQrScanner,
                    ),
                    helperText:
                        'pages.printer_edit.general.moonraker_api_desc'.tr(),
                    helperMaxLines: 3),
                name: 'printerApiKey',
                initialValue: machine.apiKey,
              ),
              const Divider(),
              _SectionHeaderWithAction(
                  title: 'pages.dashboard.general.cam_card.webcam'.tr(),
                  action: TextButton.icon(
                    onPressed: ref
                        .read(webcamListControllerProvider.notifier)
                        .addNewWebCam,
                    label: const Text('general.add').tr(),
                    icon: const Icon(FlutterIcons.webcam_mco),
                  )),
              const WebcamList(),
              const Divider(),
              const RemoteSettings()
            ],
          ),
        ),
      ),
    );
  }
}

class WebcamList extends ConsumerWidget {
  const WebcamList({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    List<WebcamSetting> cams = ref.watch(webcamListControllerProvider);

    if (cams.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(8.0),
        child: const Text('pages.printer_edit.cams.no_webcams').tr(),
      );
    }

    return ReorderableListView(
        buildDefaultDragHandles: false,
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        onReorder:
            ref.read(webcamListControllerProvider.notifier).onWebCamReorder,
        onReorderStart: (i) => FocusScope.of(context).unfocus(),
        children: List.generate(cams.length, (index) {
          WebcamSetting cam = cams[index];
          return _WebCamItem(
            key: ValueKey(cam.uuid),
            cam: cam,
            idx: index,
          );
        }));
  }
}

class _WebCamItem extends HookConsumerWidget {
  final WebcamSetting cam;
  final int idx;

  const _WebCamItem({
    Key? key,
    required this.cam,
    required this.idx,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var camName = useState(cam.name);
    var selMode = useState(cam.mode);
    return Card(
        child: ExpansionTile(
            maintainState: true,
            tilePadding: const EdgeInsets.symmetric(horizontal: 10),
            childrenPadding: const EdgeInsets.symmetric(horizontal: 10),
            title: Text(camName.value),
            leading: ReorderableDragStartListener(
              index: idx,
              child: const Icon(Icons.drag_handle),
            ),
            children: [
          FormBuilderTextField(
            decoration: InputDecoration(
              labelText: 'pages.printer_edit.general.displayname'.tr(),
              suffix: IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () => ref
                      .read(webcamListControllerProvider.notifier)
                      .removeWebcam(cam)),
            ),
            name: '${cam.uuid}-camName',
            initialValue: cam.name,
            onChanged: (name) => camName.value = ((name?.isNotEmpty ?? false)
                ? name!
                : 'pages.printer_edit.cams.new_cam'.tr()),
            validator: FormBuilderValidators.compose(
                [FormBuilderValidators.required()]),
          ),
          FormBuilderTextField(
            decoration: InputDecoration(
                labelText: 'pages.printer_edit.cams.webcam_addr'.tr(),
                helperText:
                    '${tr('pages.printer_edit.cams.default_addr')}: http://<URL>/webcam/?action=stream'),
            name: '${cam.uuid}-camUrl',
            initialValue: cam.url,
            validator: FormBuilderValidators.compose([
              FormBuilderValidators.required(),
              FormBuilderValidators.url(
                  protocols: ['http', 'https'], requireProtocol: true)
            ]),
          ),
          FormBuilderDropdown(
            name: '${cam.uuid}-mode',
            initialValue: cam.mode,
            items: WebCamMode.values
                .map((mode) => DropdownMenuItem<WebCamMode>(
                    value: mode,
                    child: Text(mode.name
                        .toLowerCase()
                        .replaceAll("_", " ")
                        .titleCase())))
                .toList(),
            decoration: InputDecoration(
              labelText: 'pages.printer_edit.cams.cam_mode'.tr(),
            ),
            onChanged: (WebCamMode? v) => selMode.value = v!,
          ),
          if (selMode.value == WebCamMode.ADAPTIVE_STREAM)
            FormBuilderTextField(
              decoration: InputDecoration(
                labelText: 'pages.printer_edit.cams.target_fps'.tr(),
                suffix: const Text('FPS'),
              ),
              name: '${cam.uuid}-tFps',
              initialValue: cam.targetFps.toString(),
              validator: FormBuilderValidators.compose([
                FormBuilderValidators.min(0),
                FormBuilderValidators.numeric(),
                FormBuilderValidators.required()
              ]),
              valueTransformer: (String? text) =>
                  text == null ? 0 : num.tryParse(text),
              keyboardType: const TextInputType.numberWithOptions(
                  signed: false, decimal: false),
            ),
          FormBuilderSwitch(
            title: const Text('pages.printer_edit.cams.flip_vertical').tr(),
            decoration: const InputDecoration(border: InputBorder.none),
            secondary: const Icon(FlutterIcons.swap_vertical_mco),
            initialValue: cam.flipVertical,
            name: '${cam.uuid}-camFV',
            activeColor: Theme.of(context).colorScheme.primary,
          ),
          FormBuilderSwitch(
            title: const Text('pages.printer_edit.cams.flip_horizontal').tr(),
            decoration: const InputDecoration(border: InputBorder.none),
            secondary: const Icon(FlutterIcons.swap_horizontal_mco),
            initialValue: cam.flipHorizontal,
            name: '${cam.uuid}-camFH',
            activeColor: Theme.of(context).colorScheme.primary,
          ),
        ]));
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({Key? key, required this.title}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: Theme.of(context).colorScheme.secondary,
          fontSize: 12.0,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _SectionHeaderWithAction extends StatelessWidget {
  final String title;
  final Widget action;

  const _SectionHeaderWithAction({
    Key? key,
    required this.title,
    required this.action,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title.toUpperCase(),
          style: TextStyle(
            color: Theme.of(context).colorScheme.secondary,
            fontSize: 12.0,
            fontWeight: FontWeight.bold,
          ),
        ),
        action
      ],
    );
  }
}

class RemoteSettings extends ConsumerWidget {
  const RemoteSettings({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var themeData = Theme.of(context);
    return Column(
      children: [
        ...ref.watch(remoteMachineSettingProvider).when(
            data: (machineSettings) => [
                  _SectionHeader(
                      title: 'pages.printer_edit.motion_system.title'.tr()),
                  FormBuilderSwitch(
                    name: 'invertX',
                    initialValue: machineSettings.inverts[0],
                    title:
                        const Text('pages.printer_edit.motion_system.invert_x')
                            .tr(),
                    decoration: const InputDecoration(
                        border: InputBorder.none, isCollapsed: true),
                    activeColor: themeData.colorScheme.primary,
                  ),
                  FormBuilderSwitch(
                    name: 'invertY',
                    initialValue: machineSettings.inverts[1],
                    title:
                        const Text('pages.printer_edit.motion_system.invert_y')
                            .tr(),
                    decoration: const InputDecoration(
                        border: InputBorder.none, isCollapsed: true),
                    activeColor: themeData.colorScheme.primary,
                  ),
                  FormBuilderSwitch(
                    name: 'invertZ',
                    initialValue: machineSettings.inverts[2],
                    title:
                        const Text('pages.printer_edit.motion_system.invert_z')
                            .tr(),
                    decoration: const InputDecoration(
                        border: InputBorder.none, isCollapsed: true),
                    activeColor: themeData.colorScheme.primary,
                  ),
                  FormBuilderTextField(
                    name: 'speedXY',
                    initialValue: machineSettings.speedXY.toString(),
                    valueTransformer: (text) =>
                        (text != null) ? int.tryParse(text) : 0,
                    decoration: InputDecoration(
                        labelText:
                            'pages.printer_edit.motion_system.speed_xy'.tr(),
                        suffixText: 'mm/s',
                        isDense: true),
                    keyboardType: const TextInputType.numberWithOptions(
                        signed: false, decimal: false),
                    validator: FormBuilderValidators.compose([
                      FormBuilderValidators.required(),
                      FormBuilderValidators.min(1)
                    ]),
                  ),
                  FormBuilderTextField(
                    name: 'speedZ',
                    initialValue: machineSettings.speedZ.toString(),
                    valueTransformer: (text) =>
                        (text != null) ? int.tryParse(text) : 0,
                    decoration: InputDecoration(
                        labelText:
                            'pages.printer_edit.motion_system.speed_z'.tr(),
                        suffixText: 'mm/s',
                        isDense: true),
                    keyboardType: const TextInputType.numberWithOptions(
                        signed: false, decimal: false),
                    validator: FormBuilderValidators.compose([
                      FormBuilderValidators.required(),
                      FormBuilderValidators.min(1)
                    ]),
                  ),
                  const MoveStepSegmentInput(),
                  const BabyStepSegmentInput(),
                  const Divider(),
                  _SectionHeader(
                      title: 'pages.printer_edit.extruders.title'.tr()),
                  FormBuilderTextField(
                    name: 'extrudeSpeed',
                    initialValue: machineSettings.extrudeFeedrate.toString(),
                    valueTransformer: (text) =>
                        (text != null) ? int.tryParse(text) : 0,
                    decoration: InputDecoration(
                        labelText: 'pages.printer_edit.extruders.feedrate'.tr(),
                        suffixText: 'mm/s',
                        isDense: true),
                    keyboardType: const TextInputType.numberWithOptions(
                        signed: false, decimal: false),
                    validator: FormBuilderValidators.compose([
                      FormBuilderValidators.required(),
                      FormBuilderValidators.min(1)
                    ]),
                  ),
                  const ExtruderStepSegmentInput(),
                  const Divider(),
                  _SectionHeaderWithAction(
                      title: 'pages.dashboard.control.macro_card.title'.tr(),
                      action: TextButton.icon(
                        onPressed: ref
                            .read(macroGroupListControllerProvider.notifier)
                            .addNewMacroGroup,
                        label: const Text('general.add').tr(),
                        icon: const Icon(Icons.source_outlined),
                      )),
                  const MacroGroupList(),
                  const Divider(),
                  _SectionHeaderWithAction(
                      title:
                          'pages.dashboard.general.temp_card.temp_presets'.tr(),
                      action: TextButton.icon(
                        onPressed: ref
                            .watch(temperaturePresetListControllerProvider
                                .notifier)
                            .addNewTemperaturePreset,
                        label: const Text('general.add').tr(),
                        icon: const Icon(FlutterIcons.thermometer_lines_mco),
                      )),
                  const TemperaturePresetList(),
                ],
            error: (e, s) => [
                  ListTile(
                    tileColor: themeData.colorScheme.errorContainer,
                    textColor: themeData.colorScheme.onErrorContainer,
                    iconColor: themeData.colorScheme.onErrorContainer,
                    leading: const Icon(
                      Icons.error_outline,
                      size: 40,
                    ),
                    title: const Text(
                      'pages.printer_edit.could_not_fetch_additional',
                    ).tr(),
                    subtitle:
                        const Text('pages.printer_edit.fetch_error_hint').tr(),
                  ),
                ],
            loading: () => [
                  FadingText(
                      'pages.printer_edit.fetching_additional_settings'.tr()),
                ]),
        const Divider(),
        Align(
          alignment: Alignment.bottomCenter,
          child: TextButton.icon(
              onPressed:
                  ref.read(printerEditControllerProvider.notifier).deleteIt,
              icon: const Icon(Icons.delete_forever_outlined),
              label: const Text('pages.printer_edit.remove_printer').tr()),
        )
      ],
    );
  }
}

class MoveStepSegmentInput extends ConsumerWidget {
  const MoveStepSegmentInput({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Segments(
      decoration: InputDecoration(
          labelText: 'pages.printer_edit.motion_system.steps_move'.tr(),
          suffixText: 'mm'),
      options: ref
          .watch(moveStepStateProvider)
          .map((e) => FormBuilderFieldOption(value: e, child: Text('$e')))
          .toList(growable: false),
      onAdd: ref.read(moveStepStateProvider.notifier).onAdd,
      onSelected: ref.read(moveStepStateProvider.notifier).onSelected,
      validator: FormBuilderValidators.compose([
        FormBuilderValidators.required(),
        FormBuilderValidators.numeric(),
        FormBuilderValidators.integer(),
        FormBuilderValidators.min(1),
        ref.read(moveStepStateProvider.notifier).validate
      ]),
      inputType: TextInputType.number,
    );
  }
}

class BabyStepSegmentInput extends ConsumerWidget {
  const BabyStepSegmentInput({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Segments(
      decoration: InputDecoration(
          labelText: 'pages.printer_edit.motion_system.steps_baby'.tr(),
          suffixText: 'mm'),
      options: ref
          .watch(babyStepStateProvider)
          .map((e) => FormBuilderFieldOption(value: e, child: Text('$e')))
          .toList(growable: false),
      onAdd: ref.read(babyStepStateProvider.notifier).onAdd,
      onSelected: ref.read(babyStepStateProvider.notifier).onSelected,
      validator: FormBuilderValidators.compose([
        FormBuilderValidators.required(),
        FormBuilderValidators.numeric(),
        FormBuilderValidators.min(0.001),
        ref.read(babyStepStateProvider.notifier).validate
      ]),
      inputType: const TextInputType.numberWithOptions(decimal: true),
    );
  }
}

class ExtruderStepSegmentInput extends ConsumerWidget {
  const ExtruderStepSegmentInput({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Segments(
      decoration: InputDecoration(
          labelText: 'pages.printer_edit.extruders.steps_extrude'.tr(),
          suffixText: 'mm'),
      options: ref
          .watch(extruderStepStateProvider)
          .map((e) => FormBuilderFieldOption(value: e, child: Text('$e')))
          .toList(growable: false),
      onAdd: ref.read(extruderStepStateProvider.notifier).onAdd,
      onSelected: ref.read(extruderStepStateProvider.notifier).onSelected,
      validator: FormBuilderValidators.compose([
        FormBuilderValidators.required(),
        FormBuilderValidators.numeric(),
        FormBuilderValidators.integer(),
        FormBuilderValidators.min(1),
        ref.read(extruderStepStateProvider.notifier).validate
      ]),
      inputType: TextInputType.number,
    );
  }
}

class MacroGroupList extends ConsumerWidget {
  const MacroGroupList({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    List<MacroGroup> macroGroups = ref.watch(macroGroupListControllerProvider);
    MacroGroup defaultGrp =
        ref.watch(macroGroupListControllerProvider.notifier).defaultGrp;

    if (macroGroups.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(8.0),
        child: const Text('pages.printer_edit.macros.no_macros_found').tr(),
      );
    }
    return ReorderableListView(
        buildDefaultDragHandles: false,
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        onReorder:
            ref.read(macroGroupListControllerProvider.notifier).onGroupReorder,
        onReorderStart: (i) => FocusScope.of(context).unfocus(),
        children: List.generate(macroGroups.length, (index) {
          MacroGroup macroGroup = macroGroups[index];
          return _MacroGroup(
            key: ValueKey(macroGroup.uuid),
            macroGroup: macroGroup,
            idx: index,
            canEditName: macroGroup != defaultGrp,
          );
        }));
  }
}

class _MacroGroup extends HookConsumerWidget {
  const _MacroGroup(
      {Key? key,
      required this.macroGroup,
      required this.idx,
      this.canEditName = true})
      : super(key: key);

  final MacroGroup macroGroup;
  final int idx;
  final bool canEditName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var name = useState(macroGroup.name);
    var macros = ref.watch(macroGroupControllerProvder(macroGroup));
    var dragging = ref.watch(
        macroGroupDragginControllerProvider.select((value) => value != null));

    return Card(
        child: ExpansionTile(
            maintainState: true,
            tilePadding: const EdgeInsets.symmetric(horizontal: 10),
            childrenPadding:
                const EdgeInsets.only(left: 10, right: 10, bottom: 10),
            leading: ReorderableDragStartListener(
              index: idx,
              child: const Icon(Icons.drag_handle),
            ),
            title: DragTarget<int>(
              builder: (BuildContext context, List<int?> candidateData,
                  List<dynamic> rejectedData) {
                var themeData = Theme.of(context);
                var row = Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(name.value),
                      Chip(
                        label: Text('${macros.length}'),
                        backgroundColor: themeData.colorScheme.background,
                      )
                    ],
                  ),
                );
                if (!dragging) return row;

                var targetCol = candidateData.isNotEmpty
                    ? themeData.colorScheme.primaryContainer
                    : themeData.colorScheme.background.lighten(10);

                return Container(
                  decoration: BoxDecoration(
                    color: targetCol,
                    borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(14), right: Radius.circular(14)),
                    border: Border.all(color: themeData.colorScheme.secondary),
                  ),
                  child: row,
                );
              },
              onAccept: (int d) => ref
                  .read(macroGroupDragginControllerProvider.notifier)
                  .onMacroDragAccepted(macroGroup, d),
            ),
            children: [
          if (canEditName)
            FormBuilderTextField(
              decoration: InputDecoration(
                  labelText: 'pages.printer_edit.general.displayname'.tr(),
                  suffix: IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () => ref
                        .read(macroGroupListControllerProvider.notifier)
                        .removeMacroGroup(macroGroup),
                  )),
              name: '${macroGroup.uuid}-macroName',
              initialValue: name.value,
              onChanged: (v) => name.value = ((v?.isEmpty ?? true)
                  ? 'pages.printer_edit.macros.new_macro_grp'.tr()
                  : v!),
              validator: FormBuilderValidators.compose([
                FormBuilderValidators.required(),
                FormBuilderValidators.notEqual('Default',
                    errorText: 'Group can not be named Default')
              ]),
            ),
          const SizedBox(
            height: 8,
          ),
          const _SectionHeader(title: 'Macros'),
          if (macros.isEmpty)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Text('No macros in the group!'),
            )
          else
            ReorderableWrap(
              spacing: 4.0,
              buildDraggableFeedback: (context, constraint, widget) => Material(
                color: Colors.transparent,
                child: ConstrainedBox(
                  constraints: constraint,
                  child: widget,
                ),
              ),
              onReorderStarted: (index) {
                FocusScope.of(context).unfocus();
                ref
                    .read(macroGroupDragginControllerProvider.notifier)
                    .onMacroReorderStarted(macroGroup);
              },
              onReorder: ref
                  .read(macroGroupControllerProvder(macroGroup).notifier)
                  .onMacroReorder,
              onNoReorder: ref
                  .read(macroGroupControllerProvder(macroGroup).notifier)
                  .onNoReorder,
              children: macros
                  .map((m) => Chip(label: Text(m.beautifiedName)))
                  .toList(),
            )
        ]));
  }
}

class TemperaturePresetList extends ConsumerWidget {
  const TemperaturePresetList({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    List<TemperaturePreset> tempPresets =
        ref.watch(temperaturePresetListControllerProvider);

    if (tempPresets.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(8.0),
        child: const Text('pages.printer_edit.presets.no_presets').tr(),
      );
    }
    var machine = ref.watch(currentlyEditing);
    return ReorderableListView(
      buildDefaultDragHandles: false,
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      onReorder: ref
          .watch(temperaturePresetListControllerProvider.notifier)
          .onGroupReorder,
      onReorderStart: (i) => FocusScope.of(context).unfocus(),
      children: List.generate(tempPresets.length, (index) {
        TemperaturePreset preset = tempPresets[index];
        return _TempPresetItem(
          key: ValueKey(preset.uuid),
          preset: preset,
          idx: index,
          machine: machine,
        );
      }),
    );
  }
}

class _TempPresetItem extends HookConsumerWidget {
  const _TempPresetItem(
      {Key? key,
      required this.preset,
      required this.idx,
      required this.machine})
      : super(key: key);
  final TemperaturePreset preset;
  final int idx;
  final Machine
      machine; // We cant use the provider here since the reordable cant use the provider while dragging!

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var name = useState(preset.name);
    ConfigExtruder? primaryExtConfig = ref
        .watch(printerProvider(machine.uuid)
            .selectAs((data) => data.configFile.primaryExtruder))
        .valueOrNull;
    ConfigHeaterBed? bedConfig = ref
        .watch(printerProvider(machine.uuid)
            .selectAs((data) => data.configFile.configHeaterBed))
        .valueOrNull;
    var extruderMaxTemp = (primaryExtConfig?.maxTemp ?? 500).toInt();
    var bedMaxTemp = (bedConfig?.maxTemp ?? 120).toInt();
    return Card(
        child: ExpansionTile(
            maintainState: true,
            tilePadding: const EdgeInsets.symmetric(horizontal: 10),
            childrenPadding:
                const EdgeInsets.only(left: 10, right: 10, bottom: 10),
            title: Text(name.value),
            leading: ReorderableDragStartListener(
              index: idx,
              child: const Icon(Icons.drag_handle),
            ),
            children: [
          FormBuilderTextField(
            decoration: InputDecoration(
                labelText: 'pages.printer_edit.general.displayname'.tr(),
                suffix: IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () => ref
                      .read(temperaturePresetListControllerProvider.notifier)
                      .removeTemperaturePreset(preset),
                )),
            name: '${preset.uuid}-presetName',
            initialValue: name.value,
            onChanged: (v) => name.value = ((v?.isEmpty ?? true)
                ? 'pages.printer_edit.presets.new_preset'.tr()
                : v!),
            validator: FormBuilderValidators.compose(
                [FormBuilderValidators.required()]),
          ),
          FormBuilderTextField(
            decoration: InputDecoration(
                labelText: tr('pages.printer_edit.presets.hotend_temp'),
                suffixText: '°C'),
            name: '${preset.uuid}-extruderTemp',
            initialValue: preset.extruderTemp.toString(),
            valueTransformer: (String? text) => (text != null)
                ? int.tryParse(text)
                : primaryExtConfig?.minTemp ?? 0,
            validator: FormBuilderValidators.compose(
              [
                FormBuilderValidators.required(),
                FormBuilderValidators.min(0),
                FormBuilderValidators.max(extruderMaxTemp,
                    errorText: 'Heater only allows up to $extruderMaxTemp°C'),
              ],
            ),
            keyboardType: TextInputType.number,
          ),
          FormBuilderTextField(
            decoration: InputDecoration(
                labelText: tr('pages.printer_edit.presets.bed_temp'),
                suffixText: '°C'),
            name: '${preset.uuid}-bedTemp',
            initialValue: preset.bedTemp.toString(),
            valueTransformer: (String? text) =>
                (text != null) ? int.tryParse(text) : bedConfig?.minTemp ?? 0,
            validator: FormBuilderValidators.compose(
              [
                FormBuilderValidators.required(),
                FormBuilderValidators.min(0),
                FormBuilderValidators.max(bedMaxTemp,
                    errorText: 'Heater only allows up to $bedMaxTemp°C'),
              ],
            ),
            keyboardType: TextInputType.number,
          )
        ]));
  }
}

//
// //ToDo: Better name for this widget
class Segments<T> extends StatefulWidget {
  const Segments(
      {Key? key,
      this.decoration = const InputDecoration(),
      this.maxOptions = 5,
      required this.options,
      this.onSelected,
      this.onAdd,
      this.validator,
      this.inputType})
      : super(key: key);

  final InputDecoration decoration;

  final int maxOptions;

  final List<FormBuilderFieldOption<T>> options;

  final Function(T)? onSelected;

  final Function(String)? onAdd;

  final FormFieldValidator<String>? validator;

  final TextInputType? inputType;

  @override
  State<Segments<T>> createState() => _SegmentsState<T>();
}

class _SegmentsState<T> extends State<Segments<T>> {
  bool editing = false;
  TextEditingController textCtrler = TextEditingController();
  String? error;

  @override
  void initState() {
    super.initState();
    if (widget.validator != null) textCtrler.addListener(validateInput);
  }

  validateInput() {
    String text = textCtrler.text;

    if (T == double) {
      text = text.replaceAll(',', '.');
    }

    setState(() {
      error = widget.validator!(text);
    });
  }

  submit() {
    setState(() {
      String curText = textCtrler.text;
      if (curText.isNotEmpty) widget.onAdd!(curText);
      editing = false;
    });
  }

  Future<bool> cancel() {
    if (editing == false) return Future.value(true);

    setState(() {
      editing = false;
    });
    return Future.value(false);
  }

  onChipPressed(FormBuilderFieldOption<T> option) {
    if (widget.onSelected != null) widget.onSelected!(option.value);
  }

  goIntoEditing() {
    setState(() {
      textCtrler.clear();
      editing = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedCrossFade(
      duration: kThemeAnimationDuration,
      crossFadeState:
          editing ? CrossFadeState.showFirst : CrossFadeState.showSecond,
      firstChild: buildEditing(context),
      secondChild: buildNonEditing(context),
    );
  }

  WillPopScope buildEditing(BuildContext context) {
    return WillPopScope(
      onWillPop: () => cancel(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
              child: TextField(
            controller: textCtrler,
            onEditingComplete: submit,
            decoration: widget.decoration.copyWith(errorText: error),
            keyboardType: widget.inputType,
          )),
          IconButton(
            color: Theme.of(context).colorScheme.primary,
            icon: const Icon(Icons.done),
            onPressed: error == null ? submit : null,
          )
        ],
      ),
    );
  }

  InputDecorator buildNonEditing(BuildContext context) {
    return InputDecorator(
      decoration: widget.decoration,
      child: Wrap(
        direction: Axis.horizontal,
        verticalDirection: VerticalDirection.down,
        children: <Widget>[
          for (FormBuilderFieldOption<T> option in widget.options)
            ChoiceChip(
                selected: false,
                label: option,
                onSelected: (s) => onChipPressed(option)),
          if (widget.options.isEmpty)
            ChoiceChip(
              label: const Text('pages.printer_edit.no_values_found').tr(),
              selected: false,
              onSelected: (v) => null,
            ),
          if (widget.onAdd != null && widget.options.length < widget.maxOptions)
            ChoiceChip(
              backgroundColor: Theme.of(context).colorScheme.primary,
              label: Text(
                '+',
                style: DefaultTextStyle.of(context).style.copyWith(
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
              ),
              selected: false,
              onSelected: (v) => goIntoEditing(),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    textCtrler.dispose();
    super.dispose();
  }
}
