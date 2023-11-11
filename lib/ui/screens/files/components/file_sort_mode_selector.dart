/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/ui/screens/files/components/file_sort_mode_selector_controller.dart';

class FileSortModeSelector extends ConsumerWidget {
  const FileSortModeSelector({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<FileSort>(
      icon: const Icon(Icons.sort),
      onSelected: ref.watch(fileSortControllerProvider.notifier).updateSelected,
      itemBuilder: (BuildContext context) =>
          List.generate(FileSort.values.length, (index) {
        var e = FileSort.values[index];
        return CheckedPopupMenuItem(
          value: e,
          checked: e == ref.watch(fileSortControllerProvider),
          child: Text(e.translation).tr(),
        );
      }),
    );
  }
}
