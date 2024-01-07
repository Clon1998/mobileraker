/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:firebase_auth/firebase_auth.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../util/logger.dart';

part 'auth.g.dart';

@Riverpod(keepAlive: true)
FirebaseAuth auth(AuthRef ref) {
  return FirebaseAuth.instance;
}

@Riverpod(keepAlive: true)
Stream<User?> firebaseUser(FirebaseUserRef ref) {
  var firebaseAuth = ref.watch(authProvider);

  ref.listenSelf((previous, next) {
    logger.i('Firebase Auth User changed from $previous to $next');
  });
  return firebaseAuth.authStateChanges();
}
