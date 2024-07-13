/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:common/data/dto/obico/platform_info.dart';
import 'package:common/data/dto/octoeverywhere/app_connection_info_response.dart';
import 'package:common/data/dto/octoeverywhere/app_portal_result.dart';
import 'package:common/data/model/hive/machine.dart';
import 'package:common/data/model/hive/octoeverywhere.dart';
import 'package:common/exceptions/obico_exception.dart';
import 'package:common/exceptions/octo_everywhere_exception.dart';
import 'package:common/network/http_client_factory.dart';
import 'package:common/network/json_rpc_client.dart';
import 'package:common/service/app_router.dart';
import 'package:common/service/firebase/remote_config.dart';
import 'package:common/service/machine_service.dart';
import 'package:common/service/obico/obico_tunnel_service.dart';
import 'package:common/service/octoeverywhere/app_connection_service.dart';
import 'package:common/service/payment_service.dart';
import 'package:common/service/ui/snackbar_service_interface.dart';
import 'package:common/ui/theme/theme_pack.dart';
import 'package:common/util/extensions/dio_options_extension.dart';
import 'package:common/util/extensions/object_extension.dart';
import 'package:common/util/extensions/uri_extension.dart';
import 'package:common/util/logger.dart';
import 'package:common/util/misc.dart';
import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hashlib/hashlib.dart';
import 'package:hashlib_codecs/hashlib_codecs.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:mobileraker/routing/app_router.dart';
import 'package:mobileraker/ui/screens/printers/components/http_headers.dart';
import 'package:mobileraker/ui/screens/qr_scanner/qr_scanner_page.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../components/ssl_settings.dart';

part 'printers_add_controller.freezed.dart';
part 'printers_add_controller.g.dart';

@riverpod
GlobalKey<FormBuilderState> formKey(FormKeyRef _) {
  return GlobalKey<FormBuilderState>();
}

@riverpod
class PrinterAddViewController extends _$PrinterAddViewController {
  @override
  PrinterAddState build() {
    var isSupporter = ref.watch(isSupporterProvider);
    var maxNonSupporterMachines = ref.watch(remoteConfigIntProvider('non_suporters_max_printers'));
    if (!isSupporter && maxNonSupporterMachines > 0) {
      ref.read(allMachinesProvider.selectAsync((data) => data.length)).then((value) {
        if (value >= maxNonSupporterMachines) {
          state = state.copyWith(
            nonSupporterError: tr(
              'components.supporter_only_feature.printer_add',
              args: [maxNonSupporterMachines.toString()],
            ),
          );
        }
      });
    }
    logger.i('PrinterAddViewController.build()');
    return const PrinterAddState();
  }

  onStepTapped(int step) {
    if (state.nonSupporterError != null) return;
    state = state.copyWith(step: step);
  }

  previousStep() {
    if (state.nonSupporterError != null) return;
    state = state.copyWith(step: max(0, state.step - 1));
  }

  addFromOcto() async {
    if (state.nonSupporterError != null) return;
    state = state.copyWith(step: 3);
    var appConnectionService = ref.read(appConnectionServiceProvider);

    try {
      AppPortalResult appPortalResult = await appConnectionService.linkAppWithOcto();

      AppConnectionInfoResponse appConnectionInfo = await appConnectionService.getInfo(appPortalResult.appApiToken);

      var infoResult = appConnectionInfo.result;
      var localIp = infoResult.printerLocalIp;
      logger.i('OctoEverywhere returned Local IP: $localIp');

      if (localIp == null) {
        throw const OctoEverywhereException(
          'Could not retrieve Printer\'s local IP.',
        );
      }

      var httpUri = buildMoonrakerHttpUri(localIp);
      if (httpUri == null) {
        throw const OctoEverywhereException(
          'Could not retrieve Printer\'s local IP.',
        );
      }

      var machine = Machine(
        name: infoResult.printerName,
        httpUri: httpUri,
        octoEverywhere: OctoEverywhere.fromDto(appPortalResult),
      );
      machine = await ref.read(machineServiceProvider).addMachine(machine);
      state = state.copyWith(addedMachine: true, machineToAdd: machine);
    } on OctoEverywhereException catch (e, s) {
      logger.e('Error while trying to add printer via Octo', e, s);
      _thirdPartyAddError('OctoEverywhere-Error:', e.message);
    } catch (e, s) {
      logger.e('Error while trying to add printer via Octo', e, s);
      _thirdPartyAddError('Error:', e.toString());
    }
  }

