#!/usr/bin/env python3
"""Independent simulation of the ChitMate rules.

This is NOT the app code. It is a separately written model of the rules agreed
with the product owner. It plays thousands of random schemes from start to
finish and checks the promises the rules make:

  * every chit wins exactly once, so a scheme of N chits ends after N months
  * the money always balances (payouts of a month add up to the pool)
  * nobody is paid two months in a row, unless the rule had to be eased
  * the rule is eased only when EVERY remaining chit touches last month's
    winners, and then only the least-overlapping chits stay eligible
  * votes never exceed a person's voting power, never repeat a target, and
    only go to eligible people
  * voting power: one per full chit; shares-only holders get one

It also prints the worked examples from the conversation so their numbers can
be compared with the Dart unit tests.

Run:  python3 tool/simulate_rules.py
"""
import random
import sys
from collections import defaultdict


# ----------------------------------------------------------------- rules ---
def power(chits, member):
    full = sum(1 for c in chits if len(c) == 1 and member in c)
    if full:
        return full
    return 1 if any(member in c for c in chits) else 0


def dues(chits, member):
    return sum(c.get(member, 0) for c in chits)


def payout(chits, idx):
    n = len(chits)
    return {m: s * n for m, s in chits[idx].items()}


def eligibility(chits, won, last_owners):
    unwon = [i for i in range(len(chits)) if i not in won]
    if not unwon:
        return [], False

    def overlap(i):
        return len(set(chits[i]) & last_owners)

    strict = [i for i in unwon if overlap(i) == 0]
    if strict:
        return strict, False
    best = min(overlap(i) for i in unwon)
    return [i for i in unwon if overlap(i) == best], True


# ------------------------------------------------------------ generation ---
def random_group(rng):
    n_members = rng.randint(2, 9)
    members = list(range(n_members))
    value = rng.choice([1000, 2000, 5000, 10000, 25000])
    chits = []
    for m in members:
        for _ in range(rng.choice([0, 1, 1, 1, 2, 3])):
            chits.append({m: value})
    for _ in range(rng.randint(0, 4)):
        owners = rng.sample(members, rng.randint(2, min(4, n_members))) if n_members >= 2 else []
        if len(owners) < 2:
            continue
        units = value // 100
        cuts = sorted(rng.sample(range(1, units), len(owners) - 1))
        parts = [(b - a) * 100 for a, b in zip([0] + cuts, cuts + [units])]
        chits.append(dict(zip(owners, parts)))
    # everybody needs a stake, and a scheme needs at least 2 chits
    for m in members:
        if not any(m in c for c in chits):
            chits.append({m: value})
    while len(chits) < 2:
        chits.append({rng.choice(members): value})
    return members, value, chits


# ------------------------------------------------------------------ play ---
def play(rng, members, value, chits, stats):
    n = len(chits)
    pool = value * n
    for c in chits:
        assert sum(c.values()) == value and all(v > 0 for v in c.values())
    assert sum(dues(chits, m) for m in members) == pool

    won = {}
    last = set()
    for rnd in range(n):
        elig, relaxed = eligibility(chits, won, last)
        assert elig, 'unwon chits exist but none eligible'
        unwon = [i for i in range(n) if i not in won]
        strict_exists = any(not (set(chits[i]) & last) for i in unwon)
        assert relaxed == (not strict_exists)

        if len(unwon) == 1:
            pick = unwon[0]
            stats['auto_last'] += 1
        else:
            method = rng.choice(['vote', 'manual', 'random'])
            stats[method] += 1
            if method == 'vote':
                targets = sorted({m for i in elig for m in chits[i]})
                votes = defaultdict(int)
                for voter in members:
                    p = power(chits, voter)
                    k = rng.randint(0, p)  # may cast fewer than allowed
                    chosen = rng.sample(targets, min(k, len(targets)))
                    assert len(chosen) <= p and len(set(chosen)) == len(chosen)
                    for t in chosen:
                        votes[t] += 1
                if not votes:
                    stats['no_votes_fallback'] += 1
                    pick = rng.choice(elig)
                else:
                    top = max(votes.values())
                    leaders = sorted(t for t, v in votes.items() if v == top)
                    if len(leaders) > 1:
                        stats['ties'] += 1
                    who = rng.choice(leaders)
                    options = [i for i in elig if who in chits[i]]
                    assert options, 'voted-in member has no eligible chit'
                    pick = rng.choice(options)
            else:
                pick = rng.choice(elig)

        assert pick in elig
        assert pick not in won
        pay = payout(chits, pick)
        assert sum(pay.values()) == pool, (pay, pool)
        owners = set(chits[pick])
        if owners & last:
            assert relaxed, 'consecutive payee but rule was not flagged as eased'
            stats['relaxed_rounds'] += 1
        won[pick] = rnd
        last = owners
        stats['rounds'] += 1
    assert len(won) == n
    stats['schemes'] += 1


