/// Everything that changes a [ChitGroup]: setup, the monthly rounds, payments.
///
/// Each method checks the rules first and throws a [RuleViolation] with a
/// message written for people. Every change is written to the group's updates
/// feed, so members can always see who did what and when.
library;

import 'dart:math';

import '../core/dates.dart';
import '../core/format.dart';
import '../core/ids.dart';
import 'labels.dart';
import 'models.dart';
import 'notices.dart';
import 'rules.dart';

/// Thrown when an action would break a rule. [message] is shown as-is.
class RuleViolation implements Exception {
  RuleViolation(this.message);

  final String message;

  @override
  String toString() => message;
}

class ChitActions {
  ChitActions({Random? random, DateTime Function()? clock})
      : _random = random ?? Random.secure(),
        _clock = clock ?? DateTime.now;

  static const int maxChitValue = 10000000;
  static const int maxChits = 60;
  static const int maxMembers = 60;
  static const int maxNameLength = 40;
  static const int maxAnnouncementLength = 1000;

  final Random _random;
  final DateTime Function() _clock;

  DateTime get now => _clock();

  // ------------------------------------------------------------- helpers --

  void _log(
    ChitGroup g,
    String text, {
    required String actor,
    FeedKind kind = FeedKind.change,
  }) {
    g.feed.add(FeedEntry(
      id: generateId(),
      at: _clock(),
      kind: kind,
      text: text,
      author: actor,
    ));
  }

  void _system(ChitGroup g, String text) =>
      _log(g, text, actor: 'ChitMate', kind: FeedKind.system);

  String _cleanName(String raw, String what) {
    final name = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (name.isEmpty) throw RuleViolation('Enter $what.');
    if (name.length > maxNameLength) {
      throw RuleViolation('Keep $what under $maxNameLength characters.');
    }
    return name;
  }

  void _requireNotStarted(ChitGroup g, String what) {
    if (g.started) {
      throw RuleViolation('$what is locked once the first month has started.');
    }
  }

  String _describeShares(ChitGroup g, Map<String, int> shares) {
    final parts = shares.entries
        .map((e) => '${g.memberName(e.key)} ${rupees(e.value)}')
        .toList()
      ..sort();
    return parts.join(' + ');
  }

  // ---------------------------------------------------------- group setup --

  /// Creates a group. Only [createdAt] is required; everything else can be
  /// filled in or changed later.
  ChitGroup createGroup({
    required DateTime createdAt,
    required String organiserName,
    String? name,
    int? chitValue,
    int? plannedMembers,
  }) {
    if (chitValue != null && (chitValue <= 0 || chitValue > maxChitValue)) {
      throw RuleViolation('Chit value must be between ₹1 and ${rupees(maxChitValue)}.');
    }
    if (plannedMembers != null && (plannedMembers < 2 || plannedMembers > maxMembers)) {
      throw RuleViolation('A group needs between 2 and $maxMembers members.');
    }
    final trimmed = (name ?? '').trim();
    if (trimmed.length > maxNameLength) {
      throw RuleViolation('Keep the group name under $maxNameLength characters.');
    }
    final g = ChitGroup(
      id: generateId(),
      name: trimmed.isEmpty ? 'Chit group' : trimmed,
      createdAt: dateOnly(createdAt),
      chitValue: chitValue,
      plannedMembers: plannedMembers,
    );
    final organiser = organiserName.trim();
    if (organiser.isNotEmpty) {
      g.members.add(Member(id: generateId(), name: organiser));
    }
    _system(g, 'Group created on ${formatDate(g.createdAt)}.');
    return g;
  }

  void renameGroup(ChitGroup g, String name, {required String actor}) {
    final clean = _cleanName(name, 'a group name');
    if (clean == g.name) return;
    _log(g, 'Group renamed from "${g.name}" to "$clean".', actor: actor);
    g.name = clean;
  }

