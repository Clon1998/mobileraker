/*
 * Copyright (c) 2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/dto/files/gcode_file.dart';
import 'package:common/data/dto/history/historical_print_job.dart';
import 'package:common/data/dto/job_queue/job_queue_status.dart';
import 'package:common/data/dto/machine/print_state_enum.dart';
import 'package:common/data/dto/machine/printer_builder.dart';
import 'package:common/data/dto/power/power_device.dart';
import 'package:common/data/dto/server/klipper.dart';
import 'package:common/data/dto/server/klipper_system_info.dart';
import 'package:common/data/dto/update_manager/update_status.dart';
import 'package:common/data/model/moonraker_db/webcam_info.dart';
import 'package:common/network/json_rpc_client.dart';
import 'package:common/service/demo/demo_moonraker.dart';
import 'package:common/service/demo/demo_printer.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_utils.dart';

void main() {
  setUpAll(setupTestLogger);

  late DemoMoonraker moonraker;
  late DemoJsonRpcClient client;
  final notifications = <Map<String, dynamic>>[];

  setUp(() {
    moonraker = DemoMoonraker(autoTick: false);
    client = DemoJsonRpcClient(moonraker);
    notifications.clear();
    client.addMethodListener(notifications.add);
  });

  tearDown(() async {
    await client.dispose();
    moonraker.dispose();
  });

  Future<Map<String, dynamic>> rpc(String method, [Map<String, dynamic>? params]) async =>
      (await client.sendJRpcMethod(method, params: params)).result;

  Future<PrinterBuilder> queryPrinter() async {
    final objects = (await rpc('printer.objects.list'))['objects'].cast<String>();
    final builder = PrinterBuilder()..queryableObjects = List<String>.unmodifiable(objects);
    final status = (await rpc('printer.objects.query', {
      'objects': {for (final o in objects) o: null},
    }))['status'] as Map<String, dynamic>;
    for (final key in status.keys) {
      builder.partialUpdateField(key, status);
    }
    return builder;
  }

  test('the printer objects parse into a printer that is printing', () async {
    final printer = (await queryPrinter()).build();

    expect(printer.print.state, PrintState.printing);
    expect(printer.extruders, hasLength(1));
    expect(printer.heaterBed, isNotNull);
    expect(printer.excludeObject?.objects, hasLength(4));
    expect(printer.bedMesh?.profiles, isNotEmpty);
    expect(printer.gcodeMacros, isNotEmpty);
    expect(printer.leds, hasLength(2));
    expect(printer.fans, hasLength(2));
    expect(printer.temperatureSensors, hasLength(2));
    expect(printer.filamentSensors, hasLength(1));
    expect(printer.firmwareRetraction, isNotNull);
  });

  test('ticks advance the print and push status updates', () async {
    final before = (await queryPrinter()).build().virtualSdCard!.progress;
    moonraker.tick();
    await pumpEventQueue();

    expect(notifications.where((n) => n['method'] == 'notify_status_update'), isNotEmpty);
    final after = (await queryPrinter()).build().virtualSdCard!.progress;
    expect(after, greaterThan(before));
  });

  test('g-code changes the printer', () async {
    await rpc('printer.gcode.script', {'script': 'M140 S95\nSET_GCODE_OFFSET Z_ADJUST=0.05\nEXCLUDE_OBJECT NAME=bin_2'});
    final printer = (await queryPrinter()).build();

    expect(printer.heaterBed!.target, 95);
    expect(printer.gCodeMove.homingOrigin[2], closeTo(0.05, 1e-6));
    expect(printer.excludeObject!.excludedObjects, ['bin_2']);
  });

  test('cancel, then start another print', () async {
    await rpc('printer.print.cancel');
    expect((await queryPrinter()).build().print.state, PrintState.cancelled);

    await rpc('printer.print.start', {'filename': 'Cable_clips_x8_PLA_24m.gcode'});
    final printer = (await queryPrinter()).build();
    expect(printer.print.state, PrintState.printing);
    expect(printer.print.filename, 'Cable_clips_x8_PLA_24m.gcode');
    expect(printer.excludeObject!.objects, hasLength(8));
  });

  test('server responses parse into the app DTOs', () async {
    final server = KlipperInstance.fromJson(await rpc('server.info'));
    expect(server.klippyState, KlipperState.ready);
    expect(server.hasSpoolmanComponent && server.hasPowerComponent && server.hasUpdateManagerComponent, isTrue);

    final system = KlipperSystemInfo.fromJson((await rpc('machine.system_info'))['system_info']);
    expect(system.serviceState, isNotEmpty);

    final updates = UpdateStatus.fromJson(await rpc('machine.update.status'));
    expect(updates.updaters.map((u) => u.name), containsAll(['moonraker', 'klipper', 'mainsail', 'system']));

    final power = (await rpc('machine.device_power.devices'))['devices'] as List;
    expect(power.map((e) => PowerDevice.fromJson(e)), hasLength(3));

    final queue = JobQueueStatus.fromJson(
      await rpc('server.job_queue.post_job', {
        'filenames': ['Planter_ABS_3h12m.gcode'],
      }),
    );
    expect(queue.queuedJobs, hasLength(1));

    final history = (await rpc('server.history.list'))['jobs'] as List;
    expect(history.map((e) => HistoricalPrintJob.fromJson(e)), hasLength(7));

    final dir = await rpc('server.files.get_directory', {'path': 'gcodes', 'extended': true});
    final files = [for (final f in dir['files'] as List) GCodeFile.fromJson(f, 'gcodes')];
    expect(files, hasLength(4));
    expect((dir['dirs'] as List).single['dirname'], 'calibration');

    final meta = GCodeFile.fromMetaData(
      'Planter_ABS_3h12m.gcode',
      'gcodes',
      await rpc('server.files.metadata', {'filename': 'Planter_ABS_3h12m.gcode'}),
    );
    expect(meta.estimatedTime, 11520);

    final cams = (await rpc('server.webcams.list'))['webcams'] as List;
    expect(cams.map((e) => WebcamInfo.fromJson(e)).single.name, 'Demo cam');
  });

  test('files can be created, moved and deleted', () async {
    await rpc('server.files.post_directory', {'path': 'gcodes/new'});
    await rpc('server.files.move', {'source': 'gcodes/Planter_ABS_3h12m.gcode', 'dest': 'gcodes/new'});
    final moved = await rpc('server.files.get_directory', {'path': 'gcodes/new'});
    expect((moved['files'] as List).single['filename'], 'Planter_ABS_3h12m.gcode');
    expect(moonraker.fileContent('gcodes/new/Planter_ABS_3h12m.gcode'), contains('EXCLUDE_OBJECT_DEFINE'));

    await rpc('server.files.delete_directory', {'path': 'gcodes/new', 'force': true});
    final root = await rpc('server.files.get_directory', {'path': 'gcodes'});
    expect((root['files'] as List).map((f) => f['filename']), isNot(contains('Planter_ABS_3h12m.gcode')));
    expect(notifications.where((n) => n['method'] == 'notify_filelist_changed'), isNotEmpty);

    // The file that prints can't be deleted
    expect(
      () => rpc('server.files.delete_file', {'path': 'gcodes/Gridfinity_bins_x4_PLA_2h05m.gcode'}),
      throwsA(isA<JRpcError>()),
    );
  });

  test('the database behaves like moonraker', () async {
    expect(
      () => rpc('server.database.get_item', {'namespace': 'mobileraker', 'key': 'settings'}),
      throwsA(isA<JRpcError>().having((e) => e.message, 'message', "Namespace 'mobileraker' not found")),
    );
    await rpc('server.database.post_item', {
      'namespace': 'mobileraker',
      'key': 'settings.temp',
      'value': {'a': 1},
    });
    final item = await rpc('server.database.get_item', {'namespace': 'mobileraker', 'key': 'settings'});
    expect(item['value'], {
      'temp': {'a': 1},
    });
  });

  test('spoolman answers through the proxy', () async {
    final spools = await rpc('server.spoolman.proxy', {
      'use_v2_response': true,
      'request_method': 'GET',
      'path': '/v1/spool',
      'query': 'limit=2&offset=0',
    });
    expect(spools['response'], hasLength(2));
    expect(spools['response_headers']['X-Total-Count'], '4');

    final info = await rpc('server.spoolman.proxy', {'request_method': 'GET', 'path': '/v1/info'});
    expect(info['version'], isNotEmpty);
  });
}
