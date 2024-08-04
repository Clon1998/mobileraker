/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/dto/files/gcode_file.dart';
import 'package:common/data/dto/files/remote_file_mixin.dart';
import 'package:common/service/selected_machine_service.dart';
import 'package:common/service/setting_service.dart';
import 'package:common/util/extensions/async_ext.dart';
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
  // Just have a fallback
  String _suffix = 'fallback';

  KeyValueStoreKey get _key => CompositeKey.keyWithString(UtilityKeys.fileExplorerSortCfg, _suffix);

  @override
  FileSort build() {
    _suffix = ref.watch(selectedMachineProvider.selectAs((value) => value?.uuid)).valueOrNull ?? '';

    var selSort = ref
        .watch(settingServiceProvider).readInt(_key, FileSort.lastModified.index);

    if (selSort >= FileSort.values.length || selSort < 0) {
      selSort = FileSort.lastModified.index;
    }

    return FileSort.values[selSort];
  }

  updateSelected(FileSort newSelected) {
    state = newSelected;

    ref
        .read(settingServiceProvider).writeInt(_key, newSelected.index);
  }
}
