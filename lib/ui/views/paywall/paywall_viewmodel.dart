import 'dart:developer';

import 'package:flutter/services.dart';
import 'package:mobileraker/app/app_setup.locator.dart';
import 'package:mobileraker/app/app_setup.logger.dart';
import 'package:mobileraker/service/purchases_service.dart';
import 'package:mobileraker/service/selected_machine_service.dart';
import 'package:mobileraker/ui/common/mixins/printer_mixin.dart';
import 'package:mobileraker/ui/common/mixins/selected_machine_mixin.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:stacked/stacked.dart';

const String off = 'OFFERINGS';

class PaywallViewModel extends MultipleStreamViewModel
    with SelectedMachineMixin, PrinterMixin {
// class PaywallViewModel extends FutureViewModel<Offerings> {
  final _logger = getLogger('PaywallViewModel');
  final _purchasesService = locator<PurchasesService>();
  final _selMach = locator<SelectedMachineService>();

  bool isEntitlementActive(String entitlement) =>
      _purchasesService.isEntitlementActive(entitlement);

  @override
  Map<String, StreamData> get streamsMap => {
        off: StreamData<Offerings>(
            _purchasesService.fetchOfferings().asStream()),
        ...super.streamsMap
      };

  @override
  onData(String key, dynamic data) {
    if (key == off) {
      var offerings = data as Offerings;
      _logger.wtf('Received offerings:');
      log(offerings.toString());
      _logger.wtf('Offerings.cur: ${offerings.current}');

    }
  }

  buy() async {
    try {
      var purchaserInfo =
          await Purchases.purchasePackage(dataMap![off]!.current!.monthly!);
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
