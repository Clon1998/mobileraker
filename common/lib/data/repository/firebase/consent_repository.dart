/*
 * Copyright (c) 2025. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:common/data/enums/consent_entry_type.dart';
import 'package:common/data/repository/crud_repository.dart';
import 'package:common/exceptions/mobileraker_exception.dart';
import 'package:common/util/logger.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../service/firebase/firestore.dart';
import '../../model/firestore/consent.dart';
import '../../model/firestore/consent_entry.dart';

part 'consent_repository.g.dart';

@Riverpod(keepAlive: true)
ConsentRepository consentRepository(Ref ref) {
  return ConsentRepository(ref.watch(firestoreProvider));
}

class ConsentRepository implements CRUDRepository<Consent, String> {
  ConsentRepository(
    FirebaseFirestore firestore,
  ) : _consentCollection = firestore.collection('consents').withConverter(
              fromFirestore: (snapshot, _) => Consent.fromJson(snapshot.data()!),
              toFirestore: (model, _) => model?.toJson() ?? {},
            );

  final CollectionReference<Consent?> _consentCollection;

  @override
  Future<List<Consent>> all() {
    throw UnsupportedError('all is not supported for consents');
  }

  @override
  Future<int> count() {
    throw UnsupportedError('count is not supported for consents');
  }

  @override
  Future<void> create(Consent entity) async => _createOrUpdate(entity, 'create');

  @override
  Future<Consent> delete(String id) async {
    final doc = await _consentCollection.doc(id).get();
    if (!doc.exists) {
      talker.info('[ConsentRepository] consent with id $id does not exist');
      throw MobilerakerException('Consent with id $id does not exist');
    }

    await _consentCollection.doc(id).delete();

    return doc.data()!;
  }

  @override
  Future<Consent?> read({String? id, int index = -1}) async {
    assert(id != null || index >= 0);
    // Basically I need to first get the document with the given ID, afterwards I need to get each of the subCollections!
    talker.info('[ConsentRepository] trying to read consent with id: $id');

    // The consentObject without the collections
    final consentDoc = _consentCollection.doc(id);
    var rawConsentObject = await consentDoc.get();
    if (!rawConsentObject.exists) {
      talker.info('[ConsentRepository] consent with id $id does not exist');
      return null;
    }

    talker.info('[ConsentRepository] got consent object: ${rawConsentObject.data()}');

    // Get the entries
    var entiresRef = await consentDoc
        .collection('entries')
        .withConverter(
          fromFirestore: (snapshot, _) => ConsentEntry.fromJson(snapshot.data()!),
          toFirestore: (model, _) => model.toJson(),
        )
        .get();

    talker.info('[ConsentRepository] got entries: ${entiresRef.docs.map((e) => e.data())}');

    return rawConsentObject.data()?.copyWith(entries: {
      for (QueryDocumentSnapshot<ConsentEntry> entry in entiresRef.docs)
        ConsentEntryType.fromJson(entry.id): entry.data(),
    });
  }

  @override
  Future<void> update(Consent entity) => _createOrUpdate(entity, 'update');

  Future<void> _createOrUpdate(Consent entity, String type) async {
    talker.info('[ConsentRepository] trying to $type consent: $entity');
    final consentDoc = _consentCollection.doc(entity.idHash);
    await consentDoc.set(entity);
    talker.info('[ConsentRepository] ${type}ed consentDoc with id: ${consentDoc.id}');

    talker.info('[ConsentRepository] trying to $type entries for consent: $entity');
    for (var entry in entity.entries.entries) {
      await consentDoc.collection('entries').doc(entry.key.toJsonEnum()).set(entry.value.toJson());
    }
    talker.info('[ConsentRepository] ${type}ed entries for consent: $entity');
  }
}
