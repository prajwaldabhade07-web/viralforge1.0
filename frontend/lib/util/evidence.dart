final _clock = RegExp(r'(?:(\d{1,2}):)?(\d{1,2}):(\d{2})(?:\.\d+)?');
final _secs = RegExp(r'(\d+(?:\.\d+)?)\s*(?:s|sec|secs|seconds)\b', caseSensitive: false);

/// First timestamp in strings like "0:00-0:02", "at 0:05", "1:02:03" or "12s". Null when none is found.
double? parseEvidenceSeconds(String? text) {
  if (text == null || text.trim().isEmpty) return null;
  final m = _clock.firstMatch(text);
  if (m != null) {
    final h = int.tryParse(m.group(1) ?? '0') ?? 0;
    final mm = int.tryParse(m.group(2) ?? '');
    final ss = int.tryParse(m.group(3) ?? '');
    if (mm != null && ss != null && ss < 60) return (h * 3600 + mm * 60 + ss).toDouble();
  }
  final s = _secs.firstMatch(text);
  if (s != null) return double.tryParse(s.group(1) ?? '');
  return null;
}

String formatClock(double seconds) {
  final t = (seconds.isFinite && seconds > 0) ? seconds.floor() : 0;
  return '${t ~/ 60}:${(t % 60).toString().padLeft(2, '0')}';
}