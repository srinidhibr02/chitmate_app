/// Plain data for a chit group. No Flutter imports: this layer can be tested
/// with `flutter test` without any UI.
///
/// Money is stored as whole rupees (`int`). A chit's shares always add up to
/// the group's chit value, so every payout (`share x number of chits`) is an
/// exact whole number of rupees too.
library;

import '../core/dates.dart';
import '../core/format.dart';

/// How the winning chit of a round is chosen.
enum RoundMethod { vote, manual, random }

/// What happens when a vote ends level.
enum TieBreakMode { auto, admin }

/// Where a round is in its life.
enum RoundStatus { pending, open, awaitingTieBreak, completed }

/// What kind of entry sits in the updates feed.
enum FeedKind { announcement, system, change }

/// Payment state of one member for one round.
enum PaymentStatus { paid, partial, pending, overdue }

T _enumByName<T extends Enum>(List<T> values, Object? name, T fallback) {
  for (final v in values) {
    if (v.name == name) return v;
  }
  return fallback;
}

DateTime? _dateOrNull(Object? v) =>
    v is String ? DateTime.tryParse(v) : null;

class Member {
  Member({
    required this.id,
    required this.name,
    this.phone,
    this.left = false,
    this.leftAt,
  });

  final String id;
  String name;

  /// Sign-in number in the form +91XXXXXXXXXX. It identifies the person: adding
  /// the same number again brings back a member who left.
  String? phone;

  /// True once the member has been removed from the group. Their chit shares
  /// and payments stay on record, but they no longer vote.
  bool left;
  DateTime? leftAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'phone': phone,
        'left': left,
        'leftAt': leftAt?.toIso8601String(),
      };

  factory Member.fromJson(Map<String, dynamic> j) => Member(
        id: j['id'] as String,
        name: j['name'] as String,
        phone: j['phone'] as String?,
        left: j['left'] == true,
        leftAt: _dateOrNull(j['leftAt']),
      );
}

/// One chit. Its [shares] (member id -> rupees) always add up to the chit
/// value of the group.
class Chit {
  Chit({
    required this.id,
    required this.number,
    required Map<String, int> shares,
  }) : shares = Map<String, int>.of(shares);

  final String id;

  /// Display number (Chit 1, Chit 2 ...). Fixed once the cycle starts.
  final int number;

  /// member id -> rupees put into this chit every month.
  Map<String, int> shares;

  Iterable<String> get ownerIds => shares.keys;

  /// True when one person owns the whole chit.
  bool get isFull => shares.length == 1;

  bool ownedBy(String memberId) => shares.containsKey(memberId);

  int get total => shares.values.fold<int>(0, (a, b) => a + b);

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'number': number,
        'shares': shares,
      };

  factory Chit.fromJson(Map<String, dynamic> j) {
    final raw = (j['shares'] as Map).cast<String, Object?>();
    return Chit(
      id: j['id'] as String,
      number: j['number'] as int,
      shares: <String, int>{
        for (final e in raw.entries) e.key: (e.value as num).toInt(),
      },
    );
  }
}

class Vote {
  const Vote({required this.voterId, required this.targetId, required this.at});

  final String voterId;
  final String targetId;
  final DateTime at;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'voterId': voterId,
        'targetId': targetId,
        'at': at.toIso8601String(),
      };

  factory Vote.fromJson(Map<String, dynamic> j) => Vote(
        voterId: j['voterId'] as String,
        targetId: j['targetId'] as String,
        at: _dateOrNull(j['at']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      );
}

/// One month of the scheme.
class Round {
  Round({
    required this.index,
    required this.announcementDate,
    this.method,
    this.tieBreak = TieBreakMode.auto,
    this.status = RoundStatus.pending,
    List<Vote>? votes,
    List<String>? tiedMemberIds,
    this.winnerChitId,
    this.winnerMemberId,
    this.resolution,
    this.relaxed = false,
    List<String>? eligibleChitIds,
    Map<String, int>? paid,
    Set<String>? payoutsDone,
    this.openedAt,
    this.completedAt,
  })  : votes = votes ?? <Vote>[],
        tiedMemberIds = tiedMemberIds ?? <String>[],
        eligibleChitIds = eligibleChitIds ?? <String>[],
        paid = paid ?? <String, int>{},
        payoutsDone = payoutsDone ?? <String>{};

  /// 0-based position in the cycle. Display as `index + 1`.
  final int index;

  DateTime announcementDate;
  RoundMethod? method;
  TieBreakMode tieBreak;
  RoundStatus status;
  final List<Vote> votes;

  /// Members level on votes while the admin decides.
  List<String> tiedMemberIds;

