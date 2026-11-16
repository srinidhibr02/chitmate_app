/// How a group is written to, and read from, the cloud database.
///
/// A group is one document. `data` holds the whole group; the other fields are
/// copied out of it so that security rules and queries can use them:
/// `adminUid` (who may change it) and `memberPhones` (who may see it).
library;

import '../domain/models.dart';

/// Oldest feed entries are dropped from the cloud copy beyond this, to stay
/// well inside the database's 1 MB document limit.
const int kMaxCloudFeedEntries = 400;

Map<String, dynamic> groupToDoc(ChitGroup g) {
  final json = g.toJson();
  final feed = json['feed'];
  if (feed is List && feed.length > kMaxCloudFeedEntries) {
    json['feed'] = feed.sublist(feed.length - kMaxCloudFeedEntries);
  }
  return <String, dynamic>{
    'adminUid': g.adminUid,
    'memberPhones': memberPhonesOf(g),
    'data': json,
  };
}

/// Phone numbers of the people who are in the group now. Anyone who left is
/// left out, so they lose access.
List<String> memberPhonesOf(ChitGroup g) {
  final out = <String>{};
  for (final m in g.activeMembers) {
    final p = m.phone;
    if (p != null && p.isNotEmpty) out.add(p);
  }
  return out.toList()..sort();
}

/// Returns null when the document is not a readable group.
ChitGroup? groupFromDoc(Map<String, dynamic>? doc) {
  if (doc == null) return null;
  final data = doc['data'];
  if (data is! Map) return null;
  try {
    final g = ChitGroup.fromJson(data.cast<String, dynamic>());
    final admin = doc['adminUid'];
    if (admin is String && admin.isNotEmpty) g.adminUid = admin;
    return g;
  } catch (_) {
    return null;
  }
}
