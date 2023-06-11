/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:io';

import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mobileraker/data/model/firestore/supporters.dart';
import 'package:mobileraker/logger.dart';
import 'package:mobileraker/service/firebase/firestore.dart';
import 'package:mobileraker/service/notification_service.dart';
import 'package:mobileraker/service/ui/snackbar_service.dart';
import 'package:mobileraker/util/extensions/async_ext.dart';
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
    _setupListeners();
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

  // TODO: rework/extract to own method, this is just a dirty POC
  _setupListeners() {
    final _boxSettings = Hive.box('settingsbox');
    final _key = 'subData';
    // _boxSettings.delete(_key);
    ref.listen(customerInfoProvider, (previous, next) async {
      if (next.valueOrFullNull?.activeSubscriptions.isNotEmpty == true) {
        CustomerInfo customerInfo = next.value!;
        String token =
            await ref.read(notificationServiceProvider).fetchCurrentFcmToken();
        var entitlementInfo = customerInfo.entitlements.active.values.first;
        if (_boxSettings.containsKey(_key)) {
          Map<dynamic, dynamic> name = _boxSettings.get(_key);
          var supporter = Supporter.fromJson(name.cast<String, dynamic>());
          logger.i(
              'Read Supporter from local storage local: ${supporter.expirationDate}, customer ${entitlementInfo.expirationDate}');
          if (supporter.expirationDate != null &&
              DateTime.now().isBefore(supporter.expirationDate!)) {
            logger.i(
                'No need to write to firebase, its expected to still have a valid sub!');
            return;
          }
        }

        DateTime? dt = null;
        if (entitlementInfo.expirationDate != null) {
          dt = DateTime.parse(entitlementInfo.expirationDate!);
        }

        try {
          var supporter = Supporter(fcmToken: token, expirationDate: dt);
          await ref
              .read(firestoreProvider)
              .collection('sup')
              .doc(customerInfo.originalAppUserId)
              .set(supporter.toFirebase());
          logger.i(
              'Added fcmToken to fireStore... now writing it to local storage');
          _boxSettings.put(_key, supporter.toJson());
        } catch (e) {
          logger.w(
              'Error while trying to register FCM token with firebase:', e);
        }
      }
    });
  }
}
