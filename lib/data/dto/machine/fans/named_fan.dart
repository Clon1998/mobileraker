import 'fan.dart';

abstract class NamedFan implements Fan {
  const NamedFan();
  abstract final String name;
}
