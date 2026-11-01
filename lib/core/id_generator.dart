/// Generates unique string ids for entities.
/// Combines the current timestamp with a monotonic counter so ids are
/// unique within a session and sort chronologically.
class IdGenerator {
  IdGenerator._();

  static int _counter = 0;

  /// Returns a new id, optionally prefixed (e.g. 'med', 'sale').
  static String generate([String prefix = '']) {
    _counter++;
    final stamp = DateTime.now().millisecondsSinceEpoch;
    return prefix.isEmpty ? '${stamp}_$_counter' : '${prefix}_$stamp$_counter';
  }
}
