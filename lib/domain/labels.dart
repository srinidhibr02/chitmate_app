/// Human-readable names for the enums.
library;

import 'models.dart';

String methodLabel(RoundMethod m) {
  switch (m) {
    case RoundMethod.vote:
      return 'Vote';
    case RoundMethod.manual:
      return 'Pick by agreement';
    case RoundMethod.random:
      return 'Random draw';
  }
}

String methodDescription(RoundMethod m) {
  switch (m) {
    case RoundMethod.vote:
      return 'Members vote for who should receive this month\'s chit.';
    case RoundMethod.manual:
      return 'The group agrees on a chit and the admin records it.';
    case RoundMethod.random:
      return 'The app draws one eligible chit at random, fairly and only once.';
  }
}

String tieBreakLabel(TieBreakMode t) {
  switch (t) {
    case TieBreakMode.auto:
      return 'App draws randomly';
    case TieBreakMode.admin:
      return 'Admin decides after discussion';
  }
}

String roundStatusLabel(RoundStatus s) {
  switch (s) {
    case RoundStatus.pending:
      return 'Waiting';
    case RoundStatus.open:
      return 'In progress';
    case RoundStatus.awaitingTieBreak:
      return 'Tie - admin to decide';
    case RoundStatus.completed:
      return 'Decided';
  }
}

/// "Setting up", "Month 3 of 8" or "Completed".
String groupStatusLabel(ChitGroup g) {
  if (!g.started) return 'Setting up';
  final cur = g.currentRound;
  if (cur == null) return 'Completed';
  return 'Month ${cur.number} of ${g.rounds.length}';
}

String paymentStatusLabel(PaymentStatus s) {
  switch (s) {
    case PaymentStatus.paid:
      return 'Paid';
    case PaymentStatus.partial:
      return 'Part paid';
    case PaymentStatus.pending:
      return 'Pending';
    case PaymentStatus.overdue:
      return 'Overdue';
  }
}
