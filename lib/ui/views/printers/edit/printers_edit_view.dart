import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:mobileraker/domain/macro_group.dart';
import 'package:mobileraker/domain/printer_setting.dart';
import 'package:mobileraker/domain/temperature_preset.dart';
import 'package:mobileraker/domain/webcam_setting.dart';
import 'package:reorderables/reorderables.dart';
import 'package:stacked/stacked.dart';

import 'printers_edit_viewmodel.dart';

class PrintersEdit extends ViewModelBuilderWidget<PrintersEditViewModel> {
  const PrintersEdit({Key? key, required this.printerSetting})
      : super(key: key);
  final PrinterSetting printerSetting;

  @override
  Widget builder(
      BuildContext context, PrintersEditViewModel model, Widget? child) {
    var themeData = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'pages.printer_edit.title',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ).tr(args: [model.printerDisplayName]),
        actions: [
          if (model.canShowImportSettings)
            IconButton(
                icon: Icon(
                  FlutterIcons.import_mco,
                ),
                tooltip: 'pages.printer_edit.import_settings'.tr(),
                onPressed: model.onImportSettings),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: model.onFormConfirm,
        child: Icon(Icons.save_outlined),
      ),
      body: SingleChildScrollView(
        child: FormBuilder(
          autoFocusOnValidationFailure: true,
          key: model.formKey,
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
                  initialValue: model.printerDisplayName,
                  validator: FormBuilderValidators.compose(
                      [FormBuilderValidators.required(context)]),
                ),
                FormBuilderTextField(
                  decoration: InputDecoration(
                    labelText: 'pages.printer_edit.general.printer_addr'.tr(),
                    hintText: 'pages.printer_edit.general.full_url'.tr(),
                  ),
                  name: 'printerUrl',
                  initialValue: model.printerHttpUrl,
                  validator: FormBuilderValidators.compose([
                    FormBuilderValidators.required(context),
                    FormBuilderValidators.url(context,
                        protocols: ['http', 'https'], requireProtocol: true)
                  ]),
                ),
                FormBuilderTextField(
                  decoration: InputDecoration(
                    labelText: 'pages.printer_edit.general.ws_addr'.tr(),
                    hintText: 'pages.printer_edit.general.full_url'.tr(),
                  ),
                  name: 'wsUrl',
                  initialValue: model.printerWsUrl,
                  validator: FormBuilderValidators.compose([
                    FormBuilderValidators.required(context),
                    FormBuilderValidators.url(context,
                        protocols: ['ws', 'wss'], requireProtocol: true)
                  ]),
                ),
                FormBuilderTextField(
                  decoration: InputDecoration(
                      labelText:
                          'pages.printer_edit.general.moonraker_api_key'.tr(),
                      suffix: IconButton(
                        icon: Icon(Icons.qr_code_sharp),
                        onPressed: model.openQrScanner,
                      ),
                      helperText:
                          'pages.printer_edit.general.moonraker_api_desc'.tr(),
                      helperMaxLines: 3),
                  name: 'printerApiKey',
                  initialValue: model.printerApiKey,
                ),
                Divider(),
                _SectionHeader(
                    title: 'pages.printer_edit.motion_system.title'.tr()),
                FormBuilderSwitch(
                  name: 'invertX',
                  initialValue: model.printerInvertX,
                  title: Text('pages.printer_edit.motion_system.invert_x').tr(),
                  decoration: InputDecoration(
                      border: InputBorder.none, isCollapsed: true),
                  activeColor: themeData.colorScheme.primary,
                ),
                FormBuilderSwitch(
                  name: 'invertY',
                  initialValue: model.printerInvertY,
                  title: Text('pages.printer_edit.motion_system.invert_y').tr(),
                  decoration: InputDecoration(
                      border: InputBorder.none, isCollapsed: true),
                  activeColor: themeData.colorScheme.primary,
                ),
                FormBuilderSwitch(
                  name: 'invertZ',
                  initialValue: model.printerInvertZ,
                  title: Text('pages.printer_edit.motion_system.invert_z').tr(),
                  decoration: InputDecoration(
                      border: InputBorder.none, isCollapsed: true),
                  activeColor: themeData.colorScheme.primary,
                ),
                FormBuilderTextField(
                  name: 'speedXY',
                  initialValue: model.printerSpeedXY.toString(),
                  valueTransformer: (text) =>
                      (text != null) ? int.tryParse(text) : 0,
                  decoration: InputDecoration(
                      labelText:
                          'pages.printer_edit.motion_system.speed_xy'.tr(),
                      suffixText: 'mm/s',
                      isDense: true),
                  keyboardType: TextInputType.numberWithOptions(
                      signed: false, decimal: false),
                  validator: FormBuilderValidators.compose([
                    FormBuilderValidators.required(context),
                    FormBuilderValidators.min(context, 1)
                  ]),
                ),
                FormBuilderTextField(
                  name: 'speedZ',
                  initialValue: model.printerSpeedZ.toString(),
                  valueTransformer: (text) =>
                      (text != null) ? int.tryParse(text) : 0,
                  decoration: InputDecoration(
                      labelText:
                          'pages.printer_edit.motion_system.speed_z'.tr(),
                      suffixText: 'mm/s',
                      isDense: true),
                  keyboardType: TextInputType.numberWithOptions(
                      signed: false, decimal: false),
                  validator: FormBuilderValidators.compose([
                    FormBuilderValidators.required(context),
                    FormBuilderValidators.min(context, 1)
                  ]),
                ),
                Segments(
                  decoration: InputDecoration(
                      labelText:
                          'pages.printer_edit.motion_system.steps_move'.tr(),
                      suffixText: 'mm'),
                  options: model.printerMoveSteps
                      .map((e) =>
                          FormBuilderFieldOption(value: e, child: Text('$e')))
                      .toList(growable: false),
                  onSelected: model.removeMoveStep,
                  onAdd: model.addMoveStep,
                  inputType: TextInputType.number,
                ),
                Segments(
                  decoration: InputDecoration(
                      labelText:
                          'pages.printer_edit.motion_system.steps_baby'.tr(),
                      suffixText: 'mm'),
                  options: model.printerBabySteps
                      .map((e) =>
                          FormBuilderFieldOption(value: e, child: Text('$e')))
                      .toList(growable: false),
                  onSelected: model.removeBabyStep,
                  onAdd: model.addBabyStep,
                  inputType: TextInputType.numberWithOptions(decimal: true),
                ),
                Divider(),
                _SectionHeader(
                    title: 'pages.printer_edit.extruders.title'.tr()),
                FormBuilderTextField(
                  name: 'extrudeSpeed',
                  initialValue: model.printerExtruderFeedrate.toString(),
                  valueTransformer: (text) =>
                      (text != null) ? int.tryParse(text) : 0,
                  decoration: InputDecoration(
                      labelText: 'pages.printer_edit.extruders.feedrate'.tr(),
                      suffixText: 'mm/s',
                      isDense: true),
                  keyboardType: TextInputType.numberWithOptions(
                      signed: false, decimal: false),
                  validator: FormBuilderValidators.compose([
                    FormBuilderValidators.required(context),
                    FormBuilderValidators.min(context, 1)
                  ]),
                ),
                Segments(
                  decoration: InputDecoration(
                      labelText:
                          'pages.printer_edit.extruders.steps_extrude'.tr(),
                      suffixText: 'mm'),
                  options: model.printerExtruderSteps
                      .map((e) =>
                          FormBuilderFieldOption(value: e, child: Text('$e')))
                      .toList(growable: false),
                  onSelected: model.removeExtruderStep,
                  onAdd: model.addExtruderStep,
                  inputType: TextInputType.number,
                ),
                Divider(),
                _SectionHeaderWithAction(
                    title: 'pages.overview.control.macro_card.title'.tr(),
                    action: TextButton.icon(
                      onPressed: model.onMacroGroupAdd,
                      label: Text('general.add').tr(),
                      icon: Icon(Icons.source_outlined),
                    )),
                _buildMacroGroups(context, model),
                Divider(),
                _SectionHeaderWithAction(
                    title: 'pages.overview.general.cam_card.webcam'.tr(),
                    action: TextButton.icon(
                      onPressed: model.onWebCamAdd,
                      label: Text('general.add').tr(),
                      icon: Icon(FlutterIcons.webcam_mco),
                    )),
                _buildWebCams(model),
                Divider(),
                _SectionHeaderWithAction(
                    title: 'pages.overview.general.temp_card.temp_presets'.tr(),
                    action: TextButton.icon(
                      onPressed: model.onTempPresetAdd,
                      label: Text('general.add').tr(),
                      icon: Icon(FlutterIcons.thermometer_lines_mco),
                    )),
                _buildTempPresets(model),
                Divider(),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: TextButton.icon(
                      onPressed: model.onDeleteTap,
                      icon: Icon(Icons.delete_forever_outlined),
                      label: Text('pages.printer_edit.remove_printer').tr()),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  PrintersEditViewModel viewModelBuilder(BuildContext context) =>
      PrintersEditViewModel(printerSetting);

  Widget _buildWebCams(PrintersEditViewModel model) {
    if (model.webcams.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(8.0),
        child: Text('pages.printer_edit.cams.no_webcams').tr(),
      );
    }

    return ReorderableListView(
        buildDefaultDragHandles: false,
        physics: NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        children: List.generate(model.webcams.length, (index) {
          WebcamSetting cam = model.webcams[index];
          return _WebCamItem(
            key: ValueKey(cam.uuid),
            model: model,
            cam: cam,
            idx: index,
          );
        }),
        onReorder: model.onWebCamReorder);
  }

