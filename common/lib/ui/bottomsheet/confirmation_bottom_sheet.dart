/*
 * Copyright (c) 2023-2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/service/ui/bottom_sheet_service_interface.dart';
import 'package:common/ui/components/sheet_search_header.dart';
import 'package:common/ui/theme/theme_pack.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:smooth_sheets/smooth_sheets.dart';

part 'confirmation_bottom_sheet.freezed.dart';

/// Asks to confirm an action: the shared sheet header with the [ConfirmationBottomSheetArgs.title], the description,
/// an optional hint and cancel/confirm buttons. Pops with [BottomSheetResult.confirmed] or [BottomSheetResult.dismissed].
class ConfirmationBottomSheet extends ConsumerWidget {
  const ConfirmationBottomSheet({super.key, required this.args});

  final ConfirmationBottomSheetArgs args;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeData = Theme.of(context);
    final colorScheme = themeData.colorScheme;
    final cc = themeData.extension<CustomColors>();
    final buttonSize = const Size.fromHeight(48);

    return SheetContentScaffold(
      topBar: SheetSearchHeader(title: args.title),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(args.description, style: themeData.textTheme.bodyLarge),
            if (args.hint != null) ...[
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lightbulb_outline, size: 16, color: colorScheme.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      args.hint!,
                      style: themeData.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
      bottomBarVisibility: BottomBarVisibility.always(),
      bottomBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(minimumSize: buttonSize),
                  onPressed: () => context.pop(BottomSheetResult.dismissed()),
                  child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize: buttonSize,
                    backgroundColor: args.danger ? cc?.danger : null,
                    foregroundColor: args.danger ? cc?.onDanger : null,
                  ),
                  onPressed: () => context.pop(BottomSheetResult.confirmed()),
                  child: Text(args.actionLabel ?? tr('general.confirm')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

@freezed
sealed class ConfirmationBottomSheetArgs with _$ConfirmationBottomSheetArgs {
  const factory ConfirmationBottomSheetArgs({
    required String title,
    required String description,
    String? hint,
    String? actionLabel,
    @Default(true) bool danger,
  }) = _ConfirmationBottomSheetArgs;
}
