/// Returns a timezone identifier that Xiaomi firmware can resolve
/// unambiguously.
///
/// Dart exposes platform timezone abbreviations on some targets (`CST`,
/// `EDT`, ...). Abbreviations are ambiguous and must not be sent as the
/// Xiaomi timezone ID. An IANA identifier is kept when available; otherwise
/// the current offset is represented as a fixed GMT identifier.
String xiaomiTimeZoneId(String name, Duration offset) {
  if (name == 'UTC' || name.contains('/')) return name;

  final totalMinutes = offset.inMinutes;
  if (totalMinutes == 0) return 'UTC';
  final absoluteMinutes = totalMinutes.abs();
  final hours = (absoluteMinutes ~/ 60).toString().padLeft(2, '0');
  final minutes = (absoluteMinutes % 60).toString().padLeft(2, '0');
  final sign = totalMinutes < 0 ? '-' : '+';
  return 'GMT$sign$hours:$minutes';
}
