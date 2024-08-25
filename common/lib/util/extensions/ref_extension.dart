/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:async';

import 'package:common/util/logger.dart';
import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

extension MobilerakerAutoDispose on AutoDisposeRef {
  // Returns a stream that alwways issues the latest/cached value of the provider
  // if the provider has one, even if multiple listeners listen to the stream!
  Stream<T> watchAsSubject<T>(ProviderListenable<AsyncValue<T>> provider,
      {bool skipLoadingOnReload = false, bool skipLoadingOnRefresh = true, bool asSubject = true}) {
    final ctrler = StreamController<T>();
    onDispose(() {
      ctrler.close();
    });

    listen<AsyncValue<T>>(provider, (prev, next) {
      if (next.isRefreshing) {
        logger.e('isRefreshing SKIPPED');
        return;
      }
      next.when(
        skipLoadingOnReload: skipLoadingOnReload,
        skipLoadingOnRefresh: skipLoadingOnRefresh,
        data: (d) {
          ctrler.add(d);
        },
        error: (e, s) {
          ctrler.addError(e, s);
        },
        // This does not work with all usage rn!...
        loading: () {
          if (prev != null) invalidateSelf();
        },
      );
      // loading: () => null);
    }, fireImmediately: asSubject);
    return ctrler.stream;
  }

  /// Watches and listens to a provider for changes that satisfy the given condition.
  ///
  /// This method returns a future that completes when the condition specified by [evaluatePredicate] is met.
  /// The method continues to monitor the provider for any changes in condition status.
  /// If the condition changes, the caller is required to invalidate and trigger a rebuild.
  ///
  /// If you need to wait outside of a provider or builder context, use the [readWhere] method.
  ///
  /// The generic type parameter [T] represents the type of data expected from the provider.
  ///
  /// The [provider] parameter is the object to watch and listen for changes.
  /// The [evaluatePredicate] parameter is a predicated function that takes an object of type [T] and returns
  /// a boolean value indicating whether the condition is met.
  ///
  /// The optional parameter [throwIfDisposeBeforeComplete] determines whether an error should be thrown
  /// if the provider is disposed before the completion of the watch operation.
  ///
  /// This method returns a future of type [T] that resolves with the data when the condition is met.
  /// If an error occurs during the watch operation, the future completes with an error.
  ///
  @Deprecated('Use a stream and async* instead, see jrpc_client_provider.dart for an example!')
  Future<T> watchWhere<T>(ProviderListenable<AsyncValue<T>> provider, bool Function(T) evaluatePredicate,
      [bool throwIfDisposeBeforeComplete = true]) {
    final completer = Completer<T>();
    onDispose(() {
      if (!completer.isCompleted && throwIfDisposeBeforeComplete) {
        logger.e('Provider with ref $this diposed before `where` could complete');
        completer.completeError(StateError('provider disposed before `where` could complete'), StackTrace.current);
      }
    });
    listen<AsyncValue<T>>(provider, (prev, next) {
      if (next.isRefreshing) return;
      next.when(
          data: (d) {
            if (evaluatePredicate(d)) {
              if (completer.isCompleted) {
                logger.i('watchWhere just forces owner to invalidate! Ref:$this');
                invalidateSelf();
              } else {
                completer.complete(d);
              }
            } else {
              if (completer.isCompleted) {
                if (kDebugMode) logger.e('THIS IS NEW 11 $this');
                invalidateSelf();
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

  /// See [watchWhere], shorthand to ensure provider is not null!
  @Deprecated('Use a stream and async* instead, see file_service.dart for an example!')
  Future<T> watchWhereNotNull<T>(ProviderListenable<AsyncValue<T?>> provider) {
    final completer = Completer<T>();
    onDispose(() {
      if (!completer.isCompleted) {
        logger.e('Provider with ref $this diposed before `whereNotNull` could complete');
        completer.completeError(
            StateError('provider disposed before `whereNotNull` could complete'), StackTrace.current);
      }
    });

    listen<AsyncValue<T?>>(provider, (prev, next) {
      if (next.isRefreshing) return;

      next.when(
          data: (d) {
            if (d != null) {
              if (completer.isCompleted) {
                invalidateSelf();
                logger.w(
                    'watchWhereNotNull just forces owner to invalidate because a updated value is available! Ref: $this');
              } else {
                completer.complete(d);
              }
            } else {
              if (completer.isCompleted) {
                if (kDebugMode) logger.e('THIS IS NEW NULL');
                invalidateSelf();
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

  /// This method returns a future that completes with the current value of the provider
  /// when the condition specified by [evaluatePredicate] is met. The method immediately reads the
  /// initial value from the provider and stops listening for changes once the condition is met.
  Future<T> readWhere<T>(ProviderListenable<AsyncValue<T>> provider, bool Function(T) evaluatePredicate,
      [bool throwIfDisposeBeforeComplete = true]) {
    final completer = Completer<T>();
    onDispose(() {
      if (!completer.isCompleted && throwIfDisposeBeforeComplete) {
        logger.e('Provider with ref $this diposed before `read` could complete');
        completer.completeError(
            StateError('provider disposed before `read` could complete for ref:$this'), StackTrace.current);
      }
    });

    ProviderSubscription sub = listen<AsyncValue<T>>(provider, (prev, next) {
      if (next.isRefreshing) return;
      if (completer.isCompleted) {
        return;
      }
      next.when(
          data: (d) {
            if (evaluatePredicate(d)) {
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

  /// Helper method to externally keep a provider alive without the need to watch it!
  ProviderSubscription<T> keepAliveExternally<T>(ProviderListenable<T> provider) {
    var providerSubscription = listen(provider, (_, __) {});
    onDispose(() => providerSubscription.close());
    return providerSubscription;
  }

  /// Adds the ability to automatically dispose a provider
  /// after it has not been listened to for a specified duration.
  ///
  /// This method creates a `KeepAliveLink` and sets a timer. If the provider is not listened
  /// to within the specified [timeout] duration (default 30 seconds), the provider is
  /// automatically disposed. This is useful for cleaning up resources when a provider
  /// is no longer needed.
  ///
  /// Usage:
  /// ```dart
  /// final myProvider = Provider<int>((ref) {
  ///   // Provider logic here
  /// });
  ///
  /// final myRef = AutoDisposeRef.read(myProvider);
  ///
  /// final keepAliveLink = myRef.timeoutKeepAlive(Duration(seconds: 60));
  /// // The myProvider will be automatically disposed if not listened to for 60 seconds.
  /// ```
  ///
  /// Parameters:
  /// - [timeout]: The duration of inactivity after which the provider will be disposed.
  ///
  /// Returns a [KeepAliveLink] that can be used to manually close the link before the timeout
  /// if needed.
  KeepAliveLink keepAliveFor([Duration timeout = const Duration(seconds: 30)]) {
    var link = keepAlive();

    Timer? timer;
    onCancel(() => timer = Timer(timeout, () => link.close()));
    onResume(() => timer?.cancel());
    onDispose(() => timer?.cancel());
    return link;
  }
}

extension MobilerakerWidgetRef on WidgetRef {
  /// Helper method to externally keep a provider alive without the need to watch it!
  ProviderSubscription<T> keepAliveExternally<T>(ProviderListenable<T> provider) {
    var providerSubscription = listenManual(provider, (_, __) {});
    return providerSubscription;
  }
}