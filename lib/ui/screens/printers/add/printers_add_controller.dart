/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:mobileraker/data/data_source/json_rpc_client.dart';
import 'package:mobileraker/data/dto/octoeverywhere/app_connection_info_response.dart';
import 'package:mobileraker/data/dto/octoeverywhere/app_portal_result.dart';
import 'package:mobileraker/data/model/hive/machine.dart';
import 'package:mobileraker/data/model/hive/octoeverywhere.dart';
import 'package:mobileraker/exceptions.dart';
import 'package:mobileraker/logger.dart';
import 'package:mobileraker/routing/app_router.dart';
import 'package:mobileraker/service/machine_service.dart';
import 'package:mobileraker/service/octoeverywhere/app_connection_service.dart';
import 'package:mobileraker/service/ui/snackbar_service.dart';
import 'package:mobileraker/ui/screens/qr_scanner/qr_scanner_page.dart';
import 'package:mobileraker/util/misc.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'printers_add_controller.g.dart';

@riverpod
GlobalKey<FormBuilderState> simpleFormKey(SimpleFormKeyRef ref) {
  return GlobalKey<FormBuilderState>();
}

@riverpod
GlobalKey<FormBuilderState> advancedFormKey(AdvancedFormKeyRef ref) {
  return GlobalKey<FormBuilderState>();
}

final printerAddViewController = StateNotifierProvider.autoDispose<
        PrinterAddViewController, AsyncValue<ClientState>>(
    name: 'printerAddViewController', (ref) => PrinterAddViewController(ref));

class PrinterAddViewController extends StateNotifier<AsyncValue<ClientState>> {
  PrinterAddViewController(this.ref)
      : _appConnectionService = ref.watch(appConnectionServiceProvider),
        _snackBarService = ref.watch(snackBarServiceProvider),
        super(const AsyncValue.loading());

  final AutoDisposeRef ref;
  final AppConnectionService _appConnectionService;
  final SnackBarService _snackBarService;

  StreamSubscription? _testConnectionRPCState;

  onFormConfirm() async {
    var formState = ref.read(simpleFormKeyProvider).currentState!;
    if (formState.saveAndValidate()) {
      var printerName = formState.value['printerName'];
      var printerAPIKey = formState.value['printerApiKey'];
      var printerUrl = formState.value['printerUrl'];
      var trustSelfSigned = formState.value['trustSelfSigned'];
      String wsUrl = urlToWebsocketUrl(printerUrl);
      String httpUrl = urlToHttpUrl(printerUrl);

      var machine = Machine(
          name: printerName,
          wsUrl: wsUrl,
          httpUrl: httpUrl,
          trustUntrustedCertificate: trustSelfSigned,
          apiKey: printerAPIKey);
      await ref.read(machineServiceProvider).addMachine(machine);
      ref.read(goRouterProvider).goNamed(AppRoute.dashBoard.name);
    }
  }

  onTestConnectionTap() async {
    var formState = ref.read(simpleFormKeyProvider).currentState!;

    logger.e('onTestConnectionTap');

    if (formState.saveAndValidate()) {
      var printerUrl = formState.value['printerUrl'];
      var printerAPIKey = formState.value['printerApiKey'];
      var trustSelfSigned = formState.value['trustSelfSigned'];
      printerUrl = urlToWebsocketUrl(printerUrl);

      var jsonRpcClientBuilder = JsonRpcClientBuilder()
        ..uri = Uri.parse(printerUrl)
        ..apiKey = printerAPIKey
        ..trustSelfSignedCertificate = trustSelfSigned;
      var jsonRpcClient = jsonRpcClientBuilder.build();
      jsonRpcClient.openChannel();
      _testConnectionRPCState = jsonRpcClient.stateStream.listen((event) {
        state = AsyncValue.data(event);
      });

      await stream.firstWhere((element) => [
            ClientState.connected,
            ClientState.error
          ].contains(element.valueOrNull));

      if (mounted) {
        if (jsonRpcClient.hasError) {
          state =
              AsyncValue.error(jsonRpcClient.errorReason!, StackTrace.current);
        }
      }
      _testConnectionRPCState?.cancel();
      jsonRpcClient.dispose();
    } else {
      ref.read(snackBarServiceProvider).show(SnackBarConfig(
            type: SnackbarType.error,
            message: 'Input validation failed!',
          ));
    }
  }

