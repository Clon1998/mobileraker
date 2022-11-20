import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/data/dto/machine/printer.dart';
import 'package:mobileraker/logger.dart';
import 'package:mobileraker/service/moonraker/printer_service.dart';
import 'package:pull_to_refresh_flutter3/pull_to_refresh_flutter3.dart';

class PullToRefreshPrinter extends ConsumerStatefulWidget {
  const PullToRefreshPrinter({Key? key, this.child}) : super(key: key);

  final Widget? child;

  @override
  ConsumerState createState() => _PullToRefreshPrinterState();
}

class _PullToRefreshPrinterState extends ConsumerState<PullToRefreshPrinter> {
  final RefreshController refreshController =
      RefreshController(initialRefresh: false);


  @override
  Widget build(BuildContext context) {
    var onBackground = Theme.of(context).colorScheme.onBackground;
    return SmartRefresher(
      header: ClassicHeader(
        textStyle: TextStyle(color: onBackground),
        failedIcon: Icon(Icons.error, color: onBackground),
        completeIcon: Icon(Icons.done, color: onBackground),
        idleIcon: Icon(Icons.arrow_downward, color: onBackground),
        releaseIcon: Icon(Icons.refresh, color: onBackground),
      ),
      controller: refreshController,
      onRefresh: onRefresh,
      child: widget.child,
    );
  }

  onRefresh() {
    var printerService = ref.read(printerServiceSelectedProvider);

    var old = printerService.currentOrNull;
    late ProviderSubscription sub;

    sub = ref.listenManual<AsyncValue<Printer>>(printerSelectedProvider,
        (_, next) {
      next.whenData((value) {
        if (value != old) {
          refreshController.refreshCompleted();
          logger.i("Refreshing printer COMPLETE");
          sub.close();
        } else {
          logger.e('Expected not the same !');
        }
      });
    });
    printerService.refreshPrinter();
  }

  @override
  void dispose() {
    super.dispose();
    refreshController.dispose();
  }
}
