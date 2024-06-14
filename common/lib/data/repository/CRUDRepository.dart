/*
 * Copyright (c) 2024. Patrick Schmidt.
 * All rights reserved.
 */

abstract interface class CRUDRepository<T, ID> {
  Future<void> create(T entity);

  Future<T?> read({ID uuid, int index = -1});

  Future<void> update(T entity);

  Future<T> delete(String uuid);

  Future<List<T>> all();

  Future<int> count();
}
