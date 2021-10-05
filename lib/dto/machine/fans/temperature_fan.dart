import 'package:mobileraker/dto/machine/fans/named_fan.dart';

class TemperatureFan implements NamedFan {
  @override
  String name;
  @override
  double speed = 0.0;

  TemperatureFan(this.name);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is TemperatureFan &&
              runtimeType == other.runtimeType &&
              name == other.name &&
              speed == other.speed;

  @override
  int get hashCode => name.hashCode ^ speed.hashCode;
}
