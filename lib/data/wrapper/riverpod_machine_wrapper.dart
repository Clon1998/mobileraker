import 'package:mobileraker/data/model/hive/machine.dart';

/// We need this wrapper to use machine for family ....
class MachineWrapper {

  MachineWrapper(this.machine);

  final Machine machine;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MachineWrapper &&
          runtimeType == other.runtimeType &&
          machine.uuid == other.machine.uuid;

  @override
  int get hashCode => machine.uuid.hashCode;
}
