import 'package:chit_mate/data/group_codec.dart';
import 'package:chit_mate/domain/models.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  test('a group survives the trip through a cloud document', () {
    final a = testActions();
    final b = example1(a, start: true);
    final g = b.group..adminUid = 'admin-1';
    a.renameMember(g, b.id('A'), 'A', phone: '9876500001', actor: 'x');
    a.renameMember(g, b.id('B'), 'B', phone: '9876500002', actor: 'x');

    final doc = groupToDoc(g);
    expect(doc['adminUid'], 'admin-1');
    expect(doc['memberPhones'], <String>['+919876500001', '+919876500002']);

    final back = groupFromDoc(doc)!;
    expect(back.toJson(), g.toJson());
    expect(back.adminUid, 'admin-1');
  });

  test('people who left lose access; numbers are listed once', () {
    final a = testActions();
    final b = example1(a, start: true);
    final g = b.group;
    a.renameMember(g, b.id('A'), 'A', phone: '9876500001', actor: 'x');
    a.renameMember(g, b.id('D'), 'D', phone: '9876500004', actor: 'x');
    expect(memberPhonesOf(g), <String>['+919876500001', '+919876500004']);
    a.removeMember(g, b.id('D'), actor: 'x');
    expect(memberPhonesOf(g), <String>['+919876500001']);
  });

  test('a very long feed is trimmed in the cloud copy, newest kept', () {
    final a = testActions();
    final g = example1(a).group;
    for (var i = 0; i < kMaxCloudFeedEntries + 50; i++) {
      a.postAnnouncement(g, 'Message $i', actor: 'Admin');
    }
    final feed = (groupToDoc(g)['data'] as Map)['feed'] as List;
    expect(feed.length, kMaxCloudFeedEntries);
    expect((feed.last as Map)['text'], 'Message ${kMaxCloudFeedEntries + 49}');
  });

  test('unreadable documents are skipped, not crashed on', () {
    expect(groupFromDoc(null), isNull);
    expect(groupFromDoc(<String, dynamic>{'adminUid': 'x'}), isNull);
    expect(groupFromDoc(<String, dynamic>{'data': 'nonsense'}), isNull);
    expect(groupFromDoc(<String, dynamic>{'data': <String, dynamic>{'id': 1}}), isNull);
  });

  test('older groups without an organiser id still load', () {
    final g = ChitGroup.fromJson(<String, dynamic>{'id': 'g', 'name': 'Old'});
    expect(g.adminUid, isNull);
  });
}
