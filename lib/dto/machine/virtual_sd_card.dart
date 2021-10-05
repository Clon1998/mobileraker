class VirtualSdCard {
  double progress = 0;
  bool isActive = false;
  int filePosition = 0;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is VirtualSdCard &&
              runtimeType == other.runtimeType &&
              progress == other.progress &&
              isActive == other.isActive &&
              filePosition == other.filePosition;

  @override
  int get hashCode =>
      progress.hashCode ^ isActive.hashCode ^ filePosition.hashCode;
}
