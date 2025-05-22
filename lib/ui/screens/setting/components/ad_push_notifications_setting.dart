/*
 * Copyright (c) 2025. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/enums/consent_entry_type.dart';
import 'package:common/data/enums/consent_status.dart';
import 'package:common/service/consent_service.dart';
import 'package:common/ui/components/async_button_.dart';
import 'package:common/util/extensions/object_extension.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class AdPushNotificationsSetting extends ConsumerWidget {
  const AdPushNotificationsSetting({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final consentService = ref.watch(consentServiceProvider);

    var consentState = ref.watch(consentEntryProvider(ConsentEntryType.marketingNotifications));

    final value = consentState.hasValue && consentState.value!.status == ConsentStatus.GRANTED;

    final enabled = consentState.hasValue && !consentState.hasError;
    // logger.wtf('ConsentState: $consentState, Value: $value, Enabled: $enabled');

    return InputDecorator(
      decoration: InputDecoration(
        border: InputBorder.none,
        isCollapsed: true,
        errorText: tr('pages.setting.notification.opt_out_marketing_error').only(consentState.hasError),
      ),
      child: ListTile(
        dense: true,
        isThreeLine: false,
        enabled: enabled,
        contentPadding: EdgeInsets.zero,
        title: Text(ConsentEntryType.marketingNotifications.title).tr(),
        subtitle: Text(ConsentEntryType.marketingNotifications.shortDescription).tr(),
        trailing: AsyncSwitch(
          value: value,
          onChanged: (b) {
            return consentService.updateConsentEntry(
              ConsentEntryType.marketingNotifications,
              b ? ConsentStatus.GRANTED : ConsentStatus.DENIED,
            );
          }.only(enabled),
        ),
      ),
    );
  }
}
