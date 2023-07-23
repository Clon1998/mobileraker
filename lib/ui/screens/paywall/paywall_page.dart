/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:loader_overlay/loader_overlay.dart';
import 'package:mobileraker/logger.dart';
import 'package:mobileraker/service/payment_service.dart';
import 'package:mobileraker/ui/components/drawer/nav_drawer_view.dart';
import 'package:mobileraker/ui/components/error_card.dart';
import 'package:mobileraker/ui/screens/paywall/paywall_page_controller.dart';
import 'package:mobileraker/util/extensions/async_ext.dart';
import 'package:mobileraker/util/extensions/revenuecat_extension.dart';
import 'package:mobileraker/util/misc.dart';
import 'package:mobileraker/util/time_util.dart';
import 'package:progress_indicators/progress_indicators.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

class PaywallPage extends HookConsumerWidget {
  const PaywallPage({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
        drawer: const NavigationDrawerWidget(),
        body: LoaderOverlay(
            useDefaultLoading: false,
            overlayWidget: Center(
                child: Column(
              key: UniqueKey(),
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SpinKitFadingCube(
                  color: Theme.of(context).colorScheme.secondary,
                ),
                const SizedBox(
                  height: 30,
                ),
                FadingText(tr('pages.paywall.calling_store')),
                // Text("Fetching printer ...")
              ],
            )),
            child: CustomScrollView(
              physics: const ClampingScrollPhysics(),
              slivers: [
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
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: _PaywallPage(),
                )
              ],
            )));
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
  const _PaywallPage({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(
        paywallPageControllerProvider.select((value) => value.makingPurchase),
        (previous, next) {
      if (next) {
        context.loaderOverlay.show();
      } else {
        context.loaderOverlay.hide();
      }
    });

    return ref
        .watch(paywallPageControllerProvider.select((value) => value.offerings))
        .when(
            data: (data) => _PaywallOfferings(offerings: data),
            error: (e, s) {
              if (e is PlatformException) {
                if (e.code == "3") {
                  var themeData = Theme.of(context);
                  var textStyleOnError =
                      TextStyle(color: themeData.colorScheme.onErrorContainer);
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                          ),
                          child: RichText(
                              text: TextSpan(
                                  style: textStyleOnError,
                                  text:
                                      'To support the project, a properly configured ${(Platform.isAndroid) ? 'Google' : 'Apple'}-Account is required!',
                                  children: const [
                                TextSpan(
                                  text:
                                      'However, you can support the project by either rating it in the app stores, providing feedback via Github, or make donations.\nYou can find out more on the Github page of Mobileraker.',
                                )
                              ])),
                        ),
                        ElevatedButton.icon(
                          icon: const Icon(FlutterIcons.github_faw5d),
                          onPressed: ref
                              .read(paywallPageControllerProvider.notifier)
                              .openGithub,
                          label: const Text('GitHub'),
                        ),
                        const SizedBox(
                          height: 8,
                        )
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
                          leading: Icon(
                            FlutterIcons.issue_opened_oct,
                          ),
                          title: Text('Can not fetch supporter tiers!'),
                        ),
                        Text(
                          'Sorry...\nIt seems like there was a problem while trying to load the different Supported tiers!\nPlease try again later!',
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(
                          height: 8,
                        )
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
                    const SizedBox(
                      height: 20,
                    ),
                    FadingText('Loading supporter Tiers')
                  ],
                ));
  }
}

class _PaywallOfferings extends ConsumerWidget {
  const _PaywallOfferings({
    Key? key,
    required this.offerings,
  }) : super(key: key);

  final Offerings? offerings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: ref.watch(isSupporterProvider)
            ? _ManageTiers(offerings: offerings)
            : _SubscribeTiers(offerings: offerings),
      ),
    );
  }
}

class _SubscribeTiers extends ConsumerWidget {
  const _SubscribeTiers({Key? key, required this.offerings}) : super(key: key);