  addFromObico() async {
    if (state.nonSupporterError != null) return;
    state = state.copyWith(step: 3);
    var tunnelService = ref.read(obicoTunnelServiceProvider());

    try {
      var tunnel = await tunnelService.linkApp();
      logger.i('Tunnel to obico was established successfully!');
      PlatformInfo platformInfo = await tunnelService.retrievePlatformInfo(tunnel);
      logger.i('Local Platform Info used by obico client app: $platformInfo');

      var localAddress = '${platformInfo.host}:${platformInfo.port}';
      var httpUri = buildMoonrakerHttpUri(localAddress);
      if (httpUri == null) {
        throw const ObicoException('Could not retrieve Printer\'s local IP.');
      }

      var machine = Machine(
        name: platformInfo.name ?? 'Obico Printer',
        httpUri: httpUri,
        obicoTunnel: tunnel,
      );
      machine = await ref.read(machineServiceProvider).addMachine(machine);
      state = state.copyWith(addedMachine: true, machineToAdd: machine);
    } on ObicoException catch (e, s) {
      logger.e('Error while trying to add printer via Obico', e, s);
      _thirdPartyAddError('Obico-Error:', e.message);
    } catch (e, s) {
      logger.e('Error while trying to add printer via Obico', e, s);
      _thirdPartyAddError('Error', e.toString());
    }
  }

  void onPopInvoked(bool isPop) {
    if (!isPop) ref.read(printerAddViewControllerProvider.notifier).previousStep();
  }

  selectMode(bool isExpert) {
    if (isExpert != state.isExpert) {
      ref.invalidate(formKeyProvider);
    }
    state = state.copyWith(isExpert: isExpert, step: 1);
  }

  provideMachine(Machine machine) {
    logger.i('provideMachine got: $machine');
    state = state.copyWith(step: state.step + 1, machineToAdd: machine);
  }

  submitMachine() async {
    if (state.nonSupporterError != null) return;
    logger.i('Submitting machine');
    state = state.copyWith(step: state.step + 1);
    await ref.read(machineServiceProvider).addMachine(state.machineToAdd!);
    state = state.copyWith(addedMachine: true);
  }

  goToDashboard() {
    ref.read(goRouterProvider).goNamed(AppRoute.dashBoard.name);
  }

  _thirdPartyAddError(String title, String message) {
    ref.read(snackBarServiceProvider).show(SnackBarConfig(
          type: SnackbarType.error,
          title: title,
          message: message,
        ));
    state = state.copyWith(step: 0);
  }
}

@riverpod
class SimpleFormController extends _$SimpleFormController {
  static String formKey = 'simple';

  FormBuilderState get _formState => ref.read(formKeyProvider).currentState!;

  FormBuilderFieldState get _displayNameField => _formState.fields['simple.name']!;

  FormBuilderFieldState get _urlField => _formState.fields['simple.url']!;

  FormBuilderFieldState get _apiKeyField => _formState.fields['simple.apikey']!;

  @override
  SimpleFormState build() => const SimpleFormState();

  toggleProtocol() {
    state = state.copyWith(isHttps: !state.isHttps);
  }

  openQrScanner(BuildContext context) async {
    Barcode? qr = await Navigator.of(context).push(MaterialPageRoute(builder: (ctx) => const QrScannerPage()));
    if (qr?.rawValue != null) {
      _apiKeyField.didChange(qr!.rawValue);
    }
  }

  proceed() {
    if (!_formState.saveAndValidate()) return;

    ref.read(printerAddViewControllerProvider.notifier).provideMachine(Machine(
          name: _displayNameField.transformedValue,
          httpUri: buildMoonrakerHttpUri(
            '${state.scheme}${_urlField.transformedValue}',
          )!,
          apiKey: _apiKeyField.transformedValue,
        ));
  }

  void focusNext(String key, FocusNode fieldNode, FocusNode nextNode) {
    if (_formState.fields[key]?.validate() == true) {
      nextNode.requestFocus();
    } else {
      fieldNode.requestFocus();
    }
  }
}

@riverpod
class AdvancedFormController extends _$AdvancedFormController {
  static String formKey = 'advanced';

