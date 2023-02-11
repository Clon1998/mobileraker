import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:logger/logger.dart';

final logger =
    Logger(printer: PrettyPrinter(methodCount: 0, noBoxingByDefault: true));

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
    var familiy = provider.argument?.toString() ?? '';
    logger.wtf(
        'RiverPod::DISPOSED:${provider.name ?? provider.runtimeType}#${identityHashCode(provider)} $familiy');
  }

  @override
  void didAddProvider(
      ProviderBase provider, Object? value, ProviderContainer container) {
    var familiy = provider.argument?.toString() ?? '';
    logger.wtf(
        'RiverPod::CREATED-> ${provider.name ?? provider.runtimeType}#${identityHashCode(provider)} $familiy WITH PARENT? ${container.depth}');
  }
  //
  // @override
  // void didUpdateProvider(
  //   ProviderBase provider,
  //   Object? previousValue,
  //   Object? newValue,
  //   ProviderContainer container,
  // ) {
  //   var familiy = provider.argument?.toString() ?? '';
  //   var providerStr =
  //       '${provider.name ?? provider.runtimeType}#${identityHashCode(provider)}$familiy';
  //
  //   logger.wtf(
  //       'RiverPod::UPDATE-old-> $providerStr ${identityHashCode(previousValue)}:${previousValue.toString().truncate(200)}');
  //   logger.wtf(
  //       'RiverPod::UPDATE-new->$providerStr ${identityHashCode(newValue)}:${newValue.toString().truncate(200)}');
  // }
}
