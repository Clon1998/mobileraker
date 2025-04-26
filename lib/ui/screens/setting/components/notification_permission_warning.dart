/*
 * Copyright (c) 2025. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/service/notification_service.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'animation_settings.dart';

part 'notification_permission_warning.g.dart';

class NotificationPermissionWarning extends ConsumerWidget {
  const NotificationPermissionWarning({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var themeData = Theme.of(context);
    return Material(
      type: MaterialType.transparency,
      child: AnimatedSwitcher(
        transitionBuilder: (child, anim) => SizeTransition(
          sizeFactor: anim,
          child: FadeTransition(opacity: anim, child: child),
        ),
        duration: kSettingPageWarningDuration,
        child: (ref.watch(_hasNotifcationPermissionProvider).valueOrNull != false)
            ? const SizedBox.shrink(key: Key('notiWarnEmpty'))
            : Padding(
                key: Key('notiWarn'),
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: ListTile(
                  tileColor: themeData.colorScheme.errorContainer,
                  textColor: themeData.colorScheme.onErrorContainer,
                  iconColor: themeData.colorScheme.onErrorContainer,
                  onTap: () async {
                    final service = ref.read(notificationServiceProvider);
                    try {
                      await service.requestNotificationPermission();
                    } finally {
                      ref.invalidate(_hasNotifcationPermissionProvider);
                    }
                  },
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(15)),
                  ),
                  leading: const Icon(
                    Icons.notifications_off_outlined,
                    size: 40,
                  ),
                  title: const Text(
                    'pages.setting.notification.no_permission_title',
                  ).tr(),
                  subtitle: const Text(
                    'pages.setting.notification.no_permission_desc',
                  ).tr(),
                ),
              ),
      ),
    );
  }
}

@riverpod
Future<bool> _hasNotifcationPermission(Ref ref) {
  final notificationService = ref.watch(notificationServiceProvider);

  return notificationService.hasNotificationPermission();
}
