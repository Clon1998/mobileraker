import 'dart:math';

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/data/dto/machine/printer.dart';
import 'package:mobileraker/logger.dart';
import 'package:mobileraker/service/moonraker/printer_service.dart';
import 'package:mobileraker/util/async_ext.dart';
import 'package:pull_to_refresh_flutter3/pull_to_refresh_flutter3.dart';


final _refreshController =
Provider.autoDispose((ref) => RefreshController(initialRefresh: false));

final refreshPrinterController =
StateNotifierProvider.autoDispose<RefreshPrinterController, void>(
        (ref) => RefreshPrinterController(ref));


class PullToRefreshPrinter extends HookConsumerWidget {
  final Widget? child;

  const PullToRefreshPrinter({super.key, this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var onBackground = Theme.of(context).colorScheme.onBackground;
    return SmartRefresher(
      header: ClassicHeader(
        textStyle: TextStyle(color: onBackground),
        failedIcon: Icon(Icons.error, color: onBackground),
        completeIcon: Icon(Icons.done, color: onBackground),
        idleIcon: Icon(Icons.arrow_downward, color: onBackground),
        releaseIcon: Icon(Icons.refresh, color: onBackground),
      ),
      controller: ref.read(refreshPrinterController.notifier).refreshController,
      onRefresh: ref.read(refreshPrinterController.notifier).onRefresh,
      child: child,
    );
  }
}

class RefreshPrinterController extends StateNotifier<void> {
  RefreshPrinterController(this.ref)
      : refreshController = ref.watch(_refreshController),
        super(null);

  final AutoDisposeRef ref;

  final RefreshController refreshController;

  onRefresh() {
    var printerService = ref.read(printerServiceSelectedProvider);

    var old = printerService.currentOrNull;
    printerService.refreshPrinter();
    late ProviderSubscription sub;
    sub = ref.listen<AsyncValue<Printer>>(printerSelectedProvider, (_, next) {
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
    
  }

  @override
  dispose() {
    super.dispose();
  }
}
