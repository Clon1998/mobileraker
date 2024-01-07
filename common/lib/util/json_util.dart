/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

List<T>? updateHistoryListInJson<T>(
    Map<String, dynamic> inputJson, String listKey, String valueKey) {
  var currentHistory = inputJson[listKey] as List<dynamic>?;
  if (currentHistory == null) {
    return null;
  }
  T toAdd = inputJson[valueKey];
  if (currentHistory.length >= 1200) {
    return [...currentHistory.sublist(1), toAdd];
  }
  return [...currentHistory, toAdd];
}
