import 'package:mobileraker/dto/machine/fans/named_fan.dart';

class ControllerFan implements NamedFan {
  @override
  String name;
  @override
  double speed = 0.0;

  ControllerFan(this.name);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is ControllerFan &&
              runtimeType == other.runtimeType &&
              name == other.name &&
              speed == other.speed;

  @override
  int get hashCode => name.hashCode ^ speed.hashCode;
}
