/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:collection/collection.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

extension MobilerakerDiscount on StoreProductDiscount {
  String get discountDurationText {
    //DAY, WEEK, MONTH or YEAR.
    var dateUnit = switch (periodUnit) {
      'YEAR' => plural('date.year', cycles),
      'MONTH' => plural('date.month', cycles),
      'WEEK' => plural('date.week', cycles),
      'DAY' => plural('date.day', cycles),
      _ => throw ArgumentError('Detected unsupported period'),
    };

    return '$cycles $dateUnit';
  }
}

extension MobilerakerIntroductoryPrice on IntroductoryPrice {
  String get discountDurationText {
    String dateUnit = periodUnitToText(periodUnit, cycles);

    return '$cycles $dateUnit';
  }
}

extension MobilerakerOption on SubscriptionOption {
  String? get introPhaseDurationText => _durationText(introPhase);

  String? get freePhaseDurationText => _durationText(freePhase);

  String? _durationText(PricingPhase? phase) {
    if (phase == null) return null;
    var period = phase.billingPeriod;
    // How often the billingPeriod is applied (E.g. Period is 7 days and cycle 3, results in 21 days)
    var cycles = phase.billingCycleCount ?? 1;
    var total = (period?.value ?? 1) * cycles;
    var dateUnit = periodUnitToText(period?.unit, total);

    // ToDo do I need info about the recurrenceMode??

    return '$total $dateUnit';
  }
}

String periodUnitToText(PeriodUnit? periodUnit, int cycles) {
  var dateUnit = switch (periodUnit) {
    PeriodUnit.year => plural('date.year', cycles),
    PeriodUnit.month || null => plural('date.month', cycles),
    PeriodUnit.week => plural('date.week', cycles),
    PeriodUnit.day => plural('date.day', cycles),
    _ => throw ArgumentError('Detected unsupported period'),
  };
  return dateUnit;
}

extension MobilerakerCustomerInfo on CustomerInfo {
  bool isSubscriptionActive(Package subPackage) {
    var productIdentifier = subPackage.storeProduct.identifier;
    if (subPackage.storeProduct.productCategory == ProductCategory.subscription) {
      return activeSubscriptions.contains(productIdentifier);
    }

    return nonSubscriptionTransactions
        .any((tx) => tx.productIdentifier == productIdentifier || tx.productIdentifier == '${productIdentifier}_promo');
  }

  EntitlementInfo? getActiveEntitlementForPackage(Package package) {
    var productIdentifier = package.storeProduct.identifier.split(':').first;

    return entitlements.active.values.firstWhereOrNull(
        (e) => e.productIdentifier == productIdentifier || e.productIdentifier == '${productIdentifier}_promo');
  }
}
