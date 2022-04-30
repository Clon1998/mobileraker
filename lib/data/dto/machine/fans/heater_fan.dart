import 'package:mobileraker/data/dto/machine/fans/named_fan.dart';

class HeaterFan implements NamedFan {
  @override
  String name;

  @override
  double speed = 0.0;

  HeaterFan(this.name);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is HeaterFan &&
              runtimeType == other.runtimeType &&
              name == other.name &&
              speed == other.speed;

  @override
  int get hashCode => name.hashCode ^ speed.hashCode;
}
