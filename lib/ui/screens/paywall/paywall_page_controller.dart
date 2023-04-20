import 'package:flutter/services.dart';
import 'package:mobileraker/logger.dart';
import 'package:mobileraker/service/payment_service.dart';
import 'package:mobileraker/util/extensions/async_ext.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:url_launcher/url_launcher_string.dart';

part 'paywall_page_controller.g.dart';

@riverpod
class PaywallPageController extends _$PaywallPageController {
  @override
  FutureOr<Offering?> build() async {
    try {
      Offerings offerings = await ref.watch(paymentServiceProvider).getOfferings();
      if (offerings.current != null &&
          offerings.current!.availablePackages.isNotEmpty) {
        return offerings.current;
      }
      return null;
    } on PlatformException catch (e, s) {
      logger.e('Error while trying to fetch offerings from revenue cat!');
      return Future.error(e, s);
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
    await ref.read(paymentServiceProvider).purchasePackage(packageToBuy);
    
    
  }

  openManagement() async {
    var managementUrl = ref.read(customerInfoProvider.selectAs((data) => data.managementURL)).valueOrNull;
    logger.wtf(managementUrl);
    if (managementUrl == null) return;

    if (await canLaunchUrlString(managementUrl)) {
      await launchUrlString(managementUrl, mode: LaunchMode.externalApplication);
    } else {
      throw 'Could not launch $managementUrl';
    }
  }
}