  /// Sets the chit value. Locked once the cycle has started. Chits owned by
  /// one person follow the new value automatically; shared chits keep their
  /// amounts and show up in the checklist until they add up again.
  void setChitValue(ChitGroup g, int value, {required String actor}) {
    _requireNotStarted(g, 'The chit value');
    if (value <= 0 || value > maxChitValue) {
      throw RuleViolation('Chit value must be between ₹1 and ${rupees(maxChitValue)}.');
    }
    final old = g.chitValue;
    if (old == value) return;
    g.chitValue = value;
    for (final c in g.chits) {
      if (c.isFull) c.shares = <String, int>{c.ownerIds.first: value};
    }
    _log(
      g,
      old == null
          ? 'Chit value set to ${rupees(value)}.'
          : 'Chit value changed from ${rupees(old)} to ${rupees(value)}.',
      actor: actor,
    );
  }

  void setPlannedMembers(ChitGroup g, int? count, {required String actor}) {
    if (count != null && (count < 2 || count > maxMembers)) {
      throw RuleViolation('A group needs between 2 and $maxMembers members.');
    }
    if (g.plannedMembers == count) return;
    g.plannedMembers = count;
    _log(
      g,
      count == null
          ? 'Planned member count cleared.'
          : 'Planned member count set to $count.',
      actor: actor,
    );
  }

  /// Sets the date of the first announcement (before the cycle starts). Later
  /// months fall on the same day of each following month.
  void setFirstAnnouncementDate(ChitGroup g, DateTime date, {required String actor}) {
    if (g.started) {
      throw RuleViolation('Use "Reschedule" to move dates after the cycle has started.');
    }
    final d = dateOnly(date);
    final old = g.firstAnnouncementDate;
    if (old != null && sameDay(old, d)) return;
    g.firstAnnouncementDate = d;
    _log(
      g,
      old == null
          ? 'First announcement date set to ${formatDateLong(d)}.'
          : 'First announcement date moved from ${formatDate(old)} to ${formatDate(d)}.',
      actor: actor,
    );
  }

  /// Moves the next announcement to [nextDate]; every later month follows on
  /// the same day of its month.
  void reschedule(ChitGroup g, DateTime nextDate, {required String actor}) {
    if (!g.started) {
      throw RuleViolation('Start the cycle first, or change the first announcement date.');
    }
    final cur = g.currentRound;
    if (cur == null) throw RuleViolation('Every month is already decided.');
    final d = dateOnly(nextDate);
    final old = cur.announcementDate;
    for (final r in g.rounds) {
      if (r.isCompleted) continue;
      r.announcementDate = addMonths(d, r.index - cur.index);
    }
    _log(
      g,
      'Month ${cur.number} announcement moved from ${formatDate(old)} to ${formatDate(d)}; '
      'later months follow.',
      actor: actor,
    );
  }

  void setRemindersEnabled(ChitGroup g, bool enabled) {
    g.remindersEnabled = enabled;
  }

  // -------------------------------------------------------------- members --

  Member addMember(ChitGroup g, String name, {String? phone, required String actor}) {
    final clean = _cleanName(name, 'a name');
    if (g.members.length >= maxMembers) {
      throw RuleViolation('A group can have at most $maxMembers members.');
    }
    if (g.members.any((m) => m.name.toLowerCase() == clean.toLowerCase())) {
      throw RuleViolation('Someone named "$clean" is already in this group.');
    }
    final p = phone?.trim();
    final m = Member(id: generateId(), name: clean, phone: (p == null || p.isEmpty) ? null : p);
    g.members.add(m);
    _log(g, '$clean joined the group.', actor: actor);
    return m;
  }

