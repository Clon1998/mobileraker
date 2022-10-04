import 'package:flutter/material.dart';
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
