import 'package:flutter/material.dart';
import 'package:mobileraker/data/dto/server/klipper.dart';
import 'package:mobileraker/ui/common/mixins/machine_multi_stream_view_model.dart';
import 'package:stacked/stacked.dart';

mixin KlippyMultiStreamViewModel on MachineMultiStreamViewModel {
  @protected
  static const KlippyDataStreamKey = 'cKlippy';

  bool get isKlippyInstanceReady => dataReady(KlippyDataStreamKey);

  KlipperInstance get klippyInstance => dataMap![KlippyDataStreamKey];

  @override
  Map<String, StreamData> get streamsMap {
    Map<String, StreamData> parentMap = super.streamsMap;

    return {
      ...parentMap,
      if (this.isMachineAvailable)
        KlippyDataStreamKey:
            StreamData<KlipperInstance>(klippyService.klipperStream),
    };
  }
}