  void renameMember(ChitGroup g, String memberId, String name, {String? phone, required String actor}) {
    final m = g.memberById(memberId);
    if (m == null) throw RuleViolation('Member not found.');
    final clean = _cleanName(name, 'a name');
    if (g.members.any((o) => o.id != memberId && o.name.toLowerCase() == clean.toLowerCase())) {
      throw RuleViolation('Someone named "$clean" is already in this group.');
    }
    final p = phone?.trim();
    m.phone = (p == null || p.isEmpty) ? null : p;
    if (m.name != clean) {
      _log(g, '${m.name} is now called $clean.', actor: actor);
      m.name = clean;
    }
  }

  void removeMember(ChitGroup g, String memberId, {required String actor}) {
    final m = g.memberById(memberId);
    if (m == null) throw RuleViolation('Member not found.');
    for (final c in g.chits) {
      if (c.ownedBy(memberId)) {
        throw RuleViolation('${m.name} owns a share of Chit ${c.number}. '
            'Change or remove that chit first.');
      }
    }
    for (final r in g.rounds) {
      final involved = r.votes.any((v) => v.voterId == memberId || v.targetId == memberId) ||
          r.paid.containsKey(memberId);
      if (involved) {
        throw RuleViolation('${m.name} appears in the history of month ${r.number} '
            'and cannot be removed.');
      }
    }
    g.members.removeWhere((x) => x.id == memberId);
    _log(g, '${m.name} left the group.', actor: actor);
  }

  // ---------------------------------------------------------------- chits --

  /// Adds a chit. [shares] maps member id to rupees and must add up to the
  /// chit value. Only possible before the cycle starts.
  Chit addChit(ChitGroup g, Map<String, int> shares, {required String actor}) {
    _requireNotStarted(g, 'The number of chits');
    if (g.chits.length >= maxChits) {
      throw RuleViolation('A group can have at most $maxChits chits.');
    }
    final err = Rules.sharesError(g, shares);
    if (err != null) throw RuleViolation(err);
    var number = 0;
    for (final c in g.chits) {
      number = max(number, c.number);
    }
    final chit = Chit(id: generateId(), number: number + 1, shares: shares);
    g.chits.add(chit);
    _log(g, 'Chit ${chit.number} added: ${_describeShares(g, shares)}.', actor: actor);
    return chit;
  }

  /// Changes who owns a chit and how much each pays. After the cycle starts
  /// this is only allowed for chits that have not won, between months, and
  /// only when [coOwnersAgreed] confirms everyone affected has said yes.
  void updateChitShares(
    ChitGroup g,
    String chitId,
    Map<String, int> shares, {
    required String actor,
    bool coOwnersAgreed = false,
  }) {
    final chit = g.chitById(chitId);
    if (chit == null) throw RuleViolation('Chit not found.');
    final err = Rules.sharesError(g, shares);
    if (err != null) throw RuleViolation(err);
    if (g.started) {
      if (Rules.wonChitIds(g).contains(chitId)) {
        throw RuleViolation('Chit ${chit.number} has already won, so its shares are locked.');
      }
      final busy = g.rounds.any(
        (r) => r.status == RoundStatus.open || r.status == RoundStatus.awaitingTieBreak,
      );
      if (busy) {
        throw RuleViolation('Finish the month in progress before changing shares.');
      }
      if (!coOwnersAgreed) {
        throw RuleViolation('Confirm that everyone affected has agreed to this change.');
      }
    }
    final before = _describeShares(g, chit.shares);
    final after = _describeShares(g, shares);
    if (before == after) return;
    chit.shares = Map<String, int>.of(shares);
    _log(g, 'Chit ${chit.number} changed from $before to $after.', actor: actor);
  }

  /// Removes a chit (only before the cycle starts).
  void removeChit(ChitGroup g, String chitId, {required String actor}) {
    _requireNotStarted(g, 'The number of chits');
    final chit = g.chitById(chitId);
    if (chit == null) throw RuleViolation('Chit not found.');
    g.chits.removeWhere((c) => c.id == chitId);
    _log(g, 'Chit ${chit.number} removed.', actor: actor);
  }

  // ---------------------------------------------------------------- cycle --

