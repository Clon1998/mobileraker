/*
 * Copyright (c) 2023-2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/repository/machine_settings_repository.dart';
import 'package:common/network/json_rpc_client.dart';
import 'package:common/service/machine_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isMissingMachineSettingsError', () {
    test('recognizes the "key missing in an existing namespace" variant', () {
      final error = JRpcError(
        -32601,
        "Key '${MachineSettingsRepository.key}' in namespace '${MachineSettingsRepository.namespace}' not found",
      );

      expect(isMissingMachineSettingsError(error), isTrue);
    });

    test('recognizes the "namespace never created" variant (fresh/older-Moonraker machines)', () {
      // This is what LMDB-backed Moonraker instances (pre Dec-2023, still shipped on some vendor
      // forks such as the Creality Sonic Pad) raise for a machine that never wrote anything under
      // the namespace at all - as opposed to the "Key '...' in namespace '...'" variant above, which
      // requires the namespace to already exist.
      final error = JRpcError(
        -32601,
        "Namespace '${MachineSettingsRepository.namespace}' not found",
      );

      expect(isMissingMachineSettingsError(error), isTrue);
    });

    test('does not swallow unrelated JRpcErrors', () {
      final error = JRpcError(-32603, 'Internal error');

      expect(isMissingMachineSettingsError(error), isFalse);
    });

    test('does not match a "not found" error for a different namespace', () {
      final error = JRpcError(-32601, "Namespace 'some_other_component' not found");

      expect(isMissingMachineSettingsError(error), isFalse);
    });
  });
}
