/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

sealed class ModelEvent<T> {
  final T data;

  final String key;

  ModelEvent(this.data, this.key);

  factory ModelEvent.insert(T data, String key) => ModelEventInsert(data, key);

  factory ModelEvent.update(T data, String key) => ModelEventUpdate(data, key);

  factory ModelEvent.delete(T data, String key) => ModelEventDelete(data, key);
}

class ModelEventInsert<T> extends ModelEvent<T> {
  // Data represents the new data
  ModelEventInsert(super.data, super.key);
}

class ModelEventUpdate<T> extends ModelEvent<T> {
  // Data represents the object with updates
  ModelEventUpdate(super.data, super.key);
}

class ModelEventDelete<T> extends ModelEvent<T> {
  // Data represents the deleted object
  ModelEventDelete(super.data, super.key);
}
