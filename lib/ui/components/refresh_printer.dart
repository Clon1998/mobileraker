import 'package:flutter/widgets.dart';
import 'package:mobileraker/app/AppSetup.locator.dart';
import 'package:mobileraker/app/AppSetup.logger.dart';
import 'package:mobileraker/service/MachineService.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:stacked/stacked.dart';

class PullToRefreshPrinter
    extends ViewModelBuilderWidget<RefreshPrinterViewModel> {
  final Widget? child;

  const PullToRefreshPrinter({Key? key, required this.child}) : super(key: key);

  @override
  Widget builder(BuildContext context, RefreshPrinterViewModel model,
      Widget? staticChild) {
    return SmartRefresher(
      controller: model.refreshController,
      onRefresh: model.onRefresh,
      child: child,
    );
  }

  @override
  RefreshPrinterViewModel viewModelBuilder(BuildContext context) =>
      RefreshPrinterViewModel();
}

class RefreshPrinterViewModel extends BaseViewModel {
  RefreshController refreshController =
      RefreshController(initialRefresh: false);
  final _machineService = locator<MachineService>();
  final _logger = getLogger('RefreshPrinterViewModel');

  onRefresh() {
    var _printerService =
        _machineService.selectedPrinter.valueOrNull?.printerService;
    // We need to work with hashes since the PrinterObject never gets destroyed <.< (TODO: USE FREEZE FOR IMMUTABLE OBJECTS!!!!)
    var oldPrinterHash = _printerService?.printerStream.valueOrNull?.hashCode??0;
    var subscription;
    subscription = _printerService?.printerStream.stream.listen((event) {
      if (event.hashCode != oldPrinterHash) {
        _logger.v("Refreshing printer COMPLETE");
        refreshController.refreshCompleted();
        subscription.cancel();
      }
    });
    _logger.v("Refreshing printer...");
    _printerService?.refreshPrinter();
  }
}
