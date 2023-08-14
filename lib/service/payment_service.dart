/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:async';
import 'dart:io';

import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:mobileraker/data/model/firestore/supporters.dart';
import 'package:mobileraker/logger.dart';
import 'package:mobileraker/service/firebase/firestore.dart';
import 'package:mobileraker/service/notification_service.dart';
import 'package:mobileraker/service/setting_service.dart';
import 'package:mobileraker/service/ui/snackbar_service.dart';
import 'package:mobileraker/util/extensions/object_extension.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'payment_service.g.dart';

// GP: $RCAnonymousID:0b43a2b24a9c4cdb9edb57198a077e5f
// BLA: $RCAnonymousID:f78797ad228f4a718864dd8b7baf911c
// NOW-BLA: $RCAnonymousID:b21163a05e7642ac928b7c028c9125a6
@Riverpod(keepAlive: true)
Future<CustomerInfo> customerInfo(CustomerInfoRef ref) async {
  try {
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
    logger.i('RCat ID: ${customerInfo.originalAppUserId}');

    return customerInfo;
  } on PlatformException catch (e, s) {
    logger.w('Could not fetch customer info. Platform code: ${e.code}!', e, s);
    return const CustomerInfo(EntitlementInfos({}, {}), {}, [], [], [], "", "", {}, "");
  }
}

@Riverpod(keepAlive: true)
bool isSupporter(IsSupporterRef ref) {
  return ref.watch(isSupporterAsyncProvider).valueOrNull == true;
}

@Riverpod(keepAlive: true)
FutureOr<bool> isSupporterAsync(IsSupporterAsyncRef ref) async {
  var customerInfo = await ref.watch(customerInfoProvider.future);
  return customerInfo.entitlements.active.containsKey('Supporter') == true;
}

@Riverpod(keepAlive: true)
PaymentService paymentService(PaymentServiceRef ref) {
  return PaymentService(ref);
}

// ToDo: Decide if I need a wrapper or not.. Purchases itself already is a singleton
class PaymentService {
  PaymentService(this._ref) : _settingService = _ref.watch(settingServiceProvider);

  final SettingService _settingService;

  final PaymentServiceRef _ref;

  Future<void> initialize() async {
    if (kDebugMode) await Purchases.setLogLevel(LogLevel.info);

    PurchasesConfiguration configuration;
    if (Platform.isAndroid) {
      configuration = PurchasesConfiguration('goog_uzbmaMIthLRzhDyQpPsmvOXbaCK');
    } else if (Platform.isIOS) {
      configuration = PurchasesConfiguration('appl_RsarzvMWCvAavWUevgRSXXLDeTL');
    } else {
      throw StateError('Unsupported device type!');
    }
    await Purchases.configure(configuration);
    _setupListeners();
    logger.i('Completed PaymentService init');
  }

  Future<Offerings> getOfferings() {
    return Purchases.getOfferings();
  }

  Future<void> purchasePackage(Package packageToBuy,
      [GoogleProductChangeInfo? googleProductChangeInfo]) async {
    try {
      var storeProduct = packageToBuy.storeProduct;
      if (Platform.isIOS && storeProduct.discounts?.isNotEmpty == true) {
        logger.i('Trying to buy ${storeProduct.identifier} at discounted rate ');
        var promotionalOffer =
            await Purchases.getPromotionalOffer(storeProduct, storeProduct.discounts!.first);

        await Purchases.purchaseDiscountedPackage(packageToBuy, promotionalOffer);
      } else {
        logger.i('Trying to buy ${storeProduct.identifier}');
        await Purchases.purchasePackage(packageToBuy,
            googleProductChangeInfo: googleProductChangeInfo);
      }

      var customerInfo = await _ref.refresh(customerInfoProvider.future);
      logger.i('Successful bought package... $customerInfo');
      // _ref.read(snackBarServiceProvider).show(SnackBarConfig(
      //     title: 'Confirmed!',
      //     message: 'You just subscribed to Mobileraker! Thanks a lot for the support!'));
    } on PlatformException catch (e) {
      var errorCode = PurchasesErrorHelper.getErrorCode(e);
      if (errorCode != PurchasesErrorCode.purchaseCancelledError) {
        logger.e('Error while trying to purchase; $e');
        _ref.read(snackBarServiceProvider).show(SnackBarConfig(
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
      var length = customerInfo.entitlements.active.length;
      logger.i(
          'Restored Subs: ${customerInfo.activeSubscriptions}, nonSubs: ${customerInfo.nonSubscriptionTransactions}');
      if (length > 0) {
        _ref.read(snackBarServiceProvider).show(SnackBarConfig(
            type: SnackbarType.info,
            title: 'Purchases restored',
            message: 'Managed to restore Supporter-Status!'));
      }
      _ref.invalidate(customerInfoProvider);
    } on PlatformException catch (e) {
      var errorCode = PurchasesErrorHelper.getErrorCode(e);
      logger.e('Error while trying to restore purchases; $e');
      _ref.read(snackBarServiceProvider).show(SnackBarConfig(
          type: SnackbarType.error,
          title: 'Error during restore',
          message: errorCode.name.capitalize));
    }
  }

  // TODO: rework/extract to own method, this is just a dirty POC
  _setupListeners() {
    // _boxSettings.delete(_key);
    _ref.listen(
      isSupporterProvider,
      (previous, next) async {
        if (next) {
          try {
            CustomerInfo customerInfo = await _ref.read(customerInfoProvider.future);
            String token = await _ref.read(fcmTokenProvider.future);
            if (token.isEmpty || customerInfo.originalAppUserId.isEmpty) return;

            var supporterEntitlement = customerInfo.entitlements.active['Supporter']!;
            final settingKey = CompositeKey.keyWithString(
                UtilityKeys.supporterTokenDate, customerInfo.originalAppUserId);

            if (_settingService.containsKey(settingKey)) {
              Map<dynamic, dynamic> name = _settingService.read(settingKey, {});
              var supporter = Supporter.fromJson(name.cast<String, dynamic>());

              logger.i(
                  'Read Supporter storage local: ${supporter.expirationDate}, ${supporter.fcmToken}. Customer.expirationDate: ${supporterEntitlement.expirationDate}, FcmToken: $token');
              if (supporter.expirationDate != null &&
                  DateTime.now().isBefore(supporter.expirationDate!) &&
                  supporter.fcmToken == token) {
                logger.i('No need to write to firebase, its expected to still have a valid sub!');
                return;
              }
            }

            // entitlement.expirationDate can be null if it is a lifetime sub
            DateTime dt = supporterEntitlement.expirationDate?.let(DateTime.parse) ??
                DateTime.now().add(const Duration(days: 30));

            try {
              var supporter = Supporter(fcmToken: token, expirationDate: dt);
              await _ref
                  .read(firestoreProvider)
                  .collection('sup')
                  .doc(customerInfo.originalAppUserId)
                  .set(supporter.toFirebase());
              logger.i('Added fcmToken to fireStore... now writing it to local storage');
              _settingService.write(settingKey, supporter.toJson());
            } catch (e) {
              logger.w('Error while trying to register FCM token with firebase:', e);
            }
          } catch (e, s) {
            logger.e(
                'Error while trying to register supporter status/fcm token in firebase:', e, s);
          }
        }
      },
      fireImmediately: true,
    );
  }
}
