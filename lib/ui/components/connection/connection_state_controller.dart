import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobileraker/data/data_source/json_rpc_client.dart';
import 'package:mobileraker/data/model/hive/machine.dart';
import 'package:mobileraker/exceptions.dart';
import 'package:mobileraker/logger.dart';
import 'package:mobileraker/routing/app_router.dart';
import 'package:mobileraker/service/machine_service.dart';
import 'package:mobileraker/service/moonraker/jrpc_client_provider.dart';
import 'package:mobileraker/service/moonraker/klippy_service.dart';
import 'package:mobileraker/service/selected_machine_service.dart';
import 'package:mobileraker/util/extensions/async_ext.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:url_launcher/url_launcher.dart';

part 'connection_state_controller.g.dart';

@riverpod
class ConnectionStateController extends _$ConnectionStateController {
  @override
  Future<ClientState> build() async =>
      ref.watch(jrpcClientStateSelectedProvider.future);

  onRetryPressed() {
    ref.read(jrpcClientSelectedProvider).openChannel();
  }

  String get clientErrorMessage {
    var jsonRpcClient = ref.read(jrpcClientSelectedProvider);
    Exception? errorReason = jsonRpcClient.errorReason;
    if (errorReason is TimeoutException) {
      return 'A timeout occurred while trying to connect to the machine! Ensure the machine can be reached from your current network...';
    } else if (errorReason is OctoEverywhereException) {
      return 'OctoEverywhere returned: ${errorReason.message}';
    } else if (errorReason != null) {
      return errorReason.toString();
    } else {
      return 'Error while trying to connect. Please retry later.';
    }
  }

  bool get errorIsOctoSupportedExpired {
    var jsonRpcClient = ref.read(jrpcClientSelectedProvider);
    Exception? errorReason = jsonRpcClient.errorReason;
    if (errorReason is! OctoEverywhereHttpException) {
      return false;
    }

    return errorReason.statusCode == 605;
  }

  onChangeAppLifecycleState(_, AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        logger.i("App forgrounded");
        var selMachine = ref.read(selectedMachineProvider).valueOrFullNull;

        if (selMachine != null) {
          logger.i('Refreshing selectedPrinter...');
          ref.invalidate(machineProvider(selMachine.uuid));
        }

        break;

      case AppLifecycleState.paused:
        logger.i("App backgrounded");
        break;
      default:
        logger.i("App in $state");
    }
  }

  onRestartKlipperPressed() {
    ref.read(klipperServiceSelectedProvider).restartKlipper();
  }

  onRestartMCUPressed() {
    ref.read(klipperServiceSelectedProvider).restartMCUs();
  }

  onEditPrinter() async {
    Machine? machine = await ref.read(selectedMachineProvider.future);
    if (machine != null) {
      ref
          .read(goRouterProvider)
          .pushNamed(AppRoute.printerEdit.name, extra: machine);
    }
  }

  onGoToOE() async {
    var oeURI = Uri.parse(
        'https://octoeverywhere.com/appportal/v1/nosupporterperks?moonraker=true&appid=mobileraker');
    if (await canLaunchUrl(oeURI)) {
      await launchUrl(oeURI, mode: LaunchMode.externalApplication);
    } else {
      throw 'Could not launch $oeURI';
    }
  }
}
