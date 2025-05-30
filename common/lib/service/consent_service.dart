/*
 * Copyright (c) 2025. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:async';

import 'package:common/data/enums/consent_entry_type.dart';
import 'package:common/data/enums/consent_status.dart';
import 'package:common/data/model/firestore/consent_entry.dart';
import 'package:common/data/repository/firebase/consent_repository.dart';
import 'package:common/service/firebase/auth.dart';
import 'package:common/util/logger.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hashlib/hashlib.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/model/firestore/consent.dart';
import '../data/model/firestore/consent_entry_history.dart';

part 'consent_service.g.dart';

@Riverpod(keepAlive: true)
ConsentService consentService(Ref ref) {
  final consentService = ConsentService(consentRepository: ref.watch(consentRepositoryProvider));
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
    required ConsentRepository consentRepository,
  }) : _consentRepository = consentRepository;

  final ConsentRepository _consentRepository;

  final StreamController<Consent> _consentStreamController = StreamController();

  Stream<Consent> get consentStream => _consentStreamController.stream;

  Consent? _current;

  Consent get currentConsent => _current!;

  set currentConsent(Consent nI) {
    if (_consentStreamController.isClosed) {
      talker.warning('Tried to set a currentConsent value on a disposed service? ${identityHashCode(this)}', null,
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
    talker.info('[ConsentService] Updating consent entry: $type to $newStatus');
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
      await _consentRepository.update(newConsent);
      talker.info('[ConsentService] Completed updating consent entry: $type to $newStatus');
      currentConsent = newConsent;
      return newConsent;
    } catch (e, s) {
      talker.error('[ConsentService] Error updating consent entry', e, s);
      //TODO: Decide if I want to do this?
      _consentStreamController.addError(e, s);
      rethrow;
    }
  }

  /// Resets the user. Primarly for testing purposes.
  Future<Consent> resetUser() async {
    talker.info('[ConsentService] Resetting user consent data');

    try {
      var idHash = currentConsent.idHash;
      await _consentRepository.delete(idHash);
      talker.info('[ConsentService] Completed resetting user consent data');

      return _createNewConsentDoc(idHash);
    } catch (e, s) {
      talker.error('[ConsentService] Error updating consent entry', e, s);
      //TODO: Decide if I want to do this?
      _consentStreamController.addError(e, s);
      rethrow;
    }
  }

  Future<void> _updateConsentDataIfNecessary(String fireaseUserId) async {
    talker.info('[ConsentService] Updating consent data for user: $fireaseUserId');
    final hashDigest = sha256.string(fireaseUserId);
    talker.info('[ConsentService] Hashed fireaseUserId token:sha256($fireaseUserId)=$hashDigest');
    final hashId = hashDigest.hex();

    try {
      talker.info('[ConsentService] Fetching consent data for hash: $hashId');
      var consent = await _consentRepository.read(id: hashId);
      if (consent == null) {
        talker.info('[ConsentService] Consent data does not exist.');
        consent = await _createNewConsentDoc(hashId);
      } else {
        talker.info('[ConsentService] Consent data exists: $consent');
      }
      currentConsent = consent;
    } catch (e, s) {
      talker.error('[ConsentService] Error fetching consent data for hash: $hashId', e, s);
      _consentStreamController.addError(e, s);
    }
  }

  Future<Consent> _createNewConsentDoc(String hashId) async {
    talker.info('[ConsentService] Creating new consent document for hash: $hashId');
    final consent = Consent.empty(hashId);
    _consentRepository.create(consent);
    talker.info('[ConsentService] New consent document created: $hashId');
    return consent;
  }

  void dispose() {
    _consentStreamController.close();
  }
}
