import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:stacked/stacked.dart';

import 'printers_add_viewmodel.dart';

class PrintersAdd extends StatelessWidget {
  const PrintersAdd({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ViewModelBuilder<PrintersAddViewModel>.reactive(
        builder: (context, model, child) {
          return Scaffold(
            appBar: AppBar(
              title: Text('Add new printer'),
            ),
            body: FormBuilder(
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
                      validator: FormBuilderValidators.compose(
                          [FormBuilderValidators.required(context)]),
                    ),
                    FormBuilderTextField(
                      decoration: InputDecoration(
                        labelText: 'Printer-Address',
                      ),
                      name: 'printerUrl',
                      initialValue: 'mainsailos.local',
                      validator: FormBuilderValidators.compose([
                        FormBuilderValidators.required(context),
                        FormBuilderValidators.url(context)
                      ]),
                    ),
                    Divider(),
                    _SectionHeader(title: 'Misc'),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Connection is not tested'),
                        ElevatedButton(
                            onPressed: model.onTestConnectionTap, child: Text('Test'))
                      ],
                    ),
                    TextButton(
                      onPressed: model.onFormConfirm,
                      child: Text('Add printer'),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
        viewModelBuilder: () => PrintersAddViewModel());
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
