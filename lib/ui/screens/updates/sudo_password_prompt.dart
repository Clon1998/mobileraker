/*
 * Copyright (c) 2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/network/json_rpc_client.dart';
import 'package:common/service/moonraker/update_manager_service.dart';
import 'package:common/service/ui/dialog_service_interface.dart';
import 'package:common/service/ui/snackbar_service_interface.dart';
import 'package:common/util/logger.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/service/ui/dialog_service_impl.dart';
import 'package:mobileraker/ui/components/dialog/text_input/text_input_dialog.dart';

/// Asks for the sudo password Moonraker waits for and hands it over, so the pending tasks (e.g. an update) continue.
/// The password is only sent to Moonraker, which keeps it until it restarts.
Future<void> promptSudoPassword(ProviderContainer container, String machineUUID) async {
  final dialogService = container.read(dialogServiceProvider);
  final snackBarService = container.read(snackBarServiceProvider);
  final linuxUser = container.read(sudoRequestProvider(machineUUID)).value?.linuxUser;

  final res = await dialogService.show(
    DialogRequest(
      type: DialogType.textInput,
      title: tr('dialogs.sudo_password.title'),
      actionLabel: tr('dialogs.sudo_password.action'),
      data: TextInputDialogArguments(
        initialValue: '',
        obscureText: true,
        labelText: linuxUser == null
            ? tr('dialogs.sudo_password.label')
            : tr('dialogs.sudo_password.label_user', args: [linuxUser]),
        helperText: tr('dialogs.sudo_password.helper'),
        validator: FormBuilderValidators.required(),
      ),
    ),
  );
  final password = res?.data;
  if (res?.confirmed != true || password is! String) return;

  try {
    final responses = await container.read(sudoRequestProvider(machineUUID).notifier).submitPassword(password);
    snackBarService.show(
      SnackBarConfig(
        title: tr('dialogs.sudo_password.accepted'),
        message: responses.isEmpty ? null : responses.join('\n'),
      ),
    );
  } catch (e) {
    // Not the stack trace of the request: nothing of it may end up in the log.
    talker.warning('[UpdateManager] Moonraker did not accept the sudo password or a pending task failed');
    snackBarService.show(
      SnackBarConfig(
        type: SnackbarType.error,
        title: tr('dialogs.sudo_password.failed'),
        message: e is JRpcError ? e.message : e.toString(),
      ),
    );
  }
}
