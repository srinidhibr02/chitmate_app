/// The pure rules of a chit scheme: who may win, who may vote, what is owed.
///
/// Nothing in here changes any data, so each rule can be tested on its own.
library;

import 'dart:math';

import '../core/dates.dart';
import '../core/format.dart';
import 'models.dart';

/// Which chits may win a round.
class Eligibility {
  const Eligibility({
    required this.chits,
    required this.relaxed,
    required this.blockedMemberIds,
  });

  /// Chits that may win, in chit-number order.
  final List<Chit> chits;

  /// True when the "no two months in a row" rule had to be eased because every
  /// remaining chit involves someone who was paid last month.
  final bool relaxed;

  /// People who were paid last month.
  final Set<String> blockedMemberIds;

  Set<String> get chitIds => <String>{for (final c in chits) c.id};

  /// People who own at least one eligible chit (the valid targets of a vote).
  Set<String> get memberIds => <String>{
        for (final c in chits) ...c.ownerIds,
      };
}

/// Standing of a vote count.
class VoteOutcome {
  const VoteOutcome({required this.counts, required this.leaders, required this.topVotes});

  /// Votes per person (people with none are absent).
  final Map<String, int> counts;

  /// People with the most votes, sorted by id. Empty when nobody voted.
  final List<String> leaders;
  final int topVotes;

  bool get hasVotes => leaders.isNotEmpty;
  bool get isTie => leaders.length > 1;
}

/// One line of the "ready to start" checklist.
class ReadinessIssue {
  const ReadinessIssue(this.message, {this.blocking = true});

  final String message;

  /// Blocking issues stop the cycle from starting; the rest are advice.
  final bool blocking;
}

/// Someone holding a large part of all votes.
class ConcentrationWarning {
  const ConcentrationWarning({required this.memberId, required this.votes, required this.total});

  final String memberId;
  final int votes;
  final int total;

  double get share => total == 0 ? 0 : votes / total;
}

class Rules {
  Rules._();

  /// Warn the admin when one person holds more than this share of all votes.
  static const double concentrationThreshold = 0.4;

  // ---------------------------------------------------------------- money --

  /// What a member pays every month: the sum of their shares in all chits.
  static int monthlyDue(ChitGroup g, String memberId) {
    var sum = 0;
    for (final c in g.chits) {
      sum += c.shares[memberId] ?? 0;
    }
    return sum;
  }

  /// What each owner receives when [chit] wins: `share x number of chits`
  /// (identical to `pool x share / chit value`, but always exact).
  static Map<String, int> payoutFor(ChitGroup g, Chit chit) {
    final n = g.chits.length;
    return <String, int>{
      for (final e in chit.shares.entries) e.key: e.value * n,
    };
  }

  /// Payout of a completed round (empty until a winner exists).
  static Map<String, int> roundPayouts(ChitGroup g, Round r) {
    final id = r.winnerChitId;
    if (id == null) return const <String, int>{};
    final chit = g.chitById(id);
    if (chit == null) return const <String, int>{};
    return payoutFor(g, chit);
  }

  /// Total paid in so far for [r].
  static int collected(Round r) => r.paid.values.fold<int>(0, (a, b) => a + b);

  static int paidBy(Round r, String memberId) => r.paid[memberId] ?? 0;

  /// Payment state of one member in one round.
  static PaymentStatus paymentStatus(
    ChitGroup g,
    Round r,
    String memberId,
    DateTime now,
  ) {
    final due = monthlyDue(g, memberId);
    final paid = paidBy(r, memberId);
    if (due == 0 || paid >= due) return PaymentStatus.paid;
    if (dateOnly(now).isAfter(dateOnly(r.announcementDate))) {
      return PaymentStatus.overdue;
    }
    return paid > 0 ? PaymentStatus.partial : PaymentStatus.pending;
  }

  /// Unpaid amount over every round whose date has passed (or that is already
  /// decided).
  static int outstanding(ChitGroup g, String memberId, DateTime now) {
    final today = dateOnly(now);
    final due = monthlyDue(g, memberId);
    var total = 0;
    for (final r in g.rounds) {
      final past = r.isCompleted || !dateOnly(r.announcementDate).isAfter(today);
      if (!past) continue;
      final owed = due - paidBy(r, memberId);
      if (owed > 0) total += owed;
    }
    return total;
  }

  // ---------------------------------------------------------- eligibility --

  /// Chits that have already won in rounds before [before] (all rounds when
  /// null).
  static Set<String> wonChitIds(ChitGroup g, {int? before}) {
    final out = <String>{};
    for (final r in g.rounds) {
      if (before != null && r.index >= before) continue;
      final id = r.winnerChitId;
      if (id != null) out.add(id);
    }
    return out;
  }

  /// Chits that have not won yet.
  static List<Chit> unwonChits(ChitGroup g) {
    final won = wonChitIds(g);
    return <Chit>[
      for (final c in g.chits)
        if (!won.contains(c.id)) c,
    ];
  }