  final Offerings? offerings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var textTheme = Theme.of(context).textTheme;
    logger.e('Offerings: ${offerings?.all.keys}');
    // logger.e('Offerings: ${offerings?.all}');
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'pages.paywall.subscribe_view.title',
          textAlign: TextAlign.center,
          style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ).tr(),
        // Flexible(
        //   child: Padding(
        //     padding: const EdgeInsets.symmetric(vertical: 8.0),
        //     child: SvgPicture.asset(
        //       'assets/vector/undraw_pair_programming_re_or4x.svg',
        //     ),
        //   ),
        // ),
        Text('pages.paywall.subscribe_view.info',
                textAlign: TextAlign.center, style: textTheme.bodySmall)
            .tr(),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Learn about Supporter Perks',
              style: textTheme.displaySmall
                  ?.copyWith(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            IconButton(
                onPressed: ref
                    .read(paywallPageControllerProvider.notifier)
                    .openPerksInfo,
                icon: const Icon(Icons.info_outline))
          ],
        ),
        Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'pages.paywall.subscribe_view.list_title',
                style: textTheme.displaySmall
                    ?.copyWith(fontSize: 20, fontWeight: FontWeight.w900),
              ).tr(),
            )),
        _SupporterTierOfferingList(
            availablePackages: offerings?.current?.availablePackages
                .where((element) =>
                    element.storeProduct.productCategory ==
                    ProductCategory.subscription)
                .toList(growable: false)),
        if (offerings?.all.containsKey('tip') == true)
          FilledButton.icon(
            onPressed:
                ref.read(paywallPageControllerProvider.notifier).tipTheDev,
            icon: const Icon(Icons.volunteer_activism),
            label: const Text('Tip the Dev'),
          ),
        const _RestoreButton(),
        // const _TippingButton(),
      ],
    );
  }
}

class _ManageTiers extends ConsumerWidget {
  const _ManageTiers({Key? key, this.offerings}) : super(key: key);

  final Offerings? offerings;

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
            onPressed:
                ref.read(paywallPageControllerProvider.notifier).openDevContact,
            label: const Text('pages.paywall.contact_dialog.title').tr()),
        Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'pages.paywall.manage_view.list_title',
                style: textTheme.displaySmall
                    ?.copyWith(fontSize: 20, fontWeight: FontWeight.w900),
              ).tr(),
            )),
        Expanded(
          child: _SupporterTierOfferingList(
            availablePackages: offerings?.current?.availablePackages,
          ),
        ),
        ElevatedButton.icon(
            icon: const Icon(Icons.subscriptions_outlined),
            label: const Text('pages.paywall.manage_view.store_btn')
                .tr(args: [storeName()]),
            onPressed: (ref
                        .watch(customerInfoProvider
                            .selectAs((data) => data.managementURL != null))
                        .valueOrNull ==
                    true)
                ? () => ref
                    .read(paywallPageControllerProvider.notifier)
                    .openManagement()
                : null),
      ],
    );
  }
}

class _SupporterTierOfferingList extends ConsumerWidget {
  const _SupporterTierOfferingList({super.key, this.availablePackages});

  final List<Package>? availablePackages;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (availablePackages == null || availablePackages!.isEmpty) {
      return ErrorCard(
        title: const Text('pages.paywall.supporter_tier_list.error_title').tr(),
        body: const Text('pages.paywall.supporter_tier_list.error_body').tr(),
      );
    }

    logger.e(
        'Got ${availablePackages?.length ?? 0} available Packets: $availablePackages');

    return Column(
        mainAxisSize: MainAxisSize.min,
        children: availablePackages!
            .map((package) => Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 4),
                  child: Platform.isAndroid
                      ? _AndroidSupporterTierCard(package: package)
                      : _SupporterTierCard(package: package),
                ))
            .toList());
  }
}

class _SupporterTierCard extends ConsumerWidget {
  const _SupporterTierCard({
    super.key,
    required this.package,
  });

  final Package package;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    EntitlementInfo? activeEntitlement =
        ref.watch(customerInfoProvider.select((asyncData) {
      CustomerInfo? customerInfo = asyncData.valueOrFullNull;
      var isActive = customerInfo?.activeSubscriptions
          .contains(package.storeProduct.identifier);

      if (isActive != true) {
        return null;
      }

      return customerInfo?.entitlements.active.values.first;
    }));

