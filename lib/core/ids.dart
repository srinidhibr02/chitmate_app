import 'dart:math';

int _counter = 0;
final Random _idRandom = Random();

/// A short unique id, good enough for records stored on one phone.
String generateId() {
  _counter++;
  final time = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
  final noise = _idRandom.nextInt(1 << 30).toRadixString(36);
  return '$time$noise${_counter.toRadixString(36)}';
}
