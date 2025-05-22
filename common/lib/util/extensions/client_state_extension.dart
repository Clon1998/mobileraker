/*
 * Copyright (c) 2025. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/network/json_rpc_client.dart';
import 'package:easy_localization/easy_localization.dart';

extension ClientStateExtension on ClientState {
  String get displayName {
    return tr('client_state.$name');
  }
}