    var storeProduct = package.storeProduct;
    var discountOffer = storeProduct.discounts?.firstOrNull;

    // ToDo: Intro Prices for IOS
    // var hasIntroPrice = storeProduct.introductoryPrice != null;
    // Purchases.checkTrialOrIntroductoryPriceEligibility(productIdentifiers) // IOS ONLY

    Widget? header = _constructHeader(context, storeProduct);

    return _SubscriptionOfferTile(
      offerHeader: header,
      purchasePackage: () => ref
          .read(paywallPageControllerProvider.notifier)
          .makePurchase(package),
      isActiveSubscription: activeEntitlement?.isActive == true,
      isRenewingSubscription: activeEntitlement?.willRenew == true,
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
      offerDiscount = introOffer.price / storeProduct.price;
    } else {
      offerDuration = discountOffer!.discountDurationText;
      offerDiscount = discountOffer.price / storeProduct.price;
    }

    return Column(
      children: [
        Text(
          tr(
            'pages.paywall.promo_title',
          ),
          style: themeData.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        Text(
          tr('pages.paywall.intro_phase', args: [
            offerDuration,
            NumberFormat.percentPattern(context.locale.languageCode)
                .format(offerDiscount)
          ]),
          style: themeData.textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
        const Divider(),
      ],
    );
  }
}

class _AndroidSupporterTierCard extends ConsumerWidget {
  const _AndroidSupporterTierCard({
    super.key,
    required this.package,
  });

  final Package package;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    EntitlementInfo? activeEntitlement =
        ref.watch(customerInfoProvider.select((asyncData) {
      CustomerInfo? customerInfo = asyncData.valueOrFullNull;
      var isActive = customerInfo?.activeSubscriptions
          .contains(package.storeProduct.identifier);

      if (isActive != true) {
        return null;
      }

      return customerInfo?.entitlements.active.values.first;
    }));

    var storeProduct = package.storeProduct;
    var defaultOption = storeProduct.defaultOption!;

    var isDiscounted = !defaultOption.isBasePlan;
    var hasFreePhase = defaultOption.freePhase != null;
    var hasIntroPhase = defaultOption.introPhase != null;

    Widget? header = _constructOfferHeader(defaultOption, context);
    String? discountedPriceString;
    if (isDiscounted && (hasIntroPhase || hasFreePhase)) {
      discountedPriceString = hasIntroPhase
          ? defaultOption.introPhase!.price.formatted
          : tr('general.free');
    }

    return _SubscriptionOfferTile(
      offerHeader: header,
      purchasePackage: () => ref
          .read(paywallPageControllerProvider.notifier)
          .makePurchase(package),
      isActiveSubscription: activeEntitlement?.isActive == true,
      isRenewingSubscription: activeEntitlement?.willRenew == true,
      subscriptionTitle: storeProduct.title,
      subscriptionDescription: storeProduct.description,
      subscriptionPriceString: storeProduct.priceString,
      subscriptionIso8601: (!hasFreePhase || hasIntroPhase)
          ? storeProduct.subscriptionPeriod
          : null,
      discountedPriceString: discountedPriceString,
    );
  }

