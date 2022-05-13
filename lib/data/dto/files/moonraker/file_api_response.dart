import 'package:enum_to_string/enum_to_string.dart';
import 'package:mobileraker/data/dto/files/moonraker/file_notification_item.dart';
import 'package:mobileraker/data/dto/files/moonraker/file_notification_source_item.dart';
import 'package:mobileraker/service/moonraker/file_service.dart';

class FileApiResponse {
  final FileAction fileAction;
  final FileNotificationItem item;
  final FileNotificationSourceItem? sourceItem;
  
  FileApiResponse.fromJson(Map<String, dynamic> json)
      : this.fileAction =
            EnumToString.fromString(FileAction.values, json['action'])!,
        this.item = FileNotificationItem.fromJson(json['item']),
        this.sourceItem = (json.containsKey('source_item'))
            ? FileNotificationSourceItem.fromJson(json['source_item'])
            : null;


  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FileApiResponse &&
          runtimeType == other.runtimeType &&
          fileAction == other.fileAction &&
          item == other.item &&
          sourceItem == other.sourceItem;

  @override
  int get hashCode => fileAction.hashCode ^ item.hashCode ^ sourceItem.hashCode;

  @override
  String toString() {
    return 'FileListChangedNotification{fileAction: $fileAction, item: $item, sourceItem: $sourceItem}';
  }
}
