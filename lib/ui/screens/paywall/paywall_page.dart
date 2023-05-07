import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/service/payment_service.dart';
import 'package:mobileraker/ui/components/drawer/nav_drawer_view.dart';
import 'package:mobileraker/ui/components/error_card.dart';
import 'package:mobileraker/ui/screens/paywall/paywall_page_controller.dart';
import 'package:mobileraker/util/extensions/async_ext.dart';
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
      body: const _PaywallPage(),
    );
  }
}

class _PaywallPage extends ConsumerWidget {
  const _PaywallPage({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(paywallPageControllerProvider).when(
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
                      title: (Platform.isAndroid)
                          ? Text(
                              'GooglePlay unavailable',
                              style: textStyleOnError,
                            )
                          : Text('AppStore unavailable',
                              style: textStyleOnError),
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
    var activeEntitlements = ref
        .watch(customerInfoProvider
            .selectAs((data) => data.entitlements.active.values))
        .valueOrNull;
    var userEnt = <String>[];

    activeEntitlements?.forEach((element) {
      userEnt.add(element.productIdentifier);
    });

    var textTheme = Theme.of(context).textTheme;

    var itemCount = offering!.availablePackages.length;
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          ...userEnt.map((e) => Text('Active Sub: $e')),
          if (ref
                  .watch(customerInfoProvider
                      .selectAs((data) => data.managementURL != null))
                  .valueOrNull ==
              true)
            ElevatedButton.icon(
                icon: const Icon(Icons.subscriptions_outlined),
                label: const Text('Manage Subscriptions'),
                onPressed: () => ref
                    .read(paywallPageControllerProvider.notifier)
                    .openManagement()),
          Text(
            'Become a Mobileraker Supporter!',
            textAlign: TextAlign.center,
            style:
                textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          Flexible(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: SvgPicture.asset(
                'assets/vector/undraw_pair_programming_re_or4x.svg',
              ),
            ),
          ),
          Text('''
Mobileraker aims to provide a fast and reliable mobile UI for Klipper, driven by the spirit of RepRap, that open-source software and hardware can make a positive impact.
As Mobileraker is developed by a single developer and offered for free, it relies on community funding to cover both operational and development costs. 
    ''', textAlign: TextAlign.center, style: textTheme.bodySmall),
          Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Choose Supporter Tier:',
                  style: textTheme.displaySmall
                      ?.copyWith(fontSize: 20, fontWeight: FontWeight.w900),
                ),
              )),
          if (offering != null)
            Expanded(
              child: ListView.builder(
                itemCount: itemCount,
                itemBuilder: (BuildContext context, int index) {
                  var myProductList = offering!.availablePackages;

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
            ),
        ],
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
    var storeProduct = package.storeProduct;
    var themeData = Theme.of(context);

    var borderRadius = BorderRadius.circular(16);
    return DefaultTextStyle(
      style: themeData.textTheme.labelLarge!
          .copyWith(color: themeData.colorScheme.onPrimaryContainer),
      child: Ink(
        decoration: BoxDecoration(
            borderRadius: borderRadius,
            color: themeData.colorScheme.primaryContainer),
        child: InkWell(
          onTap: () => ref
              .read(paywallPageControllerProvider.notifier)
              .makePurchase(package),
          borderRadius: borderRadius,
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              // mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        storeProduct.title + "(${storeProduct.identifier})",
                      ),
                      Text(
                        storeProduct.description + 'Desc',
                      )
                    ],
                  ),
                ),
                Text(
                  storeProduct.priceString,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    ListTile(
        textColor: themeData.colorScheme.onSurfaceVariant,
        onTap: () {
          ref
              .read(paywallPageControllerProvider.notifier)
              .makePurchase(package);
          // try {
          //   CustomerInfo customerInfo =
          //   await Purchases.purchasePackage(
          //       myProductList[index]);
          //   appData.entitlementIsActive = customerInfo
          //       .entitlements.all[entitlementID].isActive;
          // } catch (e) {
          //   print(e);
          // }
          //
          // setState(() {});
          // Navigator.pop(context);
        },
        title: Text(
          storeProduct.title + "(${storeProduct.identifier})",
        ),
        subtitle: Text(
          storeProduct.description,
        ),
        trailing: Text(
          storeProduct.priceString,
        ));
  }
}
