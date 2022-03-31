import 'package:flutter/material.dart';
import 'package:mobileraker/app/app_setup.router.dart';
import 'package:mobileraker/ui/components/drawer/nav_drawer_view.dart';
import 'package:mobileraker/ui/views/paywall/paywall_viewmodel.dart';
import 'package:progress_indicators/progress_indicators.dart';
import 'package:stacked/stacked.dart';

class PaywallView extends ViewModelBuilderWidget<PaywallViewModel> {
  @override
  Widget builder(BuildContext context, PaywallViewModel model, Widget? child) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('Support the Dev!'),
        ),
        drawer: NavigationDrawerWidget(curPath: Routes.paywallView),
        body: Center(child: ff(model)));
  }

  Widget? ff(PaywallViewModel model) {
    if (!model.dataReady) return FadingText('Fetching offers');

    if (model.isEntitlementActive('Supporter'))
      return Text('Yay! Thanks for supporting the App!');

    return TextButton(onPressed: model.buy, child: Text('Test-Buy'));
  }

  @override
  PaywallViewModel viewModelBuilder(BuildContext context) => PaywallViewModel();
}
