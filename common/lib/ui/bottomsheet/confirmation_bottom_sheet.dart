/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/ui/theme/theme_pack.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:smooth_sheets/smooth_sheets.dart';

part 'confirmation_bottom_sheet.freezed.dart';

class ConfirmationBottomSheet extends ConsumerWidget {
  const ConfirmationBottomSheet({
    super.key,
    required this.args,
  });

  final ConfirmationBottomSheetArgs args;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var themeData = Theme.of(context);
    var cc = themeData.extension<CustomColors>();

    final body = Padding(
      padding: const EdgeInsets.fromLTRB(25, 10, 25, 00),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            args.title,
            style: themeData.textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 5),
          Text(args.description, style: themeData.textTheme.titleSmall),
          const SizedBox(height: 10),
          if (args.hint != null) Text(args.hint!, style: themeData.textTheme.bodySmall, textAlign: TextAlign.center),
        ],
      ),
    );

    return SheetContentScaffold(
      body: body,
      bottomBar: StickyBottomBarVisibility(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 25.0, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (ModalRoute.of(context)?.impliesAppBarDismissal == true)
                  TextButton.icon(
                    label: Text(MaterialLocalizations.of(context).backButtonTooltip),
                    icon: const Icon(Icons.keyboard_arrow_left),
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                if (ModalRoute.of(context)?.impliesAppBarDismissal != true)
                  TextButton.icon(
                    label: Text(MaterialLocalizations.of(context).closeButtonTooltip),
                    icon: const Icon(Icons.keyboard_arrow_down),
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: cc?.danger, foregroundColor: cc?.onDanger),
                  onPressed: () => context.pop(true),
                  child: const Text('general.confirm').tr(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

@freezed
class ConfirmationBottomSheetArgs with _$ConfirmationBottomSheetArgs {
  const factory ConfirmationBottomSheetArgs({
    required String title,
    required String description,
    String? hint,
  }) = _ConfirmationBottomSheetArgs;
}
