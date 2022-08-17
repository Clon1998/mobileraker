import 'fan.dart';

abstract class NamedFan implements Fan {
  abstract final String name;

  NamedFan copyWith({String? name, double? speed});
}
