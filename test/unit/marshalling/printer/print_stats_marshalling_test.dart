import 'package:flutter_test/flutter_test.dart';
import 'package:mobileraker/data/dto/machine/print_stats.dart';

import '../../../test_utils.dart';

void main() {
  test('PrintStats fromJson', () {
    var obj = PrintStatsObject();

    expect(obj, isNotNull);
    expect(obj.state, equals(PrintState.standby));
    expect(obj.totalDuration, equals(100.00));
    expect(obj.printDuration, equals(0));
    expect(obj.filamentUsed, equals(123.4));
    expect(obj.message, equals(''));
    expect(obj.filename, equals(''));
  });

  group('PrintStats partialUpdate', () {
    test('state', () {
      var old = PrintStatsObject();

      var updateJson = {"state": 'error'};

      var updatedObj = PrintStats.partialUpdate(old, updateJson);

      expect(updatedObj, isNotNull);
      expect(updatedObj.state, equals(PrintState.error));
      expect(updatedObj.totalDuration, equals(100.00));
      expect(updatedObj.printDuration, equals(0));
      expect(updatedObj.filamentUsed, equals(123.4));
      expect(updatedObj.message, equals(''));
      expect(updatedObj.filename, equals(''));
    });

    test('total_duration', () {
      var old = PrintStatsObject();

      var updateJson = {"total_duration": 44002};

      var updatedObj = PrintStats.partialUpdate(old, updateJson);

      expect(updatedObj, isNotNull);
      expect(updatedObj.state, equals(PrintState.standby));
      expect(updatedObj.totalDuration, equals(44002));
      expect(updatedObj.printDuration, equals(0));
      expect(updatedObj.filamentUsed, equals(123.4));
      expect(updatedObj.message, equals(''));
      expect(updatedObj.filename, equals(''));
    });

    test('print_duration', () {
      var old = PrintStatsObject();

      var updateJson = {"print_duration": 4444};

      var updatedObj = PrintStats.partialUpdate(old, updateJson);

      expect(updatedObj, isNotNull);
      expect(updatedObj.state, equals(PrintState.standby));
      expect(updatedObj.totalDuration, equals(100.00));
      expect(updatedObj.printDuration, equals(4444));
      expect(updatedObj.filamentUsed, equals(123.4));
      expect(updatedObj.message, equals(''));
      expect(updatedObj.filename, equals(''));
    });

    test('filament_used', () {
      var old = PrintStatsObject();

      var updateJson = {"filament_used": 123123.5};

      var updatedObj = PrintStats.partialUpdate(old, updateJson);

      expect(updatedObj, isNotNull);
      expect(updatedObj.state, equals(PrintState.standby));
      expect(updatedObj.totalDuration, equals(100.00));
      expect(updatedObj.printDuration, equals(0));
      expect(updatedObj.filamentUsed, equals(123123.5));
      expect(updatedObj.message, equals(''));
      expect(updatedObj.filename, equals(''));
    });

    test('message', () {
      var old = PrintStatsObject();

      var updateJson = {"message": 'Abababab'};

      var updatedObj = PrintStats.partialUpdate(old, updateJson);

      expect(updatedObj, isNotNull);
      expect(updatedObj.state, equals(PrintState.standby));
      expect(updatedObj.totalDuration, equals(100.00));
      expect(updatedObj.printDuration, equals(0));
      expect(updatedObj.filamentUsed, equals(123.4));
      expect(updatedObj.message, equals('Abababab'));
      expect(updatedObj.filename, equals(''));
    });

    test('filename', () {
      var old = PrintStatsObject();

      var updateJson = {"filename": 'abc/root.gcode'};

      var updatedObj = PrintStats.partialUpdate(old, updateJson);

      expect(updatedObj, isNotNull);
      expect(updatedObj.state, equals(PrintState.standby));
      expect(updatedObj.totalDuration, equals(100.00));
      expect(updatedObj.printDuration, equals(0));
      expect(updatedObj.filamentUsed, equals(123.4));
      expect(updatedObj.message, equals(''));
      expect(updatedObj.filename, equals('abc/root.gcode'));
    });

    test('Full update', () {
      PrintStats old = PrintStatsObject();
      String input =
          '{"result": {"status": {"print_stats": {"info": {"total_layer": null, "current_layer": null}, "print_duration": 1.0, "total_duration": 4.0, "filament_used": 12.4, "filename": "ff", "state": "complete", "message": "Done"}}, "eventtime": 3798698.261748828}}';

      var updateJson = objectFromHttpApiResult(input, "print_stats");

      var updatedObj = PrintStats.partialUpdate(old, updateJson);

      expect(updatedObj, isNotNull);
      expect(updatedObj.state, equals(PrintState.complete));
      expect(updatedObj.totalDuration, equals(4.00));
      expect(updatedObj.printDuration, equals(1));
      expect(updatedObj.filamentUsed, equals(12.4));
      expect(updatedObj.message, equals('Done'));
      expect(updatedObj.filename, equals('ff'));
    });
  });
}

PrintStats PrintStatsObject() {
  String input =
      '{"result": {"status": {"print_stats": {"info": {"total_layer": null, "current_layer": null}, "print_duration": 0.0, "total_duration": 100.0, "filament_used": 123.4, "filename": "", "state": "standby", "message": ""}}, "eventtime": 3798698.261748828}}';

  var jsonRaw = objectFromHttpApiResult(input, "print_stats");

  return PrintStats.fromJson(jsonRaw);
}
