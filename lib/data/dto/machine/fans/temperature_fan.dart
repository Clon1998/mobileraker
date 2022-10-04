import 'named_fan.dart';

class TemperatureFan implements NamedFan {
  TemperatureFan({required this.name, this.speed = 0.0});

  @override
  final String name;
  @override
  final double speed;

  @override
  TemperatureFan copyWith({String? name, double? speed}) {
    return TemperatureFan(name: name ?? this.name, speed: speed ?? this.speed);
  }

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
