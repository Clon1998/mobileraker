import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:mobileraker/app/app_setup.router.dart';
import 'package:mobileraker/data/model/hive/machine.dart';
import 'package:mobileraker/ui/components/drawer/nav_drawer_view.dart';
import 'package:mobileraker/ui/views/overview/components/single_printer_card.dart';
import 'package:mobileraker/ui/views/overview/overview_viewmodel.dart';
import 'package:progress_indicators/progress_indicators.dart';
import 'package:stacked/stacked.dart';

class OverViewView extends ViewModelBuilderWidget<OverViewViewModel> {
  const OverViewView({Key? key}) : super(key: key);

  @override
  Widget builder(
          BuildContext context, OverViewViewModel model, Widget? child) =>
      Scaffold(
        appBar: AppBar(
          title: Text(
            'pages.overview.title',
            overflow: TextOverflow.fade,
          ).tr(),
        ),
        body: _buildBody(context, model),
        drawer: NavigationDrawerWidget(curPath: Routes.overViewView),
      );

  Widget _buildBody(BuildContext context, OverViewViewModel model) {
    if (!model.dataReady) {
      return Center(
          child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SpinKitRipple(
            color: Theme.of(context).colorScheme.secondary,
            size: 100,
          ),
          SizedBox(
            height: 30,
          ),
          FadingText(tr('pages.overview.fetching_machines')),
          // Text('Fetching printer ...')
        ],
      ));
    }

    List<Machine> machines = model.data!;

    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ...machines.map((machine) => SinglePrinterCard(machine)),
          Center(
            child: ElevatedButton.icon(
                onPressed: model.onAddPressed,
                icon: Icon(Icons.add),
                label: Text('pages.overview.add_machine').tr()),
          )
        ],
      ),
    );
  }

  @override
  OverViewViewModel viewModelBuilder(BuildContext context) =>
      OverViewViewModel();
}
