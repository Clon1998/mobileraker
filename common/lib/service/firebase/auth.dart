/*
 * Copyright (c) 2023-2025. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:firebase_auth/firebase_auth.dart';
import 'package:riverpod/riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../util/logger.dart';

part 'auth.g.dart';

@Riverpod(keepAlive: true)
FirebaseAuth auth(Ref ref) {
  return FirebaseAuth.instance;
}

@Riverpod(keepAlive: true)
class FirebaseUser extends _$FirebaseUser {
  @override
  Stream<User?> build() {
    var firebaseAuth = ref.watch(authProvider);
    listenSelf((AsyncValue<User?>? previous, next) {
      talker.info('Firebase Auth User changed from $previous to $next');

      if (next case AsyncData(value: null)) {
        talker.info('Firebase Auth User is null, can safely log in as annonymous user');
        firebaseAuth.signInAnonymously();
      }
    });

    return firebaseAuth.userChanges();
  }
}
