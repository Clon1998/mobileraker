import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobileraker/data/dto/config/config_file.dart';
import 'package:mobileraker/data/dto/config/led/config_neopixel.dart';

void main() {
  test('Test ConfigFile parsing, multi extruder one one nozzle!', () {
    final configFile =
        File('test_resources/marshalling/multi_extruder_configfile.json');
    var configFileJson = jsonDecode(configFile.readAsStringSync());

    var config = ConfigFile.parse(configFileJson['settings']);

    expect(config, isNotNull);
  });

  test('Test ConfigFile parsing, neopixels', () {
    const neopixelStr = '''
    {
      "pin": "PC12",
      "chain_count": 3,
      "initial_red": 1.0,
      "initial_green": 0.0,
      "initial_blue": 0.0,
      "color_order": ["RGB"]
      }
    ''';
    var neopixelJson = jsonDecode(neopixelStr);

    var configNeopixel = ConfigNeopixel.fromJson("fysetc_mini12864", neopixelJson);

    expect(configNeopixel, isNotNull);
  });
}
