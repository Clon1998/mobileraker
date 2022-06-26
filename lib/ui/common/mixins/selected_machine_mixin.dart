import 'package:flutter/widgets.dart';
import 'package:mobileraker/app/app_setup.locator.dart';
import 'package:mobileraker/app/app_setup.logger.dart';
import 'package:mobileraker/data/model/hive/machine.dart';
import 'package:mobileraker/service/moonraker/file_service.dart';
import 'package:mobileraker/service/moonraker/klippy_service.dart';
import 'package:mobileraker/service/moonraker/printer_service.dart';
import 'package:mobileraker/service/selected_machine_service.dart';

import 'package:stacked/stacked.dart';

mixin SelectedMachineMixin on MultipleStreamViewModel {
  final _logger = getLogger('SelectedMachineMultiStreamViewModel');
  @protected
  static const SelectedMachineStreamKey = 'selMachine';
  final _selectedMachineService = locator<SelectedMachineService>();

  Machine? _last;
  int? _lastHash; // Since i am not using immutables _last is kinda meh,,,

  bool get isSelectedMachineReady => _last != null;

  Machine? get selectedMachine => _last;

  @protected
  PrinterService get printerService => selectedMachine!.printerService;

  @protected
  KlippyService get klippyService => selectedMachine!.klippyService;

  @protected
  FileService get fileService => selectedMachine!.fileService;

  @override
  Map<String, StreamData> get streamsMap {
    return {
      SelectedMachineStreamKey:
          StreamData<Machine?>(_selectedMachineService.selectedMachine),
    };
  }

  @override
  initialise() {
    /// Id prefer to do it completely via the stream...
    /// However since the lib fucks up the data its better to have a value
    /// already available. Prevents views to render a bit to late.
    /// E.g. FileView to GcodeDetailView's transition
    _last = _selectedMachineService.selectedMachine.valueOrNull;
    _lastHash = _last.hashCode;
    super.initialise();
  }

  @override
  onData(String key, data) {
    super.onData(key, data);
    switch (key) {
      case SelectedMachineStreamKey:
        if (_lastHash != data.hashCode) {
          _logger.wtf(('message'));
          _last = data;
          _lastHash = data.hashCode;
          notifySourceChanged(clearOldData: false);
        }
        break;
      default:
        // Do nothing
        break;
    }
  }
}
