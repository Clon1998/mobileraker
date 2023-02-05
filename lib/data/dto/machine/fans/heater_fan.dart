import 'package:freezed_annotation/freezed_annotation.dart';

import 'named_fan.dart';


part 'heater_fan.freezed.dart';

@freezed
class HeaterFan extends NamedFan with _$HeaterFan {
  const factory HeaterFan({
    required String name,
    @Default(0) double speed,
  }) = _HeaterFan;
}