  FormBuilderState get _formState => ref.read(formKeyProvider).currentState!;

  FormBuilderFieldState get _displayNameField => _formState.fields['advanced.name']!;

  FormBuilderFieldState get _httpField => _formState.fields['advanced.http']!;

  FormBuilderFieldState get _wsField => _formState.fields['advanced.ws']!;

  FormBuilderFieldState get _apiKeyField => _formState.fields['advanced.apikey']!;

  FormBuilderFieldState get _localTimeoutField => _formState.fields['advanced.localTimeout']!;

  @override
  AdvancedFormState build() {
    var pState = ref.read(printerAddViewControllerProvider);

    if (pState.machineToAdd != null) {
      return AdvancedFormState(
        headers: pState.machineToAdd!.httpHeaders,
        trustUntrustedCertificate: pState.machineToAdd!.trustUntrustedCertificate,
        pinnedCertificateDER: pState.machineToAdd!.pinnedCertificateDERBase64,
      );
    }

    return const AdvancedFormState();
  }

  openQrScanner(BuildContext context) async {
    Barcode? qr = await Navigator.of(context).push(MaterialPageRoute(builder: (ctx) => const QrScannerPage()));
    if (qr?.rawValue != null) {
      _apiKeyField.didChange(qr!.rawValue);
    }
  }

  proceed() {
    if (!_formState.saveAndValidate()) return;
    var httpInput = _httpField.transformedValue;

    var headers = ref.read(headersControllerProvider(state.headers));
    var sslSettings =
        ref.read(sslSettingsControllerProvider(state.pinnedCertificateDER, state.trustUntrustedCertificate));

    ref.read(printerAddViewControllerProvider.notifier).provideMachine(Machine(
          name: _displayNameField.transformedValue,
          httpUri: buildMoonrakerHttpUri(httpInput)!,
          apiKey: _apiKeyField.transformedValue,
          timeout: _localTimeoutField.transformedValue,
          httpHeaders: headers,
          trustUntrustedCertificate: sslSettings.trustSelfSigned,
          pinnedCertificateDERBase64: sslSettings.certificateDER,
        ));
  }

  void focusNext(String key, FocusNode fieldNode, [FocusNode? nextNode = null]) {
    if (_formState.fields[key]?.validate() == true) {
      if (nextNode != null) {
        nextNode.requestFocus();
      } else {
        fieldNode.nextFocus();
      }
    } else {
      fieldNode.requestFocus();
    }
  }
}

@riverpod
class TestConnectionController extends _$TestConnectionController {
  StreamSubscription? _testConnectionRPCState;
  late JsonRpcClient _client;
  late HttpClient _httpClient;
  late Map<String, String> _httpHeaders;

  @override
  TestConnectionState build() {
    ref.listenSelf((previous, next) {
      logger.wtf('TestConnectionState: $previous -> $next');
    });
    PrinterAddState printerAddState = ref.watch(printerAddViewControllerProvider);
    var machineToAdd = printerAddState.machineToAdd;
    if (machineToAdd == null) {
      throw ArgumentError(
        'Expected the machine to add to be available. However it is null?',
      );
    }

    TestConnectionState s;

    final baseOptions = BaseOptions(
      baseUrl: machineToAdd.httpUri.toString(),
      headers: machineToAdd.headerWithApiKey,
      connectTimeout: Duration(seconds: machineToAdd.timeout),
      receiveTimeout: Duration(seconds: machineToAdd.timeout),
    )
      ..trustUntrustedCertificate = machineToAdd.trustUntrustedCertificate
      ..pinnedCertificateFingerPrint =
          machineToAdd.pinnedCertificateDERBase64?.let((it) => sha256.convert(fromBase64(it)))
      ..clientType = ClientType.local;

    final httpClientFactory = ref.read(httpClientFactoryProvider);

    final httpClient = httpClientFactory.fromBaseOptions(baseOptions);

    JsonRpcClientBuilder jsonRpcClientBuilder = JsonRpcClientBuilder.fromBaseOptions(baseOptions, machineToAdd);
    jsonRpcClientBuilder.httpClient = httpClient;

    _httpClient = httpClient;
    _client = jsonRpcClientBuilder.build();
    _httpHeaders = machineToAdd.headerWithApiKey;
    _testWebsocket();

    s = TestConnectionState(
      httpUri: machineToAdd.httpUri,
      wsUri: _client.uri,
    );

    _testHttp(s.httpUri);

    ref.onDispose(() => _testConnectionRPCState?.cancel());
    ref.onDispose(_client.dispose);
    ref.onDispose(_httpClient.close);

    return s;
  }

