import 'package:flutter/material.dart';
import 'package:mobileraker/data/data_source/json_rpc_client.dart';
import 'package:mobileraker/exceptions.dart';
import 'package:stringr/stringr.dart';

String urlToWebsocketUrl(String enteredURL) {
  if (enteredURL.isEmpty) return enteredURL;

  var pattern = RegExp(
      r'^((https?|http|ws|wss?)://)?([-A-Z0-9.]+)(?::([0-9]{1,5}))?(/[-A-Z0-9+&@#/%=~_|!:,.;]*)?$',
      caseSensitive: false);

  var match = pattern.firstMatch(enteredURL);

  var protocol = match?.group(2);
  var host = match?.group(3);
  var port = match?.group(4);
  var path = match?.group(5);

  if (match == null || host == null) return enteredURL;

  if (protocol == null) path ??= '/websocket';

  protocol ??= 'ws';
  protocol = protocol.replaceAll('https', 'wss').replaceAll('http', 'ws');

  var result = '$protocol://$host';
  if (port != null) result = '$result:$port';
  if (path != null) result = '$result$path';
  return result;
}

String urlToHttpUrl(String enteredURL) {
  var parse = Uri.tryParse(enteredURL);
  if (parse == null) return enteredURL;
  if (!parse.hasScheme) {
    parse = Uri.tryParse('http://$enteredURL');
  } else if (parse.isScheme('ws')) {
    parse = parse.replace(scheme: 'http');
  } else if (parse.isScheme('wss')) {
    parse = parse.replace(scheme: 'http');
  }

  return parse.toString();
}

String beautifyName(String name) {
  return name.replaceAll("_", " ").titleCase();
}

FormFieldValidator<T> notContains<T>(
  BuildContext context,
  List<T> blockList, {
  String? errorText,
}) {
  return (T? valueCandidate) {
    if (valueCandidate != null) {
      assert(valueCandidate is! List &&
          valueCandidate is! Map &&
          valueCandidate is! Set);

      if (blockList.contains(valueCandidate)) {
        return errorText ?? 'Value in Blocklist!';
      }
    }
    return null;
  };
}

int hashAllNullable(Iterable<dynamic>? list) {
  if (list == null) return null.hashCode;
  return Object.hashAll(list);
}

verifyHttpResponseCodes(int statusCode,
    [ClientType clientType = ClientType.local]) {
  if (clientType == ClientType.octo) {
    _verifyOctoHttpResponseCodes(statusCode);
  } else {
    _verifyLocalHttpResponseCodes(statusCode);
  }
}

_verifyOctoHttpResponseCodes(int statusCode) {
  switch (statusCode) {
    case 200:
      return;
    case 400:
      throw const OctoEverywhereHttpException(
          'Internal App error while trying too fetch info. No AppToken was found!',
          400);
    case 600:
      throw const OctoEverywhereHttpException(
          'Unknown Error - Something went wrong, try again later.', 600);
    case 601:
      throw const OctoEverywhereHttpException(
          'Printer is Not Connected To OctoEverywhere', 601);
    case 602:
      throw const OctoEverywhereHttpException(
          'OctoEverywhere\'s Connection to Klipper Timed Out.', 602);
    case 603:
      throw const OctoEverywhereHttpException('App Connection Not Found', 603);
    case 604:
      throw const OctoEverywhereHttpException(
          'App Connection Revoked/Expired', 604);
    case 605:
      throw const OctoEverywhereHttpException(
          'App Connection Owner\'s Account Is No Longer a Supporter.', 605);
    case 606:
      throw const OctoEverywhereHttpException(
          'Invalid App Connection Credentials', 606);
    case 607:
      throw const OctoEverywhereHttpException(
          'File Download Limit Exceeded', 607);
    case 608:
      throw const OctoEverywhereHttpException(
          'File Upload Limit Exceeded', 608);
    case 609:
      throw const OctoEverywhereHttpException(
          'Webcam Back to Back Limit Exceeded', 609);
    default:
      throw MobilerakerException(
          'Unknown Error - Response from octoeverywhere could not be parsed. StatusCode $statusCode');
  }
}

_verifyLocalHttpResponseCodes(int statusCode) {
  switch (statusCode) {
    case 200:
      return;
    default:
      throw MobilerakerException('Unknown Error - StatusCode $statusCode');
  }
}
