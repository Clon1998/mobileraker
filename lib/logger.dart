import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:logger_flutter/logger_flutter.dart';

final logger =
    Logger(printer: PrettyPrinter(methodCount: 0, noBoxingByDefault: true), output: LogConsole.wrap(innerOutput: ConsoleOutput()));

class RiverPodLogger extends ProviderObserver {
  const RiverPodLogger();


  @override
  void providerDidFail(ProviderBase provider, Object error,
      StackTrace stackTrace, ProviderContainer container) {

    logger.e('${provider.name ?? provider.runtimeType}#${identityHashCode(provider)} failed with', error, stackTrace);

  }


  @override
  void didDisposeProvider(ProviderBase provider, ProviderContainer container) {
    logger.i(
        'DISPOSED-> ${provider.name ?? provider.runtimeType}#${identityHashCode(provider)}');
  }

  @override
  void didAddProvider(ProviderBase provider, Object? value, ProviderContainer container) {
    logger.i(
        'CREAATED-> ${provider.name ?? provider.runtimeType}#${identityHashCode(provider)} WITH PARENT? ${container.depth}');

  }

// @override
  // void didUpdateProvider(
  //   ProviderBase provider,
  //   Object? previousValue,
  //   Object? newValue,
  //   ProviderContainer container,
  // ) {
  //   logger.i(
  //       '${provider.name ?? provider.runtimeType}#${identityHashCode(provider)}');
  //   logger.i('OLD: ${previousValue.runtimeType}#${identityHashCode(previousValue)}');
  //   logger.i('new: ${previousValue.runtimeType}#${identityHashCode(previousValue)}');
  // }
}
