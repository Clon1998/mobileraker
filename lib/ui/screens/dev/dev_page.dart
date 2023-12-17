/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:io';

import 'package:common/data/dto/machine/bed_mesh/bed_mesh.dart';
import 'package:common/service/live_activity_service.dart';
import 'package:common/service/moonraker/printer_service.dart';
import 'package:common/service/selected_machine_service.dart';
import 'package:common/ui/components/drawer/nav_drawer_view.dart';
import 'package:common/util/extensions/date_time_extension.dart';
import 'package:common/util/logger.dart';
import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_echarts/flutter_echarts.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:live_activities/live_activities.dart';
import 'package:mobileraker/ui/screens/dashboard/components/control_xyz/control_xyz_card.dart';
import 'package:path_provider/path_provider.dart';

class DevPage extends HookConsumerWidget {
  DevPage({
    Key? key,
  }) : super(key: key);

  String? _bla;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var selMachine = ref.watch(selectedMachineProvider).value;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dev'),
      ),
      drawer: const NavigationDrawerWidget(),
      body: ListView(
        children: [
          if (selMachine?.uuid != null) ControlXYZCard(machineUUID: selMachine!.uuid),
          // const ControlXYZLoading(),
          // const ZOffsetLoading(),
          // const Text('One'),
          // ElevatedButton(onPressed: () => stateActivity(), child: const Text('STATE of Activity')),
          ElevatedButton(onPressed: () => startLiveActivity(ref), child: const Text('start activity')),
          ElevatedButton(onPressed: () => updateLiveActivity(ref), child: const Text('update activity')),
          // TextButton(onPressed: () => test(ref), child: const Text('Copy Chart OPTIONS')),
          // ElevatedButton(onPressed: () => dummyDownload(), child: const Text('Download file!')),
          // // Expanded(child: WebRtcCam()),
          // AsyncValueWidget(
          //   value: ref.watch(printerSelectedProvider.selectAs((p) => p.bedMesh)),
          //   data: (data) => getMeshChart(data),
          // ),
        ],
      ),
    );
  }

  Widget getMeshChart(BedMesh? mesh) {
    if (mesh == null) return const Text('No Mesh');

    var options = getChartOptions(mesh);
    return Container(
      color: Colors.blueGrey,
      height: 600,
      width: 300,
      child: Echarts(
        option: options,
      ),
    );
  }

  stateActivity() async {
    final _liveActivitiesPlugin = LiveActivities();
    logger.i('#1');
    await _liveActivitiesPlugin.init(appGroupId: "group.mobileraker.liveactivity");
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

  test(WidgetRef ref) async {
    var read = ref.read(printerSelectedProvider).value;

    String chartOptions = getChartOptions(read!.bedMesh!);

    Clipboard.setData(ClipboardData(text: chartOptions));
    logger.i('Copied!');
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

String getChartOptions(BedMesh mesh) {
  var series = dataSeries(mesh);

// legend: {
//   show: false,
//   selected: this.selected,
//   },
  var colorAxisName = '"rgba(255,255,255,0.5)"';
  var colorAxisLabel = '"rgba(255,255,255,0.5)"';
  var colorAxisLine = '"rgba(255,255,255,0.2)"';
  var colorAxisTick = '"rgba(255,255,255,0.2)"';
  var colorSplitLine = '"rgba(255,255,255,0.2)"';
  var colorAxisPointer = '"rgba(255,255,255,0.8)"';

  var colorVisualMap = '"rgba(255,255,255,0.8)"';

  var axisX = [0, 300];
  var axisY = [0, 300];

  var scaleX = 1;
  var scaleY = 1;
  var scaleZ = 0.5;

  var visualMapMin = -0.1;
  var visualMapMax = 0.1;
  var visualMapSeriesIndex = [0];
  var fontSizeVisualMap = 14;

  return '''
{
    tooltip: {
        backgroundColor: 'rgba(0,0,0,0.9)',
        borderWidth: 0,
        textStyle: {
            color: '#fff',
            fontSize: '14px',
        },
        padding: 15,
    },
    darkMode: true,
    animation: false,

    visualMap: {
        show: true,
        min: $visualMapMin,
        max: $visualMapMax,
        calculable: true,
        dimension: 2,
        inRange: {
            color: [
                '#313695',
                '#4575b4',
                '#74add1',
                '#abd9e9',
                '#e0f3f8',
                '#ffffbf',
                '#fee090',
                '#fdae61',
                '#f46d43',
                '#d73027',
                '#a50026',
            ],
        },
        seriesIndex: $visualMapSeriesIndex,
        left: 10,
        top: 20,
        bottom: 0,
        itemWidth: 10,
        itemHeight: 350,
        precision: 3,
        textStyle: {
            color: $colorVisualMap,
            fontSize: $fontSizeVisualMap,
        },
    },
    xAxis3D: {
        type: 'value',
        nameTextStyle: {
            color: $colorAxisName,
        },
        min: ${axisX[0]},
        max: ${axisX[1]},
        minInterval: 1,
    },
    yAxis3D: {
        type: 'value',
        nameTextStyle: {
            color: $colorAxisName,
        },
        min: ${axisY[0]},
        max: ${axisY[1]},
    },
    zAxis3D: {
        type: 'value',
        min: ${scaleZ * -1},
        max: $scaleZ,
        nameTextStyle: {
            color: $colorAxisName,
        },
        axisPointer: {
            label: {
                formatter: function (value) {
                    value = parseFloat(value);
                    return value.toFixed(2);
                },
            },
        },
    },
    grid3D: {
        axisLabel: {
            textStyle: {
                color: $colorAxisLabel,
            },
        },
        axisLine: {
            lineStyle: {
                color: $colorAxisLine,
            },
        },
        axisTick: {
            lineStyle: {
                color: $colorAxisTick,
            },
        },
        splitLine: {
            lineStyle: {
                color: $colorSplitLine,
            },
        },
        axisPointer: {
            lineStyle: {
                color: $colorAxisPointer,
            },
            label: {
                textStyle: {
                    color: $colorAxisPointer,
                },
            },
        },
    },
    series: $series
}
  ''';
}

Map<String, dynamic> dataSeries(BedMesh mesh) {
  var xCount = mesh.probedMatrix[0].length;
  var yCount = mesh.probedMatrix.length;
  var xMin = mesh.minX;
  var xMax = mesh.maxX;
  var yMin = mesh.minY;
  var yMax = mesh.maxY;
  var xStep = (xMax - xMin) / (xCount - 1);
  var yStep = (yMax - yMin) / (yCount - 1);

  var data = <List<double>>[];
  var yPoint = 0;
  for (var row in mesh.probedMatrix) {
    var xPoint = 0;
    for (var value in row) {
      data.add([xMin + xStep * xPoint, yMin + yStep * yPoint, value]);
      xPoint++;
    }
    yPoint++;
  }

  return {
    "type": '"surface"',
    "name": '"probed"',
    "dataShape": [yCount, xCount],
    "data": data,
    "itemStyle": {
      "opacity": 1,
    },
    "wireframe": {
      "show": false,
    },
  };
}

void dummyDownload() async {
  final tmpDir = await getTemporaryDirectory();
  final File file = File('${tmpDir.path}/dummy.zip');

  var dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 5),
  ));

  // Some file that is rather "large" and takes longer to download
  var uri = "https://github.com/cfug/flutter.cn/archive/refs/heads/main.zip";

  var response = await dio.download(
    uri,
    file.path,
    onReceiveProgress: (received, total) {
      logger.i('Received: $received, Total: $total');
    },
  );
  print('Download is done: ${response.statusCode}');
}