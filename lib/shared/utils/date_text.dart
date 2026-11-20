/// Dates as people read them in the app: dd/MM/yyyy (2026-11-20, owner's
/// request: one format on every screen).

String _two(int n) => n.toString().padLeft(2, '0');

/// 20/11/2026.
String dmy(DateTime d) => '${_two(d.day)}/${_two(d.month)}/${d.year}';

/// 20/11 — for tight chart axes only.
String dm(DateTime d) => '${_two(d.day)}/${_two(d.month)}';

/// A stored day key ("2026-11-20", e.g. a settlement day) as 20/11/2026.
/// Anything that isn't a day key is returned unchanged.
String dmyKey(String key) {
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(key);
  return m == null ? key : '${m[3]}/${m[2]}/${m[1]}';
}
