/*
 * Copyright (c) 2023-2025. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:convert';

import 'package:common/data/dto/history/history_params.dart';
import 'package:common/data/enums/sort_kind_enum.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('HistoryParams fromJson', () {
    String jsonRaw = '{"limit":50,"start":10,"since":1742100652,"before":1742211652.54,"order":"asc"}';

    HistoryParams obj = HistoryParams.fromJson(jsonDecode(jsonRaw));

    expect(obj, isNotNull);
    expect(obj.limit, equals(50));
    expect(obj.start, equals(10));
    // Sun Mar 16 2025 04:50:52 GMT+0000 -> local time +1
    expect(obj.since, equals(DateTime(2025, 3, 16, 5, 50, 52)));

    // Mon Mar 17 2025 11:40:52 GMT+0000 -> local time +1
    expect(obj.before, equals(DateTime(2025, 3, 17, 12, 40, 52, 540)));
  });

  test('HistoryParams toJson', () {
    HistoryParams obj = HistoryParams(
      start: 10,
      limit: 50,
      since: DateTime(2025, 5, 16, 4, 50, 52),
      before: DateTime(2025, 5, 17, 11, 40, 52),
      order: SortKind.ascending,
    );
    var json = jsonEncode(obj.toJson());

    expect(json, isNotNull);
    expect(json, '{\"start\":10,\"limit\":50,\"since\":1747363852.0,\"before\":1747474852.0,\"order\":\"asc\"}');
  });
}
