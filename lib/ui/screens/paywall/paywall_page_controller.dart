import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/services.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:mobileraker/logger.dart';
import 'package:mobileraker/service/payment_service.dart';
import 'package:mobileraker/service/ui/dialog_service.dart';
import 'package:mobileraker/util/extensions/async_ext.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:url_launcher/url_launcher_string.dart';

part 'paywall_page_controller.freezed.dart';
part 'paywall_page_controller.g.dart';

@riverpod
class PaywallPageController extends _$PaywallPageController {
  @override
  PaywallPageState build() {
    _fetchOfferings();
    return const PaywallPageState();
  }

  _fetchOfferings() async {
    try {
      Offerings offerings =
          await ref.watch(paymentServiceProvider).getOfferings();
      if (offerings.current != null &&
          offerings.current!.availablePackages.isNotEmpty) {
        state = state.copyWith(offering: AsyncValue.data(offerings.current));
        return;
      }
      state = state.copyWith(offering: const AsyncValue.data(null));
    } on PlatformException catch (e, s) {
      logger.e('Error while trying to fetch offerings from revenue cat!', e, s);
      state = state.copyWith(offering: AsyncValue.error(e, s));
    }
  }

  openGithub() async {
    const String url = 'https://github.com/Clon1998/mobileraker';
    if (await canLaunchUrlString(url)) {
      await launchUrlString(url, mode: LaunchMode.externalApplication);
    } else {
      throw 'Could not launch $url';
    }
  }

  makePurchase(Package packageToBuy) async {
    // state = const AsyncLoading();
    state = state.copyWith(makingPurchase: true);
    CustomerInfo customerInfo = await ref.read(customerInfoProvider.future);

    UpgradeInfo? upgradeInfo;
    if (Platform.isAndroid && customerInfo.activeSubscriptions.isNotEmpty) {
      EntitlementInfo activeEnt = customerInfo.entitlements.active.values.first;
      if (activeEnt.willRenew) {
        upgradeInfo = UpgradeInfo(customerInfo.activeSubscriptions.first);
      }
    }

    await ref
        .read(paymentServiceProvider)
        .purchasePackage(packageToBuy, upgradeInfo);
    state = state.copyWith(makingPurchase: false);
  }

  restore() async {
    state = state.copyWith(makingPurchase: true);
    await ref.read(paymentServiceProvider).restorePurchases();
    state = state.copyWith(makingPurchase: false);
  }

  openManagement() async {
    var managementUrl = ref
        .read(customerInfoProvider.selectAs((data) => data.managementURL))
        .valueOrNull;
    logger.wtf(managementUrl);
    if (managementUrl == null) return;

    if (await canLaunchUrlString(managementUrl)) {
      await launchUrlString(managementUrl,
          mode: LaunchMode.externalApplication);
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
        body: 'pages.paywall.contact_dialog.body'
            .tr(args: ['dev@mobileraker.com', 'Pad#3489'])));
  }
}

@freezed
class PaywallPageState with _$PaywallPageState {
  const factory PaywallPageState(
          {@Default(false) bool makingPurchase,
          @Default(AsyncValue.loading()) AsyncValue<Offering?> offering}) =
      _PaywallPageState;
}
