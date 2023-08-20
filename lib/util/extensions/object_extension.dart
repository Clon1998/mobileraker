/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

extension ScopeFunctions<R> on R {
  T let<T>(T Function(R it) fun) => fun(this);

  R also(Function(R it) fun) {
    fun(this);
    return this;
  }
}
