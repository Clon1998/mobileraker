import 'dart:convert';

/// Returns the ObjectsJson from the moonraker JSON result using
/// /printer/objects/query?<OBJECT> Endpoint
Map<String, dynamic> objectFromHttpApiResult(String input, String objectKey) {
  var rawJson = jsonDecode(input);
  return rawJson['result']['status'][objectKey];
}
