import 'package:mobileraker/dto/machine/fans/fan.dart';

abstract class NamedFan implements Fan {
  String name;

  NamedFan(this.name);
}
