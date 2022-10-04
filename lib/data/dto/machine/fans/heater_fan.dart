import 'named_fan.dart';

class HeaterFan implements NamedFan {
  HeaterFan({required this.name, this.speed = 0.0});

  @override
  final String name;

  @override
  final double speed;

  @override
  HeaterFan copyWith({String? name, double? speed}) {
    return HeaterFan(name: name ?? this.name, speed: speed ?? this.speed);
  }

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