  /// Everyone who owns a share of the chit that won the previous round. They
  /// received money last month, so they may not be paid again this month.
  static Set<String> blockedMembers(ChitGroup g, int roundIndex) {
    if (roundIndex <= 0 || roundIndex > g.rounds.length) return <String>{};
    final id = g.rounds[roundIndex - 1].winnerChitId;
    if (id == null) return <String>{};
    final chit = g.chitById(id);
    return chit == null ? <String>{} : chit.ownerIds.toSet();
  }

  /// Which chits may win round [roundIndex].
  ///
  /// * A chit that already won can never win again.
  /// * A chit is blocked when any of its owners was paid last month.
  /// * If that blocks every remaining chit (typically the last months, when
  ///   one person holds everything that is left), the rule is eased: only the
  ///   chits that overlap least with last month's winners stay in, and
  ///   [Eligibility.relaxed] is set so the app can explain why.
  static Eligibility eligibility(ChitGroup g, int roundIndex) {
    final won = wonChitIds(g, before: roundIndex);
    final unwon = <Chit>[
      for (final c in g.chits)
        if (!won.contains(c.id)) c,
    ]..sort((a, b) => a.number.compareTo(b.number));
    final blocked = blockedMembers(g, roundIndex);
    if (unwon.isEmpty) {
      return Eligibility(chits: const <Chit>[], relaxed: false, blockedMemberIds: blocked);
    }
    int overlap(Chit c) => c.ownerIds.where(blocked.contains).length;
    final strict = <Chit>[
      for (final c in unwon)
        if (overlap(c) == 0) c,
    ];
    if (strict.isNotEmpty) {
      return Eligibility(chits: strict, relaxed: false, blockedMemberIds: blocked);
    }
    var best = overlap(unwon.first);
    for (final c in unwon) {
      best = min(best, overlap(c));
    }
    return Eligibility(
      chits: <Chit>[
        for (final c in unwon)
          if (overlap(c) == best) c,
      ],
      relaxed: true,
      blockedMemberIds: blocked,
    );
  }

  /// Members who can receive votes in round [roundIndex], in member-list order.
  static List<Member> eligibleTargets(ChitGroup g, int roundIndex) {
    final ids = eligibility(g, roundIndex).memberIds;
    return <Member>[
      for (final m in g.members)
        if (ids.contains(m.id)) m,
    ];
  }

  /// The eligible chits that [memberId] owns a share of.
  static List<Chit> eligibleChitsOf(ChitGroup g, int roundIndex, String memberId) {
    return <Chit>[
      for (final c in eligibility(g, roundIndex).chits)
        if (c.ownedBy(memberId)) c,
    ];
  }

  // --------------------------------------------------------------- voting --

  /// Chits that a single person owns outright.
  static int fullChitCount(ChitGroup g, String memberId) {
    var n = 0;
    for (final c in g.chits) {
      if (c.isFull && c.ownedBy(memberId)) n++;
    }
    return n;
  }

  /// Votes a member may cast: one per full chit; someone with only shares in
  /// shared chits gets one; anyone else gets none. Shares never add votes on
  /// top of full chits.
  static int votingPower(ChitGroup g, String memberId) {
    if (g.memberById(memberId)?.left ?? false) return 0;
    final full = fullChitCount(g, memberId);
    if (full > 0) return full;
    final hasShare = g.chits.any((c) => c.ownedBy(memberId));
    return hasShare ? 1 : 0;
  }

  /// Voting power of every member who has any.
  static Map<String, int> votingPowerMap(ChitGroup g) {
    final out = <String, int>{};
    for (final m in g.members) {
      final p = votingPower(g, m.id);
      if (p > 0) out[m.id] = p;
    }
    return out;
  }

  static int totalVotes(ChitGroup g) =>
      votingPowerMap(g).values.fold<int>(0, (a, b) => a + b);

  /// Votes this member has already cast in [r].
  static int votesUsed(Round r, String voterId) =>
      r.votes.where((v) => v.voterId == voterId).length;

  /// Votes this member can still cast in [r].
  static int votesLeft(ChitGroup g, Round r, String voterId) =>
      max(0, votingPower(g, voterId) - votesUsed(r, voterId));

  /// Why this vote cannot be recorded, or null when it is fine.
  static String? voteError(ChitGroup g, Round r, String voterId, String targetId) {
    if (r.method != RoundMethod.vote) return 'This month is not decided by a vote.';
    if (r.status != RoundStatus.open) return 'Voting is not open for this month.';
    final voter = g.memberById(voterId);
    final target = g.memberById(targetId);
    if (voter == null || target == null) return 'Unknown member.';
    final power = votingPower(g, voterId);
    if (voter.left) return '${voter.name} has left the group, so no vote.';
    if (power == 0) return '${voter.name} has no chit, so no vote.';
    final mine = r.votes.where((v) => v.voterId == voterId).toList();
    if (mine.length >= power) {
      return '${voter.name} has already used ${plural(power, 'vote')}. Only the first votes count.';
    }
    if (mine.any((v) => v.targetId == targetId)) {
      return 'Each of ${voter.name}\'s votes must go to a different person.';
    }
    final ok = eligibility(g, r.index).memberIds.contains(targetId);
    if (!ok) return '${target.name} cannot receive votes this month.';
    return null;
  }

