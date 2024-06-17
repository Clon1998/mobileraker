/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:io';

import 'package:collection/collection.dart';
import 'package:common/service/payment_service.dart';
import 'package:common/ui/components/error_card.dart';
import 'package:common/ui/components/nav/nav_drawer_view.dart';
import 'package:common/ui/components/nav/nav_rail_view.dart';
import 'package:common/util/extensions/async_ext.dart';
import 'package:common/util/extensions/build_context_extension.dart';
import 'package:common/util/extensions/object_extension.dart';
import 'package:common/util/logger.dart';
import 'package:common/util/misc.dart';
import 'package:common/util/time_util.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:loader_overlay/loader_overlay.dart';
import 'package:mobileraker/ui/screens/paywall/paywall_page_controller.dart';
import 'package:mobileraker/util/extensions/revenuecat_extension.dart';
import 'package:progress_indicators/progress_indicators.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

class PaywallPage extends HookConsumerWidget {
  const PaywallPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget body = CustomScrollView(
      physics: const ClampingScrollPhysics().only(context.isCompact),
      slivers: [
        if (context.isCompact)
          SliverLayoutBuilder(builder: (context, constraints) {
            return SliverAppBar(
              expandedHeight: 210,
              floating: false,
              flexibleSpace: FlexibleSpaceBar(
                collapseMode: CollapseMode.parallax,
                background: SvgPicture.asset(
                  'assets/vector/undraw_pair_programming_re_or4x.svg',
                ),
              ),
            );
          }),
        if (context.isLargerThanCompact)
          SliverToBoxAdapter(
            child: SvgPicture.asset(
              height: 210,
              'assets/vector/undraw_pair_programming_re_or4x.svg',
            ),
          ),
        const SliverFillRemaining(
          hasScrollBody: false,
          child: _PaywallPage(),
        ),
      ],
    );
    if (context.isLargerThanCompact) {
      body = NavigationRailView(page: body);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('pages.paywall.title')),
        // toolbarOpacity: 0.2,
        // backgroundColor: Colors.greenAccent,
      ).unless(context.isCompact),
      drawer: const NavigationDrawerWidget(),
      body: LoaderOverlay(
        useDefaultLoading: false,
        overlayWidgetBuilder: (_) => Center(
          child: Column(
            key: UniqueKey(),
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SpinKitFadingCube(
                color: Theme.of(context).colorScheme.secondary,
              ),
              const SizedBox(height: 30),
              FadingText(tr('pages.paywall.calling_store')),
              // Text("Fetching printer ...")
            ],
          ),
        ),
        child: body,
      ),
    );
  }
}

// class PaywallPage extends StatelessWidget {
//   const PaywallPage({
//     Key? key,
//   }) : super(key: key);
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text('pages.paywall.title').tr()),
//       drawer: const NavigationDrawerWidget(),
//       body: LoaderOverlay(
//           useDefaultLoading: false,
//           overlayWidget: Center(
//               child: Column(
//             key: UniqueKey(),
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//               SpinKitFadingCube(
//                 color: Theme.of(context).colorScheme.secondary,
//               ),
//               const SizedBox(
//                 height: 30,
//               ),
//               FadingText(tr('pages.paywall.calling_store')),
//               // Text("Fetching printer ...")
//             ],
//           )),
//           child: const _PaywallPage()),
//     );
//   }
// }

class _PaywallPage extends ConsumerWidget {
  const _PaywallPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(
      paywallPageControllerProvider.selectAs((value) => value.makingPurchase),
      (previous, next) {
        if (next.valueOrNull == true) {
          context.loaderOverlay.show();
        } else {
          context.loaderOverlay.hide();
        }
      },
    );

