/*
 * Copyright (c) 2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/dto/files/folder.dart';
import 'package:common/data/dto/files/gcode_file.dart';
import 'package:common/data/dto/files/remote_file_mixin.dart';
import 'package:common/data/dto/job_queue/job_queue_entry.dart';
import 'package:common/data/dto/job_queue/job_queue_status.dart';
import 'package:common/data/enums/file_action_sheet_action_enum.dart';
import 'package:common/data/enums/sort_kind_enum.dart';
import 'package:common/data/enums/sort_mode_enum.dart';
import 'package:common/data/model/sort_configuration.dart';
import 'package:common/service/machine_service.dart';
import 'package:common/service/moonraker/file_service.dart';
import 'package:common/service/payment_service.dart';
import 'package:common/service/ui/bottom_sheet_service_interface.dart';
import 'package:common/service/ui/dialog_service_interface.dart';
import 'package:common/service/ui/snackbar_service_interface.dart';
import 'package:common/service/ui/theme_service.dart';
import 'package:common/ui/components/nav/nav_rail_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:hooks_riverpod/misc.dart' show Override;
import 'package:mobileraker/routing/app_router.dart';
import 'package:mobileraker/service/ui/bottom_sheet_service_impl.dart';
import 'package:mobileraker/ui/components/bottomsheet/action_bottom_sheet.dart';
import 'package:mobileraker/ui/components/bottomsheet/sort_mode_bottom_sheet.dart';
import 'package:mobileraker/ui/components/dialog/text_input/text_input_dialog.dart';
import 'package:mobileraker/ui/screens/files/components/sorted_file_list_header.dart';
import 'package:mobileraker/ui/screens/files/file_manager_page.dart';
import 'package:mobileraker_pro/job_queue/service/job_queue_service.dart';
import 'package:mobileraker_pro/service/ui/pro_sheet_type.dart';
import 'package:test_support/test_support.dart';

/// The flows of the file manager that go through the bottom sheet and dialog services and end in a call to Moonraker.
void main() {
  setUpWidgetTests();

  final machine = Fixtures.machine();
  final benchy = Fixtures.gcode('benchy.gcode');
  final cube = Fixtures.gcode('cube.gcode', estimatedTime: 1200);

  late FakeJsonRpcClient rpc;
  late FakeBottomSheetService sheets;
  late FakeDialogService dialogs;
  late FakeSnackBarService snackBars;
  late List<SortConfiguration> requestedSorts;
  late JobQueueStatus queue;

  Map<String, dynamic> actionResponse(String action, dynamic params) => {
    'action': action,
    'item': {'path': (params as Map)['path'] ?? params['dest'], 'root': 'gcodes'},
  };

  setUp(() {
    rpc = FakeJsonRpcClient(
      responses: {
        'server.files.delete_file': (p) => actionResponse('delete_file', p),
        'server.files.delete_directory': (p) => actionResponse('delete_dir', p),
        'server.files.move': (p) => actionResponse('move_file', p),
        'server.files.post_directory': (p) => actionResponse('create_dir', p),
        'server.job_queue.status': (_) => {'queued_jobs': [], 'queue_state': 'ready'},
      },
    );
    sheets = FakeBottomSheetService();
    dialogs = FakeDialogService();
    snackBars = FakeSnackBarService();
    requestedSorts = [];
    queue = JobQueueStatus(queueState: QueueState.ready);
  });

  List<Override> overrides() => [
    ...connectedMachineOverrides(machine, client: rpc),
    ...remoteConfigOverrides(),
    ...uiServiceOverrides(snackBars: snackBars, dialogs: dialogs, bottomSheets: sheets),
    allMachinesProvider.overrideWith(() => FakeAllMachines([machine])),
    isSupporterProvider.overrideWithValue(false),
    // The navigation rail of larger layouts shows the app's logo.
    activeThemeProvider.overrideWithValue(AsyncData(ThemeModel(testThemePacks().first, ThemeMode.light))),
    jobQueueProvider(machine.uuid).overrideWithValue(AsyncData(queue)),
    moonrakerFolderContentProvider.overrideWith((ref, args) {
      requestedSorts.add(args.$3);
      final List<RemoteFile> content = switch (args.$2) {
        'gcodes' => [Fixtures.folder('calibration'), benchy, cube],
        _ => [],
      };
      return FolderContentWrapper(
        args.$2,
        content.whereType<Folder>().toList(),
        content.where((f) => f is! Folder).toList(),
      );
    }),
  ];

  // In the shell like in the app: on larger layouts the shell shows the navigation rail.
  GoRouter router() => GoRouter(
    initialLocation: '/files/gcodes',
    routes: [
      ShellRoute(
        builder: (_, _, child) => NavigationRailShell(child: child),
        routes: [
          GoRoute(
            path: '/files/:path',
            name: AppRoute.fileManager_explorer.name,
            builder: (_, state) => FileManagerPage(filePath: state.pathParameters['path']!),
            routes: [
              GoRoute(
                path: 'details',
                name: AppRoute.fileManager_exlorer_gcodeDetail.name,
                builder: (_, state) => Text('Details page of ${(state.extra as GCodeFile).name}'),
              ),
              GoRoute(
                path: 'search',
                name: AppRoute.fileManager_exlorer_search.name,
                builder: (_, state) =>
                    Text('Search ${state.pathParameters['path']} of ${state.uri.queryParameters['machineUUID']}'),
              ),
            ],
          ),
        ],
      ),
    ],
  );

  Future<void> pumpFiles(WidgetTester tester, {TestDevice device = TestDevice.phone}) async {
    await tester.pumpRouterApp(router(), device: device, overrides: overrides());
    await tester.pumpAndSettle();
  }

  /// Lets the action sheet "close" (the services wait for its animation) and the action run.
  Future<void> settleAction(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
  }

  Future<void> openFileActions(WidgetTester tester, GCodeFile file) async {
    await tester.tap(find.byKey(Key('file_item_more_button_${file.hashCode}')));
    await settleAction(tester);
  }

  Future<void> tapAddFab(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.add));
    await settleAction(tester);
  }

  final sortButton = find.descendant(of: find.byType(SortedFileListHeader), matching: find.byType(TextButton));

  TextInputDialogArguments textInputArgs() => dialogs.requests.single.data as TextInputDialogArguments;

  group('sort', () {
    testWidgets('the sort button offers the G-code sort modes with the active one', (tester) async {
      await pumpFiles(tester);

      await tester.tap(sortButton);
      await tester.pumpAndSettle();

      final config = sheets.shown.single;
      expect(config.type, SheetType.sortMode);
      final args = config.data as SortModeSheetArgs;
      expect(args.toShow, SortMode.availableForGCodes());
      expect(args.active, requestedSorts.last);
    });

    testWidgets('picking a sort mode shows it and loads the folder with it', (tester) async {
      sheets.result = BottomSheetResult.confirmed(const SortConfiguration(SortMode.size, SortKind.ascending));
      await pumpFiles(tester);

      await tester.tap(sortButton);
      await tester.pumpAndSettle();

      expect(find.text('Size'), findsOneWidget);
      expect(requestedSorts.last, const SortConfiguration(SortMode.size, SortKind.ascending));
    });

    testWidgets('the picked sort mode is kept for the next visit', (tester) async {
      sheets.result = BottomSheetResult.confirmed(const SortConfiguration(SortMode.lastPrinted, SortKind.descending));
      await pumpFiles(tester);
      await tester.tap(sortButton);
      await tester.pumpAndSettle();
      await tester.unmountApp();

      requestedSorts.clear();
      sheets.result = BottomSheetResult.dismissed();
      await pumpFiles(tester);

      expect(find.text('Last printed'), findsOneWidget);
      expect(requestedSorts.last, const SortConfiguration(SortMode.lastPrinted, SortKind.descending));
    });

    testWidgets('dismissing the sort sheet keeps the sort mode', (tester) async {
      await pumpFiles(tester);
      final before = requestedSorts.last;

      await tester.tap(sortButton);
      await tester.pumpAndSettle();

      expect(find.text('Name'), findsOneWidget);
      expect(requestedSorts.last, before);
    });
  });

  testWidgets('search opens the search page of the folder', (tester) async {
    await pumpFiles(tester);

    await tester.tap(find.byTooltip('Search in folder'));
    await tester.pumpAndSettle();

    expect(find.text('Search gcodes of ${machine.uuid}'), findsOneWidget);
  });

  group('file actions', () {
    testWidgets('delete asks first, then deletes the file', (tester) async {
      sheets.result = BottomSheetResult.confirmed(FileSheetAction.delete);
      dialogs.response = DialogResponse.confirmed();
      await pumpFiles(tester);

      await openFileActions(tester, benchy);

      expect(sheets.shown.single.type, SheetType.actions);
      expect(dialogs.confirms, hasLength(1));
      expect(rpc.calls.where((c) => c.method == 'server.files.delete_file').single.params, {
        'path': 'gcodes/benchy.gcode',
      });
    });

    testWidgets('delete does nothing when the confirmation is dismissed', (tester) async {
      sheets.result = BottomSheetResult.confirmed(FileSheetAction.delete);
      await pumpFiles(tester);

      await openFileActions(tester, benchy);

      expect(dialogs.confirms, hasLength(1));
      expect(rpc.methods, isNot(contains('server.files.delete_file')));
    });

    testWidgets('a folder is deleted with its content', (tester) async {
      sheets.result = BottomSheetResult.confirmed(FileSheetAction.delete);
      dialogs.response = DialogResponse.confirmed();
      await pumpFiles(tester);

      await tester.tap(find.byKey(Key('file_item_more_button_${Fixtures.folder('calibration').hashCode}')));
      await settleAction(tester);

      expect(rpc.calls.where((c) => c.method == 'server.files.delete_directory').single.params, {
        'path': 'gcodes/calibration',
        'force': true,
      });
    });

    testWidgets('rename asks for the name without the extension and moves the file', (tester) async {
      sheets.result = BottomSheetResult.confirmed(FileSheetAction.rename);
      dialogs.response = DialogResponse.confirmed('boat');
      await pumpFiles(tester);

      await openFileActions(tester, benchy);

      expect(textInputArgs().initialValue, 'benchy');
      expect(textInputArgs().suffixText, '.gcode');
      expect(rpc.calls.where((c) => c.method == 'server.files.move').single.params, {
        'source': 'gcodes/benchy.gcode',
        'dest': 'gcodes/boat.gcode',
      });
    });

    testWidgets('rename to the same name makes no call', (tester) async {
      sheets.result = BottomSheetResult.confirmed(FileSheetAction.rename);
      dialogs.response = DialogResponse.confirmed('benchy');
      await pumpFiles(tester);

      await openFileActions(tester, benchy);

      expect(rpc.methods, isNot(contains('server.files.move')));
    });

    testWidgets('rename rejects invalid names', (tester) async {
      sheets.result = BottomSheetResult.confirmed(FileSheetAction.rename);
      await pumpFiles(tester);

      await openFileActions(tester, benchy);

      final validator = textInputArgs().validator!;
      expect(validator(''), isNotNull);
      expect(validator('a/b'), isNotNull);
      expect(validator('boat'), isNull);
    });

    testWidgets(
      'rename rejects the name of another file in the folder',
      (tester) async {
        sheets.result = BottomSheetResult.confirmed(FileSheetAction.rename);
        await pumpFiles(tester);

        await openFileActions(tester, benchy);

        // The dialog asks for the name without ".gcode", the used names have it.
        final validator = textInputArgs().validator!;
        expect(validator('cube'), 'File name already in use', reason: 'cube.gcode exists already');
        expect(validator('benchy'), isNull, reason: 'its own name');
      },
    );
  });

  group('add button', () {
    testWidgets('offers new folder, new file and uploads', (tester) async {
      await pumpFiles(tester);

      await tapAddFab(tester);

      final args = sheets.shown.single.data as ActionBottomSheetArgs;
      expect(
        args.actions,
        containsAllInOrder([
          FileSheetAction.newFolder,
          FileSheetAction.newFile,
          FileSheetAction.uploadFile,
          FileSheetAction.uploadFiles,
        ]),
      );
    });

    testWidgets('a new folder is created in the current folder', (tester) async {
      sheets.result = BottomSheetResult.confirmed(FileSheetAction.newFolder);
      dialogs.response = DialogResponse.confirmed('prints');
      await pumpFiles(tester);

      await tapAddFab(tester);

      expect(rpc.calls.where((c) => c.method == 'server.files.post_directory').single.params, {
        'path': 'gcodes/prints',
      });
    });

    testWidgets('the new folder name can not be one that exists', (tester) async {
      sheets.result = BottomSheetResult.confirmed(FileSheetAction.newFolder);
      await pumpFiles(tester);

      await tapAddFab(tester);

      final validator = textInputArgs().validator!;
      expect(validator('calibration'), isNotNull);
      expect(validator('prints'), isNull);
      expect(rpc.methods, isNot(contains('server.files.post_directory')), reason: 'the dialog was dismissed');
    });

    testWidgets('uploads are a supporter feature', (tester) async {
      sheets.result = BottomSheetResult.confirmed(FileSheetAction.uploadFile);
      await pumpFiles(tester);

      await tapAddFab(tester);

      expect(snackBars.shown.single.type, SnackbarType.warning);
      expect(snackBars.shown.single.title, 'Supporter Only Feature');
    });
  });

  group('job queue', () {
    final queued = JobQueueStatus(
      queueState: QueueState.ready,
      queuedJobs: [
        for (final i in [1, 2])
          JobQueueEntry(filename: 'job$i.gcode', jobId: '$i', timeAdded: DateTime(2026), timeInQueue: 10),
      ],
    );
    final jobQueueAction = find.descendant(of: find.byType(AppBar), matching: find.byTooltip('Job Queue'));

    testWidgets('phone: the queue button above the add button opens the queue', (tester) async {
      queue = queued;
      await pumpFiles(tester);

      expect(jobQueueAction, findsNothing, reason: 'not in the app bar');
      expect(find.byType(FloatingActionButton), findsNWidgets(2));

      await tester.tap(find.byType(FloatingActionButton).first);
      await tester.pumpAndSettle();

      expect(sheets.shown.single.type, ProSheetType.jobQueueMenu);
    });

    testWidgets('phone: without queued jobs only the add button', (tester) async {
      await pumpFiles(tester);

      expect(find.byType(FloatingActionButton), findsOneWidget);
    });

    testWidgets('tablet: the queue is an app bar action with the number of jobs', (tester) async {
      queue = queued;
      await pumpFiles(tester, device: TestDevice.tablet);

      expect(jobQueueAction, findsOneWidget);
      expect(find.descendant(of: jobQueueAction, matching: find.text('2')), findsOneWidget);

      await tester.tap(jobQueueAction);
      await tester.pumpAndSettle();

      expect(sheets.shown.single.type, ProSheetType.jobQueueMenu);
    });

    testWidgets('tablet: without queued jobs there is no queue action', (tester) async {
      await pumpFiles(tester, device: TestDevice.tablet);

      expect(jobQueueAction, findsNothing);
    });
  });
}
