/*
 * Copyright (c) 2023-2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/service/ui/dialog_service_interface.dart';
import 'package:common/util/extensions/object_extension.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/service/ui/dialog_service_impl.dart';
import 'package:mobileraker/ui/screens/printers/components/section_header.dart';

class HttpHeadersFormField extends ConsumerWidget {
  const HttpHeadersFormField({super.key, this.initialValue = const {}, required this.name});

  final String name;
  final Map<String, String> initialValue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dialogService = ref.read(dialogServiceProvider);

    return FormBuilderField<Map<String, String>>(
      initialValue: initialValue,
      builder: (FormFieldState<Map<String, String>> field) {
        final enabled = field.widget.enabled && (FormBuilder.of(context)?.enabled ?? true);
        final headers = field.value ?? {};

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SectionHeader(title: tr('pages.printer_add.advanced_form.section_headers')),
                TextButton.icon(
                  onPressed: (() => dialogService.show(DialogRequest(type: DialogType.httpHeader)).then((
                    dialogResponse,
                  ) {
                    if (!field.mounted) return;
                    if (dialogResponse?.confirmed == true) {
                      final data = dialogResponse!.data as MapEntry<String, String>;
                      if (data.key.isNotEmpty) {
                        field.didChange(Map.unmodifiable({...headers}..[data.key] = data.value));
                      }
                    }
                  })).only(enabled),
                  icon: const Icon(Icons.add_box_outlined),
                  label: const Text('general.add').tr(),
                ),
              ],
            ),
            if (headers.isEmpty) Center(child: const Text('pages.printer_add.advanced_form.empty_headers').tr()),
            for (final MapEntry(:key, :value) in headers.entries)
              _HttpHeader(
                header: key,
                value: value,
                onDelete: (() => field.didChange(Map.unmodifiable({...headers}..remove(key)))).only(enabled),
                onTap:
                    (() => dialogService.show(DialogRequest(type: DialogType.httpHeader, title: key, body: value)).then(
                      (dialogResponse) {
                        if (!field.mounted) return;
                        if (dialogResponse?.confirmed == true) {
                          final data = dialogResponse!.data as MapEntry<String, String>;
                          final updated = {...headers}..remove(key);

                          if (data.key.isNotEmpty) {
                            updated[data.key] = data.value;
                          }
                          field.didChange(Map.unmodifiable(updated));
                        }
                      },
                    )).only(enabled),
              ),
          ],
        );
      },
      name: name,
    );
  }
}

class _HttpHeader extends StatelessWidget {
  const _HttpHeader({super.key, required this.header, required this.value, this.onTap, this.onDelete});

  final String header;
  final String value;
  final VoidCallback? onDelete;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final themeData = Theme.of(context);
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
          IconButton(onPressed: onDelete, icon: const Icon(Icons.delete_forever)),
        ],
      ),
    );
  }
}
