/*
 * Copyright (c) 2023-2025. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:async';
import 'dart:io';

import 'package:common/service/firebase/auth.dart';
import 'package:common/service/misc_providers.dart';
import 'package:common/util/extensions/object_extension.dart';
import 'package:common/util/logger.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:riverpod/riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:stringr/stringr.dart';

import '../data/model/firestore/supporters.dart';
import 'firebase/firestore.dart';
import 'notification_service.dart';
import 'setting_service.dart';
import 'ui/snackbar_service_interface.dart';

part 'payment_service.g.dart';

@ProviderFor(CustomerInfoNotifier)
final customerInfoProvider = customerInfoNotifierProvider;

@Riverpod(keepAlive: true)
class CustomerInfoNotifier extends _$CustomerInfoNotifier {
  @override
  Future<CustomerInfo> build() async {
    try {
      talker.info('Fetching customer info');
      var customerInfo = await Purchases.getCustomerInfo();
      talker.info('Got customerInfo: $customerInfo');

      checkForExpired() async {
        talker.info('Checking for expired subs!');
        var curUserInfo = state;
        var now = DateTime.now();
        if (curUserInfo.hasValue) {
          var hasExpired = curUserInfo.requireValue.entitlements.active.values.any(
              (ent) => ent.expirationDate != null && DateTime.tryParse(ent.expirationDate!)?.isBefore(now) == true);
          if (hasExpired) {
            talker.info('Found expired Entitlement, force refresh!');
            state = await AsyncValue.guard(() async {
              await Purchases.invalidateCustomerInfoCache();
              return Purchases.getCustomerInfo();
            });
            // ref.state = AsyncValue.guard(() => )
          }
        }
      }

      ref.onAddListener(checkForExpired);
      ref.onResume(checkForExpired);
      talker.info('RCat ID: ${customerInfo.originalAppUserId}');

      return customerInfo;
    } on PlatformException catch (e, s) {
      talker.warning('Could not fetch customer info. Platform code: ${e.code}!', e, s);
      return const CustomerInfo(EntitlementInfos({}, {}), {}, [], [], [], "", "", {}, "");
    }
  }
}

@Riverpod(keepAlive: true)
bool isSupporter(Ref ref) {
  if (kDebugMode) return true;
  return ref.watch(isSupporterAsyncProvider).valueOrNull == true;
}

@Riverpod(keepAlive: true)
FutureOr<bool> isSupporterAsync(Ref ref) async {
  if (kDebugMode) return true;
  var customerInfo = await ref.watch(customerInfoProvider.future);
  return customerInfo.entitlements.active.containsKey('Supporter') == true;
}

/// Returns the platform, if any, where the user bought the supporter package
@Riverpod(keepAlive: true)
bool? supportBoughtOnThisPlatform(Ref ref) {
  var customerInfo = ref.watch(customerInfoProvider).valueOrNull;

  if (customerInfo?.entitlements.active.containsKey('Supporter') != true) return null;

  return customerInfo!.entitlements.active['Supporter']!.store ==
      (Platform.isAndroid
          ? Store.playStore
          : Platform.isMacOS
              ? Store.macAppStore
              : Store.appStore);
}

@Riverpod(keepAlive: true)
bool hasSubscriptionAndLifetime(Ref ref) {
  CustomerInfo? customerInfo = ref.watch(customerInfoProvider).valueOrNull;

  if (customerInfo == null) return false;

  final ent = customerInfo.entitlements.active['Supporter'];
  final subEnt = customerInfo.entitlements.active['supporter_subscription'];

  customerInfo.entitlements.active.forEach((_, action) {
    talker.warning('Action: ${action}');
  });

  talker.warning('Ent: $ent');
  talker.warning('SubEnt: $subEnt');

  if (subEnt == null || ent == null) return false;
  return subEnt.isActive && ent.isActive && subEnt.productIdentifier != ent.productIdentifier;
}

@Riverpod(keepAlive: true)
PaymentService paymentService(Ref ref) {
  return PaymentService(ref);
}

// ToDo: Decide if I need a wrapper or not.. Purchases itself already is a singleton
class PaymentService {
  PaymentService(this._ref) : _settingService = _ref.watch(settingServiceProvider);

  final SettingService _settingService;

  final Ref _ref;

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
    talker.info('Completed PaymentService init');
  }

  Future<Offerings> getOfferings() {
    return Purchases.getOfferings();
  }

  Future<void> purchasePackage(Package packageToBuy, [GoogleProductChangeInfo? googleProductChangeInfo]) async {
    try {
      var storeProduct = packageToBuy.storeProduct;
      if (Platform.isIOS && storeProduct.discounts?.isNotEmpty == true) {
        talker.info('Trying to buy ${storeProduct.identifier} at discounted rate ');
        var promotionalOffer = await Purchases.getPromotionalOffer(storeProduct, storeProduct.discounts!.first);

        await Purchases.purchaseDiscountedPackage(packageToBuy, promotionalOffer);
      } else {
        talker.info('Trying to buy ${storeProduct.identifier}');
        await Purchases.purchasePackage(packageToBuy, googleProductChangeInfo: googleProductChangeInfo);
      }

      var customerInfo = await _ref.refresh(customerInfoProvider.future);
      talker.info('Successful bought package... $customerInfo');
      // _ref.read(snackBarServiceProvider).show(SnackBarConfig(
      //     title: 'Confirmed!',
      //     message: 'You just subscribed to Mobileraker! Thanks a lot for the support!'));
    } on PlatformException catch (e) {
      var errorCode = PurchasesErrorHelper.getErrorCode(e);
      if (errorCode != PurchasesErrorCode.purchaseCancelledError) {
        FirebaseCrashlytics.instance.recordError(
          e,
          StackTrace.current,
          reason: 'Error while trying to purchase',
          fatal: true,
        );

        talker.error('Error while trying to purchase; $e');
        _ref.read(snackBarServiceProvider).show(
            SnackBarConfig(type: SnackbarType.error, title: 'Unexpected Error', message: errorCode.name.capitalize()));
      } else {
        talker.warning('User canceled purchase!');
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
      talker.info('Found $length entitlements');
      talker.info(
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

      talker.error('Error while trying to restore purchases; $e');
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

              talker.info(
                  'Read Supporter storage local: ${supporter.expirationDate}, ${supporter.fcmToken}. Customer.expirationDate: ${supporterEntitlement.expirationDate}, FcmToken: $token');
              if (supporter.expirationDate != null &&
                  DateTime.now().isBefore(supporter.expirationDate!) &&
                  supporter.fcmToken == token) {
                talker.info('No need to write to firebase, its expected to still have a valid sub!');
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
              talker.info('Added fcmToken to fireStore... now writing it to local storage');
              _settingService.write(settingKey, supporter.toJson());
            } catch (e) {
              talker.warning('Error while trying to register FCM token with firebase:', e);
            }
          } catch (e, s) {
            talker.error('Error while trying to register supporter status/fcm token in firebase:', e, s);
          }
        }
      },
      fireImmediately: true,
    );

    _ref.listen(
      firebaseUserProvider,
      (previous, next) async {
        var isLogin = previous?.valueOrNull == null && next.valueOrNull != null ||
            previous?.valueOrNull?.isAnonymous == true && next.valueOrNull?.isAnonymous == false;
        var isLogout = previous?.valueOrNull != null && next.valueOrNull == null ||
            previous?.valueOrNull?.isAnonymous == false && next.valueOrNull?.isAnonymous == true;

        talker.info('[PaymentService] User changed. isLogin: $isLogin, isLogout: $isLogout');

        if (isLogin) {
          try {
            LogInResult logInResult = await Purchases.logIn(next.requireValue!.uid);
            talker.info(
                '[PaymentService] Logged user into rCat: created: ${logInResult.created} - ${logInResult.customerInfo}}');
          } on PlatformException catch (e) {
            var errorCode = PurchasesErrorHelper.getErrorCode(e);

            talker.error('[PaymentService] Error while trying to log in to Purchases: $errorCode');
          }
        } else if (isLogout) {
          try {
            var customerInfo = await Purchases.logOut();
            talker.info('[PaymentService] Logged user out of rCat - new Anonym ID: ${customerInfo.originalAppUserId}');
          } on PlatformException catch (e) {
            var errorCode = PurchasesErrorHelper.getErrorCode(e);
            talker.error('[PaymentService] Error while logging out of rCat: $errorCode');
          }
        }
        _ref.invalidate(customerInfoProvider);
      },
      fireImmediately: true,
    );

    _ref.listen(
      fcmTokenProvider,
      (prev, next) async {
        if (!next.hasValue) return;
        talker.info('Syncing FCM token with Purchases: ${next.value}');
        try {
          await Purchases.setPushToken(next.value!);
          talker.info('Synced FCM token with Purchases');
        } catch (e) {
          talker.warning('Error while trying to sync FCM token with Purchases', e);
        }
      },
      fireImmediately: true,
    );

    _ref.listen(
      versionInfoProvider,
      (prev, next) async {
        if (!next.hasValue) return;
        var packageInfo = next.requireValue;
        talker.info('Setting device version to Purchases: $packageInfo');
        try {
          await Purchases.setAttributes({r'$deviceVersion': packageInfo.toString()});
          talker.info('Set device version to Purchases');
        } catch (e) {
          talker.warning('Error while trying to set device version to Purchases', e);
        }
      },
      fireImmediately: true,
    );
  }
}
