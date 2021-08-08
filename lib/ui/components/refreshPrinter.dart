import 'package:flutter/widgets.dart';
import 'package:mobileraker/app/AppSetup.locator.dart';
import 'package:mobileraker/service/SelectedMachineService.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:stacked/stacked.dart';

class PullToRefreshPrinter extends StatelessWidget {
  final Widget? child;

  const PullToRefreshPrinter({Key? key, required this.child}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ViewModelBuilder<RefreshPrinterViewModel>.nonReactive(

      viewModelBuilder:() => RefreshPrinterViewModel(),
      builder: (context, model, _child) => SmartRefresher(
        controller: model.refreshController,
        onRefresh: model.onRefresh,
        child: child,
      ),
    );
  }
}

class RefreshPrinterViewModel extends BaseViewModel {
  RefreshController refreshController =
      RefreshController(initialRefresh: false);
  final _selectedMachineService = locator<SelectedMachineService>();

  onRefresh() {
    var _printerService =
        _selectedMachineService.selectedPrinter.valueOrNull?.printerService;
    var oldPrinter = _printerService?.printerStream.value;
    _printerService?.refreshPrinter();
    var subscription;
    subscription = _printerService?.printerStream.stream.listen((event) {
      if (event != oldPrinter) refreshController.refreshCompleted();
      subscription.cancel();
    });
  }
}
