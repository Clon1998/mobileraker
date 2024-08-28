/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:io';

import 'package:common/util/extensions/dio_options_extension.dart';
import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:stringr/stringr.dart';

import '../exceptions/mobileraker_exception.dart';
import '../exceptions/obico_exception.dart';
import '../exceptions/octo_everywhere_exception.dart';
import '../network/json_rpc_client.dart';
import '../util/extensions/object_extension.dart';
import '../util/extensions/uri_extension.dart';
import 'logger.dart';

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

  return machineUri
      .toHttpUri()
      // For K1 its a bad user experience to remove the printer port.
      // But if the printer port equals a default moonraker instance replace it with default http(s) port.
      .let((it) => it.hasPort && it.port == 7125 ? it.replace(port: it.isScheme('https') ? 443 : 80) : it)
      .resolveUri(camUri);
  // return machineUri.toHttpUri().removePort().resolveUri(camUri);
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
  return name.replaceAll('_', ' ').titleCase();
}

FormFieldValidator<T> notContains<T>(
  List<T> blockList, {
  String? errorText,
}) {
  return (T? valueCandidate) {
    if (valueCandidate != null) {
      assert(valueCandidate is! List && valueCandidate is! Map && valueCandidate is! Set);
      logger.wtf('Checking $valueCandidate');
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

verifyHttpResponseCodesForObico(int statusCode) => verifyHttpResponseCodes(statusCode, ClientType.octo);

verifyHttpResponseCodes(int statusCode, [ClientType clientType = ClientType.local]) {
  if (clientType == ClientType.octo) {
    _verifyOctoHttpResponseCodes(statusCode);
  } else if (clientType == ClientType.obico) {
    _verifyObicoHttpResponseCodes(statusCode);
  }
  _verifyHttpResponseCodes(statusCode);
}

_verifyOctoHttpResponseCodes(int statusCode) {
  switch (statusCode) {
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
  }
}

_verifyHttpResponseCodes(int statusCode) {
  switch (statusCode) {
    case 200:
      return;

    //-------
    case 400:
      throw const HttpException('Bad-Response: 400-BadRequest');
    case 401:
      throw const HttpException('Bad-Response: 401-Unauthorized');
    case 403:
      throw const HttpException('Bad-Response: 403-Forbidden');
    case 404:
      throw const HttpException('Bad-Response: 404-NotFound');
    case 405:
      throw const HttpException('Bad-Response: 405-MethodNotAllowed');
    case 408:
      throw const HttpException('Bad-Response: 408-RequestTimeout');
    case 422:
      throw const HttpException('Bad-Response: 422-UnprocessableEntity');
    case 429:
      throw const HttpException('Bad-Response: 429-TooManyRequests');

    case 500:
      throw const HttpException('Bad-Response: 500-InternalServerError');
    case 501:
      throw const HttpException('Bad-Response: 501-NotImplemented');
    case 502:
      throw const HttpException('Bad-Response: 502-BadGateway');
    case 503:
      throw const HttpException('Bad-Response: 503-ServiceUnavailable');
    case 504:
      throw const HttpException('Bad-Response: 504-GatewayTimeout');
    case 505:
      throw const HttpException('Bad-Response: 505-HTTPVersionNotSupported');
    case 507:
      throw const HttpException('Bad-Response: 507-InsufficientStorage');
    case 508:
      throw const HttpException('Bad-Response: 508-LoopDetected');
    case 511:
      throw const HttpException('Bad-Response: 511-NetworkAuthenticationRequired');

    case 440:
      throw const HttpException('Bad-Response: 440-LoginTimeout (IIS)');
    case 460:
      throw const HttpException('Bad-Response: 460-ClientClosedRequest (AWS Elastic Load Balancer)');
    case 499:
      throw const HttpException('Bad-Response: 499-ClientClosedRequest (ngnix)');
    case 520:
      throw const HttpException('Bad-Response: 520-WebServerReturnedUnknownError');
    case 521:
      throw const HttpException('Bad-Response: 521-WebServerIsDown');
    case 522:
      throw const HttpException('Bad-Response: 522-ConnectionTimedOut');
    case 523:
      throw const HttpException('Bad-Response: 523-OriginIsUnreachable');
    case 524:
      throw const HttpException('Bad-Response: 524-TimeoutOccurred');
    case 525:
      throw const HttpException('Bad-Response: 525-SSLHandshakeFailed');
    case 527:
      throw const HttpException('Bad-Response: 527-RailgunError');
    case 598:
      throw const HttpException('Bad-Response: 598-NetworkReadTimeoutError');
    case 599:
      throw const HttpException('Bad-Response: 599-NetworkConnectTimeoutError It\'s possible to override this list');

    default:
      throw HttpException('HttpException - StatusCode $statusCode');
  }
}

_verifyObicoHttpResponseCodes(int statusCode) {
  var err = switch (statusCode) {
    401 => throw const ObicoHttpException('Unauthenticated request', 401),
    481 => throw const ObicoHttpException('Over free tunnel monthly data cap.', 481),
    482 => throw const ObicoHttpException('Obico for Klipper is not connected to the Obico server.', 482),
    483 => throw const ObicoHttpException('Obico for Klipper is connected but timed out (30s)', 483),
    _ => null
  };
  if (err != null) {
    throw err;
  }
}

String storeName() {
  return tr((Platform.isAndroid) ? 'general.google_play' : 'general.ios_store');
}

MobilerakerDioException convertDioException(DioException base) {
  var err = switch (base.requestOptions.clientType) {
    ClientType.octo => _convertBadResponseOctoeverywhere(base),
    ClientType.obico => _convertBadResponseObico(base),
    _ => base
  };
  if (err is! MobilerakerDioException) {
    err = MobilerakerDioException.fromDio(err);
  }

  return err;
}

DioException _convertBadResponseObico(DioException base) {
  if (base.type != DioExceptionType.badResponse) return base;

  var statusCode = base.response?.statusCode;
  if (statusCode == null) return base;
  return switch (statusCode) {
    401 => ObicoDioException('Unauthenticated request', 401, requestOptions: base.requestOptions),
    481 => ObicoDioException('Over free tunnel monthly data cap.', 481, requestOptions: base.requestOptions),
    482 => ObicoDioException('Obico for Klipper is not connected to the Obico server.', 482,
        requestOptions: base.requestOptions),
    483 =>
      ObicoDioException('Obico for Klipper is connected but timed out (30s)', 483, requestOptions: base.requestOptions),
    _ => base
  };
}

DioException _convertBadResponseOctoeverywhere(DioException base) {
  if (base.type != DioExceptionType.badResponse) return base;

  var statusCode = base.response?.statusCode;
  if (statusCode == null) return base;
  return switch (statusCode) {
    400 => OctoEverywhereDioException('Internal App error while trying to fetch info. No AppToken was found!', 400,
        requestOptions: base.requestOptions),
    401 => OctoEverywhereDioException('Internal App error while trying to fetch info. No AppToken was found!', 400,
        requestOptions: base.requestOptions),
    500 => OctoEverywhereDioException('Internal Server Error - OctoEverywhere\'s server is faulty', 500,
        requestOptions: base.requestOptions),
    600 => OctoEverywhereDioException('Unknown Error - Something went wrong, try again later.', 600,
        requestOptions: base.requestOptions),
    601 => OctoEverywhereDioException('Printer is Not Connected To OctoEverywhere', 601,
        requestOptions: base.requestOptions),
    602 => OctoEverywhereDioException('OctoEverywhere\'s Connection to Klipper Timed Out.', 602,
        requestOptions: base.requestOptions),
    603 => OctoEverywhereDioException('App Connection Not Found', 603, requestOptions: base.requestOptions),
    604 => OctoEverywhereDioException('App Connection Revoked/Expired. Please unlink and link the app again!', 604,
        requestOptions: base.requestOptions),
    605 => OctoEverywhereDioException('App Connection Owner\'s Account Is No Longer an Octoeverywhere-Supporter.', 605,
        requestOptions: base.requestOptions),
    606 => OctoEverywhereDioException('Invalid App Connection Credentials', 606, requestOptions: base.requestOptions),
    607 => OctoEverywhereDioException('File Download Limit Exceeded', 607, requestOptions: base.requestOptions),
    608 => OctoEverywhereDioException('File Upload Limit Exceeded', 608, requestOptions: base.requestOptions),
    609 => OctoEverywhereDioException('Webcam Back to Back Limit Exceeded', 609, requestOptions: base.requestOptions),
    _ => base,
  };
}
