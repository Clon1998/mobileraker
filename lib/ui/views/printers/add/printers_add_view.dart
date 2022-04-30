import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:mobileraker/datasource/json_rpc_client.dart';
import 'package:stacked/stacked.dart';

import 'printers_add_viewmodel.dart';

class PrinterAdd extends StatelessWidget {
  const PrinterAdd({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ViewModelBuilder<PrinterAddViewModel>.reactive(
        builder: (context, model, child) {
          return Scaffold(
            appBar: AppBar(
              title: Text('pages.printer_add.title').tr(),
              actions: [
                IconButton(
                    onPressed: model.onFormConfirm,
                    tooltip: 'pages.printer_add.title'.tr(),
                    icon: Icon(Icons.save_outlined))
              ],
            ),
            body: FormBuilder(
              key: model.formKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: Column(
                    children: <Widget>[
                      _SectionHeader(title: 'pages.setting.general.title'.tr()),
                      FormBuilderTextField(
                        decoration: InputDecoration(
                          labelText:
                              'pages.printer_edit.general.displayname'.tr(),
                        ),
                        name: 'printerName',
                        initialValue: model.defaultPrinterName,
                        validator: FormBuilderValidators.compose(
                            [FormBuilderValidators.required()]),
                      ),
                      FormBuilderTextField(
                        decoration: InputDecoration(
                            labelText:
                                'pages.printer_edit.general.printer_addr'.tr(),
                            hintText:
                                'pages.printer_add.printer_add_helper'.tr(),
                            helperMaxLines: 2,
                            helperText: model.wsUrl?.isNotEmpty ?? false
                                ? 'pages.printer_add.resulting_ws_url'
                                    .tr(args: [model.wsUrl.toString()])
                                : '' //TODO
                            ),
                        onChanged: model.onUrlEntered,
                        name: 'printerUrl',
                        // initialValue: model.inputUrl,
                        validator: FormBuilderValidators.compose([
                          FormBuilderValidators.required(),
                          FormBuilderValidators.url(
                              protocols: ['ws', 'wss', 'http', 'https'])
                        ]),
                      ),
                      FormBuilderTextField(
                        decoration: InputDecoration(
                            labelText:
                                'pages.printer_edit.general.moonraker_api_key'
                                    .tr(),
                            suffix: IconButton(
                              icon: Icon(Icons.qr_code_sharp),
                              onPressed: model.openQrScanner,
                            ),
                            helperText:
                                'pages.printer_edit.general.moonraker_api_desc'
                                    .tr(),
                            helperMaxLines: 3),
                        name: 'printerApiKey',
                      ),
                      Divider(),
                      _SectionHeader(title: 'pages.printer_add.misc'.tr()),
                      InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'pages.printer_add.test_ws'.tr(),
                          border: InputBorder.none,
                          errorText: model.wsError,
                          errorMaxLines: 3,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.radio_button_on,
                              size: 10,
                              color: model.wsStateColor,
                            ),
                            Spacer(flex: 1),
                            Text('pages.printer_add.result_ws_test')
                                .tr(args: [model.wsResult]),
                            Spacer(flex: 30),
                            ElevatedButton(
                                onPressed:
                                    (model.data != ClientState.connecting)
                                        ? model.onTestConnectionTap
                                        : null,
                                child:
                                    Text('pages.printer_add.run_test_btn').tr())
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
        viewModelBuilder: () => PrinterAddViewModel());
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
