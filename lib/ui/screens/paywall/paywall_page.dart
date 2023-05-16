import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:loader_overlay/loader_overlay.dart';
import 'package:mobileraker/service/payment_service.dart';
import 'package:mobileraker/ui/components/drawer/nav_drawer_view.dart';
import 'package:mobileraker/ui/components/error_card.dart';
import 'package:mobileraker/ui/screens/paywall/paywall_page_controller.dart';
import 'package:mobileraker/util/extensions/async_ext.dart';
import 'package:mobileraker/util/misc.dart';
import 'package:progress_indicators/progress_indicators.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

class PaywallPage extends StatelessWidget {
  const PaywallPage({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('pages.paywall.title').tr()),
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
          child: const _PaywallPage()),
    );
  }
}

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
        .watch(paywallPageControllerProvider.select((value) => value.offering))
        .when(
            data: (data) => _PaywallOfferings(offering: data),
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
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
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
            loading: () => Center(
                  child: Column(
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
                  ),
                ));
  }
}

class _PaywallOfferings extends ConsumerWidget {
  const _PaywallOfferings({
    Key? key,
    required this.offering,
  }) : super(key: key);

  final Offering? offering;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var isSupporter = ref
            .watch(customerInfoProvider
                .selectAs((data) => data.activeSubscriptions.isNotEmpty))
            .valueOrNull ==
        true;

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: isSupporter
          ? _ManageTiers(offering: offering)
          : _SubscribeTiers(offering: offering),
    );
  }
}

class _SubscribeTiers extends ConsumerWidget {
  const _SubscribeTiers({Key? key, required this.offering}) : super(key: key);

  final Offering? offering;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var textTheme = Theme.of(context).textTheme;

    return Column(
      children: [
        Text(
          'pages.paywall.subscribe_view.title',
          textAlign: TextAlign.center,
          style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ).tr(),
        Flexible(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: SvgPicture.asset(
              'assets/vector/undraw_pair_programming_re_or4x.svg',
            ),
          ),
        ),
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
        Expanded(
          child: _SupporterTierOfferingList(
              availablePackages: offering?.availablePackages),
        ),
      ],
    );
  }
}

class _ManageTiers extends ConsumerWidget {
  const _ManageTiers({Key? key, this.offering}) : super(key: key);

  final Offering? offering;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var textTheme = Theme.of(context).textTheme;
    return Column(
      children: [
        Text(
          'pages.paywall.manage_view.title',
          textAlign: TextAlign.center,
          style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ).tr(),
        Flexible(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: SvgPicture.asset(
              'assets/vector/undraw_pair_programming_re_or4x.svg',
            ),
          ),
        ),
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
            availablePackages: offering?.availablePackages,
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
    if (availablePackages?.isEmpty == true) {
      return ErrorCard(
        title: const Text('pages.paywall.supporter_tier_list.error_title').tr(),
        body: const Text('pages.paywall.supporter_tier_list.error_body').tr(),
      );
    }
    var itemCount = availablePackages!.length;

    return Material(
      color: Colors.transparent,
      child: ListView.builder(
        itemCount: itemCount,
        itemBuilder: (BuildContext context, int index) {
          var myProductList = availablePackages!;

          var package = myProductList[index];
          return Padding(
            padding: EdgeInsets.only(
                top: (index == 0) ? 0 : 4,
                bottom: (index == itemCount - 1) ? 0 : 4),
            child: _SupporterTierCard(package: package),
          );
        },
        shrinkWrap: true,
        physics: const ClampingScrollPhysics(),
      ),
    );
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
    var themeData = Theme.of(context);

    var borderRadius = BorderRadius.circular(16);
    var isActive = activeEntitlement?.isActive == true;
    var wilLRenew = activeEntitlement?.willRenew == true;
    var defaultTextStyle = themeData.textTheme.labelLarge!.copyWith(
      color: isActive
          ? themeData.colorScheme.onPrimary
          : themeData.colorScheme.onPrimaryContainer,
    );
    return DefaultTextStyle(
      style: defaultTextStyle,
      child: Ink(
        decoration: BoxDecoration(
            borderRadius: borderRadius,
            color: isActive
                ? themeData.colorScheme.primary
                : themeData.colorScheme.primaryContainer),
        child: InkWell(
          onTap: activeEntitlement?.willRenew == true
              ? null
              : () => ref
                  .read(paywallPageControllerProvider.notifier)
                  .makePurchase(package),
          borderRadius: borderRadius,
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        storeProduct.title,
                        style: defaultTextStyle.copyWith(
                            fontWeight: FontWeight.bold),
                      ),
                      Text(
                        storeProduct.description,
                      )
                    ],
                  ),
                ),
                Column(
                  children: [
                    if (isActive)
                      Text(
                        wilLRenew ? 'general.active' : 'general.canceled',
                        style: themeData.textTheme.bodySmall
                            ?.copyWith(color: themeData.colorScheme.onPrimary),
                      ).tr(),
                    Text(
                      storeProduct.priceString,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