    Widget widget = ref.watch(paywallPageControllerProvider).when(
          data: (data) => _PaywallOfferings(model: data),
          error: (e, s) {
            if (e is PlatformException) {
              if (e.code == '3') {
                var themeData = Theme.of(context);
                var textStyleOnError = TextStyle(color: themeData.colorScheme.onErrorContainer);
                return ErrorCard(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        leading: Icon(
                          FlutterIcons.issue_opened_oct,
                          color: themeData.colorScheme.onErrorContainer,
                        ),
                        title: Text(storeName(), style: textStyleOnError),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: RichText(
                          text: TextSpan(
                            style: textStyleOnError,
                            text:
                                'To support the project, a properly configured ${(Platform.isAndroid) ? 'Google' : 'Apple'}-Account is required!',
                            children: const [
                              TextSpan(
                                text:
                                    'However, you can support the project by either rating it in the app stores, providing feedback via Github, or make donations.\nYou can find out more on the Github page of Mobileraker.',
                              ),
                            ],
                          ),
                        ),
                      ),
                      ElevatedButton.icon(
                        icon: const Icon(FlutterIcons.github_faw5d),
                        onPressed: ref.read(paywallPageControllerProvider.notifier).openGithub,
                        label: const Text('GitHub'),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                );
              }
            }
            return Center(
              child: Card(
                shape: ContinuousRectangleBorder(
                  borderRadius: BorderRadius.circular(40.0),
                ),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        leading: Icon(FlutterIcons.issue_opened_oct),
                        title: Text('Can not fetch supporter tiers!'),
                      ),
                      Text(
                        'Sorry...\nIt seems like there was a problem while trying to load the different Supported tiers!\nPlease try again later!',
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            );
          },
          loading: () => Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SpinKitPumpingHeart(
                color: Theme.of(context).colorScheme.primary,
                size: 66,
              ),
              const SizedBox(height: 20),
              FadingText('Loading supporter Tiers'),
            ],
          ),
        );

    return widget;
  }
}

class _PaywallOfferings extends ConsumerWidget {
  const _PaywallOfferings({super.key, required this.model});

  final PaywallPageState model;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: ref.watch(isSupporterProvider) ? _ManageTiers(model: model) : _SubscribeTiers(model: model),
      ),
    );
  }
}

class _SubscribeTiers extends ConsumerWidget {
  const _SubscribeTiers({super.key, required this.model});

  final PaywallPageState model;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'pages.paywall.subscribe_view.title',
          textAlign: TextAlign.center,
          style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ).tr(),
        Text(
          'pages.paywall.subscribe_view.info',
          textAlign: TextAlign.center,
          style: textTheme.bodySmall,
        ).tr(),
        const _BenefitOverview(),
        Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'pages.paywall.subscribe_view.list_title',
              style: textTheme.displaySmall?.copyWith(fontSize: 20, fontWeight: FontWeight.w900),
            ).tr(),
          ),
        ),
        _OfferedProductList(
          packets: model.paywallOfferings,
          iapPromos: model.iapPromos,
        ),
        Text(
          'pages.paywall.subscribe_view.subscription_info',
          style: textTheme.bodySmall,
          textAlign: TextAlign.justify,
        ).tr(args: [storeName()]),
        if (model.tipAvailable) const _TippingButton(),

        const _RestoreButton(),
        // const _TippingButton(),
      ],
    );
  }
}

class _BenefitOverview extends ConsumerWidget {
  const _BenefitOverview({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Learn about Supporter Perks',
          style: Theme.of(context).textTheme.displaySmall?.copyWith(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        IconButton(
          onPressed: ref.read(paywallPageControllerProvider.notifier).openPerksInfo,
          icon: const Icon(Icons.info_outline),
        ),
      ],
    );
  }
}

class _ManageTiers extends ConsumerWidget {
  const _ManageTiers({super.key, required this.model});

