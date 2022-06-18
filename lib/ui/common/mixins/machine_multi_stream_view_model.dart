import 'package:flutter/widgets.dart';
import 'package:mobileraker/app/app_setup.locator.dart';
import 'package:mobileraker/app/app_setup.logger.dart';
import 'package:mobileraker/data/model/hive/machine.dart';
import 'package:mobileraker/service/moonraker/file_service.dart';
import 'package:mobileraker/service/moonraker/klippy_service.dart';
import 'package:mobileraker/service/moonraker/printer_service.dart';
import 'package:mobileraker/service/selected_machine_service.dart';
import 'package:mobileraker/ui/common/mixins/mixable_multi_stream_view_model.dart';
import 'package:stacked/stacked.dart';

mixin MachineMultiStreamViewModel on MixableMultiStreamViewModel {
  @protected
  static const SelectedMachineStreamKey = 'selMachine';
  final _selectedMachineService = locator<SelectedMachineService>();

  Machine? _last;

  bool get isMachineAvailable => _last != null;

  Machine? get machine => _last;

  @protected
  PrinterService get printerService => machine!.printerService;

  @protected
  KlippyService get klippyService => machine!.klippyService;

  @protected
  FileService get fileService => machine!.fileService;

  @override
  Map<String, StreamData> get streamsMap {
    return {
      SelectedMachineStreamKey:
          StreamData<Machine?>(_selectedMachineService.selectedMachine),
    };
  }

  @override
  onData(String key, data) {
    super.onData(key, data);
    switch (key) {
      case SelectedMachineStreamKey:
        if (_last != data) {
          _last = data;
          notifySourceChanged(clearOldData: false);
        }
        break;
      default:
        // Do nothing
        break;
    }
  }
}