  /// Locks the structure and creates one round per chit.
  void startCycle(ChitGroup g, {required String actor}) {
    if (g.started) throw RuleViolation('The cycle has already started.');
    for (final issue in Rules.readiness(g)) {
      if (issue.blocking) throw RuleViolation(issue.message);
    }
    final first = dateOnly(g.firstAnnouncementDate!);
    g.rounds
      ..clear()
      ..addAll(<Round>[
        for (var i = 0; i < g.chits.length; i++)
          Round(index: i, announcementDate: addMonths(first, i)),
      ]);
    g.startedAt = _clock();
    _log(
      g,
      'The cycle has started: ${plural(g.chits.length, 'chit')}, '
      '${rupees(g.chitValue!)} each, ${rupees(g.poolAmount)} a month for '
      '${plural(g.chits.length, 'month')}. First announcement: ${formatDateLong(first)}.',
      actor: actor,
      kind: FeedKind.announcement,
    );
  }

  Round _round(ChitGroup g, int index) {
    if (!g.started) throw RuleViolation('Start the cycle first.');
    if (index < 0 || index >= g.rounds.length) throw RuleViolation('Unknown month.');
    return g.rounds[index];
  }

  Round _currentRound(ChitGroup g, int index) {
    final r = _round(g, index);
    final cur = g.currentRound;
    if (cur == null || cur.index != index) {
      if (r.isCompleted) throw RuleViolation('Month ${r.number} is already decided.');
      throw RuleViolation('Finish month ${(cur?.number ?? r.number)} first.');
    }
    return r;
  }

  /// Opens round [index] with the chosen [method]. If only one chit is left it
  /// is awarded automatically.
  void openRound(
    ChitGroup g,
    int index, {
    required RoundMethod method,
    TieBreakMode tieBreak = TieBreakMode.auto,
    required String actor,
  }) {
    final r = _currentRound(g, index);
    if (r.status != RoundStatus.pending) {
      throw RuleViolation('Month ${r.number} is already open.');
    }
    final unwon = Rules.unwonChits(g);
    r.openedAt = _clock();
    if (unwon.length == 1) {
      r.method = RoundMethod.random;
      _finalize(g, r, unwon.first,
          'Only one chit was left, so it was awarded automatically.');
      return;
    }
    r.method = method;
    r.tieBreak = tieBreak;
    r.status = RoundStatus.open;
    _log(g, Notices.roundOpened(g, r), actor: actor, kind: FeedKind.announcement);
  }

  /// Records one vote. Each voter has as many votes as their chits allow, each
  /// for a different person; extra votes are refused (only the first count).
  void castVote(
    ChitGroup g,
    int index, {
    required String voterId,
    required String targetId,
  }) {
    final r = _currentRound(g, index);
    final err = Rules.voteError(g, r, voterId, targetId);
    if (err != null) throw RuleViolation(err);
    r.votes.add(Vote(voterId: voterId, targetId: targetId, at: _clock()));
  }

  /// Ends voting and works out the winner.
  void closeVoting(ChitGroup g, int index, {required String actor}) {
    final r = _currentRound(g, index);
    if (r.method != RoundMethod.vote || r.status != RoundStatus.open) {
      throw RuleViolation('Voting is not open for this month.');
    }
    final outcome = Rules.tally(r);
    if (!outcome.hasVotes) {
      final elig = Rules.eligibility(g, r.index).chits;
      final pick = elig[_random.nextInt(elig.length)];
      _finalize(g, r, pick,
          'Nobody voted, so the app drew one of the ${elig.length} eligible chits at random (fallback).');
      return;
    }
    final votesText = plural(outcome.topVotes, 'vote');
    if (!outcome.isTie) {
      final who = outcome.leaders.first;
      _decideForMember(g, r, who, '${g.memberName(who)} won the vote with $votesText.');
      return;
    }
    final names = outcome.leaders.map(g.memberName).join(' and ');
    if (r.tieBreak == TieBreakMode.auto) {
      final who = outcome.leaders[_random.nextInt(outcome.leaders.length)];
      _decideForMember(g, r, who,
          '$names tied on $votesText; a random draw picked ${g.memberName(who)}.');
      return;
    }
    r.status = RoundStatus.awaitingTieBreak;
    r.tiedMemberIds = outcome.leaders;
    _system(g, 'Month ${r.number}: $names are level on $votesText. '
        'The admin will decide after talking with the group.');
  }

