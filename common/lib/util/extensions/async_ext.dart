/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/util/extensions/object_extension.dart';
import 'package:common/util/logger.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// - [skipLoadingOnReload] (false by default) customizes whether [loading]
///   should be invoked if a provider rebuilds because of [Ref.watch].
///   In that situation, [when] will try to invoke either [error]/[data]
///   with the previous state.
extension AlwaysAliveAsyncDataSelector<Input> on ProviderListenable<AsyncValue<Input>> {
  ProviderListenable<AsyncValue<Output>> selectAs<Output>(
    Output Function(Input data) selector, {
    bool skipLoadingOnReload = false,
    bool debugLog = false,
  }) {
    return select((AsyncValue<Input> value) {
      /// This block of code handles transformation of AsyncValue instances, ensuring consistent behavior.
      /// We explicitly differentiate between data, error, and loading states while considering the previous value.
      /// If the previous value existed, we apply the selector function to transform the data, preventing issues with
      /// empty/new error/loading AsyncValue instances that lack values and might lead to unexpected behavior.
      if (debugLog) {
        logger.i('Select received $value');
      }

      /// This switch statement is used to handle different states of the original `AsyncValue` object.
      /// It takes an `AsyncValue` object as input and returns a new `AsyncValue` object based on the state of the input.
      final res = switch (value) {
        AsyncData(value: final data, isLoading: final isLoading) =>
          AsyncData<Output>(selector(data)).let((it) => isLoading ? it.toLoading() : it),
        AsyncError(error: final error, stackTrace: final stackTrace, hasValue: false, isLoading: final isLoading) =>
          AsyncValue<Output>.error(error, stackTrace).let((it) => isLoading ? it.toLoading() : it),
        AsyncError(value: final data?, hasValue: true, isLoading: final isLoading) =>
          AsyncValue<Output>.data(selector(data)).let((it) => isLoading ? it.toLoading() : it),
        AsyncLoading(hasValue: true, value: final data?) when skipLoadingOnReload =>
          AsyncValue<Output>.data(selector(data)),
        AsyncLoading(hasValue: true, value: final data?) => AsyncValue<Output>.data(selector(data)).toLoading(),
        _ => AsyncValue<Output>.loading(),
      };

      if (debugLog) {
        logger.i('Select returned $res');
      }

      return res;
      // ToDo: Remove the following code block, if the above code block works as expected.
      // return value.map(
      //   data: (data) {
      //     return data.whenData(selector);
      //   },
      //   error: (error) {
      //     var asyncValue = error.hasValue
      //         ? AsyncData<Output>(selector(value.value as Input)).toError(error.error, error.stackTrace)
      //         : AsyncValue<Output>.error(error.error, error.stackTrace).toLoading();
      //
      //     // Also handle the case where an error is loading
      //     if (error.isLoading) {
      //       return AsyncValue<Output>.loading().copyWithPrevious(asyncValue, isRefresh: true);
      //     }
      //
      //     return asyncValue;
      //   },
      //   loading: (loading) {
      //     if (!loading.hasValue) {
      //       return AsyncValue<Output>.loading();
      //     }
      //     final selectedValue = selector(value.value as Input);
      //
      //     if (loading.isReloading && skipLoadingOnReload) {
      //       return AsyncData<Output>(selectedValue);
      //     }
      //     return AsyncData<Output>(selectedValue).toLoading(!loading.isReloading);
      //   },
      // );
    });
  }

  /// Short
  ProviderListenable<Input> requireValue() => select((d) => d.requireValue);

  ProviderListenable<Output> selectRequireValue<Output>(Output Function(Input data) selector) {
    return select((AsyncValue<Input> value) => selector(value.requireValue));
  }
}

extension AsyncValueX<T> on AsyncValue<T> {
  T? get valueOrFullNull {
    if (hasValue && !isLoading && !hasError) return value;
    return null;
  }

  AsyncValue<T> toLoading([bool isRefresh = true]) {
    return AsyncValue<T>.loading().copyWithPrevious(this, isRefresh: isRefresh);
  }

  AsyncValue<T> toError(Object error, StackTrace stackTrace) {
    return AsyncValue<T>.error(error, stackTrace).copyWithPrevious(this);
  }

  // Wir laden und es ist kein reload (.watch forces refresh)
  bool get isLoadingOrRefreshWithError => (isLoading && !isReloading) || (hasError && isLoading);
}
