/*
 * Copyright (c) 2024. Patrick Schmidt.
 * All rights reserved.
 */

// ignore_for_file: prefer-single-widget-per-file

import 'dart:io';

import 'package:common/service/live_activity_service.dart';
import 'package:common/service/moonraker/klipper_system_service.dart';
import 'package:common/service/selected_machine_service.dart';
import 'package:common/service/ui/bottom_sheet_service_interface.dart';
import 'package:common/service/ui/snackbar_service_interface.dart';
import 'package:common/ui/components/drawer/nav_drawer_view.dart';
import 'package:common/util/extensions/date_time_extension.dart';
import 'package:common/util/logger.dart';
import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:live_activities/live_activities.dart';
import 'package:mobileraker/service/ui/bottom_sheet_service_impl.dart';
import 'package:mobileraker/ui/components/async_value_widget.dart';
import 'package:path_provider/path_provider.dart';

class DevPage extends HookConsumerWidget {
  DevPage({
    Key? key,
  }) : super(key: key);

  String? _bla;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    logger.i('REBUILIDNG DEV PAGE!');
    var selMachine = ref.watch(selectedMachineProvider).value;

    var systemInfo = ref.watch(klipperSystemInfoProvider(selMachine!.uuid));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dev'),
      ),
      drawer: const NavigationDrawerWidget(),
      body: ListView(
        children: [
          // PowerApiCardLoading(),

          // BedMeshCard(machineUUID: selMachine!.uuid),
          // FirmwareRetractionCard(machineUUID: selMachine!.uuid),
          // MachineStatusCardLoading(),
          // BedMeshCard(machineUUID: selMachine!.uuid),
          // SpoolmanCardLoading(),
          // _MeshView(machineUUID: selMachine!.uuid),
          // ControlExtruderLoading(),
          // HeaterSensorCard(machineUUID: selMachine!.uuid),
          // TemperaturePresetCard(machineUUID: selMachine!.uuid),
          // HeaterSensorPresetCardLoading(),
          // const ControlXYZLoading(),
          // const ZOffsetLoading(),
          // const Text('One'),
          // OutlinedButton(onPressed: () => stateActivity(), child: const Text('STATE of Activity')),

          AsyncValueWidget(
            value: systemInfo,
            data: (data) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var entry in data.serviceState.entries)
                    Row(
                      children: [
                        Expanded(child: Text(entry.value.name, style: Theme.of(context).textTheme.labelLarge)),
                        IconButton(onPressed: () {}, icon: const Icon(Icons.restart_alt)),
                        IconButton(onPressed: () {}, icon: const Icon(Icons.stop)),
                      ],
                    ),

                  // ListTile(
                  //   subtitle: Text('State: ${entry.value.activeState}, SubState: ${entry.value.subState}'),
                  // ),
                ],
              );
            },
          ),

          OutlinedButton(onPressed: () => startLiveActivity(ref), child: const Text('start activity')),
          OutlinedButton(onPressed: () => updateLiveActivity(ref), child: const Text('update activity')),
          OutlinedButton(
              onPressed: () => ref
                  .read(bottomSheetServiceProvider)
                  .show(BottomSheetConfig(type: SheetType.userManagement, isScrollControlled: true)),
              child: const Text('UserMngnt')),
          ElevatedButton(
              onPressed: () {
                ref.read(snackBarServiceProvider).show(SnackBarConfig(
                    type: SnackbarType.info,
                    title: 'Purchases restored',
                    message: 'Managed to restore Supporter-Status!'));
              },
              child: const Text('SNACKBAR')),

          // TextButton(onPressed: () => test(ref), child: const Text('Copy Chart OPTIONS')),
          // OutlinedButton(onPressed: () => dummyDownload(), child: const Text('Download file!')),
          // // Expanded(child: WebRtcCam()),
          // AsyncValueWidget(
          //   value: ref.watch(printerSelectedProvider.selectAs((p) => p.bedMesh)),
          //   data: (data) => getMeshChart(data),
          // ),
        ],
      ),
    );
  }

  stateActivity() async {
    final _liveActivitiesPlugin = LiveActivities();
    logger.i('#1');
    await _liveActivitiesPlugin.init(appGroupId: 'group.mobileraker.liveactivity');
    logger.i('#2');
    var activityState = await _liveActivitiesPlugin.getActivityState('123123');
    logger.i('Got state message: $activityState');
  }

  startLiveActivity(WidgetRef ref) async {
    ref.read(liveActivityServiceProvider).disableClearing();
    var liveActivities = ref.read(liveActivityProvider);

    // _liveActivitiesPlugin.activityUpdateStream.listen((event) {
    //   logger.wtf('xxxLiveActivityUpdate: $event');
    // });

    Map<String, dynamic> data = {
      'progress': 0.2,
      'state': 'printing',
      'file': 'Benchy.gcode' ?? 'Unknown',
      'eta': DateTime.now().add(const Duration(seconds: 60 * 200)).secondsSinceEpoch ?? -1,

      // Not sure yet if I want to use this
      'printStartTime': DateTime.now().secondsSinceEpoch ?? -1,

      // Labels
      'primary_color_dark': Colors.yellow.value,
      'primary_color_light': Colors.pinkAccent.value,
      'machine_name': 'Voronator',
      'eta_label': tr('pages.dashboard.general.print_card.eta'),
      'elapsed_label': tr('pages.dashboard.general.print_card.elapsed'),
      'remaining_label': tr('pages.dashboard.general.print_card.remaining'),
      'completed_label': tr('general.completed'),
    };

    var activityId = await liveActivities.createActivity(
      data,
      removeWhenAppIsKilled: true,
    );
    logger.i('Created activity with id: $activityId');
    _bla = activityId;
    var pushToken = await liveActivities.getPushToken(activityId!);
    logger.i('LiveActivity PushToken: $pushToken');
  }

  updateLiveActivity(WidgetRef ref) async {
    if (_bla == null) return;

    var liveActivities = ref.read(liveActivityProvider);
    // _liveActivitiesPlugin.activityUpdateStream.listen((event) {
    //   logger.wtf('xxxLiveActivityUpdate: $event');
    // });

    Map<String, dynamic> data = {
      'progress': 1,
      'state': 'printing',
      'file': 'Benchy.gcode' ?? 'Unknown',
      'eta': DateTime.now().add(const Duration(seconds: 60 * 120)).secondsSinceEpoch ?? -1,

      // Not sure yet if I want to use this
      'printStartTime': DateTime.now().secondsSinceEpoch ?? -1,

      // Labels
      'primary_color_dark': Colors.red.value,
      'primary_color_light': Colors.pinkAccent.value,
      'machine_name': 'Voronator',
      'eta_label': tr('pages.dashboard.general.print_card.eta'),
      'elapsed_label': tr('pages.dashboard.general.print_card.elapsed'),
      'remaining_label': tr('pages.dashboard.general.print_card.remaining'),
      'completed_label': tr('general.completed'),
    };

    var activityId = await liveActivities.updateActivity(
      _bla!,
      data,
    );
    logger.i('UPDATED activity with id: $_bla -> $activityId');
  }

//   var test = 44.4;
//   var dowloadUri = Uri.parse('http://192.168.178.135/server/files/timelapse/file_example_MP4_1920_18MG.mp4');
//   final tmpDir = await getTemporaryDirectory();
//   final tmpFile = File('${tmpDir.path}/$filess');
//
//   workerManager.executeWithPort<File, double>((port) async {
//     await setupIsolateLogger();
//     return isolateDownloadFile(port: port, targetUri: dowloadUri, downloadPath: tmpFile.path);
//   }, onMessage: (message) {
//     logger.i('Got new message from port: $message');
//   }).then((value) => logger.i('Execute done: ${value}'));
// }
}

void dummyDownload() async {
  final tmpDir = await getTemporaryDirectory();
  final File file = File('${tmpDir.path}/dummy.zip');

  var dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 5),
  ));

  // Some file that is rather "large" and takes longer to download
  var uri = 'https://github.com/cfug/flutter.cn/archive/refs/heads/main.zip';

  var response = await dio.download(
    uri,
    file.path,
    onReceiveProgress: (received, total) {
      logger.i('Received: $received, Total: $total');
    },
  );
  print('Download is done: ${response.statusCode}');
}
