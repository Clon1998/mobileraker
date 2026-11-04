/*
 * Copyright (c) 2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/dto/config/config_file.dart';
import 'package:common/data/dto/config/config_stepper.dart';
import 'package:common/data/dto/machine/bed_mesh/bed_mesh.dart';
import 'package:common/data/dto/machine/bed_mesh/bed_mesh_profile.dart';
import 'package:common/data/dto/server/klipper.dart';
import 'package:common/service/setting_service.dart';
import 'package:common/service/ui/bottom_sheet_service_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobileraker/ui/components/bottomsheet/selection_bottom_sheet.dart';
import 'package:mobileraker/ui/screens/dashboard/components/bed_mesh_card.dart';
import 'package:test_support/test_support.dart';

void main() {
  setUpWidgetTests();

  final machine = Fixtures.machine();
  late FakeJsonRpcClient rpc;
  late FakeBottomSheetService sheets;

  const params = BedMeshParams(
    minX: 10,
    maxX: 290,
    minY: 10,
    maxY: 290,
    xCount: 3,
    yCount: 3,
    meshXPPS: 2,
    meshYPPS: 2,
    algo: 'bicubic',
    tension: 0.2,
  );

  const matrix = [
    [-0.1, 0.0, 0.1],
    [-0.05, 0.0, 0.05],
    [0.0, 0.1, 0.2],
  ];

  final mesh = BedMesh(
    profileName: 'default',
    meshMin: (10, 10),
    meshMax: (290, 290),
    probedMatrix: matrix,
    meshMatrix: matrix,
    profiles: const [
      BedMeshProfile(name: 'default', meshParams: params),
      BedMeshProfile(name: 'hot_pei', meshParams: params),
    ],
  );

  ConfigFile cartesian() => ConfigFile()
    ..steppers = {
      'x': const ConfigStepper(name: 'x', positionMax: 300),
      'y': const ConfigStepper(name: 'y', positionMax: 300),
    };

  Future<void> pumpCard(
    WidgetTester tester, {
    BedMesh? bedMesh,
    bool noMesh = false,
    ConfigFile? config,
    KlipperState klippy = KlipperState.ready,
    BottomSheetResult? sheetResult,
  }) async {
    rpc = FakeJsonRpcClient();
    sheets = FakeBottomSheetService(result: sheetResult);
    await tester.pumpApp(
      SingleChildScrollView(child: BedMeshCard(machineUUID: machine.uuid)),
      overrides: [
        ...uiServiceOverrides(bottomSheets: sheets),
        ...connectedMachineOverrides(
          machine,
          client: rpc,
          klipper: Fixtures.klipper(state: klippy),
          printer: Fixtures.printer().copyWith(
            bedMesh: noMesh ? null : (bedMesh ?? mesh),
            configFile: config ?? cartesian(),
          ),
        ),
      ],
    );
    await tester.pumpAndSettle();
  }

  List<String> scripts() => [
    for (final c in rpc.calls)
      if (c.method == 'printer.gcode.script') c.params['script'] as String,
  ];

  testWidgets('shows the active profile, grid size and range', (tester) async {
    await pumpCard(tester);

    expect(find.text('Bed Mesh'), findsOneWidget);
    expect(find.text('default'), findsOneWidget);
    expect(find.text('3x3'), findsOneWidget);
    expect(find.text('0.300mm'), findsOneWidget);
    expect(find.byIcon(Icons.grid_on), findsOneWidget, reason: 'mesh matrix by default');
    await tester.unmountApp();
  });

  testWidgets('is hidden when Klipper has no bed mesh', (tester) async {
    await pumpCard(tester, noMesh: true);

    expect(find.byType(Card), findsNothing);
    await tester.unmountApp();
  });

  testWidgets('remembers whether the machine has a bed mesh', (tester) async {
    await pumpCard(tester);

    expect(testSettingsBox.get(CompositeKey.keyWithString(UiKeys.hadMeshView, machine.uuid).key), isTrue);
    await tester.unmountApp();
  });

  testWidgets('without X/Y steppers it explains that the mesh can not be rendered', (tester) async {
    await pumpCard(tester, config: ConfigFile());

    expect(find.textContaining('Rendering of the bed mesh'), findsOneWidget);
    await tester.unmountApp();
  });

  testWidgets('the mode icon switches to the probed matrix and is remembered', (tester) async {
    await pumpCard(tester);

    await tester.tap(find.byIcon(Icons.grid_on));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.blur_on), findsOneWidget);
    expect(testSettingsBox.get(CompositeKey.keyWithString(UtilityKeys.meshViewMode, machine.uuid).key), isTrue);
    await tester.unmountApp();
  });

  testWidgets('profiles offers "no mesh" and every profile, the active one selected', (tester) async {
    await pumpCard(tester);

    await tester.tap(find.text('Profiles'));
    await tester.pumpAndSettle();

    final options = await (sheets.shown.single.data as SelectionBottomSheetArgs).options;
    expect(options.map((o) => o.label), ['No Mesh', 'default', 'hot_pei']);
    expect(options.where((o) => o.selected).map((o) => o.label), ['default']);
    await tester.unmountApp();
  });

  testWidgets('picking a profile loads it', (tester) async {
    await pumpCard(tester, sheetResult: BottomSheetResult.confirmed(mesh.profiles[1]));

    await tester.tap(find.text('Profiles'));
    await tester.pumpAndSettle();

    expect(scripts(), ['BED_MESH_PROFILE LOAD="hot_pei"']);
    await tester.unmountApp();
  });

  testWidgets('picking "no mesh" clears the loaded profile', (tester) async {
    await pumpCard(tester, sheetResult: BottomSheetResult.confirmed(null));

    await tester.tap(find.text('Profiles'));
    await tester.pumpAndSettle();

    expect(scripts(), ['BED_MESH_CLEAR']);
    await tester.unmountApp();
  });

  testWidgets('profiles are disabled while Klipper can not receive commands', (tester) async {
    await pumpCard(tester, klippy: KlipperState.shutdown);

    final button = tester.widget<ButtonStyleButton>(
      find.ancestor(of: find.text('Profiles'), matching: find.bySubtype<ButtonStyleButton>()),
    );
    expect(button.onPressed, isNull);
    await tester.unmountApp();
  });
}
