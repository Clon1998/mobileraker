/*
 * Copyright (c) 2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/dto/files/folder.dart';
import 'package:common/data/dto/files/gcode_file.dart';
import 'package:common/data/dto/files/remote_file_mixin.dart';
import 'package:common/data/dto/job_queue/job_queue_status.dart';
import 'package:common/service/moonraker/file_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:hooks_riverpod/misc.dart' show Override;
import 'package:mobileraker/routing/app_router.dart';
import 'package:mobileraker/ui/screens/files/file_manager_page.dart';
import 'package:mobileraker_pro/job_queue/service/job_queue_service.dart';
import 'package:test_support/test_support.dart';

const _placeholder = 'Select a file to see its details';

void main() {
  setUpWidgetTests();

  final machine = Fixtures.machine();
  final benchy = Fixtures.gcode('benchy.gcode');
  final cube = Fixtures.gcode('cube.gcode', estimatedTime: 1200);

  // The files the fake Moonraker reports per folder; tests may change it and invalidate the provider.
  late Map<String, List<RemoteFile>> filesByPath;

  setUp(() {
    filesByPath = {
      'gcodes': [Fixtures.folder('calibration'), benchy, cube],
      'gcodes/calibration': [Fixtures.gcode('first_layer.gcode', parentPath: 'gcodes/calibration')],
      'config': [Fixtures.gcode('printer.cfg', parentPath: 'config')],
    };
  });

  List<Override> overrides() => [
    ...connectedMachineOverrides(machine),
    ...remoteConfigOverrides(),
    jobQueueProvider(machine.uuid).overrideWithValue(AsyncData(JobQueueStatus(queueState: QueueState.ready))),
    moonrakerFolderContentProvider.overrideWith((ref, args) {
      final path = args.$2;
      final content = filesByPath[path] ?? [];
      return FolderContentWrapper(path, content.whereType<Folder>().toList(), content.where((f) => f is! Folder).toList());
    }),
  ];

  GoRouter router(String path) => GoRouter(
    initialLocation: '/files/$path',
    routes: [
      GoRoute(
        path: '/files/:path',
        name: AppRoute.fileManager_explorer.name,
        builder: (_, state) => FileManagerPage(filePath: state.pathParameters['path']!),
        routes: [
          GoRoute(
            path: 'details',
            name: AppRoute.fileManager_exlorer_gcodeDetail.name,
            builder: (_, state) => Scaffold(body: Text('Details page of ${(state.extra as GCodeFile).name}')),
          ),
        ],
      ),
    ],
  );

  Future<void> pumpFiles(WidgetTester tester, {required TestDevice device, String path = 'gcodes'}) async {
    await tester.pumpRouterApp(router(path), device: device, overrides: overrides());
    await tester.pumpAndSettle();
  }

  Future<void> tapFile(WidgetTester tester, String name) async {
    await tester.tap(find.text(name).first);
    await tester.pumpAndSettle();
  }

  /// Whether the list tile of [name] has the pane's highlight (primary at 12 %). The list comes before the pane, which
  /// shows the name too.
  bool isHighlighted(WidgetTester tester, String name) {
    final tileText = find.text(name).first;
    final highlight = Theme.of(tester.element(tileText)).colorScheme.primary.withValues(alpha: 0.12);
    return tester
        .widgetList<Material>(find.ancestor(of: tileText, matching: find.byType(Material)))
        .any((m) => m.color == highlight);
  }

  /// The "Print" button only exists on the details.
  final detailsPrintButton = find.text('Print');

  group('phone', () {
    testWidgets('shows only the list; tapping a G-code file opens its details page', (tester) async {
      await pumpFiles(tester, device: TestDevice.phone);

      expect(find.text('benchy.gcode'), findsOneWidget);
      expect(find.text(_placeholder), findsNothing);

      await tapFile(tester, 'benchy.gcode');

      expect(find.text('Details page of benchy.gcode'), findsOneWidget);
    });

    testWidgets('tapping a folder opens it', (tester) async {
      await pumpFiles(tester, device: TestDevice.phone);

      await tapFile(tester, 'calibration');

      expect(find.text('first_layer.gcode'), findsOneWidget);
    });
  });

  group('list-detail', () {
    testWidgets('is used from 720 wide, below that only the list', (tester) async {
      await pumpFiles(tester, device: TestDevice.sized(719, 900));
      expect(find.text(_placeholder), findsNothing);

      await pumpFiles(tester, device: TestDevice.sized(720, 900));
      expect(find.text(_placeholder), findsOneWidget);
    });

    testWidgets('the list is at most 400 wide', (tester) async {
      await pumpFiles(tester, device: TestDevice.tablet);

      expect(tester.getSize(find.byType(VerticalDivider)).height, greaterThan(0));
      expect(tester.getTopLeft(find.byType(VerticalDivider)).dx, 400);
    });

    testWidgets('tapping a G-code file shows it in the pane next to the list and highlights it', (tester) async {
      await pumpFiles(tester, device: TestDevice.tablet);
      expect(isHighlighted(tester, 'benchy.gcode'), isFalse);

      await tapFile(tester, 'benchy.gcode');

      expect(find.text('Details page of benchy.gcode'), findsNothing, reason: 'no page is pushed');
      expect(find.text(_placeholder), findsNothing);
      expect(detailsPrintButton, findsOneWidget);
      expect(find.text('gcodes/benchy.gcode'), findsOneWidget);
      expect(find.text('cube.gcode'), findsOneWidget, reason: 'the list stays visible');
      expect(isHighlighted(tester, 'benchy.gcode'), isTrue);
    });

    testWidgets('tapping another file switches the pane and the highlight', (tester) async {
      await pumpFiles(tester, device: TestDevice.tablet);
      await tapFile(tester, 'benchy.gcode');

      await tapFile(tester, 'cube.gcode');

      expect(find.text('gcodes/cube.gcode'), findsOneWidget);
      expect(find.text('gcodes/benchy.gcode'), findsNothing);
      expect(isHighlighted(tester, 'cube.gcode'), isTrue);
      expect(isHighlighted(tester, 'benchy.gcode'), isFalse);
    });

    testWidgets('the pane goes back to the placeholder when the shown file disappears', (tester) async {
      await pumpFiles(tester, device: TestDevice.tablet);
      await tapFile(tester, 'benchy.gcode');

      filesByPath['gcodes'] = [cube];
      tester.container(of: find.byType(MaterialApp)).invalidate(moonrakerFolderContentProvider);
      await tester.pumpAndSettle();

      expect(find.text(_placeholder), findsOneWidget);
      expect(detailsPrintButton, findsNothing);
    });

    testWidgets('folders still open as their own page', (tester) async {
      await pumpFiles(tester, device: TestDevice.tablet);

      await tapFile(tester, 'calibration');

      expect(find.text('first_layer.gcode'), findsOneWidget);
    });

    testWidgets('is not used outside of the G-code folders', (tester) async {
      await pumpFiles(tester, device: TestDevice.tablet, path: 'config');

      expect(find.text('printer.cfg'), findsOneWidget);
      expect(find.text(_placeholder), findsNothing);
    });
  });
}
