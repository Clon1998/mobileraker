import 'package:mobileraker/data/dto/machine/fans/named_fan.dart';

class GenericFan implements NamedFan {
  @override
  String name;

  @override
  double speed = 0.0;

  GenericFan(this.name);

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