  String? winnerChitId;

  /// The member who won the vote (null for random / manual picks).
  String? winnerMemberId;

  /// Plain-language account of how the winner was decided.
  String? resolution;

  /// True when the "no two months in a row" rule had to be set aside.
  bool relaxed;

  /// Chits that were in the draw when the winner was decided.
  List<String> eligibleChitIds;

  /// member id -> rupees paid in for this round.
  final Map<String, int> paid;

  /// Member ids who have been handed their payout.
  final Set<String> payoutsDone;

  DateTime? openedAt;
  DateTime? completedAt;

  int get number => index + 1;
  bool get isCompleted => status == RoundStatus.completed;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'index': index,
        'announcementDate': announcementDate.toIso8601String(),
        'method': method?.name,
        'tieBreak': tieBreak.name,
        'status': status.name,
        'votes': votes.map((v) => v.toJson()).toList(),
        'tiedMemberIds': tiedMemberIds,
        'winnerChitId': winnerChitId,
        'winnerMemberId': winnerMemberId,
        'resolution': resolution,
        'relaxed': relaxed,
        'eligibleChitIds': eligibleChitIds,
        'paid': paid,
        'payoutsDone': payoutsDone.toList(),
        'openedAt': openedAt?.toIso8601String(),
        'completedAt': completedAt?.toIso8601String(),
      };

  factory Round.fromJson(Map<String, dynamic> j) {
    final methodName = j['method'];
    final paidRaw = ((j['paid'] as Map?) ?? const <String, Object?>{})
        .cast<String, Object?>();
    return Round(
      index: j['index'] as int,
      announcementDate: _dateOrNull(j['announcementDate']) ?? DateTime.now(),
      method: methodName == null
          ? null
          : _enumByName(RoundMethod.values, methodName, RoundMethod.random),
      tieBreak: _enumByName(TieBreakMode.values, j['tieBreak'], TieBreakMode.auto),
      status: _enumByName(RoundStatus.values, j['status'], RoundStatus.pending),
      votes: ((j['votes'] as List?) ?? const <Object?>[])
          .map((e) => Vote.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
      tiedMemberIds:
          ((j['tiedMemberIds'] as List?) ?? const <Object?>[]).cast<String>().toList(),
      winnerChitId: j['winnerChitId'] as String?,
      winnerMemberId: j['winnerMemberId'] as String?,
      resolution: j['resolution'] as String?,
      relaxed: (j['relaxed'] as bool?) ?? false,
      eligibleChitIds:
          ((j['eligibleChitIds'] as List?) ?? const <Object?>[]).cast<String>().toList(),
      paid: <String, int>{
        for (final e in paidRaw.entries) e.key: (e.value as num).toInt(),
      },
      payoutsDone:
          ((j['payoutsDone'] as List?) ?? const <Object?>[]).cast<String>().toSet(),
      openedAt: _dateOrNull(j['openedAt']),
      completedAt: _dateOrNull(j['completedAt']),
    );
  }
}

/// An entry in the group's updates feed (announcements, results, edits).
class FeedEntry {
  const FeedEntry({
    required this.id,
    required this.at,
    required this.kind,
    required this.text,
    required this.author,
  });

  final String id;
  final DateTime at;
  final FeedKind kind;
  final String text;
  final String author;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'at': at.toIso8601String(),
        'kind': kind.name,
        'text': text,
        'author': author,
      };

  factory FeedEntry.fromJson(Map<String, dynamic> j) => FeedEntry(
        id: j['id'] as String,
        at: _dateOrNull(j['at']) ?? DateTime.fromMillisecondsSinceEpoch(0),
        kind: _enumByName(FeedKind.values, j['kind'], FeedKind.system),
        text: j['text'] as String,
        author: (j['author'] as String?) ?? 'System',
      );
}

/// A whole chit group. Mutated in place by `ChitActions`.
class ChitGroup {
  ChitGroup({
    required this.id,
    required this.name,
    required this.createdAt,
    this.chitValue,
    this.plannedMembers,
    this.firstAnnouncementDate,
    this.remindersEnabled = true,
    this.startedAt,
    this.adminUid,
    List<Member>? members,
    List<Chit>? chits,
    List<Round>? rounds,
    List<FeedEntry>? feed,
  })  : members = members ?? <Member>[],
        chits = chits ?? <Chit>[],
        rounds = rounds ?? <Round>[],
        feed = feed ?? <FeedEntry>[];

  final String id;
  String name;

  /// Sign-in id of the organiser who runs this group. Null for groups that
  /// only exist on one phone (no login).
  String? adminUid;

  /// The only mandatory field when creating a group.
  final DateTime createdAt;

