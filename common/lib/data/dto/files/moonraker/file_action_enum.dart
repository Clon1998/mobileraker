/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

enum FileAction {
  create_file, // ignore: constant_identifier_names
  create_dir, // ignore: constant_identifier_names
  delete_file, // ignore: constant_identifier_names
  delete_dir, // ignore: constant_identifier_names
  move_file, // ignore: constant_identifier_names
  move_dir, // ignore: constant_identifier_names
  modify_file, // ignore: constant_identifier_names
  root_update // ignore: constant_identifier_names
}
