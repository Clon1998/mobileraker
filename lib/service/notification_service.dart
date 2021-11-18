import 'dart:async';

import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mobileraker/app/app_setup.locator.dart';
import 'package:mobileraker/app/app_setup.logger.dart';
import 'package:mobileraker/domain/printer_setting.dart';
import 'package:mobileraker/dto/machine/print_stats.dart';
import 'package:mobileraker/dto/machine/printer.dart';
import 'package:mobileraker/service/printer_service.dart';

import 'machine_service.dart';

class NotificationService {
  final _logger = getLogger('NotificationService');
  final _machineService = locator<MachineService>();
  final _notifyAPI = AwesomeNotifications();
  Map<String, StreamSubscription<Printer>> _printerStreamMap = {};
  StreamSubscription<ReceivedAction>? _actionStreamListen;

  initialize() {
    //TODO: Track added, and removed machines!
    //TODO: Add a channels for each machine and group these per machine!
    Iterable<PrinterSetting> allMachines = _machineService.fetchAll();

    for (PrinterSetting setting in allMachines) {
      PrinterService printerService = setting.printerService;
      _printerStreamMap[setting.uuid] = printerService.printerStream
          .listen((value) => _onPrinterChanged(setting, value));
    }

    _actionStreamListen = _notifyAPI.actionStream.listen(
        (receivedNotification) => _machineService
            .selectedMachine.valueOrNull?.websocket
            .ensureConnection());
  }

  Future<void> updatePrintStateOnce() async {
    Iterable<PrinterSetting> allMachines = _machineService.fetchAll();
    for (PrinterSetting setting in allMachines) {
      PrinterService printerService = setting.printerService;
      await printerService.printerStream.first.then((printer) async {
        _logger.v('Trying to update once for ${setting.name}');
        await _onPrinterChanged(setting, printer);
      });
    }
  }

  // updatePrintStateOnce() {
  //   Iterable<PrinterSetting> allMachines = _machineService.fetchAll();
  //   _logger.i('Updating PrintState once for BG task?');
  //   for (PrinterSetting setting in allMachines) {
  //     WebSocketWrapper websocket = setting.websocket;
  //     bool connection = websocket.ensureConnection();
  //
  //     _logger.i(
  //         'WS-Connection for ${setting.name} was ${connection ? 'OPEN' : 'CLOSED -  Trying to open again'}');
  //   }
  // }

  onMachineAdded(PrinterSetting setting) {
    _printerStreamMap[setting.uuid] = setting.printerService.printerStream
        .listen((value) => _onPrinterChanged(setting, value));
  }

  onMachineRemoved(PrinterSetting setting) {
    _printerStreamMap.remove(setting.uuid)?.cancel();
  }

  Future<void> _onPrinterChanged(
      PrinterSetting printerSetting, Printer printer) async {
    PrintState newState = printer.print.state;
    PrintState? oldState = printerSetting.lastPrintState;
    if (oldState == null) {
      printerSetting.lastPrintState = newState;
      _logger.i(
          'Printer ${printerSetting.uuid} (${printerSetting.name}) got initialized for notifications');
      _removePrintProgressNotification();
    } else {
      if (newState != oldState) {
        printerSetting.lastPrintState = newState;
        _logger.i('Print state transition $oldState -> $newState');
        _onPrintStateTransition(printerSetting, printer);
      }
    }
    if (newState == PrintState.printing)
      _updatePrintProgressNotification(printerSetting, printer,
          (printer.virtualSdCard.progress * 100).floor());
    await printerSetting.save();
  }

  Future<void> _onPrintStateTransition(
      PrinterSetting printerSetting, Printer printer) async {
    switch (printer.print.state) {
      case PrintState.standby:
        await _removePrintProgressNotification();
        break;
      case PrintState.printing:
        await _notifyAPI.createNotification(
            content: NotificationContent(
          id: 1,
          channelKey: 'printStatusUpdate_channel',
          title: 'Print state of ${printerSetting.name} changed!',
          body: 'Printer started to print file: "${printer.print.filename}"',
          notificationLayout: NotificationLayout.BigText,
        ));

        break;
      case PrintState.paused:
        // TODO: Handle this case.
        break;
      case PrintState.complete:
        await _notifyAPI.createNotification(
            content: NotificationContent(
          id: 1,
          channelKey: 'printStatusUpdate_channel',
          title: 'Print state of ${printerSetting.name} changed!',
          body: 'Printer finished printing: "${printer.print.filename}"',
          notificationLayout: NotificationLayout.BigText,
        ));

        await _removePrintProgressNotification();
        break;
      case PrintState.error:
        await _notifyAPI.createNotification(
            content: NotificationContent(
                id: 1,
                channelKey: 'printStatusUpdate_channel',
                title: 'Print state of ${printerSetting.name} changed!',
                body: 'Error while printing file: "${printer.print.filename}"',
                notificationLayout: NotificationLayout.BigText,
                color: Colors.red));
        await _removePrintProgressNotification();
        break;
    }
  }

  Future<void> _removePrintProgressNotification() => _notifyAPI.dismiss(2);

  Future<void> _updatePrintProgressNotification(
      PrinterSetting printerSetting, Printer printer,
      [int progress = 0]) async {
    if (printerSetting.lastPrintProgress == progress) return;
    printerSetting.lastPrintProgress = progress;
    var eta =
        (printer.eta != null) ? DateFormat.Hm().format(printer.eta!) : '--:--';

    await _notifyAPI.createNotification(
        content: NotificationContent(
            id: 2,
            channelKey: 'printStatusProgress_channel',
            title: 'Print progress of ${printerSetting.name}',
            body: 'ETA:$eta $progress%',
            notificationLayout: NotificationLayout.ProgressBar,
            locked: true,
            progress: progress));
  }

  dispose() {
    _printerStreamMap.values.forEach((element) => element.cancel());
    _actionStreamListen?.cancel();
  }
}
