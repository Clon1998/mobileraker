/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:io';

import 'package:common/service/payment_service.dart';
import 'package:common/service/ui/bottom_sheet_service_interface.dart';
import 'package:common/service/ui/dialog_service_interface.dart';
import 'package:common/util/extensions/async_ext.dart';
import 'package:common/util/logger.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:mobileraker/service/ui/dialog_service_impl.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../../../service/ui/bottom_sheet_service_impl.dart';

part 'paywall_page_controller.freezed.dart';
part 'paywall_page_controller.g.dart';

@riverpod
class PaywallPageController extends _$PaywallPageController {
  @override
  FutureOr<PaywallPageState> build() async {
    try {
      return _fetchPaywallState();
    } on PlatformException catch (e, s) {
      logger.e('Error while trying to fetch offerings from revenue cat!', e, s);
      rethrow;
    }
  }

  Future<PaywallPageState> _fetchPaywallState() async {
    Offerings offerings = await ref.watch(paymentServiceProvider).getOfferings();
    logger.wtf('Got offerings:${offerings.all.keys}');
    logger.wtf('Got offerings detailed:$offerings');

    Offering? activeOffering = offerings.current;
    // if (kDebugMode) activeOffering = offerings.getOffering('default_v2');
    final offerMetadata = activeOffering?.metadata ?? {};
    final excludeFromPaywall = (offerMetadata['exclude_package'] as String? ?? '').split(',').map((e) => e.trim());

    // final iapOffers = offerMetadata.
    final List<Package> packetsToOffer = activeOffering?.availablePackages
            .where((p) => !excludeFromPaywall.contains(p.identifier))
            .toList(growable: false) ??
        [];

    // Due to the lack of ability to buy things multiple times, I need to put this into a seperate offer group
    final List<Package> tipPackets = offerings.getOffering('tip')?.availablePackages ?? [];

    // Due to lack of support in the stores to offer IAP discouts I created a new offer group that is used to detect offers for IAP
    final List<Package> iapOffers = offerings.getOffering('iap_promos')?.availablePackages ?? [];

    return PaywallPageState(
      paywallOfferings: packetsToOffer,
      tipPackages: tipPackets,
      iapPromos: iapOffers,
    );
  }

  openGithub() async {
    const String url = 'https://github.com/Clon1998/mobileraker';
    if (await canLaunchUrlString(url)) {
      await launchUrlString(url, mode: LaunchMode.externalApplication);
    } else {
      throw 'Could not launch $url';
    }
  }

  onTippingPressed() async {
    // var tipPacket = state.valueOrNull?.tipPackage;
    if (state.valueOrNull?.tipAvailable != true) {
      logger.w('Tip package is not available');
      return;
    }

    var dialogResponse = await ref.read(dialogServiceProvider).show(
          DialogRequest(
            type: DialogType.tipping,
            data: state.valueOrNull?.tipPackages ?? [],
          ),
        );
    if (dialogResponse?.confirmed == true) {
      logger.i('User selected tip package: ${dialogResponse?.data}');
      makePurchase(dialogResponse!.data as Package);
    }
  }

  copyRCatIdToClipboard() {
    var customerInfo = ref.read(customerInfoProvider).valueOrNull;
    Clipboard.setData(
      ClipboardData(text: customerInfo?.originalAppUserId ?? ''),
    );
  }

  makePurchase(Package packageToBuy) async {
    // state = const AsyncLoading();
    state = state.whenData((value) => value.copyWith(makingPurchase: true));
    CustomerInfo customerInfo = await ref.read(customerInfoProvider.future);

    GoogleProductChangeInfo? googleProductChangeInfo;
    if (Platform.isAndroid &&
        customerInfo.activeSubscriptions.isNotEmpty &&
        packageToBuy.storeProduct.productCategory == ProductCategory.subscription) {
      EntitlementInfo? activeEnt = customerInfo.entitlements.active['supporter_subscription'];
      if (activeEnt?.willRenew == true) {
        googleProductChangeInfo = GoogleProductChangeInfo(activeEnt!.productIdentifier);
      }
    }

    await ref.read(paymentServiceProvider).purchasePackage(packageToBuy, googleProductChangeInfo);
    state = state.whenData((value) => value.copyWith(makingPurchase: false));
  }

  void userSignIn() {
    ref
        .read(bottomSheetServiceProvider)
        .show(BottomSheetConfig(type: SheetType.userManagement, isScrollControlled: true));
  }

  openManagement() async {
    var managementUrl = ref.read(customerInfoProvider.selectAs((data) => data.managementURL)).valueOrNull;
    // logger.wtf(managementUrl);
    if (managementUrl == null) return;

    if (await canLaunchUrlString(managementUrl)) {
      await launchUrlString(
        managementUrl,
        mode: LaunchMode.externalApplication,
      );
    } else {
      throw 'Could not launch $managementUrl';
    }
  }

  openPerksInfo() {
    ref.read(dialogServiceProvider).show(DialogRequest(type: DialogType.perks));
  }

  openDevContact() {
    var discord = tr('pages.paywall.contact_dialog.via_discord', args: []);

    ref.read(dialogServiceProvider).show(DialogRequest(
          type: DialogType.info,
          title: 'pages.paywall.contact_dialog.title'.tr(),
          body: 'pages.paywall.contact_dialog.body'.tr(args: ['dev@mobileraker.com', 'pad_sch']),
        ));
  }
}

@freezed
class PaywallPageState with _$PaywallPageState {
  const PaywallPageState._();

  const factory PaywallPageState({
    @Default(false) bool makingPurchase,
    @Default([]) List<Package> paywallOfferings,
    @Default([]) List<Package> tipPackages,
    @Default([]) List<Package> iapPromos,
  }) = _PaywallPageState;

  bool get tipAvailable => tipPackages.isNotEmpty;
}
