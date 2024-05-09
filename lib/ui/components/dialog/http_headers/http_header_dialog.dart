/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/service/ui/dialog_service_interface.dart';
import 'package:common/ui/dialog/mobileraker_dialog.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/service/ui/dialog_service_impl.dart';

class HttpHeaderDialog extends HookConsumerWidget {
  final DialogRequest request;
  final DialogCompleter completer;

  const HttpHeaderDialog({
    super.key,
    required this.request,
    required this.completer,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ProviderScope(
      overrides: [dialogCompleterProvider.overrideWithValue(completer)],
      child: _HttpHeaderDialog(request: request, completer: completer),
    );
  }
}

class _HttpHeaderDialog extends HookConsumerWidget {
  const _HttpHeaderDialog({
    super.key,
    required this.request,
    required this.completer,
  });

  final DialogRequest request;
  final DialogCompleter completer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var themeData = Theme.of(context);
    var headerController = useTextEditingController(text: request.title);
    var valueController = useTextEditingController(text: request.body);

    return MobilerakerDialog(
      actionText: MaterialLocalizations.of(context).saveButtonLabel,
      onAction: () {
        completer(DialogResponse.confirmed(MapEntry(
          headerController.text.trim(),
          valueController.text.trim(),
        )));
      },
      dismissText: MaterialLocalizations.of(context).cancelButtonLabel,
      onDismiss: () => completer(DialogResponse.aborted()),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            tr('dialogs.http_header.title'),
            style: themeData.textTheme.titleLarge,
          ),
          SizedBox(height: 16),
          TextField(
            autofocus: true,
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
    );
  }
}
