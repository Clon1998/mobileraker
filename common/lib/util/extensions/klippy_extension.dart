/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:easy_localization/easy_localization.dart';

import '../../data/dto/server/klipper.dart';

extension UiKlippy on KlipperInstance {
  String get statusMessage {
    if (!klippyConnected) {
      return tr('klipper_state.not_connected');
    }

    return klippyStateMessage ?? tr('Klipper @.lower:${klippyState.name}');
  }
}
