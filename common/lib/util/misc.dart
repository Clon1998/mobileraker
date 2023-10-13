/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:stringr/stringr.dart';

import '../exceptions/mobileraker_exception.dart';
import '../exceptions/obico_exception.dart';
import '../exceptions/octo_everywhere_exception.dart';
import '../network/json_rpc_client.dart';
import '../util/extensions/object_extension.dart';
import '../util/extensions/uri_extension.dart';

Uri? buildMoonrakerWebSocketUri(String? enteredURL, [bool defaultPathIfEmpty = true]) {
  var normalizedURL = _normalizeURL(enteredURL);
  if (normalizedURL == null) return null;

  var scheme = normalizedURL.scheme == 'wss' || normalizedURL.scheme == 'https' ? 'wss' : 'ws';
  var path = defaultPathIfEmpty && normalizedURL.hasEmptyPath ? 'websocket' : normalizedURL.path;

  return normalizedURL.replace(path: path, scheme: scheme);
}

Uri? buildMoonrakerHttpUri(String? enteredURL) {
  var normalizedURL = _normalizeURL(enteredURL);
  if (normalizedURL == null) return null;

  var scheme = normalizedURL.scheme == 'wss' || normalizedURL.scheme == 'https' ? 'https' : 'http';

  return normalizedURL.replace(scheme: scheme);
}

///Returns a URI that is either based from the machineURI or the camURI if it is absolute.
Uri buildWebCamUri(Uri machineUri, Uri camUri) {
  if (camUri.isAbsolute) return camUri;
  return machineUri.toHttpUri().removePort().resolveUri(camUri);
}

Uri buildRemoteWebCamUri(Uri remoteUri, Uri machineUri, Uri camUri) {
  if (camUri.isAbsolute) {
    if (camUri.host.toLowerCase() == machineUri.host.toLowerCase()) {
      return remoteUri.replace(
          path: camUri.path,
          query: camUri.query.isEmpty ? null : camUri.query,
          port: camUri.hasPort ? camUri.port : remoteUri.port);
    } else {
      return camUri;
    }
  } else {
    return remoteUri.toHttpUri().resolveUri(camUri);
  }
}

Uri? _normalizeURL(String? enteredURL) {
  enteredURL = enteredURL?.let((it) => it.trim());
  if (enteredURL == null || enteredURL.isEmpty) return null;
  // make sure a schema is available to ensure a host is properly parsed.
  // This is required because an IP is not parsed into the URI.host otherwise
  if (!enteredURL.startsWith(RegExp(r'[A-z]+://'))) {
    enteredURL = 'http://$enteredURL';
  }
  if (enteredURL.endsWith('/')) {
    enteredURL = enteredURL.substring(0, enteredURL.length - 1);
  }

  return Uri.tryParse(enteredURL)?.replace(userInfo: '');
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
  List<T> blockList, {
  String? errorText,
}) {
  return (T? valueCandidate) {
    if (valueCandidate != null) {
      assert(valueCandidate is! List && valueCandidate is! Map && valueCandidate is! Set);

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

verifyHttpResponseCodes(int statusCode, [ClientType clientType = ClientType.local]) {
  if (clientType == ClientType.octo) {
    _verifyOctoHttpResponseCodes(statusCode);
  } else if (clientType == ClientType.obico) {
    _verifyObicoHttpResponseCodes(statusCode);
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
          'Internal App error while trying too fetch info. No AppToken was found!', 400);
    case 500:
      throw const OctoEverywhereHttpException('Internal Server Error - OctoEverywhere\'s server is faulty', 500);
    case 600:
      throw const OctoEverywhereHttpException('Unknown Error - Something went wrong, try again later.', 600);
    case 601:
      throw const OctoEverywhereHttpException('Printer is Not Connected To OctoEverywhere', 601);
    case 602:
      throw const OctoEverywhereHttpException('OctoEverywhere\'s Connection to Klipper Timed Out.', 602);
    case 603:
      throw const OctoEverywhereHttpException('App Connection Not Found', 603);
    case 604:
      throw const OctoEverywhereHttpException(
          'App Connection Revoked/Expired. Please unlink and link the app again!', 604);
    case 605:
      throw const OctoEverywhereHttpException(
          'App Connection Owner\'s Account Is No Longer a Octoeverywhere-Supporter.', 605);
    case 606:
      throw const OctoEverywhereHttpException('Invalid App Connection Credentials', 606);
    case 607:
      throw const OctoEverywhereHttpException('File Download Limit Exceeded', 607);
    case 608:
      throw const OctoEverywhereHttpException('File Upload Limit Exceeded', 608);
    case 609:
      throw const OctoEverywhereHttpException('Webcam Back to Back Limit Exceeded', 609);
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

_verifyObicoHttpResponseCodes(int statusCode) => switch (statusCode) {
      401 => throw const ObicoHttpException('Unauthenticated request', 401),
      481 => throw const ObicoHttpException('Over free tunnel monthly data cap.', 481),
      482 => throw const ObicoHttpException('Obico for Klipper is not connected to the Obico server.', 482),
      483 => throw const ObicoHttpException('Obico for Klipper is connected but timed out (30s)', 483),
      _ => throw MobilerakerException('Unknown Error - StatusCode $statusCode')
    };

String storeName() {
  return tr((Platform.isAndroid) ? 'general.google_play' : 'general.ios_store');
}
