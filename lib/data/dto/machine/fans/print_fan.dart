import 'fan.dart';

class PrintFan implements Fan {
  const PrintFan({this.speed = 0.0});

  @override
  final double speed;

  PrintFan copyWith({double? speed}) {
    return PrintFan(speed: speed ?? this.speed);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PrintFan &&
          runtimeType == other.runtimeType &&
          speed == other.speed;

  @override
  int get hashCode => speed.hashCode;
}
