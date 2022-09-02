import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/data/data_source/json_rpc_client.dart';
import 'package:mobileraker/service/ui/dialog_service.dart';
import 'package:mobileraker/util/extensions/async_ext.dart';
import 'package:mobileraker/util/misc.dart';

import 'printers_add_controller.dart';

class PrinterAddPage extends ConsumerWidget {
  const PrinterAddPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('pages.printer_add.title').tr(),
        actions: [
          IconButton(
              onPressed:
                  ref.read(printerAddViewController.notifier).onFormConfirm,
              tooltip: 'pages.printer_add.title'.tr(),
              icon: const Icon(Icons.save_outlined))
        ],
      ),
      body: FormBuilder(
        key: ref.watch(formAddKeyProvider),
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: SingleChildScrollView(
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
                  initialValue: 'My Printer',
                  validator: FormBuilderValidators.compose(
                      [FormBuilderValidators.required()]),
                ),
                const WSInput(),
                FormBuilderTextField(
                  decoration: InputDecoration(
                      labelText:
                          'pages.printer_edit.general.moonraker_api_key'.tr(),
                      suffix: IconButton(
                        icon: const Icon(Icons.qr_code_sharp),
                        onPressed: ref
                            .watch(printerAddViewController.notifier)
                            .openQrScanner,
                      ),
                      helperText:
                          'pages.printer_edit.general.moonraker_api_desc'.tr(),
                      helperMaxLines: 3),
                  name: 'printerApiKey',
                ),
                const Divider(),
                _SectionHeader(title: 'pages.printer_add.misc'.tr()),
                InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'pages.printer_add.test_ws'.tr(),
                    border: InputBorder.none,
                    errorText: ref.watch(printerAddViewController.select(
                        (value) =>
                            value.hasError ? value.error.toString() : null)),
                    errorMaxLines: 3,
                  ),
                  child: const TestConnection(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class TestConnection extends ConsumerWidget {
  const TestConnection({
    Key? key,
  }) : super(key: key);

  String stateToText(ClientState? state) {
    if (state == null) {
      return 'not tested';
    }
    switch (state) {
      case ClientState.connecting:
        return 'connecting';
      case ClientState.connected:
        return 'connected';
      case ClientState.error:
        return 'error';
      default:
        return 'Unknown';
    }
  }

  Color stateToColor(ClientState? state) {
    if (state == null) return Colors.grey;
    switch (state) {
      case ClientState.connected:
        return Colors.green;
      case ClientState.error:
        return Colors.red;
      case ClientState.connecting:
        return Colors.lime;
      case ClientState.disconnected:
      default:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var state = ref.watch(printerAddViewController).valueOrFullNull;

    return Row(
      children: [
        Icon(
          Icons.radio_button_on,
          size: 10,
          color: stateToColor(state),
        ),
        const Spacer(flex: 1),
        const Text('pages.printer_add.result_ws_test')
            .tr(args: [stateToText(state)]),
        const Spacer(flex: 30),
        ElevatedButton(
            onPressed: ref.watch(printerAddViewController.select((data) =>
                data.valueOrFullNull != ClientState.connecting
                    ? ref
                        .read(printerAddViewController.notifier)
                        .onTestConnectionTap
                    : null)),
            child: const Text('pages.printer_add.run_test_btn').tr())
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({Key? key, required this.title}) : super(key: key);

  final String title;

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

class WSInput extends HookConsumerWidget {
  const WSInput({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var wsUrl = useState('');
    return FormBuilderTextField(
      decoration: InputDecoration(
          labelText: 'pages.printer_edit.general.printer_addr'.tr(),
          hintText: 'pages.printer_add.printer_add_helper'.tr(),
          helperMaxLines: 3,
          helperText: (wsUrl.value.isNotEmpty)
              ? 'pages.printer_add.resulting_ws_url'.tr(args: [wsUrl.value])
              : null,
          suffix: IconButton(
            icon: const Icon(
              Icons.question_mark,
            ),
            onPressed: () {
              ref.read(dialogServiceProvider).show(DialogRequest(
                  type: DialogType.info,
                  title: tr('dialogs.ws_input_help.title'),
                  body:
                      '${tr('dialogs.ws_input_help.body')}'
                          '\n192.168.1.1'
                          '\n192.168.1.1:7125'
                          '\nhttp://myprinter.com'
                          '\nws://myprinter.com/socket',
                  cancelBtn: 'Close'));
            },
          )),
      onChanged: (input) {
        if (input != null) wsUrl.value = urlToWebsocketUrl(input);
      },
      name: 'printerUrl',
      // initialValue: model.inputUrl,
      validator: FormBuilderValidators.compose([
        FormBuilderValidators.required(),
        FormBuilderValidators.url(protocols: ['ws', 'wss', 'http', 'https'])
      ]),
    );
  }
}
