/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/service/ui/dialog_service_interface.dart';
import 'package:common/util/logger.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/service/ui/dialog_service_impl.dart';
import 'package:mobileraker/ui/screens/printers/components/section_header.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'http_headers.g.dart';

@riverpod
class HeadersController extends _$HeadersController {
  @override
  Map<String, String> build(Map<String, String> initValue) {
    return initValue;
  }

  Future<void> addHttpHeader() async {
    var dialogResponse = await ref.read(dialogServiceProvider).show(DialogRequest(type: DialogType.httpHeader));

    if (dialogResponse?.confirmed == true) {
      var data = dialogResponse!.data as MapEntry<String, String>;
      logger.i('Got httpHeader response from dialog: $data');
      if (data.key.isNotEmpty) {
        state = {...state, data.key: data.value};
      }
    }
  }

  Future<void> editHttpHeader(String header, String value) async {
    var dialogResponse = await ref.read(dialogServiceProvider).show(DialogRequest(
          type: DialogType.httpHeader,
          title: header,
          body: value,
        ));

    if (dialogResponse?.confirmed == true) {
      var data = dialogResponse!.data as MapEntry<String, String>;
      logger.i('Got httpHeader response from dialog: $data');
      if (data.key != header) deleteHttpHeader(header);
      if (data.key.isNotEmpty) {
        state = {...state, data.key: data.value};
      }
    }
  }

  deleteHttpHeader(String header) {
    var current = Map.of(state);
    current.remove(header);
    state = Map.unmodifiable(current);
  }
}

class HttpHeaders extends ConsumerWidget {
  const HttpHeaders({super.key, this.initialValue = const {}});

  final Map<String, String> initialValue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var provider = headersControllerProvider(initialValue);
    var model = ref.watch(provider);
    var controller = ref.watch(provider.notifier);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SectionHeader(
              title: tr('pages.printer_add.advanced_form.section_headers'),
            ),
            TextButton.icon(
              onPressed: controller.addHttpHeader,
              icon: const Icon(Icons.add_box_outlined),
              label: const Text('general.add').tr(),
            ),
          ],
        ),
        if (model.isEmpty)
          Center(
            child: const Text('pages.printer_add.advanced_form.empty_headers').tr(),
          ),
        ...model.entries.map((e) => _HttpHeader(
              header: e.key,
              value: e.value,
              onDelete: () => controller.deleteHttpHeader(e.key),
              onTap: () => controller.editHttpHeader(e.key, e.value),
            )),
      ],
    );
  }
}

class _HttpHeader extends StatelessWidget {
  const _HttpHeader({
    super.key,
    required this.header,
    required this.value,
    this.onTap,
    this.onDelete,
  });

  final String header;
  final String value;
  final VoidCallback? onDelete;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    var themeData = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(header, style: themeData.listTileTheme.titleTextStyle),
                Text(
                  value.isEmpty ? '<EMPTY_VALUE>' : value,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: themeData.textTheme.bodySmall?.copyWith(fontSize: 13),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_forever),
          ),
        ],
      ),
    );
  }
}
