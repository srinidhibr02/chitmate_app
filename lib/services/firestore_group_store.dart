/// Cloud Firestore implementation of [CloudGroupStore].
///
/// Collection `groups`, one document per group (see `group_codec.dart`).
/// Security rules (firestore.rules) let the organiser write, and let anyone
/// whose sign-in phone number is in `memberPhones` read.
library;

import 'package:cloud_firestore/cloud_firestore.dart';

import '../data/group_codec.dart';
import '../domain/models.dart';
import 'auth_service.dart';
import 'cloud_store.dart';

class FirestoreGroupStore implements CloudGroupStore {
  FirestoreGroupStore([FirebaseFirestore? db]) : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _groups => _db.collection('groups');

  @override
  Stream<List<ChitGroup>> watchGroups(AppUser user) {
    return _groups.where('memberPhones', arrayContains: user.phone).snapshots().map((snap) {
      final out = <ChitGroup>[];
      for (final d in snap.docs) {
        final g = groupFromDoc(d.data());
        if (g != null) out.add(g);
      }
      out.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return out;
    });
  }

  @override
  Future<void> saveGroup(ChitGroup group) {
    final doc = groupToDoc(group)..['updatedAt'] = FieldValue.serverTimestamp();
    return _groups.doc(group.id).set(doc);
  }

  @override
  Future<void> deleteGroup(String groupId) => _groups.doc(groupId).delete();
}
