import 'package:flutter/material.dart';
import 'package:mobileraker/app/app_setup.locator.dart';
import 'package:mobileraker/app/app_setup.logger.dart';
import 'package:mobileraker/service/selected_machine_service.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:stacked/stacked.dart';

class PullToRefreshPrinter
    extends ViewModelBuilderWidget<RefreshPrinterViewModel> {
  final Widget? child;

  const PullToRefreshPrinter({Key? key, required this.child}) : super(key: key);

  @override
  Widget builder(BuildContext context, RefreshPrinterViewModel model,
      Widget? staticChild) {
    var onBackground = Theme.of(context).colorScheme.onBackground;
    return SmartRefresher(
      header: ClassicHeader(
        textStyle: TextStyle(color: onBackground),
        failedIcon: Icon(Icons.error, color: onBackground),
        completeIcon: Icon(Icons.done, color: onBackground),
        idleIcon: Icon(Icons.arrow_downward, color: onBackground),
        releaseIcon: Icon(Icons.refresh, color: onBackground),
      ),
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
  final _selectedMachineService = locator<SelectedMachineService>();
  final _logger = getLogger('RefreshPrinterViewModel');

  onRefresh() {
    var _printerService =
        _selectedMachineService.selectedMachine.valueOrNull?.printerService;
    // We need to work with hashes since the PrinterObject never gets destroyed <.< (TODO: USE FREEZE FOR IMMUTABLE OBJECTS!!!!)
    var oldPrinterHash =
        _printerService?.printerStream.valueOrNull?.hashCode ?? 0;
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

  @override
  dispose() {
    super.dispose();
    refreshController.dispose();
  }
}
