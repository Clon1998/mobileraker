/*
 * Copyright (c) 2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/dto/server/sudo_info.dart';
import 'package:common/data/dto/update_manager/updater_info.dart';
import 'package:common/service/ui/dialog_service_interface.dart';
import 'package:common/service/ui/snackbar_service_interface.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/service/ui/dialog_service_impl.dart';
import 'package:mobileraker/ui/components/dialog/text_input/text_input_dialog.dart';
import 'package:common/service/moonraker/update_manager_service.dart';
import 'package:common/service/payment_service.dart';
import 'package:common/service/ui/bottom_sheet_service_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobileraker/service/ui/bottom_sheet_service_impl.dart';
import 'package:test_support/test_support.dart';

import '../../../../helpers/sheet_router.dart';

class _FakeProgress extends UpdateProgress {
  _FakeProgress(this.initial);

  final UpdateProgressState initial;

  @override
  UpdateProgressState build(String machineUUID) => initial;
}

class _FakeSudo extends SudoRequest {
  _FakeSudo(this.info);

  final SudoInfo info;

  @override
  Future<SudoInfo> build(String machineUUID) async => info;
}

void main() {
  setUpWidgetTests();

  const uuid = 'm1';
  const crowsnest = UpdaterInfo(
    name: 'crowsnest',
    configuredType: UpdaterType.gitRepo,
    version: 'v4.1.10',
    isDirty: true,
    isValid: false,
  );

  group('UpdateRecoverBottomSheet', () {
    Future<Future<BottomSheetResult>> open(WidgetTester tester, {bool supporter = true, UpdaterInfo? updater}) =>
        tester.openSheet(
          BottomSheetConfig(type: SheetType.updateRecover, data: updater ?? crowsnest),
          overrides: [isSupporterProvider.overrideWithValue(supporter)],
        );

    testWidgets('a supporter picks the soft recover, which is recommended for a dirty repo', (tester) async {
      final result = await open(tester);

      expect(find.text('Fix Crowsnest'), findsOneWidget);
      expect(find.text('Recommended'), findsOneWidget);
      expect(find.byIcon(Icons.lock_outline), findsNothing);

      await tester.tap(find.text('Soft recover'));
      await tester.pumpAndSettle();

      final res = await result;
      expect(res.confirmed, isTrue);
      expect(res.data, isFalse);
    });

    testWidgets('a supporter picks the hard recover', (tester) async {
      final result = await open(tester, updater: crowsnest.copyWith(corrupt: true));

      await tester.tap(find.text('Hard recover'));
      await tester.pumpAndSettle();

      final res = await result;
      expect(res.confirmed, isTrue);
      expect(res.data, isTrue);
    });

    testWidgets('the options are locked for free users', (tester) async {
      final result = await open(tester, supporter: false);

      expect(find.byIcon(Icons.lock_outline), findsNWidgets(2));
      expect(find.textContaining('are for Supporters'), findsOneWidget);

      await tester.tap(find.text('Soft recover'));
      await tester.pumpAndSettle();
      expect(find.text('Soft recover'), findsOneWidget, reason: 'still open');

      // Like the other sheets it is dismissed by swiping it down or tapping outside.
      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();
      expect((await result).confirmed, isFalse);
    });
  });

  group('UpdateLogBottomSheet', () {
    late FakeDialogService dialogs;
    setUp(() => dialogs = FakeDialogService());

    UpdateLogEntry entry(String application, String message) =>
        UpdateLogEntry(time: DateTime(2026, 11, 11, 21, 34, 2), application: application, message: message);

    Future<void> open(WidgetTester tester, UpdateProgressState state, {SudoInfo sudo = const SudoInfo()}) =>
        tester.openSheet(
      BottomSheetConfig(type: SheetType.updateLog, data: uuid),
      overrides: [
        updateProgressProvider(uuid).overrideWith(() => _FakeProgress(state)),
        sudoRequestProvider(uuid).overrideWith(() => _FakeSudo(sudo)),
        dialogServiceProvider.overrideWithValue(dialogs),
        snackBarServiceProvider.overrideWithValue(FakeSnackBarService()),
      ],
      // The spinner never settles.
      settle: !state.isRunning,
    );

    testWidgets('shows the steps and the log of a running update', (tester) async {
      await open(
        tester,
        UpdateProgressState(
          phase: UpdatePhase.running,
          steps: const ['system', 'klipper', 'moonraker'],
          current: 'klipper',
          log: [entry('system', 'Updating packages…'), entry('klipper', 'Git Repo klipper: Fetching updates')],
        ),
      );

      expect(find.text('Updating Klipper'), findsOneWidget);
      expect(find.text('2 of 3'), findsOneWidget);
      expect(find.text('System packages'), findsOneWidget);
      expect(find.textContaining('Git Repo klipper: Fetching updates', findRichText: true), findsOneWidget);
      expect(find.text('You can close this. The update keeps running on the printer.'), findsOneWidget);
      expect(find.text('Hide'), findsOneWidget);
    });

    testWidgets('asks for the sudo password if Moonraker waits for it', (tester) async {
      await open(
        tester,
        const UpdateProgressState(phase: UpdatePhase.running, steps: ['moonraker'], current: 'moonraker'),
        sudo: const SudoInfo(
          linuxUser: 'pi',
          sudoRequested: true,
          requestMessages: ["Sudo password required to update Moonraker's systemd service."],
        ),
      );

      expect(find.text("Sudo password required to update Moonraker's systemd service."), findsOneWidget);
      expect(find.text('You can close this. The update keeps running on the printer.'), findsNothing);

      await tester.tap(find.text('Enter'));
      await tester.pump();

      final request = dialogs.requests.single;
      expect(request.type, DialogType.textInput);
      final args = request.data as TextInputDialogArguments;
      expect(args.obscureText, isTrue);
      expect(args.labelText, 'Password of "pi"');
    });

    testWidgets('a finished update can be closed', (tester) async {
      await open(
        tester,
        UpdateProgressState(
          phase: UpdatePhase.finished,
          steps: const ['klipper'],
          current: 'klipper',
          log: [entry('klipper', 'Update Finished…')],
        ),
      );

      expect(find.text('Update finished'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      expect(find.text('You can close this. The update keeps running on the printer.'), findsNothing);

      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(find.text('Update finished'), findsNothing);
    });

    testWidgets('a failed recover says so and waits for the first message without a log', (tester) async {
      await open(
        tester,
        const UpdateProgressState(
          phase: UpdatePhase.failed,
          action: UpdateAction.recover,
          steps: ['crowsnest'],
          current: 'crowsnest',
        ),
      );

      expect(find.text('Recovery failed'), findsOneWidget);
      expect(find.byIcon(Icons.error), findsOneWidget);
      expect(find.text('Waiting for Moonraker…'), findsOneWidget);
      expect(tester.widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Copy log')).onPressed, isNull);
    });
  });
}
