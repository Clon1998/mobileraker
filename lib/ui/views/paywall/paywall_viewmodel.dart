import 'dart:developer';

import 'package:flutter/services.dart';
import 'package:mobileraker/app/app_setup.locator.dart';
import 'package:mobileraker/app/app_setup.logger.dart';
import 'package:mobileraker/service/purchases_service.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:stacked/stacked.dart';

class PaywallViewModel extends FutureViewModel<Offerings> {
  final _logger = getLogger('PaywallViewModel');
  final _purchasesService = locator<PurchasesService>();

  @override
  Future<Offerings> futureToRun() => _purchasesService.fetchOfferings();

  bool isEntitlementActive(String entitlement) =>
      _purchasesService.isEntitlementActive(entitlement);

  @override
  onData(Offerings? data) {
    _logger.i('Received offerings');
    log(data.toString());
  }

  buy() async {
    try {
      var purchaserInfo =
          await Purchases.purchasePackage(data!.current!.monthly!);
      _logger.i('Received purchaserInfo');
      notifyListeners();
    } on PlatformException catch (e) {
      var errorCode = PurchasesErrorHelper.getErrorCode(e);
      if (errorCode != PurchasesErrorCode.purchaseCancelledError) {
        _logger.e(e);
      }
    }
  }
}
