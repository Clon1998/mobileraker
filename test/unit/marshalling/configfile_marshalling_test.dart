import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobileraker/data/dto/config/config_file.dart';

void main() {
  test('Test ConfigFile parsing, multi extruder one one nozzle!', () {
    final configFile =
        File('test_resources/marshalling/multi_extruder_configfile.json');
    var configFileJson = jsonDecode(configFile.readAsStringSync());

    var config = ConfigFile.parse(configFileJson['settings']);

    expect(config, isNotNull);
  });
}
