/*
 * Copyright (c) 2023-2025. Patrick Schmidt.
 * All rights reserved.
 */

class Command {
  final String cmd;
  final String description;

  Command(this.cmd, this.description);

  // Entries starting with '_' are considered hidden and can be filtered out in the UI.
  bool get isInternal => cmd.startsWith('_');

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Command &&
          runtimeType == other.runtimeType &&
          cmd == other.cmd &&
          description == other.description;

  @override
  int get hashCode => cmd.hashCode ^ description.hashCode;

  @override
  String toString() {
    return 'Command{cmd: $cmd, description: $description}';
  }
}
