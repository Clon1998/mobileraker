/*
 * Copyright (c) 2025. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:io';

import 'package:common/service/payment_service.dart';
import 'package:common/ui/components/error_card.dart';
import 'package:common/util/extensions/object_extension.dart';
import 'package:common/util/time_util.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/util/extensions/revenuecat_extension.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

class SupporterOfferings extends StatelessWidget {
  const SupporterOfferings({super.key, this.packets, this.iapPromos, this.purchasePackage});

  final List<Package>? packets;
  final List<Package>? iapPromos;
  final Function(Package packageToBuy)? purchasePackage;

  @override
  Widget build(BuildContext context) {
    if (packets == null || packets!.isEmpty) {
      return ErrorCard(
        title: const Text('pages.paywall.supporter_tier_list.error_title').tr(),
        body: const Text('pages.paywall.supporter_tier_list.error_body').tr(),
      );
    }

    for (var package in packets!) {
      // if (package.identifier != '\$rc_annual') continue;
      //
      // talker.warning('Package: ${package}');
      // talker.warning('\tSP: ${package.storeProduct}');
      //
      // talker.warning('\t\tDefault: ${package.storeProduct.defaultOption}');
      // talker.warning('\t\t\tTrial: ${package.storeProduct.defaultOption?.freePhase}');
      // talker.warning('\t\t\tIntro: ${package.storeProduct.defaultOption?.introPhase}');
      // talker.warning('\t\t\tFull: ${package.storeProduct.defaultOption?.fullPricePhase}');
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        for (var package in packets!)
          _ProductPackage(
              package: package, promoPackage: _iapPromoForPackage(package), purchasePackage: purchasePackage),
      ],
    );
  }

  Package? _iapPromoForPackage(Package package) {
    if (package.storeProduct.productCategory != ProductCategory.nonSubscription) return null;
    return iapPromos?.firstWhereOrNull(
      (promo) => promo.storeProduct.identifier == '${package.storeProduct.identifier}_promo',
    );
  }
}

class _ProductPackage extends ConsumerWidget {
  const _ProductPackage({super.key, required this.package, this.promoPackage, this.purchasePackage});

  final Package package;

  final Package? promoPackage;

  final Function(Package packageToBuy)? purchasePackage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    EntitlementInfo? activeEntitlement = ref.watch(customerInfoProvider.select((asyncData) {
      CustomerInfo? customerInfo = asyncData.valueOrNull;

      // talker.warning('CustomerInfo:');
      // talker.warning('\tActive: ${customerInfo?.entitlements.active}');

      if (customerInfo?.isSubscriptionActive(package) != true) return null;
      return customerInfo!.getActiveEntitlementForPackage(package);
    }));

    if (package.storeProduct.productCategory == ProductCategory.nonSubscription) {
      return _InAppPurchaseProduct(
        activeEntitlement: activeEntitlement,
        iapPackage: package,
        promoPackage: promoPackage,
        purchasePackage: purchasePackage,
      );
    }

    // Android Subscriptions since they might have options (E.g. offers/promos) -> ALL android subs
    if (package.storeProduct.defaultOption != null) {
      return _SubscriptionOptionProduct(
        package: package,
        activeEntitlement: activeEntitlement,
        purchasePackage: purchasePackage,
      );
    }
    return _SubscriptionProduct(
      package: package,
      activeEntitlement: activeEntitlement,
      purchasePackage: purchasePackage,
    );
  }
}

class _InAppPurchaseProduct extends ConsumerWidget {
  const _InAppPurchaseProduct({
    super.key,
    required this.activeEntitlement,
    required this.iapPackage,
    this.promoPackage,
    this.purchasePackage,
  });

  final EntitlementInfo? activeEntitlement;
  final Package iapPackage;
  final Package? promoPackage;
  final Function(Package packageToBuy)? purchasePackage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var storeProduct = iapPackage.storeProduct;
    var promoStoreProduct = promoPackage?.storeProduct;

    return _ProductTile(
      purchasePackage: () => purchasePackage?.call(promoPackage ?? iapPackage),
      isActiveSubscription: activeEntitlement?.isActive == true,
      isRenewingSubscription: false,
      isLifetimeSubscription: true,
      productTitle: iapPackage.localizedTitle,
      productSubtitle: _constructSubtitle(context, storeProduct, promoStoreProduct) ?? iapPackage.localizedSubtitle,
      productPriceString: storeProduct.priceString,
      discountedPriceString: promoStoreProduct?.priceString,
      highlight: true,
    );
  }

  String? _constructSubtitle(BuildContext context, StoreProduct storeProduct, StoreProduct? promoStoreProduct) {
    if (promoStoreProduct == null) return null;

    double offerDiscount = 1 - (promoStoreProduct.price / storeProduct.price);

    return tr('pages.paywall.iap_offer', args: [
      NumberFormat.percentPattern(context.locale.toStringWithSeparator()).format(offerDiscount),
    ]);
  }
}

// For apple subscriptions
class _SubscriptionProduct extends ConsumerWidget {
  const _SubscriptionProduct({super.key, required this.package, required this.activeEntitlement, this.purchasePackage});

  final EntitlementInfo? activeEntitlement;
  final Package package;
  final Function(Package packageToBuy)? purchasePackage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var storeProduct = package.storeProduct;
    var discountOffer = storeProduct.discounts?.firstOrNull;

    // talker.warning('discountOffer: ${storeProduct.introductoryPrice}');

    // ToDo: Intro Prices for IOS
    // var hasIntroPrice = storeProduct.introductoryPrice != null;
    // Purchases.checkTrialOrIntroductoryPriceEligibility(productIdentifiers) // IOS ONLY

    return _ProductTile(
      purchasePackage: () => purchasePackage?.call(package),
      isActiveSubscription: activeEntitlement?.isActive == true,
      isRenewingSubscription: activeEntitlement?.willRenew == true,
      isLifetimeSubscription: package.packageType == PackageType.lifetime,
      productTitle: package.localizedTitle,
      productSubtitle: _constructHeader(context, storeProduct) ?? package.localizedSubtitle,
      productIso8601: storeProduct.subscriptionPeriod,
      productPriceString: storeProduct.priceString,
      discountedPriceString: discountOffer?.priceString,
    );
  }

  String? _constructHeader(BuildContext context, StoreProduct storeProduct) {
    var discountOffer = storeProduct.discounts?.firstOrNull;
    var introOffer = storeProduct.introductoryPrice;

    if (discountOffer == null && introOffer == null) return null;

    String offerDuration;
    double offerDiscount;
    if (introOffer != null) {
      offerDuration = introOffer.discountDurationText;
      offerDiscount = 1 - (introOffer.price / storeProduct.price);
    } else {
      offerDuration = discountOffer!.discountDurationText;
      offerDiscount = 1 - (discountOffer.price / storeProduct.price);
    }

    return tr('pages.paywall.intro_phase', args: [
      offerDuration,
      NumberFormat.percentPattern(context.locale.toStringWithSeparator()).format(offerDiscount),
    ]);
  }
}

// For android subscriptions due to the new api that has Options (like yearly, monthly...)
class _SubscriptionOptionProduct extends ConsumerWidget {
  const _SubscriptionOptionProduct({super.key, required this.package, this.activeEntitlement, this.purchasePackage});

  final EntitlementInfo? activeEntitlement;
  final Package package;
  final Function(Package packageToBuy)? purchasePackage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var storeProduct = package.storeProduct;

    var defaultOption = storeProduct.defaultOption!;

    var isDiscounted = !defaultOption.isBasePlan;
    var hasFreePhase = defaultOption.freePhase != null;
    var hasIntroPhase = defaultOption.introPhase != null;

    String? discountedPriceString;
    if (isDiscounted && (hasIntroPhase || hasFreePhase)) {
      discountedPriceString = hasFreePhase ? tr('general.free') : defaultOption.introPhase!.price.formatted;
    }

    return _ProductTile(
      purchasePackage: () => purchasePackage?.call(package),
      isActiveSubscription: activeEntitlement?.isActive == true,
      isRenewingSubscription: activeEntitlement?.willRenew == true,
      isLifetimeSubscription: false,
      productTitle: package.localizedTitle,
      productSubtitle: _productSubtitle(defaultOption, context) ?? package.localizedSubtitle,
      productIso8601: (!hasFreePhase || hasIntroPhase) ? storeProduct.subscriptionPeriod : null,
      offerFooter: _productOfferFooter(defaultOption),
      productPriceString: storeProduct.priceString,
      discountedPriceString: discountedPriceString,
    );
  }

  String? _productOfferFooter(SubscriptionOption subscriptionOption) {
    // So far only android complaint
    if (!Platform.isAndroid) return null;

    if (subscriptionOption.freePhase != null) return tr('pages.paywall.trial_disclaimer');
    return tr('pages.paywall.subscription_disclaimer');
  }

  String? _productSubtitle(SubscriptionOption subscriptionOption, BuildContext context) {
    if (subscriptionOption.isBasePlan) return null;

    var tmp = <String>[];
    if (subscriptionOption.freePhase != null) {
      tmp.add(tr(
        'pages.paywall.free_phase',
        args: [subscriptionOption.freePhaseDurationText!],
      ));
    }
    if (subscriptionOption.introPhase != null) {
      // First, normalize both prices to a per-day rate
      double introPricePerDay = _normalizeToPerDay(
        subscriptionOption.introPhase!.price.amountMicros,
        subscriptionOption.introPhase!.billingPeriod!,
      );

      double fullPricePerDay = _normalizeToPerDay(
        subscriptionOption.fullPricePhase!.price.amountMicros,
        subscriptionOption.fullPricePhase!.billingPeriod!,
      );

      var discount = 1 - (introPricePerDay / fullPricePerDay);
      tmp.add(tr('pages.paywall.intro_phase', args: [
        subscriptionOption.introPhaseDurationText!,
        NumberFormat.percentPattern(context.locale.toStringWithSeparator()).format(discount),
      ]));
    }
    return tmp.isEmpty ? null : tmp.join(' + ');
  }

  double _normalizeToPerDay(int amountMicros, Period period) {
    int daysInPeriod = _convertPeriodToDays(period) * period.value;
    return amountMicros / daysInPeriod;
  }

  int _convertPeriodToDays(Period period) {
    switch (period.unit) {
      case PeriodUnit.day:
        return period.value;
      case PeriodUnit.week:
        return period.value * 7;
      case PeriodUnit.month:
        return period.value * 30; // Approximation
      case PeriodUnit.year:
        return period.value * 365; // Approximation
      case PeriodUnit.unknown:
        throw ArgumentError('Unknown period unit');
    }
  }
}

class _ProductTile extends StatelessWidget {
  const _ProductTile({
    super.key,
    this.productSubtitle,
    this.offerFooter,
    this.purchasePackage,
    required this.isActiveSubscription,
    required this.isRenewingSubscription,
    required this.isLifetimeSubscription,
    required this.productTitle,
    required this.productPriceString,
    this.discountedPriceString,
    this.productIso8601,
    this.highlight = false,
  });

  // Header of the Card
  final String? productSubtitle;

  //Foot note about the cancelation of a trial at any time
  final String? offerFooter;

  final GestureTapCallback? purchasePackage;

  final bool isActiveSubscription;
  final bool isRenewingSubscription;
  final bool isLifetimeSubscription;
  final bool highlight;

  final String productTitle;
  final String productPriceString;
  final String? productIso8601;

  final String? discountedPriceString;

  bool get hasDiscountAvailable => discountedPriceString != null;

  @override
  Widget build(BuildContext context) {
    final themeData = Theme.of(context);
    final borderRadius = BorderRadius.circular(12);

    final productCard = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          color:
              themeData.colorScheme.secondaryContainer.withValues(alpha: 0.3).only(isActiveSubscription || highlight),
          border: Border.all(
            color: isActiveSubscription || highlight || discountedPriceString != null
                ? themeData.colorScheme.primary.withValues(alpha: 0.4)
                : themeData.disabledColor,
            width: isActiveSubscription || highlight || discountedPriceString != null ? 1 : 0.5,
          ),
        ),
        child: InkWell(
          onTap: isActiveSubscription && (isRenewingSubscription || isLifetimeSubscription) ? null : purchasePackage,
          borderRadius: borderRadius,
          child: Padding(
            padding:
                const EdgeInsets.all(16.0) - (offerFooter != null ? const EdgeInsets.only(bottom: 8) : EdgeInsets.zero),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              spacing: 8,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (hasDiscountAvailable)
                            Text(
                              tr('pages.paywall.promo_title'),
                              style: themeData.textTheme.labelSmall?.copyWith(
                                color: themeData.colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          Text(
                            productTitle,
                            style: themeData.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            productSubtitle ?? ' ', // Leave an empty string here just to keep the "Space"
                            style: themeData.textTheme.bodySmall
                                ?.copyWith(color: themeData.colorScheme.secondary.only(discountedPriceString != null)),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      children: [
                        Text(
                          productPriceString,
                          style: (!isActiveSubscription && hasDiscountAvailable)
                              ? themeData.textTheme.bodySmall?.copyWith(
                                  decoration: TextDecoration.lineThrough,
                                )
                              : themeData.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        if (!isActiveSubscription && hasDiscountAvailable)
                          Text(
                            discountedPriceString!,
                            style: themeData.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        if (isLifetimeSubscription || productIso8601 != null)
                          Text(
                            productIso8601?.let(iso8601PeriodToText) ?? 'general.one_time',
                            style: themeData.textTheme.bodySmall,
                          ).tr(),
                      ],
                    ),
                  ],
                ),
                if (offerFooter != null)
                  Text(offerFooter!,
                      style: themeData.textTheme.bodySmall?.copyWith(fontSize: 9), textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    );

    if (!highlight && !isActiveSubscription) return productCard;

    final isCanceled = !isLifetimeSubscription && isActiveSubscription && !isRenewingSubscription;

    final text = !isActiveSubscription
        ? 'products.most_popular'
        : isCanceled
            ? 'general.canceled'
            : 'general.active';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Gap(15),
        Stack(
          clipBehavior: Clip.none,
          children: [
            productCard,
            Positioned(
              top: -23,
              left: 0,
              right: 0,
              child: Chip(
                label: Text(tr('@.upper:$text')),
                backgroundColor: isCanceled ? themeData.colorScheme.errorContainer : themeData.colorScheme.secondary,
                labelStyle: themeData.textTheme.bodySmall?.copyWith(
                  color: isCanceled ? themeData.colorScheme.onErrorContainer : themeData.colorScheme.onSecondary,
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
