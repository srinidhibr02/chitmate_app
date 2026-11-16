/// Indian mobile numbers. A person is identified in ChitMate by the number
/// they sign in with, so numbers are always stored in one form: +91XXXXXXXXXX.
library;

/// Returns `+91XXXXXXXXXX` for a valid Indian mobile number typed in any
/// common way ("98765 43210", "09876543210", "+91 98765-43210"), or null.
String? normalizeIndianMobile(String raw) {
  var digits = raw.replaceAll(RegExp(r'\D'), '');
  if (digits.length == 12 && digits.startsWith('91')) {
    digits = digits.substring(2);
  } else if (digits.length == 11 && digits.startsWith('0')) {
    digits = digits.substring(1);
  }
  if (!RegExp(r'^[6-9]\d{9}$').hasMatch(digits)) return null;
  return '+91$digits';
}

/// `+91 98765 43210` for display.
String formatPhone(String? e164) {
  if (e164 == null || e164.isEmpty) return '';
  final n = normalizeIndianMobile(e164);
  if (n == null) return e164;
  final d = n.substring(3);
  return '+91 ${d.substring(0, 5)} ${d.substring(5)}';
}
