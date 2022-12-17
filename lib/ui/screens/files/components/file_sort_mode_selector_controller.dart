import 'package:mobileraker/data/dto/files/folder.dart';
import 'package:mobileraker/data/dto/files/gcode_file.dart';
import 'package:mobileraker/data/dto/files/remote_file.dart';
import 'package:mobileraker/service/setting_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'file_sort_mode_selector_controller.g.dart';

enum FileSort {
  name('pages.files.name', RemoteFile.nameComparator, Folder.nameComparator),
  lastModified('pages.files.last_mod', RemoteFile.modifiedComparator,
      Folder.modifiedComparator),
  lastPrinted(
      'pages.files.last_printed', GCodeFile.lastPrintedComparator, null);

  const FileSort(this.translation, this.comparatorFile, this.comparatorFolder);

  final String translation;

  final Comparator<RemoteFile>? comparatorFile;
  final Comparator<Folder>? comparatorFolder;
}

@riverpod
class FileSortController extends _$FileSortController {
  @override
  FileSort build() {
    var selSort = ref
        .watch(settingServiceProvider)
        .readInt(selectedFileSort, FileSort.lastModified.index);

    if (selSort >= FileSort.values.length || selSort < 0) {
      selSort = FileSort.lastModified.index;
    }

    return FileSort.values[selSort];
  }

  updateSelected(FileSort newSelected) {
    state = newSelected;

    ref
        .read(settingServiceProvider)
        .writeInt(selectedFileSort, newSelected.index);
  }
}