  /// The admin settles a tie between members who were level on votes.
  void adminResolveTie(
    ChitGroup g,
    int index, {
    required String memberId,
    required String actor,
    String? note,
  }) {
    final r = _currentRound(g, index);
    if (r.status != RoundStatus.awaitingTieBreak) {
      throw RuleViolation('There is no tie to settle for this month.');
    }
    if (!r.tiedMemberIds.contains(memberId)) {
      throw RuleViolation('Choose one of the members who tied.');
    }
    final names = r.tiedMemberIds.map(g.memberName).join(' and ');
    final extra = (note == null || note.trim().isEmpty) ? '' : ' Reason: ${note.trim()}';
    _decideForMember(
      g,
      r,
      memberId,
      'Tie between $names. $actor decided after talking with the group: '
      '${g.memberName(memberId)}.$extra',
    );
  }

  /// Records a chit the group agreed on.
  void manualPick(
    ChitGroup g,
    int index, {
    required String chitId,
    required String actor,
    String? note,
  }) {
    final r = _currentRound(g, index);
    if (r.method != RoundMethod.manual || r.status != RoundStatus.open) {
      throw RuleViolation('This month is not set to a picked chit.');
    }
    final elig = Rules.eligibility(g, r.index);
    final matches = elig.chits.where((c) => c.id == chitId).toList();
    if (matches.isEmpty) {
      throw RuleViolation('That chit cannot be picked this month.');
    }
    final extra = (note == null || note.trim().isEmpty) ? '' : ' ${note.trim()}';
    _finalize(g, r, matches.first, 'Agreed by the group and recorded by $actor.$extra');
  }

  /// Draws one eligible chit at random. Only once per month.
  void randomDraw(ChitGroup g, int index, {required String actor}) {
    final r = _currentRound(g, index);
    if (r.method != RoundMethod.random || r.status != RoundStatus.open) {
      throw RuleViolation('This month is not set to a random draw.');
    }
    _drawRandom(g, r, 'Drawn at random');
  }

  /// If the admin never chose a method by the announcement date, anyone can
  /// trigger the agreed fallback: a random draw.
  void fallbackRandom(ChitGroup g, int index, {required String actor}) {
    final r = _currentRound(g, index);
    if (r.status != RoundStatus.pending) {
      throw RuleViolation('Month ${r.number} is already open.');
    }
    if (!dateOnly(_clock()).isAfter(dateOnly(r.announcementDate))) {
      throw RuleViolation('The announcement date has not passed yet.');
    }
    r.openedAt = _clock();
    final unwon = Rules.unwonChits(g);
    if (unwon.length == 1) {
      r.method = RoundMethod.random;
      _finalize(g, r, unwon.first,
          'Only one chit was left, so it was awarded automatically.');
      return;
    }
    r.method = RoundMethod.random;
    r.status = RoundStatus.open;
    _drawRandom(g, r,
        'No method was chosen by the announcement date, so the app drew at random (fallback)');
  }

  void _drawRandom(ChitGroup g, Round r, String lead) {
    final elig = Rules.eligibility(g, r.index).chits;
    if (elig.isEmpty) throw RuleViolation('No chit is left to draw.');
    final pick = elig[_random.nextInt(elig.length)];
    final names = elig.map((c) => 'Chit ${c.number}').join(', ');
    _finalize(g, r, pick, '$lead from ${plural(elig.length, 'eligible chit')} ($names).');
  }