  Widget _buildTempPresets(PrintersEditViewModel model) {
    if (model.tempPresets.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(8.0),
        child: Text('pages.printer_edit.presets.no_presets').tr(),
      );
    }
    return ReorderableListView(
      buildDefaultDragHandles: false,
      physics: NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      children: List.generate(model.tempPresets.length, (index) {
        TemperaturePreset preset = model.tempPresets[index];
        return _TempPresetItem(
          key: ValueKey(preset.uuid),
          model: model,
          temperaturePreset: preset,
          idx: index,
        );
      }),
      onReorder: model.onPresetReorder,
    );
  }

  Widget _buildMacroGroups(BuildContext context, PrintersEditViewModel model) {
    if (model.macroGroups.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(8.0),
        child: Text(model.fetchingPrinter
            ? 'pages.printer_edit.macros.no_macros_found'
            : 'pages.printer_edit.macros.no_macros_available').tr(),
      );
    }

    return Column(
      children: List.generate(model.macroGroups.length, (index) {
        MacroGroup macroGroup = model.macroGroups[index];
        return _MacroGroup(
            model: model,
            macroGroup: macroGroup,
            showDisplayNameEdit: !model.isDefaultMacroGrp(macroGroup));
      }),
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

class _WebCamItem extends StatelessWidget {
  final WebcamSetting cam;
  final PrintersEditViewModel model;
  final int idx;

  _WebCamItem({
    Key? key,
    required this.model,
    required this.cam,
    required this.idx,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
        child: ExpansionTile(
            maintainState: true,
            tilePadding: const EdgeInsets.symmetric(horizontal: 10),
            childrenPadding: const EdgeInsets.symmetric(horizontal: 10),
            title: Text('CAM#$idx'),
            leading: ReorderableDragStartListener(
              index: idx,
              child: Icon(Icons.drag_handle),
            ),
            children: [
          FormBuilderTextField(
            decoration: InputDecoration(
              labelText: 'pages.printer_edit.general.displayname'.tr(),
            ),
            name: '${cam.uuid}-camName',
            initialValue: cam.name,
            validator: FormBuilderValidators.compose(
                [FormBuilderValidators.required(context)]),
          ),
          FormBuilderTextField(
            decoration: InputDecoration(
                labelText: 'pages.printer_edit.cams.webcam_addr'.tr(),
                helperText:
                    '${tr('pages.printer_edit.cams.default_addr')}: http://<URL>/webcam/?action=stream'),
            name: '${cam.uuid}-camUrl',
            initialValue: cam.url,
            validator: FormBuilderValidators.compose([
              FormBuilderValidators.required(context),
              FormBuilderValidators.url(context,
                  protocols: ['http', 'https'], requireProtocol: true)
            ]),
          ),
          FormBuilderSwitch(
            title: const Text('pages.printer_edit.cams.flip_vertical').tr(),
            decoration: InputDecoration(border: InputBorder.none),
            secondary: const Icon(FlutterIcons.swap_vertical_mco),
            initialValue: cam.flipVertical,
            name: '${cam.uuid}-camFV',
            activeColor: Theme.of(context).colorScheme.primary,
          ),
          FormBuilderSwitch(
            title: const Text('pages.printer_edit.cams.flip_horizontal').tr(),
            decoration: InputDecoration(border: InputBorder.none),
            secondary: const Icon(FlutterIcons.swap_horizontal_mco),
            initialValue: cam.flipHorizontal,
            name: '${cam.uuid}-camFH',
            activeColor: Theme.of(context).colorScheme.primary,
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: ElevatedButton(
              onPressed: () => model.onWebCamRemove(cam),
              child: const Text('general.remove').tr(),
            ),
          )
        ]));
  }
}

class _MacroGroup extends StatefulWidget {
  final MacroGroup macroGroup;
  final bool showDisplayNameEdit;
  final PrintersEditViewModel model;

  const _MacroGroup(
      {Key? key,
      required this.model,
      required this.macroGroup,
      this.showDisplayNameEdit = true})
      : super(key: key);

  @override
  _MacroGroupState createState() => _MacroGroupState();
}

class _MacroGroupState extends State<_MacroGroup> {
  late String _cardName = widget.macroGroup.name;

  @override
  Widget build(BuildContext context) {
    return Card(
        key: ValueKey(widget.macroGroup.uuid),
        child: ExpansionTile(
            maintainState: true,
            tilePadding: const EdgeInsets.symmetric(horizontal: 10),
            childrenPadding:
                const EdgeInsets.only(left: 10, right: 10, bottom: 10),
            title: DragTarget<int>(
              builder: (BuildContext context, List<int?> candidateData,
                  List<dynamic> rejectedData) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_cardName),
                    Chip(
                      label: Text('${widget.macroGroup.macros.length}'),
                      backgroundColor: Theme.of(context).colorScheme.background,
                    )
                  ],
                );
              },
              onAccept: (int d) => setState(() {
                widget.model.onGCodeDragAccepted(widget.macroGroup, d);
              }),
            ),
            children: [
              if (widget.showDisplayNameEdit)
                FormBuilderTextField(
                  decoration: InputDecoration(
                    labelText: 'pages.printer_edit.general.displayname'.tr(),
                  ),
                  name: '${widget.macroGroup.uuid}-macroName',
                  initialValue: widget.macroGroup.name,
                  onChanged: onNameChanged,
                  validator: FormBuilderValidators.compose(
                      [FormBuilderValidators.required(context)]),
                ),
              ReorderableWrap(
                spacing: 4.0,
                children: widget.macroGroup.macros
                    .map((m) => Chip(label: Text(m.beautifiedName)))
                    .toList(),
                buildDraggableFeedback: (context, constraint, widget) =>
                    Material(
                  color: Colors.transparent,
                  child: ConstrainedBox(
                    constraints: constraint,
                    child: widget,
                  ),
                ),
                onReorderStarted: (index) =>
                    widget.model.onGCodeDragStart(widget.macroGroup),
                onReorder: widget.model.onGCodeDragReordered,
              )
            ]));
  }

  void onNameChanged(String? name) {
    setState(() {
      _cardName = (name?.isEmpty ?? true) ? 'pages.printer_edit.macros.new_macro_grp'.tr() : name!;
    });
  }
}

