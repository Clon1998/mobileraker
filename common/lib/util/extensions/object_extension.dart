/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

/// This extension adds several scope functions to any object of type [R].
///
/// Scope functions allow you to perform operations on an object within a certain scope.
/// They can be used to avoid repeating the object's name, to perform a sequence of operations
/// on the same object, or to manage resources such as streams or files.
extension ScopeFunctions<R> on R {
  /// Returns this [R] object if [cond] is true, otherwise returns null.
  ///
  /// This can be used to perform an operation on [R] only if a certain condition is true.
  /// Opposite of [unless].
  @pragma('vm:prefer-inline')
  R? only(bool cond) => cond ? this : null;

  /// Returns this [R] object if [cond] is false, otherwise returns null.
  ///
  /// This can be used to perform an operation on [R] only if a certain condition is false.
  /// Opposite of [only].
  @pragma('vm:prefer-inline')
  R? unless(bool cond) => cond ? null : this;

  /// Calls the specified function [fun] with this value as its argument and returns its result.
  ///
  /// This can be used to pass the current object to a function and continue with its result.
  @pragma("vm:prefer-inline")
  T let<T>(T Function(R it) fun) => fun(this);

  /// Calls the specified function [fun] with this value as its argument and returns this value unchanged.
  ///
  /// This can be used to perform an side effect operation on an object and then return the object itself.
  R also(Function(R it) fun) {
    fun(this);
    return this;
  }

// /// Calls the specified function [fun] with this value as its argument and returns this value unchanged.
// ///
// /// This is similar to [also], but the function [fun] is a void function.
// R apply(void Function(R it) fun) {
//   fun(this);
//   return this;
// }
}