def main():
    rng = random.Random(20261114)
    stats = defaultdict(int)
    trials = 30000
    for _ in range(trials):
        members, value, chits = random_group(rng)
        play(rng, members, value, chits, stats)
    print(f"schemes={stats['schemes']} rounds={stats['rounds']}")
    print('methods used: vote={vote} manual={manual} random={random} auto_last={auto_last}'.format(**{
        'vote': stats['vote'], 'manual': stats['manual'], 'random': stats['random'], 'auto_last': stats['auto_last']}))
    print(f"vote ties={stats['ties']}  no-vote fallbacks={stats['no_votes_fallback']}")
    pct = 100.0 * stats['relaxed_rounds'] / stats['rounds']
    print(f"rounds where the no-back-to-back rule had to be eased: {stats['relaxed_rounds']} ({pct:.2f}%)")

    # ---- the worked examples from the conversation --------------------------
    print('\nExample 1: A, B, BC (3000/7000), AD (5000/5000) at Rs 10,000 per chit')
    ex1 = [{'A': 10000}, {'B': 10000}, {'B': 3000, 'C': 7000}, {'A': 5000, 'D': 5000}]
    for m in 'ABCD':
        print(f'  {m}: dues={dues(ex1, m)} votes={power(ex1, m)}')
    print('  BC wins:', payout(ex1, 2), ' AD wins:', payout(ex1, 3), ' pool =', 10000 * len(ex1))

    print('\nExample 2: A 3 full + AD, B 2 full + BC + BE')
    ex2 = [{'A': 10000}] * 3 + [{'A': 5000, 'D': 5000}] + [{'B': 10000}] * 2 + [
        {'B': 3000, 'C': 7000}, {'B': 5000, 'E': 5000}]
    for m in 'ABCDE':
        print(f'  {m}: dues={dues(ex2, m)} votes={power(ex2, m)}')
    print('  total chits =', len(ex2), ' pool =', 10000 * len(ex2),
          ' total votes =', sum(power(ex2, m) for m in 'ABCDE'))
    print('  A share of votes: %.1f%%' % (100.0 * power(ex2, 'A') / sum(power(ex2, m) for m in 'ABCDE')))

    # worst case: A holds 3 of 5 chits
    chits = [{'A': 1}, {'A': 1}, {'A': 1}, {'B': 1}, {'C': 1}]
    forced = 0
    runs = 5000
    for _ in range(runs):
        won, last, f = {}, set(), 0
        for r in range(5):
            e, rel = eligibility(chits, won, last)
            p = rng.choice(e)
            if set(chits[p]) & last:
                f += 1
            won[p] = r
            last = set(chits[p])
        forced += f > 0
    print('\nA holds 3 of 5 chits: cycles that need the rule eased at least once: %.1f%%' % (100.0 * forced / runs))
    print('\nALL INVARIANTS HELD')


if __name__ == '__main__':
    sys.exit(main())
