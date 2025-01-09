/*
 * Copyright (c) 2023-2025. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:collection/collection.dart';
import 'package:common/data/model/sheet_action_mixin.dart';
import 'package:common/service/ui/bottom_sheet_service_interface.dart';
import 'package:common/util/extensions/object_extension.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class ActionBottomSheet extends ConsumerWidget {
  const ActionBottomSheet({super.key, required this.arguments});

  final ActionBottomSheetArgs arguments;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeData = Theme.of(context);

    return ListView(
      shrinkWrap: true,
      children: [
        const Gap(10),
        if (arguments.title != null) ...[
          ListTile(
            visualDensity: VisualDensity.compact,
            titleAlignment: ListTileTitleAlignment.center,
            leading: arguments.leading,
            iconColor: themeData.colorScheme.primary,
            // leading: arguments.leading,
            horizontalTitleGap: 8,
            title: arguments.title,
            subtitle: arguments.subtitle,
            minLeadingWidth: 42,
          ),
          const Divider(),
        ],
        for (final action in arguments.actions) _Entry(action: action),
      ],
    );
  }
}

class _Entry extends StatelessWidget {
  const _Entry({super.key, required this.action});

  final BottomSheetAction action;

  @override
  Widget build(BuildContext context) {
    final themeData = Theme.of(context);

    return switch (action) {
      DividerSheetAction() => const Divider(indent: 24 + 42 + 12, height: 4),
      _ => Padding(
          padding: themeData.useMaterial3 ? const EdgeInsets.only(left: 8.0) : EdgeInsets.zero,
          child: ListTile(
            enabled: action.enabled,
            visualDensity: VisualDensity.compact,
            leading: Icon(action.icon),
            horizontalTitleGap: 24,
            // horizontalTitleGap: 8,
            title: Text(action.labelTranslationKey).tr(),
            minLeadingWidth: 42,
            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.horizontal(left: Radius.circular(44)))
                .only(themeData.useMaterial3),
            onTap: () {
              context.pop(BottomSheetResult.confirmed(action));
            },
          ),
        ),
    };
  }
}

class ActionBottomSheetArgs {
  const ActionBottomSheetArgs({this.title, required this.actions, this.leading, this.subtitle});

  final Widget? title;
  final Widget? subtitle;
  final Widget? leading;
  final List<BottomSheetAction> actions;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ActionBottomSheetArgs &&
          runtimeType == other.runtimeType &&
          const DeepCollectionEquality().equals(other.actions, actions) &&
          leading == other.leading &&
          title == other.title &&
          subtitle == other.subtitle;

  @override
  int get hashCode => Object.hash(
        const DeepCollectionEquality().hash(actions),
        leading,
        title,
        subtitle,
      );

  @override
  String toString() {
    return 'ActionBottomSheetArgs{title: $title, actions: $actions}';
  }
}
