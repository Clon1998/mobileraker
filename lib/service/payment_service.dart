import 'dart:io';

import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:mobileraker/logger.dart';
import 'package:mobileraker/service/ui/snackbar_service.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'payment_service.g.dart';

@Riverpod(keepAlive: true)
Future<CustomerInfo> customerInfo(CustomerInfoRef ref) async {
  var customerInfo = await Purchases.getCustomerInfo();
  logger.i('Got customerInfo: $customerInfo');

  checkForExpired() async {
    logger.i('Checking for expired subs!');
    var v = ref.state;
    var now = DateTime.now();
    if (v.hasValue) {
      var hasExpired = v.value!.entitlements.active.values.any((ent) =>
          ent.expirationDate != null &&
          DateTime.tryParse(ent.expirationDate!)?.isBefore(now) == true);
      if (hasExpired) {
        logger.i('Found expired Entitlement, force refresh!');
        ref.state = await AsyncValue.guard(() async {
          await Purchases.invalidateCustomerInfoCache();
          return Purchases.getCustomerInfo();
        });
        // ref.state = AsyncValue.guard(() => )
      }
    }
  }

  ref.onAddListener(checkForExpired);
  ref.onResume(checkForExpired);

  return customerInfo;
}

@Riverpod(keepAlive: true)
PaymentService paymentService(PaymentServiceRef ref) {
  return PaymentService(ref);
}

// ToDo: Decide if I need a wrapper or not.. Purchases itself already is a singleton
class PaymentService {
  PaymentService(this.ref);

  final PaymentServiceRef ref;

  Future<void> initialize() async {
    if (kDebugMode) await Purchases.setLogLevel(LogLevel.info);

    PurchasesConfiguration configuration;
    if (Platform.isAndroid) {
      configuration =
          PurchasesConfiguration('goog_uzbmaMIthLRzhDyQpPsmvOXbaCK');
    } else if (Platform.isIOS) {
      configuration =
          PurchasesConfiguration('appl_RsarzvMWCvAavWUevgRSXXLDeTL');
    } else {
      throw StateError('Unsupported device type!');
    }
    await Purchases.configure(configuration);
  }

  Future<Offerings> getOfferings() {
    return Purchases.getOfferings();
  }

  Future<void> purchasePackage(Package packageToBuy,
      [UpgradeInfo? upgradeInfo]) async {
    try {
      logger.i('Trying to buy ${packageToBuy.storeProduct.identifier}');
      await Purchases.purchasePackage(packageToBuy, upgradeInfo: upgradeInfo);
      var customerInfo = await ref.refresh(customerInfoProvider.future);
      logger.i('Successful bought package... $customerInfo');
      ref.read(snackBarServiceProvider).show(SnackBarConfig(
          title: 'Subscribed!',
          message:
              'You just subscribed to Mobileraker! Thanks a lot for the support!'));
    } on PlatformException catch (e) {
      var errorCode = PurchasesErrorHelper.getErrorCode(e);
      if (errorCode != PurchasesErrorCode.purchaseCancelledError) {
        logger.e('Error while trying to purchase; $e');
        ref.read(snackBarServiceProvider).show(SnackBarConfig(
            type: SnackbarType.error,
            title: 'Unexpected Error',
            message: errorCode.name.capitalize));
      } else {
        logger.w('User canceled purchase!');
        // ref.read(snackBarServiceProvider).show(SnackBarConfig(
        //     type: SnackbarType.warning,
        //     title: 'Canceled',
        //     message: 'Subscription request canceled'));
      }
    }
  }

  restorePurchases() async {
    try {
      var customerInfo = await Purchases.restorePurchases();
      var length = customerInfo.activeSubscriptions.length;
      logger.i('Restored purchases: ${customerInfo.activeSubscriptions}');
      if (length > 0) {
        ref.read(snackBarServiceProvider).show(SnackBarConfig(
            type: SnackbarType.info,
            title: 'Purchases restored',
            message: 'Managed to restore $length subscriptions!'));
      }
      ref.invalidate(customerInfoProvider);
    } on PlatformException catch (e) {
      var errorCode = PurchasesErrorHelper.getErrorCode(e);
      logger.e('Error while trying to restore purchases; $e');
      ref.read(snackBarServiceProvider).show(SnackBarConfig(
          type: SnackbarType.error,
          title: 'Error during restore',
          message: errorCode.name.capitalize));
    }
  }
}
