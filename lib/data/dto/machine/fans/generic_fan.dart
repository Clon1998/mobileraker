import 'named_fan.dart';

class GenericFan implements NamedFan {
  GenericFan({required this.name, this.speed = 0.0});

  @override
  final String name;

  @override
  final double speed;

  @override
  GenericFan copyWith({String? name, double? speed}) {
    return GenericFan(name: name ?? this.name, speed: speed ?? this.speed);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GenericFan &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          speed == other.speed;

  @override
  int get hashCode => name.hashCode ^ speed.hashCode;
}
