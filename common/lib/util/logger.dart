/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:convert';
import 'dart:io';

import 'package:common/util/extensions/provider_extension.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:stringr/stringr.dart';

late final Logger logger;
late final MemoryOutput memoryOutput;
const String logFile = 'mobileraker.log';

Future<void> setupLogger() async {
  Logger.level = Level.info;
  memoryOutput = MemoryOutput(bufferSize: 200, secondOutput: ConsoleOutput());
  LogOutput logOutput;
  try {
    final logDir = await logFileDirectory();
    final logFiles = logDir.listSync();

    // handle log rotation!
    if (logFiles.length >= 5) {
      logFiles.sort((a, b) => a.statSync().modified.compareTo(b.statSync().modified));
      await Future.wait(logFiles.sublist(0, logFiles.length - 4).map((element) => element.delete()));
    }

    String timeStamp = _logFileTimestamp();
    final logFile = await File('${logDir.path}/mobileraker_$timeStamp.log').create();
    logOutput = FileOutput(
      file: logFile,
      secondOutput: memoryOutput,
    );
  } catch (e) {
    logOutput = memoryOutput;
    debugPrint('Error while setting up file-logger, falling back to memory only solution: $e');
  }

  logger = Logger(
    printer: PrettyPrinter(
        methodCount: 0,
        errorMethodCount: 200,
        noBoxingByDefault: true,
        printTime: !kDebugMode,
        colors: kDebugMode && !Platform.isIOS),
    output: logOutput,
    filter: ProductionFilter(),
  );
}

bool _isolateLoggerAvailable = false;

Future<void> setupIsolateLogger() async {
  if (_isolateLoggerAvailable) return;
  _isolateLoggerAvailable = true;
  logger = Logger(
    printer: PrettyPrinter(
        methodCount: 0,
        errorMethodCount: 200,
        noBoxingByDefault: true,
        printTime: !kDebugMode,
        colors: kDebugMode && !Platform.isIOS),
    output: ConsoleOutput(),
    filter: ProductionFilter(),
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

class RiverPodLogger extends ProviderObserver {
  const RiverPodLogger();

  @override
  void providerDidFail(
      ProviderBase<Object?> provider, Object error, StackTrace stackTrace, ProviderContainer container) {
    logger.e('[RiverPodLogger]::FAILED ${provider.toIdentityString()} failed with', error, stackTrace);
  }

  @override
  void didDisposeProvider(ProviderBase<Object?> provider, ProviderContainer container) {
    if (['toolheadInfoProvider'].contains(provider.name)) return;

    var familiy = provider.from?.toString() ?? '';
    logger.wtf('[RiverPodLogger]::DISPOSED: ${provider.toIdentityString()} $familiy');
    //
    // if (provider.name == 'klipperServiceProvider') {
    //   logger.wtf('RiverPod::klipperServiceProvider:  ${container}');
    // }
  }

  @override
  void didAddProvider(ProviderBase<Object?> provider, Object? value, ProviderContainer container) {
    logger.wtf('[RiverPodLogger]::CREATED-> ${provider.toIdentityString()} WITH PARENT? ${container.depth} ');
  }

  @override
  void didUpdateProvider(ProviderBase<Object?> provider,
    Object? previousValue,
    Object? newValue,
    ProviderContainer container,
  ) {
    if (![
      '_jsonRpcClientProvider',
      'jrpcClientProvider',
      'machineProvider',
      'klipperSelectedProvider',
      'selectedMachineProvider',
      '_jsonRpcStateProvider',
      // 'machinePrinterKlippySettingsProvider',
    ].contains(provider.name)) return;

    var familiy = provider.argument?.toString() ?? '';
    var providerStr = '${provider.name ?? provider.runtimeType}#${identityHashCode(provider)}$familiy';

    logger.wtf(
        '[RiverPodLogger]::UPDATE-old-> $providerStr ${identityHashCode(previousValue)}:${previousValue.toString().truncate(200)}');
    logger.wtf(
        '[RiverPodLogger]::UPDATE-new->$providerStr ${identityHashCode(newValue)}:${newValue.toString().truncate(200)}');
  }
}

class FileOutput extends LogOutput {
  final LogOutput? secondOutput;
  final File file;
  final bool overrideExisting;
  final Encoding encoding;
  IOSink? _sink;

  FileOutput({
    required this.file,
    this.secondOutput,
    this.overrideExisting = false,
    this.encoding = utf8,
  });

  @override
  void init() {
    _sink = file.openWrite(
      mode: overrideExisting ? FileMode.writeOnly : FileMode.writeOnlyAppend,
      encoding: encoding,
    );
    secondOutput?.init();
  }

  @override
  void output(OutputEvent event) {
    _sink?.writeAll(event.lines, '\n');
    _sink?.writeln();
    secondOutput?.output(event);
    // _sink?.flush();
  }

  @override
  void destroy() async {
    await _sink?.flush();
    await _sink?.close();
    secondOutput?.destroy();
  }
}
