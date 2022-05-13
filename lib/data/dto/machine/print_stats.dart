enum PrintState { standby, printing, paused, complete, error }

String printStateName(PrintState printState) {
  switch (printState) {
    case PrintState.standby:
      return "Standby";
    case PrintState.printing:
      return "Printing";
    case PrintState.paused:
      return "Paused";
    case PrintState.complete:
      return "Complete";
    case PrintState.error:
    default:
      return "error";
  }
}

class PrintStats {
  PrintState state = PrintState.error;
  double totalDuration = 0;
  double printDuration = 0;
  double filamentUsed = 0;
  String message = "";
  String filename = "";

  String get stateName => printStateName(state);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PrintStats &&
          runtimeType == other.runtimeType &&
          state == other.state &&
          totalDuration == other.totalDuration &&
          printDuration == other.printDuration &&
          filamentUsed == other.filamentUsed &&
          message == other.message &&
          filename == other.filename;

  @override
  int get hashCode =>
      state.hashCode ^
      totalDuration.hashCode ^
      printDuration.hashCode ^
      filamentUsed.hashCode ^
      message.hashCode ^
      filename.hashCode;
}
