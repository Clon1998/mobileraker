import 'package:mobileraker/dto/files/notification/file_list_changed_item.dart';
import 'package:mobileraker/dto/files/notification/file_list_changed_source_item.dart';
import 'package:mobileraker/service/file_service.dart';

class FileListChangedNotification {
  FileAction fileAction;
  FileListChangedItem item;
  FileListChangedSourceItem? sourceItem;

  FileListChangedNotification(this.fileAction, this.item, [this.sourceItem]);

  @override
  String toString() {
    return 'FileListChangedNotification{fileAction: $fileAction, item: $item, sourceItem: $sourceItem}';
  }
}
