/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/service/ui/dialog_service.dart';

class HttpHeaderDialog extends HookConsumerWidget {
  final DialogRequest request;
  final DialogCompleter completer;

  const HttpHeaderDialog({Key? key, required this.request, required this.completer})
      : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ProviderScope(
        overrides: [
          dialogCompleterProvider.overrideWithValue(completer),
        ],
        child: _HttpHeaderDialog(
          request: request,
          completer: completer,
        ));
  }
}

class _HttpHeaderDialog extends HookConsumerWidget {
  const _HttpHeaderDialog({
    Key? key,
    required this.request,
    required this.completer,
  }) : super(key: key);

  final DialogRequest request;
  final DialogCompleter completer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var themeData = Theme.of(context);
    var headerController = useTextEditingController(text: request.title);
    var valueController = useTextEditingController(text: request.body);

    return Dialog(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 15),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Text(
                tr('dialogs.http_header.title'),
                style: themeData.textTheme.titleLarge,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    decoration: InputDecoration(
                      labelText: tr('dialogs.http_header.header'),
                      hintText: tr('dialogs.http_header.header_hint'),
                    ),
                    controller: headerController,
                    enableSuggestions: false,
                  ),
                  TextField(
                    decoration: InputDecoration(
                      labelText: tr('dialogs.http_header.value'),
                      hintText: tr('dialogs.http_header.value_hint'),
                    ),
                    minLines: 1,
                    maxLines: 10,
                    controller: valueController,
                    enableSuggestions: false,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => completer(DialogResponse.aborted()),
                    child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
                  ),
                  TextButton(
                    onPressed: () {
                      completer(DialogResponse.confirmed(MapEntry(
                        headerController.text.trim(),
                        valueController.text.trim(),
                      )));
                    },
                    child: Text(MaterialLocalizations.of(context).saveButtonLabel),
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}
