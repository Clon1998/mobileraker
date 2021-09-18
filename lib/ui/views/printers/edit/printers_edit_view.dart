import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:mobileraker/dto/machine/printer_setting.dart';
import 'package:mobileraker/dto/machine/temperature_preset.dart';
import 'package:mobileraker/dto/machine/webcam_setting.dart';
import 'package:stacked/stacked.dart';

import 'printers_edit_viewmodel.dart';

class PrintersEdit extends ViewModelBuilderWidget<PrintersEditViewModel> {
  const PrintersEdit({Key? key, required this.printerSetting})
      : super(key: key);
  final PrinterSetting printerSetting;

  @override
  Widget builder(
      BuildContext context, PrintersEditViewModel model, Widget? child) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Edit ${model.printerDisplayName}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
              onPressed: model.onFormConfirm,
              tooltip: 'Add printer',
              icon: Icon(Icons.save_outlined))
        ],
      ),
      body: SingleChildScrollView(
        child: FormBuilder(
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
                    FormBuilderValidators.url(context, protocols: ['http','https'], requireProtocol: true)
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
                    FormBuilderValidators.url(context, protocols: ['ws', 'wss'], requireProtocol: true)
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
                _SectionHeaderWithAction(
                    title: 'WEBCAM',
                    action: TextButton.icon(
                      onPressed: model.onWebCamAdd,
                      label: Text('Add'),
                      icon: Icon(FlutterIcons.webcam_mco),
                    )),
                ..._buildWebCams(model),
                _SectionHeaderWithAction(
                    title: 'TEMPERATURE PRESETS',
                    action: TextButton.icon(
                      onPressed: model.onTempPresetAdd,
                      label: Text('Add'),
                      icon: Icon(FlutterIcons.thermometer_lines_mco),
                    )),
                ..._buildTempPresets(model),
                Divider(),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: TextButton.icon(
                      onPressed: model.onDeleteTap,
                      icon: Icon(Icons.delete_forever_outlined),
                      label: Text('Remove printer')),
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

  List<Widget> _buildWebCams(PrintersEditViewModel model) {
    if (model.webcams.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text('No webcams added'),
        )
      ];
    }

    return List.generate(model.webcams.length, (index) {
      WebcamSetting cam = model.webcams[index];
      return _WebCamItem(
        key: ValueKey(cam.uuid),
        model: model,
        cam: cam,
        idx: index,
      );
    });
  }

  List<Widget> _buildTempPresets(PrintersEditViewModel model) {
    if (model.tempPresets.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text('No presets added'),
        )
      ];
    }

    return List.generate(model.tempPresets.length, (index) {
      TemperaturePreset preset = model.tempPresets[index];
      return _TempPresetItem(
        key: ValueKey(preset.uuid),
        model: model,
        temperaturePreset: preset,
        idx: index,
      );
    });
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
          title,
          style: TextStyle(
            color: Theme.of(context).accentColor,
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
            tilePadding: EdgeInsets.symmetric(horizontal: 10),
            childrenPadding: EdgeInsets.symmetric(horizontal: 10),
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
          ),
          FormBuilderSwitch(
            title: const Text('Flip horizontal'),
            decoration: InputDecoration(border: InputBorder.none),
            secondary: const Icon(FlutterIcons.swap_horizontal_mco),
            initialValue: cam.flipHorizontal,
            name: '${cam.uuid}-camFH',
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
            tilePadding: EdgeInsets.symmetric(horizontal: 10),
            childrenPadding: EdgeInsets.symmetric(horizontal: 10),
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
                FormBuilderValidators.min(
                    context, 0),
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
          color: Theme.of(context).accentColor,
          fontSize: 12.0,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