  /// Counts the votes of [r].
  static VoteOutcome tally(Round r) {
    final counts = <String, int>{};
    for (final v in r.votes) {
      counts[v.targetId] = (counts[v.targetId] ?? 0) + 1;
    }
    var top = 0;
    for (final c in counts.values) {
      if (c > top) top = c;
    }
    final leaders = <String>[
      if (top > 0)
        for (final e in counts.entries)
          if (e.value == top) e.key,
    ]..sort();
    return VoteOutcome(counts: counts, leaders: leaders, topVotes: top);
  }

  // -------------------------------------------------------- group health --

  /// Members who hold more than [concentrationThreshold] of all votes.
  static List<ConcentrationWarning> concentrationWarnings(ChitGroup g) {
    final total = totalVotes(g);
    if (total == 0) return const <ConcentrationWarning>[];
    final out = <ConcentrationWarning>[];
    votingPowerMap(g).forEach((id, votes) {
      if (votes / total > concentrationThreshold) {
        out.add(ConcentrationWarning(memberId: id, votes: votes, total: total));
      }
    });
    return out;
  }

  /// Splits [value] rupees into [parts] whole-rupee amounts that add up to
  /// [value]; any remainder goes one rupee at a time to the first parts.
  static List<int> equalSplit(int value, int parts) {
    if (parts <= 0) return const <int>[];
    final base = value ~/ parts;
    final extra = value % parts;
    return <int>[for (var i = 0; i < parts; i++) base + (i < extra ? 1 : 0)];
  }

  /// Problem with a chit's shares, or null when valid.
  static String? sharesError(ChitGroup g, Map<String, int> shares) {
    final value = g.chitValue;
    if (value == null || value <= 0) return 'Set the chit value first.';
    if (shares.isEmpty) return 'Add at least one owner.';
    var total = 0;
    for (final e in shares.entries) {
      if (g.memberById(e.key) == null) return 'Unknown member in this chit.';
      if (e.value <= 0) return 'Every share must be more than ₹0.';
      total += e.value;
    }
    if (total < value) {
      return 'Assign ${rupees(value - total)} more to reach ${rupees(value)}.';
    }
    if (total > value) {
      return 'Shares are ${rupees(total - value)} over the chit value of ${rupees(value)}.';
    }
    return null;
  }

  /// What still needs doing before the cycle can start.
  static List<ReadinessIssue> readiness(ChitGroup g) {
    final issues = <ReadinessIssue>[];
    final value = g.chitValue;
    if (value == null || value <= 0) {
      issues.add(const ReadinessIssue('Set the chit value (amount per chit each month).'));
    }
    if (g.chits.length < 2) {
      issues.add(const ReadinessIssue('Add at least 2 chits.'));
    }
    if (value != null && value > 0) {
      for (final c in g.chits) {
        final err = sharesError(g, c.shares);
        if (err != null) issues.add(ReadinessIssue('Chit ${c.number}: $err'));
      }
    }
    if (g.firstAnnouncementDate == null) {
      issues.add(const ReadinessIssue('Pick the first announcement date.'));
    }
    for (final m in g.activeMembers) {
      if (!g.chits.any((c) => c.ownedBy(m.id))) {
        issues.add(ReadinessIssue('${m.name} has no chit yet.', blocking: false));
      }
    }
    final planned = g.plannedMembers;
    final activeCount = g.activeMembers.length;
    if (planned != null && planned != activeCount) {
      issues.add(ReadinessIssue(
        'You planned ${plural(planned, 'member')} and have $activeCount.',
        blocking: false,
      ));
    }
    for (final w in concentrationWarnings(g)) {
      issues.add(ReadinessIssue(
        '${g.memberName(w.memberId)} holds ${w.votes} of ${w.total} votes '
        '(${(w.share * 100).round()}%) and can steer most votes.',
        blocking: false,
      ));
    }
    return issues;
  }

  static bool isReady(ChitGroup g) => !readiness(g).any((i) => i.blocking);

  /// How far setup has got, from 0 to 1: chit value set, at least 2 chits,
  /// every chit adding up, first date picked.
  static double setupProgress(ChitGroup g) {
    final hasValue = (g.chitValue ?? 0) > 0;
    final enoughChits = g.chits.length >= 2;
    final chitsValid = hasValue &&
        g.chits.isNotEmpty &&
        g.chits.every((c) => sharesError(g, c.shares) == null);
    final hasDate = g.firstAnnouncementDate != null;
    final done = <bool>[hasValue, enoughChits, chitsValid, hasDate].where((b) => b).length;
    return done / 4;
  }
}
