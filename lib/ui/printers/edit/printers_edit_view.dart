import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:mobileraker/dto/machine/PrinterSetting.dart';
import 'package:mobileraker/dto/machine/WebcamSetting.dart';
import 'package:stacked/stacked.dart';

import 'printers_edit_viewmodel.dart';

class PrintersEdit extends StatelessWidget {
  const PrintersEdit({Key? key, required this.printerSetting})
      : super(key: key);
  final PrinterSetting printerSetting;

  @override
  Widget build(BuildContext context) {
    return ViewModelBuilder<PrintersEditViewModel>.reactive(
        builder: (context, model, child) {
          return Scaffold(
            appBar: AppBar(
              title: Text('Edit'),
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
                        initialValue: model.printerSetting.name,
                        validator: FormBuilderValidators.compose(
                            [FormBuilderValidators.required(context)]),
                      ),
                      FormBuilderTextField(
                        decoration: InputDecoration(
                            labelText: 'Printer-Address',
                            helperText: model.wsUrl != null
                                ? 'WS-URL: ${model.wsUrl}'
                                : '' //TODO
                            ),
                        onChanged: model.onUrlEntered,
                        name: 'printerUrl',
                        initialValue: model.inputUrl,
                        validator: FormBuilderValidators.compose([
                          FormBuilderValidators.required(context),
                          FormBuilderValidators.url(context,
                              protocols: ['ws', 'wss'])
                        ]),
                      ),
                      Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'WEBCAM',
                            style: TextStyle(
                              color: Theme.of(context).accentColor,
                              fontSize: 12.0,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextButton.icon(
                            onPressed: model.onWebCamAdd,
                            label: Text('Add'),
                            icon: Icon(FlutterIcons.webcam_mco),
                          )
                        ],
                      ),
                      ..._buildWebCams(model),
                      Divider(),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
        viewModelBuilder: () => PrintersEditViewModel(printerSetting));
  }

  List<Widget> _buildWebCams(PrintersEditViewModel model) {
    if (model.webcams.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text('No webcams added'),
        )
      ];
    }

    List<Widget> camW = List.generate(model.webcams.length, (index) {
      WebcamSetting cam = model.webcams[index];
      return _WebCamItem(
        key: ValueKey(cam.uuid),
        model: model,
        cam: cam,
        idx: index,
      );
    });
    return camW;
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
                helperText: 'Default address: http://<URL>/webcam/?action=stream'),
            name: '${cam.uuid}-camUrl',
            initialValue: cam.url,
            validator: FormBuilderValidators.compose([
              FormBuilderValidators.required(context),
              FormBuilderValidators.url(context, protocols: ['http', 'https'], requireProtocol: true)
            ]),
          ),
          FormBuilderSwitch(
            title: const Text('Flip vertical'),
            decoration: InputDecoration(
                border: InputBorder.none
            ),
            secondary: const Icon(FlutterIcons.swap_horizontal_mco),
            initialValue: cam.flipVertical,
            name: '${cam.uuid}-camFV',
          ),
          FormBuilderSwitch(
            title: const Text('Flip horizontal'),
            decoration: InputDecoration(
                border: InputBorder.none
            ),
            secondary: const Icon(FlutterIcons.swap_vertical_mco),
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
