/*
 * Copyright (c) 2025. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/service/machine_service.dart';
import 'package:common/util/extensions/async_ext.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/ui/screens/setting/setting_controller.dart';

import 'animation_settings.dart';

class CompanionMissingWarning extends ConsumerWidget {
  const CompanionMissingWarning({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var machinesWithoutCompanion =
        ref.watch(machinesWithoutCompanionProvider.selectAs((value) => value.map((e) => e.name)));

    var themeData = Theme.of(context);
    return Material(
      type: MaterialType.transparency,
      child: AnimatedSwitcher(
        transitionBuilder: (child, anim) => SizeTransition(
          sizeFactor: anim,
          child: FadeTransition(opacity: anim, child: child),
        ),
        duration: kSettingPageWarningDuration,
        child: switch (machinesWithoutCompanion) {
          AsyncData(value: final machineNames) when machineNames.isNotEmpty => Padding(
              padding: const EdgeInsets.only(top: 16),
              child: ListTile(
                onTap: ref.read(settingPageControllerProvider.notifier).openCompanion,
                tileColor: themeData.colorScheme.errorContainer,
                textColor: themeData.colorScheme.onErrorContainer,
                iconColor: themeData.colorScheme.onErrorContainer,
                // onTap: ref
                //     .watch(notificationPermissionControllerProvider.notifier)
                //     .requestPermission,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(15)),
                ),
                leading: const Icon(FlutterIcons.uninstall_ent, size: 40),
                title: const Text(
                  'pages.setting.notification.missing_companion_title',
                ).tr(),
                subtitle: const Text(
                  'pages.setting.notification.missing_companion_body',
                ).tr(args: [machineNames.join(', ')]),
              ),
            ),
          _ => SizedBox.shrink(),
        },
      ),
    );
  }
}
