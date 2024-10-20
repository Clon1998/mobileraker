/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:collection/collection.dart';
import 'package:common/data/enums/sort_kind_enum.dart';
import 'package:common/data/enums/sort_mode_enum.dart';
import 'package:common/data/model/sort_configuration.dart';
import 'package:common/service/ui/bottom_sheet_service_interface.dart';
import 'package:common/util/extensions/object_extension.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class SortModeBottomSheet extends ConsumerWidget {
  const SortModeBottomSheet({super.key, required this.arguments});

  final SortModeSheetArgs arguments;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      shrinkWrap: true,
      children: [
        const Gap(10),
        ListTile(
          visualDensity: VisualDensity.compact,
          titleAlignment: ListTileTitleAlignment.center,
          // leading: arguments.leading,
          horizontalTitleGap: 8,
          title: const Text('pages.files.sort_by.sort_by').tr(),
          minLeadingWidth: 42,
        ),
        const Divider(),
        for (final entry in arguments.toShow)
          _Entry(mode: entry, kind: arguments.active.kind.only(entry == arguments.active.mode)),
      ],
    );
  }
}

class _Entry extends StatelessWidget {
  const _Entry({super.key, required this.mode, this.kind});

  final SortMode mode;
  final SortKind? kind;

  @override
  Widget build(BuildContext context) {
    final themeData = Theme.of(context);

    final Widget? ico = switch (kind) {
      SortKind.ascending => const Icon(Icons.arrow_upward),
      SortKind.descending => const Icon(Icons.arrow_downward),
      _ => const SizedBox(width: 24),
    };

    return Padding(
      padding: themeData.useMaterial3 ? const EdgeInsets.only(right: 8.0) : EdgeInsets.zero,
      child: ListTile(
        leading: ico,
        visualDensity: VisualDensity.compact,
        horizontalTitleGap: 16,
        title: Text(mode.translation).tr(),
        selectedTileColor: themeData.colorScheme.primary.withOpacity(0.1),
        // selectedTileColor: themeData.colorScheme.secondaryFixed.withOpacity(0.9),
        // selectedColor: themeData.colorScheme.onSecondaryFixed,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.horizontal(right: Radius.circular(44)))
            .only(themeData.useMaterial3),
        selected: kind != null,
        onTap: () {
          var nextKind = mode.defaultKind;
          if (kind != null) {
            nextKind = kind == SortKind.ascending ? SortKind.descending : SortKind.ascending;
          }

          final cfg = SortConfiguration(mode, nextKind);
          Navigator.of(context).pop(BottomSheetResult.confirmed(cfg));
        },
      ),
    );
  }
}

/// Arguments for displaying a sort mode sheet.
class SortModeSheetArgs {
  const SortModeSheetArgs({required this.toShow, required this.active});

  final List<SortMode> toShow;
  final SortConfiguration active; // Changed to Map for clarity

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SortModeSheetArgs &&
          runtimeType == other.runtimeType &&
          const DeepCollectionEquality().equals(other.toShow, toShow) &&
          active == other.active;

  @override
  int get hashCode => Object.hash(
        const DeepCollectionEquality().hash(toShow),
        active,
      );

  @override
  String toString() {
    return 'SortModeSheetArgs{toShow: $toShow, active: $active}';
  }
}
