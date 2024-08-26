/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/service/ui/dialog_service_interface.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

class SearchFileDialog extends HookWidget {
  final DialogRequest request;
  final DialogCompleter completer;

  const SearchFileDialog({
    super.key,
    required this.request,
    required this.completer,
  });

  @override
  Widget build(BuildContext context) {
    final textController = useTextEditingController();

    return Dialog.fullscreen(
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: Icon(Icons.arrow_back),
            onPressed: () {
              completer(DialogResponse(confirmed: false));
            },
          ),
          actions: [
            IconButton(
              tooltip: 'Clear Search',
              icon: Icon(Icons.search_off),
              onPressed: textController.clear,
            ),
          ],
          title: TextField(
            controller: textController,
            autofocus: true,
            // cursorColor: onBackground,
            // style: themeData.textTheme.titleLarge?.copyWith(color: onBackground),
            decoration: InputDecoration(
              hintText: '${tr('pages.files.search_files')}...',
              // hintStyle: themeData.textTheme.titleLarge?.copyWith(color: onBackground.withOpacity(0.4)),
              border: InputBorder.none,
            ),
          ),
        ),
        body: Column(
          children: [
            Text('No Results'),
          ],
        ),
      ),
    );
  }
}
