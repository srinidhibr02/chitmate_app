/// The shared database of groups. [FirestoreGroupStore] is the real one;
/// [InMemoryCloudStore] stands in for it in tests.
library;

import 'dart:async';

import '../data/group_codec.dart';
import '../domain/models.dart';
import 'auth_service.dart';

abstract class CloudGroupStore {
  /// The groups [user] can see (as organiser or as a member, matched by phone
  /// number). Emits again whenever any of them changes.
  Stream<List<ChitGroup>> watchGroups(AppUser user);

  /// Creates or updates a group. Only the organiser is allowed to.
  Future<void> saveGroup(ChitGroup group);

  Future<void> deleteGroup(String groupId);
}

/// A database kept in memory. It copies groups through the same document
/// format as the real one, so tests see what the cloud would return.
class InMemoryCloudStore implements CloudGroupStore {
  final Map<String, Map<String, dynamic>> _docs = <String, Map<String, dynamic>>{};
  final StreamController<void> _changes = StreamController<void>.broadcast();

  /// When set, [saveGroup] and [deleteGroup] fail with this error.
  Object? failWith;

  int saves = 0;

  List<ChitGroup> _visibleTo(AppUser user) {
    final out = <ChitGroup>[];
    for (final doc in _docs.values) {
      final phones = (doc['memberPhones'] as List).cast<String>();
      if (phones.contains(user.phone)) {
        final g = groupFromDoc(_copy(doc));
        if (g != null) out.add(g);
      }
    }
    out.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return out;
  }

  @override
  Stream<List<ChitGroup>> watchGroups(AppUser user) async* {
    yield _visibleTo(user);
    await for (final _ in _changes.stream) {
      yield _visibleTo(user);
    }
  }

  @override
  Future<void> saveGroup(ChitGroup group) async {
    final err = failWith;
    if (err != null) throw err;
    saves++;
    _docs[group.id] = _copy(groupToDoc(group));
    _changes.add(null);
  }

  @override
  Future<void> deleteGroup(String groupId) async {
    final err = failWith;
    if (err != null) throw err;
    _docs.remove(groupId);
    _changes.add(null);
  }

  /// Read a stored group directly (for assertions).
  ChitGroup? peek(String id) => groupFromDoc(_docs[id] == null ? null : _copy(_docs[id]!));

  bool contains(String id) => _docs.containsKey(id);

  static Map<String, dynamic> _copy(Map<String, dynamic> m) => _deep(m) as Map<String, dynamic>;

  static Object? _deep(Object? v) {
    if (v is Map) return <String, dynamic>{for (final e in v.entries) e.key as String: _deep(e.value)};
    if (v is List) return <Object?>[for (final e in v) _deep(e)];
    return v;
  }
}
