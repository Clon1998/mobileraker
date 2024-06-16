/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/dto/server/klipper.dart';
import 'package:common/data/model/hive/machine.dart';
import 'package:common/network/jrpc_client_provider.dart';
import 'package:common/network/json_rpc_client.dart';
import 'package:common/service/moonraker/klippy_service.dart';
import 'package:common/service/moonraker/printer_service.dart';
import 'package:common/service/selected_machine_service.dart';
import 'package:common/service/ui/dialog_service_interface.dart';
import 'package:common/service/ui/snackbar_service_interface.dart';
import 'package:common/util/extensions/ref_extension.dart';
import 'package:common/util/logger.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:pull_to_refresh_flutter3/pull_to_refresh_flutter3.dart';

class PullToRefreshPrinter extends ConsumerStatefulWidget {
  const PullToRefreshPrinter({super.key, this.child, this.enablePullDown = true, this.scrollController, this.physics});

  final Widget? child;

  final bool enablePullDown;
  final ScrollController? scrollController;
  final ScrollPhysics? physics;

  @override
  ConsumerState createState() => _PullToRefreshPrinterState();
}

class _PullToRefreshPrinterState extends ConsumerState<PullToRefreshPrinter> {
  final RefreshController refreshController = RefreshController(initialRefresh: false);

  SnackBarService get snackBarService => ref.read(snackBarServiceProvider);

  DialogService get dialogService => ref.read(dialogServiceProvider);

  @override
  Widget build(BuildContext context) {
    var onBackground = Theme.of(context).colorScheme.onBackground;
    return SmartRefresher(
      enablePullDown: widget.enablePullDown,
      header: ClassicHeader(
        textStyle: TextStyle(color: onBackground),
        failedIcon: Icon(Icons.error, color: onBackground),
        completeIcon: Icon(Icons.done, color: onBackground),
        idleIcon: Icon(Icons.arrow_downward, color: onBackground),
        releaseIcon: Icon(Icons.refresh, color: onBackground),
      ),
      controller: refreshController,
      scrollController: widget.scrollController,
      physics: widget.physics,
      onRefresh: onRefresh,
      child: widget.child,
    );
  }

  void onRefresh() async {
    final Machine? selMachine;
    try {
      selMachine = await ref.read(selectedMachineProvider.future);

      if (selMachine == null) {
        refreshController.refreshFailed();
        return;
      }
    } catch (_) {
      refreshController.refreshFailed();
      return;
    }

    // late ProviderSubscription sub;
    ClientType clientType = ref.read(jrpcClientTypeProvider(selMachine.uuid));

    logger.i('Refreshing $clientType was PULL to REFRESH');

    ProviderSubscription<PrinterService>? printerServiceKeepAlive;
    ProviderSubscription<KlippyService>? klippyServiceKeepAlive;
    try {
      printerServiceKeepAlive = ref.keepAliveExternally(printerServiceProvider(selMachine.uuid));
      klippyServiceKeepAlive = ref.keepAliveExternally(klipperServiceProvider(selMachine.uuid));

      await klippyServiceKeepAlive.read().refreshKlippy();
      var read = ref.read(klipperProvider(selMachine.uuid));
      if (read
          case AsyncData(hasError: false, hasValue: true, value: KlipperInstance(klippyCanReceiveCommands: true))) {
        logger.i(
          'Klippy reported ready and connected, will try to refresh printer',
        );
        await printerServiceKeepAlive.read().refreshPrinter();
      }
      // throw MobilerakerException('Klippy is not ready to receive commands');
      refreshController.refreshCompleted();
    } catch (e, s) {
      logger.w('Error while trying to refresh printer', e);
      refreshController.refreshFailed();
      snackBarService.show(SnackBarConfig.stacktraceDialog(
        dialogService: dialogService,
        exception: e,
        stack: s,
        snackTitle: 'Refresh failed',
        snackMessage: 'Error while trying to refresh printer',
        dialogTitle: 'Printer refresh failed',
      ));
    } finally {
      printerServiceKeepAlive?.close();
      klippyServiceKeepAlive?.close();
    }
  }

  @override
  void dispose() {
    refreshController.dispose();
    super.dispose();
  }
}
