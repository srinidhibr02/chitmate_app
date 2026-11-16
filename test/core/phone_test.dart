import 'package:chit_mate/core/phone.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Indian mobile numbers are stored in one form', () {
    expect(normalizeIndianMobile('9876543210'), '+919876543210');
    expect(normalizeIndianMobile('98765 43210'), '+919876543210');
    expect(normalizeIndianMobile('09876543210'), '+919876543210');
    expect(normalizeIndianMobile('+91 98765-43210'), '+919876543210');
    expect(normalizeIndianMobile('919876543210'), '+919876543210');
  });

  test('invalid numbers are refused', () {
    expect(normalizeIndianMobile(''), isNull);
    expect(normalizeIndianMobile('12345'), isNull);
    expect(normalizeIndianMobile('5876543210'), isNull); // must start with 6-9
    expect(normalizeIndianMobile('98765432101'), isNull);
    expect(normalizeIndianMobile('abcdefghij'), isNull);
  });

  test('numbers are shown with spacing', () {
    expect(formatPhone('+919876543210'), '+91 98765 43210');
    expect(formatPhone(null), '');
    expect(formatPhone(''), '');
  });
}