  Widget? _constructOfferHeader(
      SubscriptionOption subscriptionOption, BuildContext context) {
    final themeData = Theme.of(context);

    if (subscriptionOption.isBasePlan) return null;
    return Column(
      children: [
        Text(
          tr(
            'pages.paywall.promo_title',
          ),
          style: themeData.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
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

  String? _constructHeaderSubtitle(
      SubscriptionOption subscriptionOption, BuildContext context) {
    if (subscriptionOption.isBasePlan) return null;

    var tmp = <String>[];
    if (subscriptionOption.freePhase != null) {
      tmp.add(tr('pages.paywall.free_phase',
          args: [subscriptionOption.freePhaseDurationText!]));
    }
    if (subscriptionOption.introPhase != null) {
      var discount = subscriptionOption.introPhase!.price.amountMicros /
          subscriptionOption.fullPricePhase!.price.amountMicros;
      tmp.add(tr('pages.paywall.intro_phase', args: [
        subscriptionOption.introPhaseDurationText!,
        NumberFormat.percentPattern(context.locale.languageCode)
            .format(discount)
      ]));
    }
    return tmp.isEmpty ? null : tmp.join(' + ');
  }
}

class _SubscriptionOfferTile extends StatelessWidget {
  const _SubscriptionOfferTile({
    Key? key,
    this.offerHeader,
    this.purchasePackage,
    required this.isActiveSubscription,
    required this.isRenewingSubscription,
    required this.subscriptionTitle,
    required this.subscriptionDescription,
    required this.subscriptionPriceString,
    this.subscriptionIso8601,
    this.discountedPriceString,
  }) : super(key: key);

  // Header of the Card
  final Widget? offerHeader;
  final GestureTapCallback? purchasePackage;

  final bool isActiveSubscription;
  final bool isRenewingSubscription;

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
      color: isActiveSubscription
          ? themeData.colorScheme.onPrimary
          : themeData.colorScheme.onPrimaryContainer,
    );

    return DefaultTextStyle(
      style: defaultTextStyle,
      child: Ink(
        decoration: BoxDecoration(
            borderRadius: borderRadius,
            color: isActiveSubscription
                ? themeData.colorScheme.primary
                : themeData.colorScheme.primaryContainer),
        child: InkWell(
          onTap: isRenewingSubscription ? null : purchasePackage,
          borderRadius: borderRadius,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  children: [
                    if (offerHeader != null) offerHeader!,
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
                                    fontWeight: FontWeight.bold),
                              ),
                              Text(
                                subscriptionDescription,
                              )
                            ],
                          ),
                        ),
                        Column(
                          children: [
                            if (isActiveSubscription)
                              Text(
                                isRenewingSubscription
                                    ? 'general.active'
                                    : 'general.canceled',
                                style: themeData.textTheme.bodySmall?.copyWith(
                                    color: themeData.colorScheme.onPrimary),
                              ).tr(),
                            Text(
                              subscriptionPriceString,
                              style: hasDiscountAvailable
                                  ? themeData.textTheme.bodySmall?.copyWith(
                                      decoration: TextDecoration.lineThrough)
                                  : null,
                            ),
                            if (hasDiscountAvailable)
                              Text(discountedPriceString!),
                            if (subscriptionIso8601 != null)
                              Text(
                                iso8601PeriodToText(subscriptionIso8601!),
                                style: themeData.textTheme.bodySmall?.copyWith(
                                    fontSize: 10,
                                    color: defaultTextStyle.color
                                        ?.getShadeColor(lighten: false)),
                              ).tr(),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // TextButton(
              //   style: TextButton.styleFrom(
              //     minimumSize: const Size.fromHeight(48),
              //     padding: EdgeInsets.zero,
              //     shape: const RoundedRectangleBorder(
              //       borderRadius:
              //       BorderRadius.vertical(bottom: Radius.circular(16)),
              //     ),
              //     foregroundColor: themeData.colorScheme.onPrimary,
              //     backgroundColor: themeData.colorScheme.primary,
              //     // onPrimary: Theme.of(context).colorScheme.onSecondary,
              //     disabledForegroundColor: themeData.colorScheme.onPrimary.withOpacity(0.38),
              //   ),
              //   onPressed: () => null,
              //   child: Text('Become a Supporter'),
              // )
            ],
          ),
        ),
      ),
    );
  }
}

class _RestoreButton extends ConsumerWidget {
  const _RestoreButton({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) => TextButton.icon(
      onPressed: ref.read(paywallPageControllerProvider.notifier).restore,
      icon: const Icon(Icons.restore),
      label: const Text('general.restore').tr());
}

class _TippingButton extends ConsumerWidget {
  const _TippingButton({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) => TextButton.icon(
      onPressed: ref.read(paywallPageControllerProvider.notifier).tipTheDev,
      icon: const Icon(Icons.volunteer_activism),
      label: const Text('pages.paywall.tip_developer').tr());
}