class _TempPresetItem extends StatefulWidget {
  final TemperaturePreset temperaturePreset;
  final PrintersEditViewModel model;
  final int idx;

  const _TempPresetItem({
    Key? key,
    required this.model,
    required this.temperaturePreset,
    required this.idx,
  }) : super(key: key);

  @override
  _TempPresetItemState createState() => _TempPresetItemState();
}

class _TempPresetItemState extends State<_TempPresetItem> {
  late String _cardName = widget.temperaturePreset.name;

  @override
  Widget build(BuildContext context) {
    var temperaturePreset = widget.temperaturePreset;
    var model = widget.model;
    return Card(
        child: ExpansionTile(
            maintainState: true,
            tilePadding: const EdgeInsets.symmetric(horizontal: 10),
            childrenPadding: const EdgeInsets.symmetric(horizontal: 10),
            title: Text('$_cardName'),
            leading: ReorderableDragStartListener(
              index: widget.idx,
              child: Icon(Icons.drag_handle),
            ),
            children: [
          FormBuilderTextField(
            decoration: InputDecoration(
              labelText: 'pages.printer_edit.general.displayname'.tr(),
            ),
            name: '${temperaturePreset.uuid}-presetName',
            initialValue: temperaturePreset.name,
            onChanged: onNameChanged,
            validator: FormBuilderValidators.compose(
                [FormBuilderValidators.required(context)]),
          ),
          FormBuilderTextField(
            decoration: InputDecoration(
                labelText: '${tr('pages.printer_edit.presets.hotend_temp')} [°C]', helperText: ''),
            name: '${temperaturePreset.uuid}-extruderTemp',
            initialValue: temperaturePreset.extruderTemp.toString(),
            valueTransformer: (String? text) => (text != null)
                ? int.tryParse(text)
                : model.extruderMinTemperature,
            validator: FormBuilderValidators.compose(
              [
                FormBuilderValidators.required(context),
                FormBuilderValidators.min(context, 0),
                FormBuilderValidators.max(
                    context, model.extruderMaxTemperature),
              ],
            ),
            keyboardType: TextInputType.number,
          ),
          FormBuilderTextField(
            decoration: InputDecoration(
                labelText: '${tr('pages.printer_edit.presets.bed_temp')} [°C]', helperText: ''),
            name: '${temperaturePreset.uuid}-bedTemp',
            initialValue: temperaturePreset.bedTemp.toString(),
            valueTransformer: (String? text) =>
                (text != null) ? int.tryParse(text) : model.bedMinTemperature,
            validator: FormBuilderValidators.compose(
              [
                FormBuilderValidators.required(context),
                FormBuilderValidators.min(context, 0),
                FormBuilderValidators.max(context, model.bedMaxTemperature),
              ],
            ),
            keyboardType: TextInputType.number,
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: ElevatedButton(
              onPressed: () => model.onTempPresetRemove(temperaturePreset),
              child: Text('general.remove').tr(),
            ),
          )
        ]));
  }

