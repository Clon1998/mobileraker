/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

class Command {
  final String cmd;
  final String description;

  Command(this.cmd, this.description);

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