  proceed() {
    ref.read(printerAddViewControllerProvider.notifier).submitMachine();
  }

  _testWebsocket() {
    _client.openChannel();
    _testConnectionRPCState = _client.stateStream.listen((event) {
      state = switch (event) {
        ClientState.connected => state.copyWith(wsState: event, wsError: null),
        ClientState.error => state.copyWith(
            wsState: event,
            wsError: _client.errorReason?.toString() ?? 'Unknown Error',
          ),
        _ => state.copyWith(wsState: event),
      };
      if (event == ClientState.connected || event == ClientState.error) {
        _testConnectionRPCState?.cancel();
        _client.dispose();

        logger.i(
          'Test connection got a result, cancel stream and dispose client.',
        );
      }
    });
  }

  _testHttp(Uri? httpUri) async {
    if (httpUri == null) return;
    try {
      var request = await _httpClient.getUrl(httpUri.appendPath('/access/info'));
      _httpHeaders.forEach((key, value) {
        request.headers.add(key, value);
      });
      var response = await request.close();

      var isSuccess = response.statusCode == 200;
      state = state.copyWith(
        httpState: isSuccess,
        httpError: isSuccess ? null : '${response.statusCode} - ${response.reasonPhrase}',
      );
    } catch (e) {
      logger.w('_testHttp returned error', e);

      state = state.copyWith(httpState: false, httpError: e.toString());
    }
  }
}

@freezed
class PrinterAddState with _$PrinterAddState {
  const PrinterAddState._();

  const factory PrinterAddState({
    String? nonSupporterError,
    @Default(false) bool isExpert,
    @Default(0) int step,
    Machine? machineToAdd,
    // This might be usefull later maybe.
    bool? addedMachine,
  }) = _PrinterAddState;
}

@freezed
class SimpleFormState with _$SimpleFormState {
  const SimpleFormState._();

  const factory SimpleFormState({
    // String? displayName,
    // Uri? wsUri,
    // Uri? httpUri,
    // String? apiKey,
    // @Default(false) bool isValid,
    @Default(false) isHttps,
  }) = _SimpleFormState;

  String get scheme => (isHttps) ? 'https://' : 'http://';
}

@freezed
class AdvancedFormState with _$AdvancedFormState {
  const AdvancedFormState._();

  const factory AdvancedFormState({
    @Default({}) Map<String, String> headers,
    @Default(false) bool trustUntrustedCertificate,
    String? pinnedCertificateDER,
  }) = _AdvancedFormState;
}

@freezed
class TestConnectionState with _$TestConnectionState {
  const TestConnectionState._();

  const factory TestConnectionState({
    Uri? wsUri,
    ClientState? wsState,
    String? wsError,
    Uri? httpUri,
    bool? httpState,
    String? httpError,
  }) = _TestConnectionState;

  bool get hasResults => wsState != null && httpState != null;

  bool get combinedResult => wsState == ClientState.connected && httpState == true;

  String get wsStateText => tr(switch (wsState) {
        ClientState.connected => 'general.valid',
        ClientState.error => 'general.invalid',
        _ => 'general.unknown',
      });

  String get httpStateText => tr(switch (httpState) {
        true => 'general.valid',
        false => 'general.invalid',
        _ => 'general.unknown',
      });

  Color wsStateColor(ThemeData theme) => switch (wsState) {
        ClientState.connected => theme.extension<CustomColors>()?.success ?? Colors.green,
        ClientState.error => theme.extension<CustomColors>()?.danger ?? Colors.yellow,
        _ => theme.extension<CustomColors>()?.info ?? Colors.lightBlue,
      };

  Color httpStateColor(ThemeData theme) => switch (httpState) {
        true => theme.extension<CustomColors>()?.success ?? Colors.green,
        false => theme.extension<CustomColors>()?.danger ?? Colors.yellow,
        _ => theme.extension<CustomColors>()?.info ?? Colors.lightBlue,
      };
}
