import 'package:mobileraker/dto/machine/fans/fan.dart';

class PrintFan implements Fan {
  @override
  double speed = 0.0;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is PrintFan &&
              runtimeType == other.runtimeType &&
              speed == other.speed;

  @override
  int get hashCode => speed.hashCode;
}
