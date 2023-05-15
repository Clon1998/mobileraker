import 'dart:async';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/logger.dart';

extension MobilerakerAutoDispose on AutoDisposeRef {
  // Future<T> watchUntil<T>(ProviderListenable<AsyncValue<T>> provider,
  //     bool Function(T) whereCb) {
  //   final completer = Completer<T>();
  //   onDispose(() {
  //     if (!completer.isCompleted) {
  //       completer.completeError(
  //           StateError('provider disposed before `where` could complete'));
  //     }
  //   });
  //
  //   late ProviderSubscription sub;
  //   sub = listen<AsyncValue<T>>(provider, (prev, next) {
  //     if (next.isRefreshing) return;
  //     next.when(
  //         data: (d) {
  //           if (whereCb(d)) {
  //             completer.complete(d);
  //             sub.close();
  //           }
  //         },
  //         error: (e, s) {
  //           completer.completeError(e, s);
  //           sub.close();
  //         },
  //         loading: () => null);
  //   }, fireImmediately: true);
  //   return completer.future;
  // }

  // Returns a stream that alwways issues the latest/cached value of the provider
  // if the provider has one, even if multiple listeners listen to the stream!
  Stream<T> watchAsSubject<T>(ProviderListenable<AsyncValue<T>> provider) {
    final ctrler = StreamController<T>();
    onDispose(() {
      ctrler.close();
    });

    listen<AsyncValue<T>>(provider, (prev, next) {
      if (next.isRefreshing) {
        return;
      }
      next.when(
          data: (d) {
            ctrler.add(d);
          },
          error: (e, s) {
            ctrler.addError(e, s);
          },
          // This does not work with all usage rn!...
          // loading: () {
          //   if (prev != null) invalidateSelf();
          // });
          loading: () => null);
    }, fireImmediately: true);
    return ctrler.stream;
  }

  /// Watches/Listens to the provided provider until the given whereCb is met!
  /// Similar to WATCH, only use this directly in a build method. Since it will trigger provider rebuilds!
  /// If you need to wait outside of a provider/builder use [readWhere]
  Future<T> watchWhere<T>(
      ProviderListenable<AsyncValue<T>> provider, bool Function(T) whereCb) {
    final completer = Completer<T>();
    onDispose(() {
      if (!completer.isCompleted) {
        completer.completeError(
            StateError('provider disposed before `where` could complete'));
      }
    });
    listen<AsyncValue<T>>(provider, (prev, next) {
      if (next.isRefreshing) return;
      next.when(
          data: (d) {
            if (whereCb(d)) {
              if (completer.isCompleted) {
                // ToDo:Reduce log level after investigating effect of it
                logger.w('watchWhere just forces owner to invalidate! Ref:$this');
                invalidateSelf();
              } else {
                completer.complete(d);
              }
            }
          },
          error: (e, s) {
            completer.completeError(e, s);
          },
          loading: () => null);
    }, fireImmediately: true);
    return completer.future;
  }

  Future<T> watchWhereNotNull<T>(ProviderListenable<AsyncValue<T?>> provider) {
    final completer = Completer<T>();
    onDispose(() {
      if (!completer.isCompleted) {
        completer.completeError(
            StateError('provider disposed before `where` could complete'),
            StackTrace.current);
      }
    });

    listen<AsyncValue<T?>>(provider, (prev, next) {
      if (next.isRefreshing) return;

      next.when(
          data: (d) {
            if (d != null) {
              if (completer.isCompleted) {
                invalidateSelf();
                logger.w('watchWhereNotNull just forces owner to invalidate! Ref: $this');
              } else {
                completer.complete(d);
              }
            }
          },
          error: (e, s) {
            completer.completeError(e, s);
          },
          loading: () => null);
    }, fireImmediately: true);
    return completer.future;
  }

  Future<T> readWhere<T>(
      ProviderListenable<AsyncValue<T>> provider, bool Function(T) whereCb) {
    final completer = Completer<T>();
    onDispose(() {
      if (!completer.isCompleted) {
        completer.completeError(
            StateError('provider disposed before `where` could complete'));
      }
    });

    ProviderSubscription sub = listen<AsyncValue<T>>(provider, (prev, next) {
      if (next.isRefreshing) return;
      if (completer.isCompleted) {
        return;
      }
      next.when(
          data: (d) {
            if (whereCb(d)) {
              completer.complete(d);
            }
          },
          error: (e, s) {
            completer.completeError(e, s);
          },
          loading: () => null);
    }, fireImmediately: true);
    completer.future.whenComplete(() => sub.close());
    return completer.future;
  }
}
