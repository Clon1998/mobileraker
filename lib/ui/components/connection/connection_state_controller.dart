import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/data/data_source/json_rpc_client.dart';
import 'package:mobileraker/logger.dart';
import 'package:mobileraker/service/moonraker/jrpc_client_provider.dart';
import 'package:mobileraker/service/moonraker/klippy_service.dart';
import 'package:mobileraker/service/selected_machine_service.dart';
import 'package:mobileraker/util/extensions/async_ext.dart';

final connectionStateControllerProvider =
    StateNotifierProvider.autoDispose<ConnectionStateController, ClientState>(
        (ref) => ConnectionStateController(ref));

class ConnectionStateController extends StateNotifier<ClientState> {
  ConnectionStateController(this.ref) : super(ClientState.disconnected) {
    ref.listen<AsyncValue<ClientState>>(jrpcClientStateSelectedProvider,
        (previous, next) {
      if (next.isRefreshing) {
        state = ClientState.connecting;
      } else {
        next.whenData((value) {
          state = value;
        });
      }
    }, fireImmediately: true);
  }

  final AutoDisposeRef ref;

  onRetryPressed() {
    ref.read(jrpcClientSelectedProvider).openChannel();
  }

  String get clientErrorMessage {
    var jsonRpcClient = ref.read(jrpcClientSelectedProvider);
    Exception? errorReason = jsonRpcClient.errorReason;
    if (jsonRpcClient.requiresAPIKey) {
      return 'It seems like you configured trusted clients for moonraker. Please add the API key in the printers settings!';
    } else if (errorReason is TimeoutException) {
      return 'A timeout occurred while trying to connect to the machine! Ensure the machine can be reached from your current network...';
    } else if (errorReason != null) {
      return errorReason.toString();
    } else {
      return 'Error while trying to connect. Please retry later.';
    }
  }

  onChangeAppLifecycleState(_, AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        logger.i("App forgrounded");
        var selMachine = ref.read(selectedMachineProvider).valueOrFullNull;

        if (selMachine != null) {
          ref.refresh(jrpcClientProvider(selMachine.uuid));
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
}
