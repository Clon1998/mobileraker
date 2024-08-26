/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

///
/// Returns whether or not a [child] is within a [parent] and returns its level.
/// Returns:
/// -1 => Not within parent
/// 0 => Is located directly in parents folder
/// 1 => Is in 1 sublevel of parent
/// ...
int isWithin(String parent, String child) {
  List<String> parentPath = parent.split('/');
  List<String> childPath = child.split('/');
  if (childPath.isEmpty) return -1;
  int childPathLen = childPath.length - 1;

  if (parentPath.length > childPathLen) return -1;

  if (parent == childPath.sublist(0, parentPath.length).join('/')) {
    return childPathLen - parentPath.length;
  }
  return -1;
}

bool isFilePath(String path) => baseName(path).split('.').length > 1;

String baseName(String path) => path.split('/').last;
