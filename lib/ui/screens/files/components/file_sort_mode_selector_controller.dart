/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:mobileraker/data/dto/files/gcode_file.dart';
import 'package:mobileraker/data/dto/files/remote_file_mixin.dart';
import 'package:mobileraker/service/setting_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'file_sort_mode_selector_controller.g.dart';

enum FileSort {
  name('pages.files.name', RemoteFile.nameComparator),
  lastModified('pages.files.last_mod', RemoteFile.modifiedComparator),
  lastPrinted('pages.files.last_printed', GCodeFile.lastPrintedComparator);

  const FileSort(this.translation, this.comparatorFile);

  final String translation;

  final Comparator<RemoteFile>? comparatorFile;
}

@riverpod
class FileSortController extends _$FileSortController {
  @override
  FileSort build() {
    var selSort = ref
        .watch(settingServiceProvider)
        .readInt(UtilityKeys.fileSortingIndex, FileSort.lastModified.index);

    if (selSort >= FileSort.values.length || selSort < 0) {
      selSort = FileSort.lastModified.index;
    }

    return FileSort.values[selSort];
  }

  updateSelected(FileSort newSelected) {
    state = newSelected;

    ref
        .read(settingServiceProvider)
        .writeInt(UtilityKeys.fileSortingIndex, newSelected.index);
  }
}
