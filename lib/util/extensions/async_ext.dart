import 'package:hooks_riverpod/hooks_riverpod.dart';

extension AlwaysAliveAsyncDataSelector<Input>
    on ProviderListenable<AsyncValue<Input>>{
  ProviderListenable<AsyncValue<Output>> selectAs<Output>(
    Output Function(Input data) selector,
  ) {
    return select(
        (AsyncValue<Input> value) => value.whenData<Output>(selector));
  }
}



extension AsyncValueX<T> on AsyncValue<T> {

  T? get valueOrFullNull {
    if (hasValue && !isLoading && !hasError) return value;
    return null;
  }
}
