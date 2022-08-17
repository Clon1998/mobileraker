import 'named_fan.dart';

class ControllerFan implements NamedFan {
  ControllerFan({required this.name, this.speed = 0.0});

  @override
  final String name;
  @override
  final double speed;

  @override
  ControllerFan copyWith({String? name, double? speed}) {
    return ControllerFan(name: name ?? this.name, speed: speed ?? this.speed);
  }

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
