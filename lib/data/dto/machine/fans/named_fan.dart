import 'package:mobileraker/data/dto/machine/fans/fan.dart';

abstract class NamedFan implements Fan {
  String name;

  NamedFan(this.name);
}
