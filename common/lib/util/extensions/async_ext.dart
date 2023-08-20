/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:hooks_riverpod/hooks_riverpod.dart';

extension AlwaysAliveAsyncDataSelector<Input> on ProviderListenable<AsyncValue<Input>> {
  ProviderListenable<AsyncValue<Output>> selectAs<Output>(
    Output Function(Input data) selector,
  ) {
    return select((AsyncValue<Input> value) {
      /// This block of code handles transformation of AsyncValue instances, ensuring consistent behavior.
      /// We explicitly differentiate between data, error, and loading states while considering the previous value.
      /// If the previous value existed, we apply the selector function to transform the data, preventing issues with
      /// empty/new error/loading AsyncValue instances that lack values and might lead to unexpected behavior.

      return value.map(
        data: (data) => data.whenData(selector),
        error: (error) => error.hasValue
            ? AsyncData<Output>(selector(value.value as Input))
                .toError(error.error, error.stackTrace)
            : AsyncValue<Output>.error(error.error, error.stackTrace),
        loading: (loading) => loading.hasValue
            ? AsyncData<Output>(selector(value.value as Input)).toLoading()
            : AsyncValue<Output>.loading(),
      );
    });
  }
}

extension AsyncValueX<T> on AsyncValue<T> {
  T? get valueOrFullNull {
    if (hasValue && !isLoading && !hasError) return value;
    return null;
  }

  AsyncValue<T> toLoading() {
    return AsyncValue<T>.loading().copyWithPrevious(this);
  }

  AsyncValue<T> toError(Object error, StackTrace stackTrace) {
    return AsyncValue<T>.error(error, stackTrace).copyWithPrevious(this);
  }
}
