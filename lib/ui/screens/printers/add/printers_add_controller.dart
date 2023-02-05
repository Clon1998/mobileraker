import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_web_auth/flutter_web_auth.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/data/data_source/json_rpc_client.dart';
import 'package:mobileraker/data/dto/octoeverywhere/app_connection_info_response.dart';
import 'package:mobileraker/data/dto/octoeverywhere/app_portal_result.dart';
import 'package:mobileraker/data/model/hive/machine.dart';
import 'package:mobileraker/data/model/hive/octoeverywhere.dart';
import 'package:mobileraker/data/repository/octo_everywhere_hive_repository.dart';
import 'package:mobileraker/exceptions.dart';
import 'package:mobileraker/logger.dart';
import 'package:mobileraker/routing/app_router.dart';
import 'package:mobileraker/service/machine_service.dart';
import 'package:mobileraker/service/octoeverywhere/app_connection_service.dart';
import 'package:mobileraker/service/ui/snackbar_service.dart';
import 'package:mobileraker/ui/screens/qr_scanner/qr_scanner_page.dart';
import 'package:mobileraker/util/misc.dart';

final formAddKeyProvider = Provider.autoDispose<GlobalKey<FormBuilderState>>(
    name: 'formAddKeyProvider', (ref) => GlobalKey<FormBuilderState>());

final printerAddViewController = StateNotifierProvider.autoDispose<
    PrinterAddViewController,
    AsyncValue<ClientState>>(
    name: 'printerAddViewController', (ref) => PrinterAddViewController(ref));

class PrinterAddViewController extends StateNotifier<AsyncValue<ClientState>> {
  PrinterAddViewController(this.ref)
      :appConnectionService=ref.watch(appConnectionServiceProvider),
        super(const AsyncValue.loading());

  final AutoDisposeRef ref;
  AppConnectionService appConnectionService;


  onFormConfirm() async {
    var formState = ref
        .read(formAddKeyProvider)
        .currentState!;
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
    var formState = ref
        .read(formAddKeyProvider)
        .currentState!;

    logger.e('onTestConnectionTap');

    if (formState.saveAndValidate()) {
      var printerUrl = formState.value['printerUrl'];
      var printerAPIKey = formState.value['printerApiKey'];
      var trustSelfSigned = formState.value['trustSelfSigned'];
      printerUrl = urlToWebsocketUrl(printerUrl);

      JsonRpcClient jsonRpcClient = JsonRpcClient(printerUrl,
          apiKey: printerAPIKey, trustSelfSignedCertificate: trustSelfSigned);

      jsonRpcClient.openChannel();
      StreamSubscription list = jsonRpcClient.stateStream.listen((event) {
        state = AsyncValue.data(event);
      });

      await stream.firstWhere((element) =>
          [
            ClientState.connected,
            ClientState.error
          ].contains(element.valueOrNull));
      if (jsonRpcClient.hasError) {
        state =
            AsyncValue.error(jsonRpcClient.errorReason!, StackTrace.current);
      }
      list.cancel();
      jsonRpcClient.dispose();
    } else {
      ref.read(snackBarServiceProvider).show(SnackBarConfig(
        type: SnackbarType.error,
        message: 'Input validation failed!',
      ));
    }
  }

  openQrScanner() async {
    var qr = await ref
        .read(goRouterProvider)
        .navigator!
        .push(MaterialPageRoute(builder: (ctx) => const QrScannerPage()));
    if (qr != null) {
      ref
          .read(formAddKeyProvider)
          .currentState
          ?.fields['printerApiKey']
          ?.didChange(qr);
    }
  }

  importFromOctoeverywhere() async {
    AppPortalResult appPortalResult = await appConnectionService.linkAppWithOcto();

    AppConnectionInfoResponse appConnectionInfo = await appConnectionService.getInfo(appPortalResult.appApiToken);

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
    );
    machine = await ref.read(machineServiceProvider).addMachine(machine);

    var octoEverywhereHiveRepository = ref.read(
        octoEverywhereHiveRepositoryProvider);

    octoEverywhereHiveRepository.insert(machine.uuid, OctoEverywhere.fromDto(appPortalResult));

    ref.read(goRouterProvider).goNamed(AppRoute.dashBoard.name);
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
