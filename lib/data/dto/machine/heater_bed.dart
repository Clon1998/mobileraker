import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:mobileraker/util/json_util.dart';

part 'heater_bed.freezed.dart';
part 'heater_bed.g.dart';

@freezed
class HeaterBed with _$HeaterBed {
  const factory HeaterBed({
    @Default(0) double temperature,
    @Default(0) double target,
    @Default(0) double power,
    List<double>? temperatureHistory,
    List<double>? targetHistory,
    List<double>? powerHistory,
    required DateTime lastHistory,
  }) = _HeaterBed;

  factory HeaterBed.fromJson(Map<String, dynamic> json) =>
      _$HeaterBedFromJson(json);

  factory HeaterBed.partialUpdate(
      HeaterBed? current, Map<String, dynamic> partialJson) {
    HeaterBed old = current ?? HeaterBed(lastHistory: DateTime(1990));

    var mergedJson = {...old.toJson(), ...partialJson};
    // Ill just put the tempCache here because I am lazy.. kinda sucks but who cares
    // Update temp cache for graphs!
    DateTime now = DateTime.now();
    if (now.difference(old.lastHistory).inSeconds >= 1) {
      mergedJson = {
        ...mergedJson,
        'temperatures':
            updateHistoryListInJson(mergedJson, 'temperatures', 'temperature'),
        'targets': updateHistoryListInJson(mergedJson, 'targets', 'target'),
        'powers': updateHistoryListInJson(mergedJson, 'powers', 'power'),
        'lastHistory': now.toIso8601String()
      };
    }

    return HeaterBed.fromJson(mergedJson);
  }
}