  void onNameChanged(String? name) {
    setState(() {
      _cardName = (name?.isEmpty ?? true) ? 'pages.printer_edit.presets.new_preset'.tr() : name!;
    });
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

//ToDo: Better name for this widget
class Segments<T> extends StatefulWidget {
  const Segments(
      {Key? key,
      this.decoration = const InputDecoration(),
      this.maxOptions = 5,
      required this.options,
      this.onSelected,
      this.onAdd,
      this.inputType})
      : super(key: key);

  final InputDecoration decoration;

  final int maxOptions;

  final List<FormBuilderFieldOption<T>> options;

  final Function(T)? onSelected;

  final Function(String)? onAdd;

  final TextInputType? inputType;

  @override
  _SegmentsState<T> createState() => _SegmentsState<T>();
}

class _SegmentsState<T> extends State<Segments<T>> {
  bool editing = false;
  TextEditingController textCtrler = TextEditingController();

  submit() {
    setState(() {
      String curText = textCtrler.text;
      if (curText.isNotEmpty) widget.onAdd!(curText);
      editing = false;
    });
  }

  Future<bool> cancel() {
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
    return AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        transitionBuilder: (Widget child, Animation<double> animation) =>
            SizeTransition(
              sizeFactor: animation,
              child: child,
            ),
        child: editing ? buildEditing(context) : buildNonEditing(context));
  }

  WillPopScope buildEditing(BuildContext context) {
    return WillPopScope(
      onWillPop: () => cancel(),
      child: Row(
        children: [
          Expanded(
              child: TextField(
            controller: textCtrler,
            onEditingComplete: submit,
            decoration: widget.decoration,
            keyboardType: widget.inputType,
          )),
          IconButton(
            color: Theme.of(context).colorScheme.primary,
            icon: Icon(Icons.done),
            onPressed: submit,
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
              label: Text('pages.printer_edit.no_values_found').tr(),
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
}
