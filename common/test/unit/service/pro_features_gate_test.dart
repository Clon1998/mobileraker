/*
 * Copyright (c) 2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/model/hive/machine.dart';
import 'package:common/service/demo/demo_printer.dart';
import 'package:common/service/payment_service.dart';
import 'package:common/service/selected_machine_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod/riverpod.dart';

void main() {
  final realMachine = Machine(name: 'Voron', httpUri: Uri.parse('http://192.168.1.20'), uuid: 'real-printer');
  final demo = demoMachine('Demo printer');

  ProviderContainer container({required bool supporter, Machine? selected}) {
    final c = ProviderContainer(
      overrides: [
        isSupporterProvider.overrideWithValue(supporter),
        isSupporterAsyncProvider.overrideWith((ref) async => supporter),
        selectedMachineProvider.overrideWith((ref) => Stream.value(selected)),
      ],
    );
    addTearDown(c.dispose);
    // The real provider keeps itself alive, the override does not: keep it listened to.
    c.listen(selectedMachineProvider, (_, _) {});
    return c;
  }

  group('canUseProFeatures', () {
    test('non-supporters get Pro on the demo printer only', () async {
      final c = container(supporter: false, selected: demo);

      expect(c.read(canUseProFeaturesProvider(demoMachineUuid)), isTrue);
      expect(c.read(canUseProFeaturesProvider(realMachine.uuid)), isFalse);
      expect(await c.read(canUseProFeaturesAsyncProvider(demoMachineUuid).future), isTrue);
      expect(await c.read(canUseProFeaturesAsyncProvider(realMachine.uuid).future), isFalse);
    });

    test('a selected demo printer unlocks nothing on a real printer', () async {
      final c = container(supporter: false, selected: demo);
      // Let the selected machine stream emit.
      await c.read(selectedMachineProvider.future);

      expect(c.read(isDemoSelectedProvider), isTrue);
      expect(c.read(canUseProFeaturesProvider(realMachine.uuid)), isFalse);
    });

    test('supporters get Pro everywhere', () async {
      final c = container(supporter: true, selected: realMachine);

      expect(c.read(canUseProFeaturesProvider(realMachine.uuid)), isTrue);
      expect(c.read(canUseProFeaturesProvider(demoMachineUuid)), isTrue);
      expect(await c.read(canUseProFeaturesAsyncProvider(realMachine.uuid).future), isTrue);
    });
  });

  group('canUseProFeaturesOnSelected', () {
    test('follows the selected printer for non-supporters', () async {
      final onDemo = container(supporter: false, selected: demo);
      await onDemo.read(selectedMachineProvider.future);
      expect(onDemo.read(canUseProFeaturesOnSelectedProvider), isTrue);

      final onReal = container(supporter: false, selected: realMachine);
      await onReal.read(selectedMachineProvider.future);
      expect(onReal.read(canUseProFeaturesOnSelectedProvider), isFalse);
    });

    test('is always true for supporters', () async {
      final c = container(supporter: true, selected: realMachine);
      await c.read(selectedMachineProvider.future);
      expect(c.read(canUseProFeaturesOnSelectedProvider), isTrue);
    });
  });
}
