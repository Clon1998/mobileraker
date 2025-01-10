/*
 * Copyright (c) 2025. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:common/data/enums/consent_entry_type.dart';
import 'package:common/data/enums/consent_status.dart';
import 'package:common/data/model/firestore/consent_entry.dart';
import 'package:common/service/firebase/auth.dart';
import 'package:common/util/logger.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hashlib/hashlib.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/model/firestore/consent.dart';
import '../data/model/firestore/consent_entry_history.dart';
import 'firebase/firestore.dart';

part 'consent_service.g.dart';

@Riverpod(keepAlive: true)
ConsentService consentService(Ref ref) {
  final consentService = ConsentService(firestore: ref.watch(firestoreProvider));
  ref.listen(firebaseUserProvider, consentService.onFirebaseUserChanged, fireImmediately: true);
  ref.onDispose(consentService.dispose);

  return consentService;
}

@Riverpod(keepAlive: true)
Stream<Consent> consent(Ref ref) {
  return ref.watch(consentServiceProvider).consentStream;
}

@Riverpod(keepAlive: true)
Future<ConsentEntry?> consentEntry(Ref ref, ConsentEntryType type) {
  return ref.watch(consentProvider.selectAsync((consent) => consent.entries[type]));
}

class ConsentService {
  ConsentService({
    required FirebaseFirestore firestore,
  }) : _consentCollection = firestore.collection('consents').withConverter(
              fromFirestore: (snapshot, _) => Consent.fromJson(snapshot.data()!),
              toFirestore: (model, _) => model?.toJson() ?? {},
            );

  CollectionReference<Consent?> _consentCollection;

  StreamController<Consent> _consentStreamController = StreamController();

  Stream<Consent> get consentStream => _consentStreamController.stream;

  Consent? _current;

  Consent get currentConsent => _current!;

  set currentConsent(Consent nI) {
    if (_consentStreamController.isClosed) {
      logger.w('Tried to set a currentConsent value on a disposed service? ${identityHashCode(this)}', null,
          StackTrace.current);
      return;
    }
    _current = nI;
    _consentStreamController.add(nI);
  }

  void onFirebaseUserChanged(AsyncValue<User?>? prev, AsyncValue<User?> next) {
    if (next.valueOrNull == null) return;

    _updateConsentDataIfNecessary(next.value!.uid);
  }

  Future<Consent> updateConsentEntry(ConsentEntryType type, ConsentStatus newStatus) async {
    logger.i('[ConsentService] Updating consent entry: $type to $newStatus');
    final entry = currentConsent.entries[type]!;
    final newConsent = currentConsent.copyWith(
      entries: {
        ...currentConsent.entries,
        type: entry.copyWith(
          status: newStatus,
          lastUpdate: DateTime.now(),
          history: [
            ConsentEntryHistory.fromEntry(entry),
            ...entry.history,
          ],
        ),
      },
      lastUpdate: DateTime.now(),
    );
    try {
      await _consentCollection.doc(currentConsent.idHash).set(newConsent);
      logger.i('[ConsentService] Completed updating consent entry: $type to $newStatus');
      currentConsent = newConsent;
      return newConsent;
    } catch (e, s) {
      logger.e('[ConsentService] Error updating consent entry', e, s);
      //TODO: Decide if I want to do this?
      _consentStreamController.addError(e, s);
      rethrow;
    }
  }

  Future<void> _updateConsentDataIfNecessary(String fireaseUserId) async {
    logger.i('[ConsentService] Updating consent data for user: $fireaseUserId');
    final hashDigest = sha256.string(fireaseUserId);
    logger.i('[ConsentService] Hashed fireaseUserId token:sha256($fireaseUserId)=$hashDigest');
    final hashId = hashDigest.hex();

    Consent consent;
    try {
      logger.i('[ConsentService] Fetching consent data for hash: $hashId');
      var documentSnapshot = await _consentCollection.doc(hashId).get();
      if (documentSnapshot.exists) {
        logger.i('[ConsentService] Consent data exists.');
        consent = documentSnapshot.data()!;
      } else {
        logger.i('[ConsentService] Consent data does not exist.');
        consent = await _createNewConsentDoc(hashId);
      }
      currentConsent = consent;
    } catch (e, s) {
      logger.e('[ConsentService] Error fetching consent data for hash: $hashId', e, s);
      _consentStreamController.addError(e, s);
    }
  }

  Future<Consent> _createNewConsentDoc(String hashId) async {
    logger.i('[ConsentService] Creating new consent document for hash: $hashId');
    final consent = Consent.empty(hashId);
    await _consentCollection.doc(hashId).set(consent);
    logger.i('[ConsentService] New consent document created: $hashId');
    return consent;
  }

  void dispose() {
    _consentStreamController.close();
  }
}
