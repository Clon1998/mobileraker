/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

extension ScopeFunctions<R> on R {
  T let<T>(T Function(R) fun) => fun(this);
}
