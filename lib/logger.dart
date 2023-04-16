import 'dart:convert';
import 'dart:io';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:stringr/stringr.dart';

late final Logger logger;
late final MemoryOutput memoryOutput;
const String logFile = 'mobileraker.log';

void setupLogger() {
  Logger.level = Level.info;
  memoryOutput = MemoryOutput(bufferSize: 200, secondOutput: ConsoleOutput());
  logger = Logger(
    printer: PrettyPrinter(methodCount: 0, noBoxingByDefault: true, colors: !Platform.isIOS),
    output: memoryOutput,
    filter: ProductionFilter(),
  );
}

class RiverPodLogger extends ProviderObserver {
  const RiverPodLogger();

  @override
  void providerDidFail(ProviderBase provider, Object error,
      StackTrace stackTrace, ProviderContainer container) {
    logger.e(
        '${provider.name ?? provider.runtimeType}#${identityHashCode(provider)} failed with',
        error,
        stackTrace);
  }

  @override
  void didDisposeProvider(ProviderBase provider, ProviderContainer container) {
    if(['toolheadInfoProvider'].contains(provider.name)) return;

    var familiy = provider.argument?.toString() ?? '';
    logger.wtf(
        'RiverPod::DISPOSED:${provider.name ?? provider.runtimeType}#${identityHashCode(provider)} $familiy');
    //
    // if (provider.name == 'klipperServiceProvider') {
    //   logger.wtf('RiverPod::klipperServiceProvider:  ${container}');
    // }
  }

  @override
  void didAddProvider(
      ProviderBase provider, Object? value, ProviderContainer container) {
    var familiy = provider.argument?.toString() ?? '';
    logger.wtf(
        'RiverPod::CREATED-> ${provider.name ?? provider.runtimeType}#${identityHashCode(provider)} $familiy WITH PARENT? ${container.depth}');
  }

  @override
  void didUpdateProvider(
    ProviderBase provider,
    Object? previousValue,
    Object? newValue,
    ProviderContainer container,
  ) {
    if (![
      '_jsonRpcClientProvider',
      'jrpcClientProvider',
      'machineProvider',
      '_jsonRpcStateProvider',

    ].contains(provider.name)) return;

    var familiy = provider.argument?.toString() ?? '';
    var providerStr =
        '${provider.name ?? provider.runtimeType}#${identityHashCode(provider)}$familiy';

    logger.wtf(
        'RiverPod::UPDATE-old-> $providerStr ${identityHashCode(previousValue)}:${previousValue.toString().truncate(200)}');
    logger.wtf(
        'RiverPod::UPDATE-new->$providerStr ${identityHashCode(newValue)}:${newValue.toString().truncate(200)}');
  }
}

class FileOutput extends LogOutput {
  final File file;
  final bool overrideExisting;
  final Encoding encoding;
  IOSink? _sink;

  FileOutput({
    required this.file,
    this.overrideExisting = false,
    this.encoding = utf8,
  });

  @override
  void init() {
    _sink = file.openWrite(
      mode: overrideExisting ? FileMode.writeOnly : FileMode.writeOnlyAppend,
      encoding: encoding,
    );
  }

  @override
  void output(OutputEvent event) {
    _sink?.writeAll(event.lines, '\n');
    _sink?.writeln();
  }

  @override
  void destroy() async {
    await _sink?.flush();
    await _sink?.close();
  }
}
