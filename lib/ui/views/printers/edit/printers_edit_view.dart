import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_icons/flutter_icons.dart';
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
          'Edit ${model.printerDisplayName}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (model.canShowImportSettings)
            IconButton(
                icon: Icon(
                  FlutterIcons.import_mco,
                ),
                tooltip: 'Import-Settings',
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
                _SectionHeader(title: 'General'),
                FormBuilderTextField(
                  decoration: InputDecoration(
                    labelText: 'Displayname',
                  ),
                  name: 'printerName',
                  initialValue: model.printerDisplayName,
                  validator: FormBuilderValidators.compose(
                      [FormBuilderValidators.required(context)]),
                ),
                FormBuilderTextField(
                  decoration: InputDecoration(
                    labelText: 'Printer-Address',
                    hintText: 'Full URL',
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
                    labelText: 'Websocket-Address',
                    hintText: 'Full URL',
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
                      labelText: 'Moonraker - API Key',
                      helperText:
                          'Only needed if youre using trusted clients. FluiddPI enforces this!'),
                  name: 'printerApiKey',
                  initialValue: model.printerApiKey,
                ),
                Divider(),
                _SectionHeader(title: 'Motion System'),
                FormBuilderSwitch(
                  name: 'invertX',
                  initialValue: model.printerInvertX,
                  title: Text('Invert X-Axis'),
                  decoration: InputDecoration(
                      border: InputBorder.none, isCollapsed: true),
                  activeColor: themeData.colorScheme.primary,
                ),
                FormBuilderSwitch(
                  name: 'invertY',
                  initialValue: model.printerInvertY,
                  title: Text('Invert Y-Axis'),
                  decoration: InputDecoration(
                      border: InputBorder.none, isCollapsed: true),
                  activeColor: themeData.colorScheme.primary,
                ),
                FormBuilderSwitch(
                  name: 'invertZ',
                  initialValue: model.printerInvertZ,
                  title: Text('Invert Z-Axis'),
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
                      labelText: 'Speed X/Y-Axis',
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
                      labelText: 'Speed Z-Axis',
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
                      labelText: 'Move steps', suffixText: 'mm'),
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
                      labelText: 'Babystepping Z-steps', suffixText: 'mm'),
                  options: model.printerBabySteps
                      .map((e) =>
                          FormBuilderFieldOption(value: e, child: Text('$e')))
                      .toList(growable: false),
                  onSelected: model.removeBabyStep,
                  onAdd: model.addBabyStep,
                  inputType: TextInputType.numberWithOptions(decimal: true),
                ),
                Divider(),
                _SectionHeader(title: 'Extruder(s)'),
                FormBuilderTextField(
                  name: 'extrudeSpeed',
                  initialValue: model.printerExtruderFeedrate.toString(),
                  valueTransformer: (text) =>
                      (text != null) ? int.tryParse(text) : 0,
                  decoration: InputDecoration(
                      labelText: 'Extruder feed rate',
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
                      labelText: 'Extrude steps', suffixText: 'mm'),
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
                    title: 'WEBCAM',
                    action: TextButton.icon(
                      onPressed: model.onWebCamAdd,
                      label: Text('Add'),
                      icon: Icon(FlutterIcons.webcam_mco),
                    )),
                _buildWebCams(model),
                Divider(),
                _SectionHeaderWithAction(
                    title: 'TEMPERATURE PRESETS',
                    action: TextButton.icon(
                      onPressed: model.onTempPresetAdd,
                      label: Text('Add'),
                      icon: Icon(FlutterIcons.thermometer_lines_mco),
                    )),
                _buildTempPresets(model),
                Divider(),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: TextButton.icon(
                      onPressed: model.onDeleteTap,
                      icon: Icon(Icons.delete_forever_outlined),
                      label: Text('Remove Printer')),
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
        child: Text('No webcams added'),
      );
    }

    return ReorderableColumn(
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
        child: Text('No presets added'),
      );
    }
    return ReorderableColumn(
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
            children: [
          FormBuilderTextField(
            decoration: InputDecoration(
              labelText: 'Displayname',
            ),
            name: '${cam.uuid}-camName',
            initialValue: cam.name,
            validator: FormBuilderValidators.compose(
                [FormBuilderValidators.required(context)]),
          ),
          FormBuilderTextField(
            decoration: InputDecoration(
                labelText: 'Webcam-Address',
                helperText:
                    'Default address: http://<URL>/webcam/?action=stream'),
            name: '${cam.uuid}-camUrl',
            initialValue: cam.url,
            validator: FormBuilderValidators.compose([
              FormBuilderValidators.required(context),
              FormBuilderValidators.url(context,
                  protocols: ['http', 'https'], requireProtocol: true)
            ]),
          ),
          FormBuilderSwitch(
            title: const Text('Flip vertical'),
            decoration: InputDecoration(border: InputBorder.none),
            secondary: const Icon(FlutterIcons.swap_vertical_mco),
            initialValue: cam.flipVertical,
            name: '${cam.uuid}-camFV',
            activeColor: Theme.of(context).colorScheme.primary,
          ),
          FormBuilderSwitch(
            title: const Text('Flip horizontal'),
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
              child: Text('Remove'),
            ),
          )
        ]));
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
            children: [
          FormBuilderTextField(
            decoration: InputDecoration(
              labelText: 'Displayname',
            ),
            name: '${temperaturePreset.uuid}-presetName',
            initialValue: temperaturePreset.name,
            onChanged: onNameChanged,
            validator: FormBuilderValidators.compose(
                [FormBuilderValidators.required(context)]),
          ),
          FormBuilderTextField(
            decoration: InputDecoration(
                labelText: 'Extruder Temperature [°C]', helperText: ''),
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
                labelText: 'Bed Temperature [°C]', helperText: ''),
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
              child: Text('Remove'),
            ),
          )
        ]));
  }

  void onNameChanged(String? name) {
    setState(() {
      _cardName = (name?.isEmpty ?? true) ? 'New Preset' : name!;
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
              label: Text('No values Found!'),
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
