/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:flutter_test/flutter_test.dart';
import 'package:mobileraker/data/data_source/json_rpc_client.dart';
import 'package:mobileraker/data/model/hive/machine.dart';
import 'package:mobileraker/data/model/hive/octoeverywhere.dart';

void main() {
  test('Convert local WS Uri to Octo URI', () async {
    String octoUriStr =
        "https://app-fwduvgajpbcz1e7mwm0ivscpo4ebtg6o.octoeverywhere.com";

    String localUriStr = "ws://192.168.178.135/websocket/AAA";

    var m =  Machine(
        name: 'test',
        wsUri: Uri.parse(localUriStr),
        httpUri: Uri.parse(localUriStr),
        octoEverywhere: OctoEverywhere(
            url: octoUriStr,
            appApiToken: 'appApiToken',
            appConnectionId: 'appConnectionId',
            authBasicHttpUser: 'user',
            authBasicHttpPassword: 'password',
            authBearerToken: 'TOKEN'));

    var jsonRpcClientBuilder = JsonRpcClientBuilder.fromOcto(m);

    expect(jsonRpcClientBuilder.uri.toString(), 'wss://app-fwduvgajpbcz1e7mwm0ivscpo4ebtg6o.octoeverywhere.com/websocket/AAA');
  });
}
