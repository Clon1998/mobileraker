import 'dart:async';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/logger.dart';

extension MobilerakerRef on Ref {
  // Future<T> watchUntil<T>(AlwaysAliveProviderListenable<AsyncValue<T>> provider,
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

  Future<T> watchWhere<T>(AlwaysAliveProviderListenable<AsyncValue<T>> provider,
      bool Function(T) whereCb) {
    final completer = Completer<T>();
    onDispose(() {
      if (!completer.isCompleted) {
        completer.completeError(
            StateError('provider disposed before `where` could complete'));
      }
    });

    listen<AsyncValue<T>>(provider, (prev, next) {
      if (next.isRefreshing) return;
      if (completer.isCompleted) {
        invalidateSelf();
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
    return completer.future;
  }

  Future<T> watchWhereNotNull<T>(
      AlwaysAliveProviderListenable<AsyncValue<T?>> provider) {
    final completer = Completer<T>();
    onDispose(() {
      if (!completer.isCompleted) {
        completer.completeError(
            StateError('provider disposed before `where` could complete'), StackTrace.current);
      }
    });

    listen<AsyncValue<T?>>(provider, (prev, next) {
      if (next.isRefreshing) return;
      if (completer.isCompleted) {
        invalidateSelf();
        return;
      }
      next.when(
          data: (d) {
            if (d != null) {
              completer.complete(d);
            }
          },
          error: (e, s) {
            completer.completeError(e, s);
          },
          loading: () => null);
    }, fireImmediately: true);
    return completer.future;
  }

  Stream<T> watchAsSubject<T>(AlwaysAliveProviderBase<AsyncValue<T>> provider) {
    final ctrler = StreamController<T>();
    onDispose(() {
      ctrler.close();
    });

    listen<AsyncValue<T>>(provider, (prev, next) {
      if (next.isRefreshing) return;
      next.when(
          data: (d) {
            ctrler.add(d);
          },
          error: (e, s) {
            ctrler.addError(e, s);
          },
          loading: () => null);
    }, fireImmediately: true);
    return ctrler.stream;
  }
}

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
          loading: () => null);
    }, fireImmediately: true);
    return ctrler.stream;
  }
}
