import 'package:mobileraker/app/app_setup.logger.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

// Wrapper for the RevenueCat Purchases API.
class PurchasesService {
  PurchasesService() {
    Purchases.addPurchaserInfoUpdateListener(purchaserInfoUpdateListener);
    Purchases.getPurchaserInfo().then(purchaserInfoUpdateListener);
  }

  final _logger = getLogger('PurchasesService');

  PurchaserInfo? _purchaserInfo;

  PurchaserInfo get purchaserInfo => _purchaserInfo!;

  bool get available => _purchaserInfo != null;

  purchaserInfoUpdateListener(PurchaserInfo purchaserInfo) {
    _logger.i('Updated purchaserInfo');
    _purchaserInfo = purchaserInfo;
  }

  bool isEntitlementActive(String entitlement) =>
      _purchaserInfo?.entitlements.all[entitlement]?.isActive ?? false;

  Future<Offerings> fetchOfferings() {
    return Purchases.getOfferings();
  }
}
