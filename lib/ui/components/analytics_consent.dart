/*
 * Copyright (c) 2025. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/util/logger.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:iabtcf_consent_info/iabtcf_consent_info.dart';

class AnalyticsConsent extends HookConsumerWidget {
  const AnalyticsConsent({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tcfStream = useMemoized(() => IabtcfConsentInfo.instance.consentInfo());

    useEffect(() {
      final subscription = tcfStream.listen(_handleConsentUpdate);
      return subscription.cancel;
    }, [tcfStream]);

    return child;
  }

  void _handleConsentUpdate(BasicConsentInfo? event) {
    if (event == null) return;

    final analytics = FirebaseAnalytics.instance;
    talker.info('[AnalyticsConsent] IAB-TCF Received a new value: $event');

    if (event.gdprApplies == false) {
      _setAllConsents(analytics, granted: true);
      talker.info('[AnalyticsConsent] IAB-TCF GDPR does not apply - all consents granted');
      return;
    }

    talker.info('[AnalyticsConsent] IAB-TCF GDPR applies');

    if (event case ConsentInfo()) {
      _setConsentsBasedOnResult(analytics, event);
    } else {
      _setAllConsents(analytics, granted: false);
      talker.info('[AnalyticsConsent] IAB-TCF GDPR applies but no consent info available');
    }
  }

  void _setAllConsents(FirebaseAnalytics analytics, {required bool granted}) {
    analytics.setConsent(
      adStorageConsentGranted: granted,
      analyticsStorageConsentGranted: granted,
      adPersonalizationSignalsConsentGranted: granted,
      adUserDataConsentGranted: granted,
    );
  }

  void _setConsentsBasedOnResult(FirebaseAnalytics analytics, ConsentInfo consentInfo) {
    final consents = consentInfo.publisherConsents;
    final adStorage = consents.contains(DataUsagePurpose.storeAndAccessInformationOnADevice);
    final analyticsStorage = consents.contains(DataUsagePurpose.measureContentPerformance);
    final adPersonalization = consents.contains(DataUsagePurpose.selectPersonalisedAds);
    final adUserData = consents.contains(DataUsagePurpose.createAPersonalisedAdsProfile);

    talker.info('[AnalyticsConsent] Setting consent - '
        'adStorage: $adStorage, '
        'analyticsStorage: $analyticsStorage, '
        'adPersonalization: $adPersonalization, '
        'adUserData: $adUserData');

    analytics.setConsent(
      adStorageConsentGranted: adStorage,
      analyticsStorageConsentGranted: analyticsStorage,
      adPersonalizationSignalsConsentGranted: adPersonalization,
      adUserDataConsentGranted: adUserData,
    );
  }
}