  /// Rupees per chit per month. Locked once the cycle starts.
  int? chitValue;

  /// Optional target number of members, shown as progress while setting up.
  int? plannedMembers;

  /// Announcement date of round 1; later rounds fall on the same day of each
  /// following month.
  DateTime? firstAnnouncementDate;

  bool remindersEnabled;

  /// Set when the cycle starts; the structure is locked from then on.
  DateTime? startedAt;

  final List<Member> members;
  final List<Chit> chits;
  final List<Round> rounds;
  final List<FeedEntry> feed;

  bool get started => startedAt != null;
  int get chitCount => chits.length;

  /// Monthly pool: chit value x number of chits (0 until a value is set).
  int get poolAmount => (chitValue ?? 0) * chits.length;

  bool get completed => started && rounds.isNotEmpty && rounds.every((r) => r.isCompleted);

  /// The round currently being worked on: the first one not yet completed.
  Round? get currentRound {
    for (final r in rounds) {
      if (!r.isCompleted) return r;
    }
    return null;
  }

  int get completedRounds => rounds.where((r) => r.isCompleted).length;

  /// Members who are in the group now.
  List<Member> get activeMembers => members.where((m) => !m.left).toList();

  /// Members who were removed but whose shares are still on record.
  List<Member> get formerMembers => members.where((m) => m.left).toList();

  Member? memberById(String id) {
    for (final m in members) {
      if (m.id == id) return m;
    }
    return null;
  }

  Chit? chitById(String id) {
    for (final c in chits) {
      if (c.id == id) return c;
    }
    return null;
  }

  String memberName(String id) => memberById(id)?.name ?? 'Unknown';

  /// `Chit 3`
  String chitName(Chit c) => 'Chit ${c.number}';

  /// `Chit 3 (Asha + Ravi)`
  String chitLabel(Chit c) {
    final names = c.ownerIds.map(memberName).toList()..sort();
    return 'Chit ${c.number} (${names.join(' + ')})';
  }

  /// Announcement date of round [index] if the cycle has not started yet.
  DateTime? plannedDateFor(int index) {
    final first = firstAnnouncementDate;
    if (first == null) return null;
    return addMonths(dateOnly(first), index);
  }

  /// The announcement date the group is working towards: the current round's
  /// date once started, otherwise the planned first date (null if unset or
  /// the cycle is finished).
  DateTime? get nextAnnouncement {
    if (started) {
      for (final r in rounds) {
        if (!r.isCompleted) return r.announcementDate;
      }
      return null;
    }
    final first = firstAnnouncementDate;
    return first == null ? null : dateOnly(first);
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'v': 1,
        'id': id,
        'name': name,
        'createdAt': createdAt.toIso8601String(),
        'chitValue': chitValue,
        'plannedMembers': plannedMembers,
        'firstAnnouncementDate': firstAnnouncementDate?.toIso8601String(),
        'remindersEnabled': remindersEnabled,
        'startedAt': startedAt?.toIso8601String(),
        'adminUid': adminUid,
        'members': members.map((m) => m.toJson()).toList(),
        'chits': chits.map((c) => c.toJson()).toList(),
        'rounds': rounds.map((r) => r.toJson()).toList(),
        'feed': feed.map((f) => f.toJson()).toList(),
      };

  factory ChitGroup.fromJson(Map<String, dynamic> j) {
    List<T> list<T>(String key, T Function(Map<String, dynamic>) f) =>
        ((j[key] as List?) ?? const <Object?>[])
            .map((e) => f((e as Map).cast<String, dynamic>()))
            .toList();
    return ChitGroup(
      id: j['id'] as String,
      name: j['name'] as String,
      createdAt: _dateOrNull(j['createdAt']) ?? DateTime.now(),
      chitValue: (j['chitValue'] as num?)?.toInt(),
      plannedMembers: (j['plannedMembers'] as num?)?.toInt(),
      firstAnnouncementDate: _dateOrNull(j['firstAnnouncementDate']),
      remindersEnabled: (j['remindersEnabled'] as bool?) ?? true,
      startedAt: _dateOrNull(j['startedAt']),
      adminUid: j['adminUid'] as String?,
      members: list('members', Member.fromJson),
      chits: list('chits', Chit.fromJson),
      rounds: list('rounds', Round.fromJson),
      feed: list('feed', FeedEntry.fromJson),
    );
  }

  /// Short plain-text line used in lists and notices.
  String get summaryLine {
    final v = chitValue;
    if (v == null) return 'Chit value not set';
    return '${rupees(v)} per chit · ${plural(chits.length, 'chit')}';
  }
}
