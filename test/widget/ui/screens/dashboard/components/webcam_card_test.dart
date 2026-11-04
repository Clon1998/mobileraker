/*
 * Copyright (c) 2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:convert';

import 'package:common/data/dto/machine/print_state_enum.dart';
import 'package:common/data/dto/machine/printer.dart';
import 'package:common/data/enums/webcam_service_type.dart';
import 'package:common/data/model/moonraker_db/webcam_info.dart';
import 'package:common/service/moonraker/printer_service.dart';
import 'package:common/service/moonraker/timelapse_service.dart';
import 'package:common/service/moonraker/webcam_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:hooks_riverpod/misc.dart' show Override;
import 'package:mobileraker/routing/app_router.dart';
import 'package:mobileraker/ui/components/mjpeg/mjpeg_manager.dart';
import 'package:mobileraker/ui/components/webcam/webcam.dart';
import 'package:mobileraker/ui/screens/dashboard/components/webcam_card.dart';
import 'package:test_support/test_support.dart';

void main() {
  setUpWidgetTests();

  final machine = Fixtures.machine();

  // An HLS stream is not supported, so the cams show a text instead of loading a stream.
  WebcamInfo cam(String name) => WebcamInfo(
    uid: name,
    name: name,
    service: WebcamServiceType.hlsStream,
    streamUrl: Uri.parse('http://printer.local/$name/stream'),
    snapshotUrl: Uri.parse('http://printer.local/$name/snapshot'),
  );

  final front = cam('front_cam');
  final nozzle = cam('nozzle_cam');

  /// How often the webcams were fetched.
  late int fetches;

  /// The webcams per fetch (the last one for all later fetches); an [Exception] fails the fetch.
  late List<Object> results;

  late List<Object?> fullscreenExtras;

  setUp(() {
    fetches = 0;
    results = [
      [front],
    ];
    fullscreenExtras = [];
  });

  List<Override> overrides({
    PrintState state = PrintState.standby,
    bool timelapse = false,
    bool hasFrame = true,
    PrinterNotifier Function()? printerNotifier,
  }) => [
    ...connectedMachineOverrides(
      machine,
      klipper: Fixtures.klipper(components: [if (timelapse) 'timelapse']),
      printer: Fixtures.printer(state: state),
      printerNotifier: printerNotifier,
    ),
    allWebcamInfosProvider(machine.uuid).overrideWith((ref) async* {
      final result = results[fetches.clamp(0, results.length - 1)];
      fetches++;
      if (result is Exception) throw result;
      yield result as List<WebcamInfo>;
    }),
    timelapseLastFrameProvider(
      machine.uuid,
    ).overrideWith((ref) => Stream.value(hasFrame ? (file: 'frame000006.jpg', receivedAt: DateTime(2026)) : null)),
    timelapseFrameTransformProvider(
      machine.uuid,
    ).overrideWith((ref) async => (flipX: false, flipY: false, rotation: 0)),
  ];

  GoRouter router() => GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => SingleChildScrollView(child: WebcamCard(machineUUID: machine.uuid)),
      ),
      GoRoute(
        path: '/fullcam',
        name: AppRoute.fullCam.name,
        builder: (_, state) {
          fullscreenExtras.add(state.extra);
          return const Text('fullscreen cam');
        },
      ),
    ],
  );

  Future<void> pumpCard(WidgetTester tester, {List<Override> Function()? withOverrides}) async {
    await tester.pumpRouterApp(router(), overrides: (withOverrides ?? overrides)());
    await tester.pumpAndSettle();
  }

  WebcamInfo shownCam(WidgetTester tester) => tester.widget<Webcam>(find.byType(Webcam)).webcamInfo;

  /// Like pumpAndSettle, for the frame's and streams' endless loading indicators.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  Future<void> pick(WidgetTester tester, String item) async {
    await tester.tap(find.byType(DropdownButton<int>));
    await settle(tester);
    await tester.tap(find.text(item).last);
    await settle(tester);
  }

  final timelapseFrame = find.byKey(const Key('wcTimelapseFrame'));

  testWidgets('without webcams there is no card', (tester) async {
    results = [<WebcamInfo>[]];
    await pumpCard(tester);

    expect(find.text('Webcam'), findsNothing);
    expect(find.byType(Card), findsNothing);
  });

  testWidgets('a single webcam is shown without a selection', (tester) async {
    await pumpCard(tester);

    expect(find.text('Webcam'), findsOneWidget);
    expect(shownCam(tester), front);
    expect(find.byType(DropdownButton<int>), findsNothing);
  });

  group('selection', () {
    testWidgets('with several webcams the first is shown, another can be picked', (tester) async {
      results = [
        [front, nozzle],
      ];
      await pumpCard(tester);
      expect(shownCam(tester), front);

      await pick(tester, 'Nozzle Cam');

      expect(shownCam(tester), nozzle);
    });

    testWidgets('the picked webcam is kept for the next visit', (tester) async {
      results = [
        [front, nozzle],
      ];
      await pumpCard(tester);
      await pick(tester, 'Nozzle Cam');
      await tester.unmountApp();

      await pumpCard(tester);

      expect(shownCam(tester), nozzle);
    });

    testWidgets('the first webcam is shown when the kept one was removed', (tester) async {
      results = [
        [front, nozzle],
      ];
      await pumpCard(tester);
      await pick(tester, 'Nozzle Cam');
      await tester.unmountApp();

      results = [
        [front],
      ];
      await pumpCard(tester);

      expect(shownCam(tester), front);
    });
  });

  group('stream', () {
    // A supported cam, whose stream sends one frame.
    final mjpeg = front.copyWith(service: WebcamServiceType.mjpegStreamer);

    Future<void> pumpStreaming(WidgetTester tester) async {
      results = [
        [mjpeg],
      ];
      await tester.pumpRouterApp(
        router(),
        overrides: [...overrides(), mjpegManagerProvider.overrideWith((ref, args) => _OneFrameMjpeg())],
      );
      await settle(tester);
    }

    testWidgets('shows the frames of the webcam', (tester) async {
      await pumpStreaming(tester);

      expect(find.bySemanticsLabel('WebCam Image'), findsOneWidget);
      expect(find.text('Webcam unavailable'), findsNothing);
    });

    testWidgets('the fullscreen button opens the webcam in fullscreen', (tester) async {
      await pumpStreaming(tester);

      // Pressed directly: over the fake frame the button does not receive taps in the test.
      tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.aspect_ratio)).onPressed!();
      await settle(tester);

      expect(find.text('fullscreen cam'), findsOneWidget);
      expect(fullscreenExtras.single, {'machine': machine, 'selectedCam': mjpeg});
    });
  });

  group('unavailable', () {
    testWidgets('a failed fetch shows that the webcam is unavailable', (tester) async {
      results = [Exception('webcam API down')];
      await pumpCard(tester);

      expect(find.text('Webcam unavailable'), findsOneWidget);
      expect(find.byType(Webcam), findsNothing);
    });

    testWidgets('retry fetches the webcams again and shows them', (tester) async {
      results = [
        Exception('webcam API down'),
        [front],
      ];
      await pumpCard(tester);

      await tester.tap(find.byTooltip('Reconnect'));
      await tester.pumpAndSettle();

      expect(fetches, 2);
      expect(find.text('Webcam unavailable'), findsNothing);
      expect(shownCam(tester), front);
    });
  });

  group('hide', () {
    final hideButton = find.byTooltip('Hide webcam');
    final showButton = find.byTooltip('Show webcam');
    const hint = 'Hidden – tap the icon to show';

    testWidgets('hiding removes the webcam and says how to show it again', (tester) async {
      await pumpCard(tester);

      await tester.tap(hideButton);
      await tester.pumpAndSettle();

      expect(find.byType(Webcam), findsNothing);
      expect(find.text(hint), findsOneWidget);
      expect(showButton, findsOneWidget);

      await tester.tap(showButton);
      await tester.pumpAndSettle();

      expect(find.text(hint), findsNothing);
      expect(shownCam(tester), front);
    });

    testWidgets('a hidden card stays hidden on the next visit', (tester) async {
      await pumpCard(tester);
      await tester.tap(hideButton);
      await tester.pumpAndSettle();
      await tester.unmountApp();

      await pumpCard(tester);

      expect(find.text(hint), findsOneWidget);
      expect(find.byType(Webcam), findsNothing);
    });

    testWidgets('a hidden card has no webcam selection', (tester) async {
      results = [
        [front, nozzle],
      ];
      await pumpCard(tester);
      await tester.tap(hideButton);
      await tester.pumpAndSettle();

      expect(find.byType(DropdownButton<int>), findsNothing);
    });
  });

  group('timelapse frame', () {
    testWidgets('during a print the latest frame can be picked, also with a single webcam', (tester) async {
      await pumpCard(tester, withOverrides: () => overrides(state: PrintState.printing, timelapse: true));

      await pick(tester, 'Latest timelapse frame');

      expect(timelapseFrame, findsOneWidget);
      expect(find.byType(Webcam), findsNothing);
    });

    testWidgets('a webcam can be picked again', (tester) async {
      await pumpCard(tester, withOverrides: () => overrides(state: PrintState.printing, timelapse: true));
      await pick(tester, 'Latest timelapse frame');

      await pick(tester, 'Front Cam');

      expect(timelapseFrame, findsNothing);
      expect(shownCam(tester), front);
    });

    testWidgets('also offered while the print is paused', (tester) async {
      await pumpCard(tester, withOverrides: () => overrides(state: PrintState.paused, timelapse: true));

      expect(find.byType(DropdownButton<int>), findsOneWidget);
    });

    for (final (reason, state, timelapse, hasFrame) in [
      ('without a print', PrintState.standby, true, true),
      ('without the timelapse component', PrintState.printing, false, true),
      ('before the first frame', PrintState.printing, true, false),
    ]) {
      testWidgets('not offered $reason', (tester) async {
        await pumpCard(
          tester,
          withOverrides: () => overrides(state: state, timelapse: timelapse, hasFrame: hasFrame),
        );

        expect(find.byType(DropdownButton<int>), findsNothing);
        expect(shownCam(tester), front);
      });
    }

    testWidgets('the webcam is shown again when the print ends', (tester) async {
      late _ChangingPrinter printer;
      await pumpCard(
        tester,
        withOverrides: () => overrides(
          timelapse: true,
          printerNotifier: () => printer = _ChangingPrinter(Fixtures.printer(state: PrintState.printing)),
        ),
      );
      await pick(tester, 'Latest timelapse frame');

      printer.emit(Fixtures.printer(state: PrintState.complete));
      await settle(tester);

      expect(timelapseFrame, findsNothing);
      expect(shownCam(tester), front);
    });
  });
}

class _ChangingPrinter extends FakePrinter {
  _ChangingPrinter(super.printer);

  void emit(Printer next) => state = AsyncData(next);
}

/// An MJPEG stream that sends a single frame.
class _OneFrameMjpeg implements MjpegManager {
  // A grey 320x240 frame, as PNG.
  static final _frame = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAUAAAADwCAIAAAD+Tyo8AAACCklEQVR42u3TQQkAAAwDsUqrf1X1sN8gkXBwKfBWJAADAwYGDAwGBgwMGBgwMBgYMDBgYDAwYGDAwICBwcCAgQEDAwYGAwMGBgwMBgYMDBgYMDAYGDAwYGDAwGBgwMCAgcHAgIEBAwMGBgMDBgYMDAYGDAwYGDAwGBgwMGBgwMBgYMDAgIHBwICBAQMDBgYDAwYGDAwYGAwMGBgwMBgYMDBgYMDAYGDAwICBAQODgQEDAwYGAwMGBgwMGBgMDBgYMDAYGDAwYGDAwGBgwMCAgQEDg4EBAwMGBgMDBgYMDBgYDAwYGDAwYGAwMGBgwMBgYMDAgIEBA4OBAQMDBgYMDAYGDAwYGAwMGBgwMGBgMDBgYMDAYGDAwICBAQODgQEDAwYGDAwGBgwMGBgMDBgYMDBgYDAwYGDAwICBwcCAgQEDg4EBAwMGBgwMBgYMDBgYDAwYGDAwYGAwMGBgwMCAgcHAgIEBA4OBAQMDBgYMDAYGDAwYGDAwGBgwMGBgMDBgYMDAgIHBwICBAQMDBgYDAwYGDAwGBgwMGBgwMBgYMDBgYDAwYGDAwICBwcCAgQEDAwYGAwMGBgwMBgYMDBgYMDAYGDAwYGDAwGBgwMCAgcHAgIEBAwMGBgMDBgYMDBgYDAwYGDAwGBgwMGBgwMBgYMDAgIHBwICBAQMDBgYDAwYGDAwYGAwMGBi4G60xDTCDuFJaAAAAAElFTkSuQmCC',
  );

  @override
  Stream<MemoryImage> get jpegStream => Stream.value(MemoryImage(_frame));

  @override
  void start() {}

  @override
  void stop() {}

  @override
  void dispose() {}
}