  final PaywallPageState model;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var textTheme = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'pages.paywall.manage_view.title',
          textAlign: TextAlign.center,
          style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ).tr(),
        FilledButton.tonalIcon(
          icon: const Icon(Icons.contact_support_outlined),
          onPressed: ref.read(paywallPageControllerProvider.notifier).openDevContact,
          label: const Text('pages.paywall.contact_dialog.title').tr(),
        ),
        const _BenefitOverview(),
        Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'pages.paywall.manage_view.list_title',
              style: textTheme.displaySmall?.copyWith(fontSize: 20, fontWeight: FontWeight.w900),
            ).tr(),
          ),
        ),
        _OfferedProductList(
          packets: model.paywallOfferings,
          iapPromos: model.iapPromos,
        ),
        Text(
          'pages.paywall.manage_view.sub_warning',
          style: textTheme.bodySmall,
          textAlign: TextAlign.justify,
        ).tr(),
        if (model.tipAvailable) const _TippingButton(),
        ElevatedButton.icon(
          icon: const Icon(Icons.subscriptions_outlined),
          label: const Text('pages.paywall.manage_view.store_btn').tr(args: [storeName()]),
          onPressed:
              (ref.watch(customerInfoProvider.selectAs((data) => data.managementURL != null)).valueOrNull == true)
                  ? () => ref.read(paywallPageControllerProvider.notifier).openManagement()
                  : null,
        ),
        const _RestoreButton(),
      ],
    );
  }
}

class _OfferedProductList extends ConsumerWidget {
  const _OfferedProductList({super.key, this.packets, this.iapPromos});

  final List<Package>? packets;
  final List<Package>? iapPromos;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (packets == null || packets!.isEmpty) {
      return ErrorCard(
        title: const Text('pages.paywall.supporter_tier_list.error_title').tr(),
        body: const Text('pages.paywall.supporter_tier_list.error_body').tr(),
      );
    }

    logger.e('Got ${packets?.length ?? 0} available Packets: $packets');

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: packets!
            .map((package) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: package.let((p) {
                    if (p.storeProduct.productCategory == ProductCategory.nonSubscription) {
                      var promoPackage = iapPromos?.firstWhereOrNull(
                        (promo) => promo.storeProduct.identifier == '${p.storeProduct.identifier}_promo',
                      );

                      return _InAppPurchaseProduct(
                        iapPackage: package,
                        promoPackage: promoPackage,
                      );
                    }
                    // Android Subscriptions since they might have options (E.g. offers/promos)
                    if (package.storeProduct.defaultOption != null) {
                      return _SubscriptionOptionProduct(package: package);
                    }
                    return _SubscriptionProduct(package: package);
                  }),
                ))
            .toList(),
      ),
    );
  }
}

class _InAppPurchaseProduct extends ConsumerWidget {
  const _InAppPurchaseProduct({
    super.key,
    required this.iapPackage,
    this.promoPackage,
  });

  final Package iapPackage;
  final Package? promoPackage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    EntitlementInfo? activeEntitlement = ref.watch(customerInfoProvider.select((asyncData) {
      CustomerInfo? customerInfo = asyncData.valueOrFullNull;
      if (customerInfo?.isSubscriptionActive(iapPackage) != true) return null;
      return customerInfo!.getActiveEntitlementForPackage(iapPackage);
    }));

    var storeProduct = iapPackage.storeProduct;
    var promoStoreProduct = promoPackage?.storeProduct;

    logger.w('SP: $storeProduct');
    logger.w('PID: ${iapPackage.identifier}');
    logger.w('SP_promo: $promoStoreProduct');
    logger.w('PID_PROMO: ${promoPackage?.identifier}');

    Widget? header = _constructHeader(context, storeProduct, promoStoreProduct);

