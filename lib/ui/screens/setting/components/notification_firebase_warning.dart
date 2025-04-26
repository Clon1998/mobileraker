/*
 * Copyright (c) 2025. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/enums/consent_entry_type.dart';
import 'package:common/data/enums/consent_status.dart';
import 'package:common/service/consent_service.dart';
import 'package:common/service/notification_service.dart';
import 'package:common/ui/components/async_button_.dart';
import 'package:common/ui/components/nav/nav_rail_view.dart';
import 'package:common/ui/components/responsive_limit.dart';
import 'package:common/util/extensions/build_context_extension.dart';
import 'package:common/util/extensions/object_extension.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/ui/screens/setting/components/companion_missing_warning.dart';
import 'package:mobileraker/ui/screens/setting/setting_controller.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'animation_settings.dart';
import 'section_header.dart';

part 'notification_firebase_warning.g.dart';

class NotificationFirebaseWarning extends ConsumerWidget {
  const NotificationFirebaseWarning({super.key});

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
        child: (ref.watch(notificationFirebaseAvailableProvider).valueOrNull != false)
            ? const SizedBox.shrink()
            : Padding(
                key: UniqueKey(),
                padding: const EdgeInsets.only(top: 16),
                child: ListTile(
                  tileColor: themeData.colorScheme.errorContainer,
                  textColor: themeData.colorScheme.onErrorContainer,
                  iconColor: themeData.colorScheme.onErrorContainer,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(15)),
                  ),
                  leading: const Icon(
                    FlutterIcons.notifications_paused_mdi,
                    size: 40,
                  ),
                  title: const Text(
                    'pages.setting.notification.no_firebase_title',
                  ).tr(),
                  subtitle: const Text('pages.setting.notification.no_firebase_desc').tr(),
                ),
              ),
      ),
    );
  }
}

@riverpod
Future<bool> notificationFirebaseAvailable(Ref ref) {
  var notificationService = ref.watch(notificationServiceProvider);
  return notificationService.isFirebaseAvailable();
}