  openQrScanner(BuildContext context) async {
    Barcode? qr = await Navigator.of(context)
        .push(MaterialPageRoute(builder: (ctx) => const QrScannerPage()));
    if (qr?.rawValue != null) {
      ref
          .read(simpleFormKeyProvider)
          .currentState
          ?.fields['printerApiKey']
          ?.didChange(qr!.rawValue);
    }
  }

  addUsingOctoeverywhere() async {
    AppPortalResult appPortalResult =
        await _appConnectionService.linkAppWithOcto();

    try {
      AppConnectionInfoResponse appConnectionInfo =
          await _appConnectionService.getInfo(appPortalResult.appApiToken);

      var infoResult = appConnectionInfo.result;
      var localIp = infoResult.printerLocalIp;
      logger.i('OctoEverywhere returned Local IP: $localIp');

      if (localIp == null) {
        throw const OctoEverywhereException(
            'Could not retrieve Printer\'s local IP.');
      }

      String wsUrl = urlToWebsocketUrl(localIp);
      String httpUrl = urlToHttpUrl(localIp);

      var machine = Machine(
          name: infoResult.printerName,
          wsUrl: wsUrl,
          httpUrl: httpUrl,
          trustUntrustedCertificate: false,
          octoEverywhere: OctoEverywhere.fromDto(appPortalResult));
      machine = await ref.read(machineServiceProvider).addMachine(machine);

      ref.read(goRouterProvider).goNamed(AppRoute.dashBoard.name);
    } on OctoEverywhereException catch (e, s) {
      logger.e('Error while trying to add printer via Ocot', e, s);
      _snackBarService.show(SnackBarConfig(
          type: SnackbarType.error,
          title: 'OctoEverywhere-Error:',
          message: e.message));
    }
  }

  @override
  void dispose() {
    super.dispose();
    _testConnectionRPCState?.cancel();
  }
}
//
// class PrinterAddViewModel extends StreamViewModel<ClientState> {
//   final String defaultPrinterName = 'My Printer';
//
//   Stream<ClientState> _wsStream = Stream<ClientState>.empty();
//
//   GlobalKey get formKey => _fbKey;
//
//   String inputUrl = '';
//
//   JsonRpcClient? _testWebSocket;
//
//   String get wsResult {
//     if (_testWebSocket?.requiresAPIKey ?? false) {
//       return 'Requires API-Key';
//     }
//
//     if (dataReady) {
//       switch (data) {
//         case ClientState.connecting:
//           return 'connecting';
//         case ClientState.connected:
//           return 'connected';
//         case ClientState.error:
//           return 'error';
//         default:
//           return 'Unknown';
//       }
//     }
//
//     return 'not tested';
//   }
//
//   String? get wsError {
//     if (dataReady) {
//       return _testWebSocket?.errorReason?.toString();
//     }
//     return null;
//   }
//
//   Color get wsStateColor {
//     if (!dataReady) return Colors.red;
//     switch (data) {
//       case ClientState.connected:
//         return Colors.green;
//       case ClientState.error:
//         return Colors.red;
//       case ClientState.disconnected:
//       case ClientState.connecting:
//       default:
//         return Colors.orange;
//     }
//   }
//
//   String? get wsUrl {
//     return urlToWebsocketUrl(inputUrl);
//   }
//
//   String? get httpUrl {
//     return urlToHttpUrl(inputUrl);
//   }
//
//   onUrlEntered(value) {
//     inputUrl = value;
//     notifyListeners();
//   }
//
//   @override
//   Stream<ClientState> get stream => _wsStream;
//
//   openQrScanner() async {
//     var readValue = await _navigationService.navigateTo(Routes.qrScannerView);
//     if (readValue != null) {
//       _fbKey.currentState?.fields['printerApiKey']?.didChange(readValue);
//     }
//     // printerApiKey = resu;
//   }
// }