    return _ProductTile(
      offerHeader: header,
      purchasePackage: () => ref.read(paywallPageControllerProvider.notifier).makePurchase(promoPackage ?? iapPackage),
      isActiveSubscription: activeEntitlement?.isActive == true,
      isRenewingSubscription: false,
      isLifetimeSubscription: true,
      subscriptionTitle: storeProduct.title,
      subscriptionDescription: storeProduct.description,
      subscriptionPriceString: storeProduct.priceString,
      subscriptionIso8601: storeProduct.subscriptionPeriod,
      discountedPriceString: promoStoreProduct?.priceString,
    );
  }

  Widget? _constructHeader(
    BuildContext context,
    StoreProduct storeProduct,
    StoreProduct? promoStoreProduct,
  ) {
    final themeData = Theme.of(context);

    if (promoStoreProduct == null) return null;

    double offerDiscount = 1 - (promoStoreProduct.price / storeProduct.price);

    return Column(
      children: [
        Text(
          tr('pages.paywall.promo_title'),
          style: themeData.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        Text(
          tr('pages.paywall.iap_offer', args: [
            NumberFormat.percentPattern(context.locale.toStringWithSeparator()).format(offerDiscount),
          ]),
          style: themeData.textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
        const Divider(),
      ],
    );
  }
}

class _SubscriptionProduct extends ConsumerWidget {
  const _SubscriptionProduct({super.key, required this.package});

  final Package package;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    EntitlementInfo? activeEntitlement = ref.watch(customerInfoProvider.select((asyncData) {
      CustomerInfo? customerInfo = asyncData.valueOrFullNull;
      if (customerInfo?.isSubscriptionActive(package) != true) return null;
      return customerInfo!.getActiveEntitlementForPackage(package);
    }));

    var storeProduct = package.storeProduct;
    var discountOffer = storeProduct.discounts?.firstOrNull;

    logger.w('SP: $storeProduct');
    logger.w('PID: ${package.identifier}');
    // ToDo: Intro Prices for IOS
    // var hasIntroPrice = storeProduct.introductoryPrice != null;
    // Purchases.checkTrialOrIntroductoryPriceEligibility(productIdentifiers) // IOS ONLY

    Widget? header = _constructHeader(context, storeProduct);

    return _ProductTile(
      offerHeader: header,
      purchasePackage: () => ref.read(paywallPageControllerProvider.notifier).makePurchase(package),
      isActiveSubscription: activeEntitlement?.isActive == true,
      isRenewingSubscription: activeEntitlement?.willRenew == true,
      isLifetimeSubscription: package.packageType == PackageType.lifetime,
      subscriptionTitle: storeProduct.title,
      subscriptionDescription: storeProduct.description,
      subscriptionPriceString: storeProduct.priceString,
      subscriptionIso8601: storeProduct.subscriptionPeriod,
      discountedPriceString: discountOffer?.priceString,
    );
  }

  Widget? _constructHeader(BuildContext context, StoreProduct storeProduct) {
    final themeData = Theme.of(context);

    var discountOffer = storeProduct.discounts?.firstOrNull;
    var introOffer = storeProduct.introductoryPrice;

    logger.e('discountOffer: $discountOffer');
    logger.e('introOffer: $introOffer');

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

    return Column(
      children: [
        Text(
          tr('pages.paywall.promo_title'),
          style: themeData.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        Text(
          tr('pages.paywall.intro_phase', args: [
            offerDuration,
            NumberFormat.percentPattern(context.locale.toStringWithSeparator()).format(offerDiscount),
          ]),
          style: themeData.textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
        const Divider(),
      ],
    );
  }
}

class _SubscriptionOptionProduct extends ConsumerWidget {
  const _SubscriptionOptionProduct({super.key, required this.package});

  final Package package;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    EntitlementInfo? activeEntitlement = ref.watch(customerInfoProvider.select((asyncData) {
      CustomerInfo? customerInfo = asyncData.valueOrFullNull;

      if (customerInfo?.isSubscriptionActive(package) != true) return null;
      return customerInfo!.getActiveEntitlementForPackage(package);
    }));

    // Sp: StoreProduct(identifier: mobileraker_supporter_v2.lifetime, description: Earn all supporter benefits forever., title: Lifetime Supporter (Mobileraker), price: 32.99, priceString: €32.99, currencyCode: EUR, introductoryPrice: null, discounts: null, productCategory: ProductCategory.nonSubscription, defaultOption: null, subscriptionOptions: null, presentedOfferingIdentifier: default_v2, subscriptionPeriod: null)
    logger.w('Sp: ${package.storeProduct}');

    var storeProduct = package.storeProduct;

    var defaultOption = storeProduct.defaultOption!;
    logger.w('DO: $defaultOption');
    var isDiscounted = !defaultOption.isBasePlan;
    var hasFreePhase = defaultOption.freePhase != null;
    var hasIntroPhase = defaultOption.introPhase != null;

    String? discountedPriceString;
    if (isDiscounted && (hasIntroPhase || hasFreePhase)) {
      discountedPriceString = hasIntroPhase ? defaultOption.introPhase!.price.formatted : tr('general.free');
    }

    return _ProductTile(
      offerHeader: _constructOfferHeader(defaultOption, context),
      offerFooter: _constructOfferFoooter(defaultOption, context),
      purchasePackage: () => ref.read(paywallPageControllerProvider.notifier).makePurchase(package),
      isActiveSubscription: activeEntitlement?.isActive == true,
      isRenewingSubscription: activeEntitlement?.willRenew == true,
      isLifetimeSubscription: false,
      subscriptionTitle: storeProduct.title,
      subscriptionDescription: storeProduct.description,
      subscriptionPriceString: storeProduct.priceString,
      subscriptionIso8601: (!hasFreePhase || hasIntroPhase) ? storeProduct.subscriptionPeriod : null,
      discountedPriceString: discountedPriceString,
    );
  }

  Widget? _constructOfferHeader(
    SubscriptionOption subscriptionOption,
    BuildContext context,
  ) {
    final themeData = Theme.of(context);

    if (subscriptionOption.isBasePlan) return null;
    return Column(
      children: [
        Text(
          tr('pages.paywall.promo_title'),
          style: themeData.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        Text(
          _constructHeaderSubtitle(subscriptionOption, context)!,
          style: themeData.textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
        const Divider(),
      ],
    );
  }

  Widget? _constructOfferFoooter(
    SubscriptionOption subscriptionOption,
    BuildContext context,
  ) {
    final themeData = Theme.of(context);

    // So far only android complaint
    if (!Platform.isAndroid) return null;
    if (subscriptionOption.isBasePlan) return null;
    if (subscriptionOption.freePhase == null) return null;
    return Padding(
      padding: const EdgeInsets.only(top: 4.0),
      child: Text(
        tr('pages.paywall.trial_disclaimer'),
        style: themeData.textTheme.bodySmall?.copyWith(fontSize: 10),
        textAlign: TextAlign.center,
      ),
    );
  }

  String? _constructHeaderSubtitle(
    SubscriptionOption subscriptionOption,
    BuildContext context,
  ) {
    if (subscriptionOption.isBasePlan) return null;

    var tmp = <String>[];
    if (subscriptionOption.freePhase != null) {
      tmp.add(tr(
        'pages.paywall.free_phase',
        args: [subscriptionOption.freePhaseDurationText!],
      ));
    }
    if (subscriptionOption.introPhase != null) {
      var discount = 1 -
          (subscriptionOption.introPhase!.price.amountMicros / subscriptionOption.fullPricePhase!.price.amountMicros);
      tmp.add(tr('pages.paywall.intro_phase', args: [
        subscriptionOption.introPhaseDurationText!,
        NumberFormat.percentPattern(context.locale.toStringWithSeparator()).format(discount),
      ]));
    }
    return tmp.isEmpty ? null : tmp.join(' + ');
  }
}

class _ProductTile extends StatelessWidget {
  const _ProductTile({
    super.key,
    this.offerHeader,
    this.offerFooter,
    this.purchasePackage,
    required this.isActiveSubscription,
    required this.isRenewingSubscription,
    required this.isLifetimeSubscription,
    required this.subscriptionTitle,
    required this.subscriptionDescription,
    required this.subscriptionPriceString,
    this.subscriptionIso8601,
    this.discountedPriceString,
  });

  // Header of the Card
  final Widget? offerHeader;
  final Widget? offerFooter;
  final GestureTapCallback? purchasePackage;

  final bool isActiveSubscription;
  final bool isRenewingSubscription;
  final bool isLifetimeSubscription;

  final String subscriptionTitle;
  final String subscriptionDescription;
  final String subscriptionPriceString;
  final String? subscriptionIso8601;

  final String? discountedPriceString;

  bool get hasDiscountAvailable => discountedPriceString != null;

  @override
  Widget build(BuildContext context) {
    var themeData = Theme.of(context);
    var borderRadius = BorderRadius.circular(16);
    var defaultTextStyle = themeData.textTheme.labelLarge!.copyWith(
      color: isActiveSubscription ? themeData.colorScheme.onPrimary : themeData.colorScheme.onPrimaryContainer,
    );

    return DefaultTextStyle(
      style: defaultTextStyle,
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          color: isActiveSubscription ? themeData.colorScheme.primary : themeData.colorScheme.primaryContainer,
        ),
        child: InkWell(
          onTap: isActiveSubscription && (isRenewingSubscription || isLifetimeSubscription) ? null : purchasePackage,
          borderRadius: borderRadius,
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              children: [
                if (!isActiveSubscription && offerHeader != null) offerHeader!,
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            subscriptionTitle,
                            style: defaultTextStyle.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(subscriptionDescription),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Column(
                        children: [
                          if (isActiveSubscription)
                            Text(
                              isRenewingSubscription || isLifetimeSubscription ? 'general.active' : 'general.canceled',
                              style: themeData.textTheme.bodySmall?.copyWith(
                                color: themeData.colorScheme.onPrimary,
                              ),
                            ).tr(),
                          if (!isLifetimeSubscription || (!isActiveSubscription && isLifetimeSubscription))
                            Text(
                              subscriptionPriceString,
                              style: (!isActiveSubscription && hasDiscountAvailable)
                                  ? themeData.textTheme.bodySmall?.copyWith(
                                      decoration: TextDecoration.lineThrough,
                                    )
                                  : null,
                            ),
                          if (!isActiveSubscription && hasDiscountAvailable) Text(discountedPriceString!),
                          if (subscriptionIso8601 != null)
                            Text(
                              iso8601PeriodToText(subscriptionIso8601!),
                              style: themeData.textTheme.bodySmall?.copyWith(
                                fontSize: 10,
                                color: defaultTextStyle.color?.getShadeColor(lighten: false),
                              ),
                            ).tr(),
                          if (isLifetimeSubscription)
                            Text(
                              'general.one_time',
                              style: themeData.textTheme.bodySmall?.copyWith(
                                fontSize: 10,
                                color: defaultTextStyle.color?.getShadeColor(lighten: false),
                              ),
                            ).tr(),
                        ],
                      ),
                    ),
                  ],
                ),
                if (!isActiveSubscription && offerFooter != null) offerFooter!,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RestoreButton extends ConsumerWidget {
  const _RestoreButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => TextButton.icon(
        onPressed: ref.read(paywallPageControllerProvider.notifier).userSignIn,
        onLongPress: ref.read(paywallPageControllerProvider.notifier).copyRCatIdToClipboard,
        icon: const Icon(Icons.restore, size: 18),
        label: const Text('pages.paywall.restore_sign_in', style: TextStyle(fontSize: 12)).tr(),
      );
}

class _TippingButton extends ConsumerWidget {
  const _TippingButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => FilledButton.tonalIcon(
        onPressed: ref.read(paywallPageControllerProvider.notifier).onTippingPressed,
        onLongPress: ref.read(paywallPageControllerProvider.notifier).copyRCatIdToClipboard,
        icon: const Icon(Icons.volunteer_activism),
        label: const Text('pages.paywall.tip_developer').tr(),
      );
}
