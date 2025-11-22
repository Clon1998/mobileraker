/*
 * Copyright (c) 2023-2025. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:talker_flutter/talker_flutter.dart';

const String logFile = 'mobileraker.log';
late final Talker talker;

Future<void> setupLogger() async {
  var mobilerakerLogHistory = MobilerakerLogHistory();

  await mobilerakerLogHistory.init();

  talker = Talker(
    settings: TalkerSettings(),
    history: mobilerakerLogHistory,
    logger: TalkerLogger(
      settings: TalkerLoggerSettings(
        // Set current logging level
        level: LogLevel.info,
      ),
    ),
  );
}

bool _isolateLoggerAvailable = false;

Future<void> setupIsolateLogger() async {
  if (_isolateLoggerAvailable) return;
  _isolateLoggerAvailable = true;
  talker = Talker(
    settings: TalkerSettings(),
    logger: TalkerLogger(
      settings: TalkerLoggerSettings(
        // Set current logging level
        level: LogLevel.info,
      ),
    ),
  );
}

Future<Directory> logFileDirectory() async {
  final temporaryDirectory = await getApplicationSupportDirectory();
  return Directory('${temporaryDirectory.path}/logs').create(recursive: true);
}

String _logFileTimestamp() {
  final now = DateTime.now();
  var format = DateFormat('yyyy-MM-ddTHH-mm-ss').format(now);
  return format;
}
//
// class RiverPodLogger extends ProviderObserver {
//   const RiverPodLogger();
//
//   @override
//   void providerDidFail(
//       ProviderBase<Object?> provider, Object error, StackTrace stackTrace, ProviderContainer container) {
//     talker.error('[RiverPodLogger]::FAILED ${provider.toIdentityString()} failed with', error, stackTrace);
//   }
//
//   @override
//   void didDisposeProvider(ProviderBase<Object?> provider, ProviderContainer container) {
//     if (['toolheadInfoProvider', 'temperatureStoreProvider'].contains(provider.name)) return;
//
//     var familiy = provider.from?.toString() ?? '';
//     logger.wtf('[RiverPodLogger]::DISPOSED: ${provider.toIdentityString()} $familiy');
//     //
//     // if (provider.name == 'klipperServiceProvider') {
//     //   logger.wtf('RiverPod::klipperServiceProvider:  ${container}');
//     // }
//   }
//
//   @override
//   void didAddProvider(ProviderBase<Object?> provider, Object? value, ProviderContainer container) {
//     logger.wtf('[RiverPodLogger]::CREATED-> ${provider.toIdentityString()} WITH PARENT? ${container.depth} ');
//   }
//
//   @override
//   void didUpdateProvider(ProviderBase<Object?> provider,
//     Object? previousValue,
//     Object? newValue,
//     ProviderContainer container,
//   ) {
//     if (![
//       '_jsonRpcClientProvider',
//       'jrpcClientProvider',
//       'machineProvider',
//       'klipperSelectedProvider',
//       'selectedMachineProvider',
//       '_jsonRpcStateProvider',
//       // 'machinePrinterKlippySettingsProvider',
//     ].contains(provider.name)) return;
//
//     var familiy = provider.argument?.toString() ?? '';
//     var providerStr = '${provider.name ?? provider.runtimeType}#${identityHashCode(provider)}$familiy';
//
//     logger.wtf(
//         '[RiverPodLogger]::UPDATE-old-> $providerStr ${identityHashCode(previousValue)}:${previousValue.toString().truncate(200)}');
//     logger.wtf(
//         '[RiverPodLogger]::UPDATE-new->$providerStr ${identityHashCode(newValue)}:${newValue.toString().truncate(200)}');
//   }
// }

class MobilerakerLogHistory extends TalkerHistory {
  MobilerakerLogHistory({this.maxItems = 1000});

  final int maxItems;

  final _history = <TalkerData>[];

  late final IOSink _logFileSink;

  Future<void> init() async {
    final logDir = await logFileDirectory();
    final logFiles = logDir.listSync();

    // handle log rotation!
    if (logFiles.length >= 5) {
      logFiles.sort((a, b) => a.statSync().modified.compareTo(b.statSync().modified));
      await Future.wait(logFiles.sublist(0, logFiles.length - 4).map((element) => element.delete()));
    }

    String timeStamp = _logFileTimestamp();
    final logFile = await File('${logDir.path}/mobileraker_$timeStamp.log').create();

    _logFileSink = logFile.openWrite();
  }

  @override
  void clean() {
    _history.clear();
  }

  @override
  List<TalkerData> get history => _history;

  @override
  void write(TalkerData data) {
    if (_history.length >= maxItems) {
      _history.removeAt(0);
    }
    _history.add(data);


    _logFileSink.write(data.generateTextMessage());
    _logFileSink.writeln();
  }
}

class MobilerakerRouteObserver extends NavigatorObserver {
  MobilerakerRouteObserver(this.name);

  final String name;

  int stackCount = 0;

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    stackCount--;
    talker.info('[MobilerakerRouteObserver-$name]::POP $route. Active is now $previousRoute. StackCount: $stackCount');
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    talker.info('[MobilerakerRouteObserver-$name]::PUSH $route.');
    stackCount++;
  }

  @override
  void didStartUserGesture(Route<dynamic> route, Route<dynamic>? previousRoute) {
    // Do Nothing
  }

  @override
  void didStopUserGesture() {
    // Do Nothing
  }
}