  void _decideForMember(ChitGroup g, Round r, String memberId, String lead) {
    final options = Rules.eligibleChitsOf(g, r.index, memberId);
    if (options.isEmpty) {
      throw RuleViolation('${g.memberName(memberId)} has no chit that can win this month.');
    }
    final pick = options[_random.nextInt(options.length)];
    final text = options.length == 1
        ? '$lead Their eligible chit is Chit ${pick.number}.'
        : '$lead Chit ${pick.number} was drawn at random from their '
            '${options.length} eligible chits.';
    _finalize(g, r, pick, text, winnerMemberId: memberId);
  }

  void _finalize(
    ChitGroup g,
    Round r,
    Chit chit,
    String resolution, {
    String? winnerMemberId,
  }) {
    final elig = Rules.eligibility(g, r.index);
    r.eligibleChitIds = elig.chits.map((c) => c.id).toList();
    r.relaxed = elig.relaxed;
    r.winnerChitId = chit.id;
    r.winnerMemberId = winnerMemberId;
    r.resolution = resolution;
    r.status = RoundStatus.completed;
    r.completedAt = _clock();
    _system(g, Notices.roundResult(g, r));
    if (g.completed) {
      _system(g, 'All ${plural(g.rounds.length, 'month')} are decided. The scheme is complete. '
          'Please settle any pending payments.');
    }
  }

  // ------------------------------------------------------------- payments --

  /// Records how much [memberId] has paid in for round [index] (0 clears it).
  void recordPayment(
    ChitGroup g,
    int index, {
    required String memberId,
    required int amount,
    required String actor,
  }) {
    final r = _round(g, index);
    final m = g.memberById(memberId);
    if (m == null) throw RuleViolation('Member not found.');
    final due = Rules.monthlyDue(g, memberId);
    if (due == 0) throw RuleViolation('${m.name} has no chit, so nothing is due.');
    if (amount < 0 || amount > due) {
      throw RuleViolation('Enter an amount between ₹0 and ${rupees(due)}.');
    }
    final old = Rules.paidBy(r, memberId);
    if (old == amount) return;
    if (amount == 0) {
      r.paid.remove(memberId);
    } else {
      r.paid[memberId] = amount;
    }
    _log(
      g,
      'Month ${r.number}: ${m.name} has paid ${rupees(amount)} of ${rupees(due)}.',
      actor: actor,
    );
  }

  /// Marks a winner's payout as handed over (or not).
  void setPayoutDone(
    ChitGroup g,
    int index, {
    required String memberId,
    required bool done,
    required String actor,
  }) {
    final r = _round(g, index);
    if (!r.isCompleted) throw RuleViolation('Month ${r.number} has no winner yet.');
    final payouts = Rules.roundPayouts(g, r);
    final amount = payouts[memberId];
    if (amount == null) throw RuleViolation('${g.memberName(memberId)} is not a recipient this month.');
    final changed = done ? r.payoutsDone.add(memberId) : r.payoutsDone.remove(memberId);
    if (!changed) return;
    _log(
      g,
      done
          ? 'Month ${r.number}: ${g.memberName(memberId)} received ${rupees(amount)}.'
          : 'Month ${r.number}: payout to ${g.memberName(memberId)} marked as not yet given.',
      actor: actor,
    );
  }

  // ------------------------------------------------------------- feed -----

  /// Posts a message from the admin to the updates feed.
  void postAnnouncement(ChitGroup g, String text, {required String actor}) {
    final clean = text.trim();
    if (clean.isEmpty) throw RuleViolation('Write a message first.');
    if (clean.length > maxAnnouncementLength) {
      throw RuleViolation('Keep messages under $maxAnnouncementLength characters.');
    }
    _log(g, clean, actor: actor, kind: FeedKind.announcement);
  }

  /// Short label for the method of [r] ("Vote", "Random draw", ...).
  static String methodText(Round r) {
    final m = r.method;
    return m == null ? 'Not chosen yet' : methodLabel(m);
  }
}
