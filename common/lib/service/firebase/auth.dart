/*
 * Copyright (c) 2023-2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/scheduler.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../util/logger.dart';
import '../misc_providers.dart';

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

    // Firebase caches the user profile (e.g. emailVerified) locally and only
    // re-fetches it from the server on an explicit reload(). Without this,
    // verifying the email in a browser never reflects back into the app,
    // even across a full restart, since the stale cached user is persisted.
    // Only bother for non-anonymous accounts still pending verification -
    // emailVerified only ever flips false -> true, so once it's true (or the
    // user is anonymous/has no email) there's nothing left to refresh.
    ref.listen(appLifecycleProvider, (previous, next) {
      if (next != AppLifecycleState.resumed) return;
      var user = firebaseAuth.currentUser;
      if (user == null || user.isAnonymous || user.emailVerified) return;

      talker.info('App resumed with unverified email, reloading Firebase user');
      user.reload();
    });

    return firebaseAuth.userChanges();
  }
}
