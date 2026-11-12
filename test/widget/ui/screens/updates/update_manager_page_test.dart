/*
 * Copyright (c) 2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/dto/machine/print_state_enum.dart';
import 'package:common/data/dto/update_manager/updater_info.dart';
import 'package:common/data/enums/updater_sheet_action_enum.dart';
import 'package:common/service/machine_service.dart';
import 'package:common/service/moonraker/update_manager_service.dart';
import 'package:common/service/payment_service.dart';
import 'package:common/service/ui/bottom_sheet_service_interface.dart';
import 'package:common/service/ui/dialog_service_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/routing/app_router.dart';
import 'package:mobileraker/service/ui/bottom_sheet_service_impl.dart';
import 'package:mobileraker/service/ui/dialog_service_impl.dart';
import 'package:mobileraker/ui/components/bottomsheet/action_bottom_sheet.dart';
import 'package:mobileraker/ui/components/dialog/text_input/text_input_dialog.dart';
import 'package:mobileraker/ui/screens/updates/update_manager_page.dart';
import 'package:pull_to_refresh_flutter3/pull_to_refresh_flutter3.dart' show SmartRefresher;
import 'package:test_support/test_support.dart';

void main() {
  setUpWidgetTests();

  final machine = Fixtures.machine();
  late FakeJsonRpcClient rpc;
  late FakeBottomSheetService sheets;
  late FakeDialogService dialogs;
  late FakeSnackBarService snackBars;

  Map<String, dynamic> git(String version, String remoteVersion, {bool dirty = false, String rollback = ''}) => {
    'configured_type': 'git_repo',
    'channel': 'dev',
    'version': version,
    'remote_version': remoteVersion,
    'rollback_version': rollback,
    'current_hash': 'hash-$version',
    'remote_hash': 'hash-$remoteVersion',
    'owner': 'owner',
    'repo_name': 'repo',
    'is_dirty': dirty,
    'is_valid': !dirty,
    'commits_behind': [
      if (version != remoteVersion)
        {'sha': 'abcdef1234567', 'author': 'Kevin', 'date': '1644534721', 'subject': 'stm32: Fix SPI', 'tag': null},
    ],
    'commits_behind_count': version == remoteVersion ? 0 : 16,
  };

  Map<String, dynamic> statusJson() => {
    'busy': false,
    'github_rate_limit': 60,
    'github_requests_remaining': 54,
    'version_info': {
      'system': {'configured_type': 'system', 'package_count': 23, 'package_list': ['libtiff5', 'rpi-eeprom']},
      'moonraker': git('v0.9.3-1', 'v0.9.3-1'),
      'klipper': git('v0.12.0-396', 'v0.13.0-4', rollback: 'v0.12.0-300'),
      'crowsnest': git('v4.1.10', 'v4.1.12', dirty: true),
      'mainsail': {'configured_type': 'web', 'channel': 'stable', 'version': 'v2.13.0', 'remote_version': 'v2.14.0'},
    },
  };

  Future<void> pumpPage(
    WidgetTester tester, {
    bool supporter = true,
    PrintState state = PrintState.standby,
    List<String> components = const ['update_manager'],
    Map<String, Map<String, dynamic> Function(dynamic params)> extraResponses = const {},
  }) async {
    rpc = FakeJsonRpcClient(responses: {'machine.update.status': (_) => statusJson(), ...extraResponses});
    sheets = FakeBottomSheetService();
    dialogs = FakeDialogService();
    snackBars = FakeSnackBarService();
    final router = GoRouter(
      initialLocation: '/updates',
      routes: [GoRoute(path: '/updates', name: AppRoute.updates.name, builder: (_, _) => const UpdateManagerPage())],
    );
    await tester.pumpRouterApp(
      router,
      overrides: [
        ...uiServiceOverrides(snackBars: snackBars, dialogs: dialogs, bottomSheets: sheets),
        ...remoteConfigOverrides(),
        ...connectedMachineOverrides(
          machine,
          client: rpc,
          klipper: Fixtures.klipper(components: components),
          printer: Fixtures.printer(state: state),
        ),
        allMachinesProvider.overrideWith(() => FakeAllMachines([machine])),
        isSupporterProvider.overrideWithValue(supporter),
      ],
    );
    await tester.pumpAndSettle();
  }

  List<RecordedRpcCall> callsOf(String method) => rpc.calls.where((c) => c.method == method).toList();

  FilledButton updateButtonOf(WidgetTester tester, String name) => tester.widget<FilledButton>(
    find.descendant(
      of: find.ancestor(of: find.text(name), matching: find.byType(Card)),
      matching: find.widgetWithText(FilledButton, 'Update'),
    ),
  );

  testWidgets('groups the software by what there is to do', (tester) async {
    await pumpPage(tester);

    expect(find.text('3 updates available'), findsOneWidget, reason: 'the dirty repo can not be updated');
    expect(find.text('Klipper, Mainsail, 23 system packages'), findsOneWidget);
    expect(find.text('Needs attention'), findsOneWidget);
    expect(find.text('Local changes detected'), findsOneWidget);
    expect(find.text('Updates available'), findsOneWidget);
    expect(find.textContaining('v0.12.0-396', findRichText: true), findsOneWidget);
    expect(find.textContaining('v0.13.0-4', findRichText: true), findsOneWidget, reason: 'the available version');
    expect(find.text('git · dev'), findsWidgets);
    expect(find.text('16 commits behind'), findsNWidgets(2));
    expect(find.text('23 packages'), findsOneWidget);

    final scrollable = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(find.text('Up to date'), 200, scrollable: scrollable);
    expect(find.text('Moonraker'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('GitHub API: 54 of 60 checks left this hour'), 200, scrollable: scrollable);
    await tester.unmountApp();
  });

  testWidgets('pull to refresh reloads the status, like the other pages', (tester) async {
    await pumpPage(tester);
    expect(find.byType(SmartRefresher), findsOneWidget);
    final before = callsOf('machine.update.status').length;

    await tester.drag(find.text('3 updates available'), const Offset(0, 300));
    await tester.pumpAndSettle();

    expect(callsOf('machine.update.status'), hasLength(before + 1));
    expect(find.text('3 updates available'), findsOneWidget);
    await tester.unmountApp();
  });

  testWidgets('expands to the commits of an update', (tester) async {
    await pumpPage(tester);
    expect(find.text('stm32: Fix SPI'), findsNothing);

    await tester.ensureVisible(find.text('16 commits behind').last);
    await tester.tap(find.text('16 commits behind').last);
    await tester.pumpAndSettle();

    expect(find.text('stm32: Fix SPI'), findsOneWidget);
    expect(find.textContaining('abcdef1'), findsOneWidget);
    expect(find.text('and 15 more commits'), findsOneWidget);
    await tester.unmountApp();
  });

  testWidgets('a supporter updates everything in one tap and sees the log', (tester) async {
    await pumpPage(tester);

    await tester.tap(find.text('Update all'));
    await tester.pumpAndSettle();

    expect(callsOf('machine.update.upgrade').single.params, isNull);
    expect(sheets.shown.single.type, SheetType.updateLog);
    expect(sheets.shown.single.data, machine.uuid);
    await tester.unmountApp();
  });

  testWidgets('update all is locked for free users, single updates are not', (tester) async {
    await pumpPage(tester, supporter: false);

    expect(find.text('Update all'), findsNothing);
    await tester.tap(find.text('Update all in one tap'));
    await tester.pumpAndSettle();

    expect(dialogs.requests.single.type, DialogType.supporterOnlyFeature);
    expect(callsOf('machine.update.upgrade'), isEmpty);

    await tester.tap(find.widgetWithText(FilledButton, 'Update').first);
    await tester.pumpAndSettle();

    expect(callsOf('machine.update.upgrade').single.params, {'name': 'klipper'});
    expect(sheets.shown.single.type, SheetType.updateLog);
    await tester.unmountApp();
  });

  testWidgets('everything is disabled while printing', (tester) async {
    await pumpPage(tester, state: PrintState.printing);

    expect(find.text('Paused while printing'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Update all')).onPressed, isNull);
    expect(updateButtonOf(tester, 'Klipper').onPressed, isNull);

    await tester.tap(find.byTooltip('Check for updates'));
    await tester.pumpAndSettle();
    expect(callsOf('machine.update.refresh'), isEmpty);
    await tester.unmountApp();
  });

  testWidgets('check for updates lets Moonraker refresh', (tester) async {
    await pumpPage(tester);
    rpc.responses['machine.update.refresh'] = (_) => statusJson();

    await tester.tap(find.byTooltip('Check for updates'));
    await tester.pumpAndSettle();

    expect(callsOf('machine.update.refresh').single.params, isNull);
    expect(snackBars.shown, isEmpty);
    await tester.unmountApp();
  });

  testWidgets('a supporter recovers a dirty repo with the picked mode', (tester) async {
    await pumpPage(tester);
    sheets.result = BottomSheetResult.confirmed(false);

    await tester.tap(find.text('Recover…'));
    await tester.pumpAndSettle();

    expect(sheets.shown.first.type, SheetType.updateRecover);
    expect((sheets.shown.first.data as UpdaterInfo).name, 'crowsnest');
    expect(callsOf('machine.update.recover').single.params, {'name': 'crowsnest', 'hard': false});
    expect(sheets.shown.last.type, SheetType.updateLog);
    await tester.unmountApp();
  });

  testWidgets('a free user sees the recover options, but nothing is recovered', (tester) async {
    await pumpPage(tester, supporter: false);
    sheets.result = BottomSheetResult.confirmed(false);

    await tester.tap(find.text('Recover…'));
    await tester.pumpAndSettle();

    expect(sheets.shown.single.type, SheetType.updateRecover);
    expect(callsOf('machine.update.recover'), isEmpty);
    await tester.unmountApp();
  });

  testWidgets('the actions of a software: roll back asks first', (tester) async {
    await pumpPage(tester);
    sheets.result = BottomSheetResult.confirmed(UpdaterSheetAction.rollback);
    dialogs.response = DialogResponse.confirmed();

    await tester.tap(find.text('Klipper'));
    await tester.pumpAndSettle();

    final args = sheets.shown.first.data as ActionBottomSheetArgs;
    expect(args.actions.whereType<UpdaterSheetAction>(), contains(UpdaterSheetAction.rollback));
    expect(dialogs.confirms.single, 'Roll back Klipper?');
    expect(callsOf('machine.update.rollback').single.params, {'name': 'klipper'});
    await tester.unmountApp();
  });

  testWidgets('roll back is for supporters', (tester) async {
    await pumpPage(tester, supporter: false);
    sheets.result = BottomSheetResult.confirmed(UpdaterSheetAction.rollback);

    await tester.tap(find.text('Klipper'));
    await tester.pumpAndSettle();

    expect(dialogs.requests.single.type, DialogType.supporterOnlyFeature);
    expect(callsOf('machine.update.rollback'), isEmpty);
    await tester.unmountApp();
  });

  testWidgets('the software that is updated offers the live log instead of its update button', (tester) async {
    await pumpPage(tester);
    final progress = tester
        .container(of: find.byType(UpdateManagerPage))
        .read(updateProgressProvider(machine.uuid).notifier);

    // Started by another client: Moonraker reports what it is working on.
    progress.state = const UpdateProgressState(phase: UpdatePhase.running, steps: ['klipper'], current: 'klipper');
    await tester.pumpProviders();
    await tester.pump(kThemeAnimationDuration);
    await tester.pump(kThemeAnimationDuration);

    expect(find.text('Show log'), findsNWidgets(2), reason: 'the banner and the card of Klipper');
    final klipperCard = find.ancestor(of: find.text('Klipper'), matching: find.byType(Card));
    final inCard = find.descendant(of: klipperCard, matching: find.text('Show log'));
    expect(inCard, findsOneWidget);
    expect(find.descendant(of: klipperCard, matching: find.text('Update')), findsNothing);

    await tester.tap(inCard);
    await tester.pump();
    expect(sheets.shown.single.type, SheetType.updateLog);

    progress.state = progress.state.copyWith(phase: UpdatePhase.finished);
    await tester.pumpAndSettle();
    expect(find.text('Show log'), findsNothing);
    await tester.unmountApp();
  });

  group('sudo', () {
    const sudoInfo = {
      'sudo_access': null,
      'linux_user': 'pi',
      'sudo_requested': true,
      'request_messages': ["Sudo password required to update Moonraker's systemd service."],
    };

    testWidgets('nothing is shown while Moonraker does not ask for it', (tester) async {
      await pumpPage(tester);

      expect(find.text('Sudo password required'), findsNothing);
      await tester.unmountApp();
    });

    testWidgets('hands the entered password to Moonraker and shows what it answered', (tester) async {
      await pumpPage(tester, extraResponses: {
        'machine.sudo.info': (_) => sudoInfo,
        'machine.sudo.password': (_) => {
          'sudo_responses': ['Sudo password successfully set.'],
          'is_restarting': false,
        },
      });
      dialogs.response = DialogResponse(confirmed: true, data: 'raspberry');

      expect(find.text('Sudo password required'), findsOneWidget);
      expect(find.text("Sudo password required to update Moonraker's systemd service."), findsOneWidget);

      await tester.tap(find.text('Enter'));
      await tester.pumpAndSettle();

      final args = dialogs.requests.single.data as TextInputDialogArguments;
      expect(args.obscureText, isTrue);
      expect(callsOf('machine.sudo.password').single.params, {'password': 'raspberry'});
      expect(snackBars.shown.single.title, 'Sudo password accepted');
      expect(snackBars.shown.single.message, 'Sudo password successfully set.');
      expect(callsOf('machine.sudo.info'), hasLength(2), reason: 'asked again whether something is still pending');
      await tester.unmountApp();
    });

    testWidgets('nothing is sent if the dialog is cancelled', (tester) async {
      await pumpPage(tester, extraResponses: {'machine.sudo.info': (_) => sudoInfo});

      await tester.tap(find.text('Enter'));
      await tester.pumpAndSettle();

      expect(callsOf('machine.sudo.password'), isEmpty);
      expect(snackBars.shown, isEmpty);
      await tester.unmountApp();
    });
  });

  testWidgets('tells if the update manager is not configured', (tester) async {
    await pumpPage(tester, components: const []);

    expect(find.text('Update manager is not set up'), findsOneWidget);
    expect(find.text('Update all'), findsNothing);
    await tester.unmountApp();
  });
}
