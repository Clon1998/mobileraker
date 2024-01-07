/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:async';
import 'dart:io';

import 'package:common/service/firebase/auth.dart';
import 'package:common/util/extensions/object_extension.dart';
import 'package:common/util/logger.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:stringr/stringr.dart';

import '../data/model/firestore/supporters.dart';
import 'firebase/firestore.dart';
import 'notification_service.dart';
import 'setting_service.dart';
import 'ui/snackbar_service_interface.dart';

part 'payment_service.g.dart';

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
        var hasExpired = v.requireValue.entitlements.active.values
            .any((ent) => ent.expirationDate != null && DateTime.tryParse(ent.expirationDate!)?.isBefore(now) == true);
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

  Future<void> purchasePackage(Package packageToBuy, [GoogleProductChangeInfo? googleProductChangeInfo]) async {
    try {
      var storeProduct = packageToBuy.storeProduct;
      if (Platform.isIOS && storeProduct.discounts?.isNotEmpty == true) {
        logger.i('Trying to buy ${storeProduct.identifier} at discounted rate ');
        var promotionalOffer = await Purchases.getPromotionalOffer(storeProduct, storeProduct.discounts!.first);

        await Purchases.purchaseDiscountedPackage(packageToBuy, promotionalOffer);
      } else {
        logger.i('Trying to buy ${storeProduct.identifier}');
        await Purchases.purchasePackage(packageToBuy, googleProductChangeInfo: googleProductChangeInfo);
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
        _ref.read(snackBarServiceProvider).show(
            SnackBarConfig(type: SnackbarType.error, title: 'Unexpected Error', message: errorCode.name.capitalize()));
      } else {
        logger.w('User canceled purchase!');
        // ref.read(snackBarServiceProvider).show(SnackBarConfig(
        //     type: SnackbarType.warning,
        //     title: 'Canceled',
        //     message: 'Subscription request canceled'));
      }
    }
  }

  Future<void> restorePurchases({bool passErrors = false, bool showSnacks = true}) async {
    try {
      var customerInfo = await Purchases.restorePurchases();
      var length = customerInfo.entitlements.active.length;
      logger.i('Found $length entitlements');
      logger.i(
          'Restored Subs: ${customerInfo.activeSubscriptions}, nonSubs: ${customerInfo.nonSubscriptionTransactions} ');

      _ref.invalidate(customerInfoProvider);
      if (!showSnacks) return;

      if (length > 0) {
        _ref.read(snackBarServiceProvider).show(SnackBarConfig(
            type: SnackbarType.info, title: 'Purchases restored', message: 'Managed to restore Supporter-Status!'));
      } else {
        _ref
            .read(snackBarServiceProvider)
            .show(SnackBarConfig(type: SnackbarType.warning, title: 'No purchases found'));
      }
    } on PlatformException catch (e) {
      if (passErrors) rethrow;

      var errorCode = PurchasesErrorHelper.getErrorCode(e);

      logger.e('Error while trying to restore purchases; $e');
      _ref.read(snackBarServiceProvider).show(SnackBarConfig(
          type: SnackbarType.error, title: 'Error during restore', message: errorCode.name.capitalize()));
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
            final settingKey =
                CompositeKey.keyWithString(UtilityKeys.supporterTokenDate, customerInfo.originalAppUserId);

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
            logger.e('Error while trying to register supporter status/fcm token in firebase:', e, s);
          }
        }
      },
      fireImmediately: true,
    );

    _ref.listen(
      firebaseUserProvider,
      (previous, next) async {
        var isLogin = previous?.valueOrNull == null && next.valueOrNull != null;
        var isLogout = previous?.valueOrNull != null && next.valueOrNull == null;

        if (isLogin) {
          try {
            LogInResult logInResult = await Purchases.logIn(next.requireValue!.uid);
            logger.i('Logged user into rCat: created: ${logInResult.created} - ${logInResult.customerInfo}}');
          } on PlatformException catch (e) {
            var errorCode = PurchasesErrorHelper.getErrorCode(e);

            logger.e('Error while trying to log in to Purchases: $errorCode');
          }
        } else if (isLogout) {
          try {
            var customerInfo = await Purchases.logOut();
            logger.i('Logged user out of rCat - new Anonym ID: ${customerInfo.originalAppUserId}');
          } on PlatformException catch (e) {
            var errorCode = PurchasesErrorHelper.getErrorCode(e);
            logger.e('Error while logging out of rCat: $errorCode');
          }
        }
        _ref.invalidate(customerInfoProvider);
      },
      fireImmediately: true,
    );
  }
}
