const platformLabels = {
  'instagram_reels': 'Instagram Reels',
  'tiktok': 'TikTok',
  'youtube_shorts': 'YouTube Shorts',
};

String platformLabel(String? p) => platformLabels[p] ?? 'Any platform';

String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

String formatDuration(num seconds) {
  final total = seconds.round();
  final m = total ~/ 60;
  final s = total % 60;
  return m > 0 ? '$m:${s.toString().padLeft(2, '0')} min' : '${s}s';
}

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// "12 Mar, 14:05" in the viewer's local time. Returns '' for unparseable input.
String formatDateTime(String? iso) {
  if (iso == null) return '';
  final d = DateTime.tryParse(iso)?.toLocal();
  if (d == null) return '';
  final hh = d.hour.toString().padLeft(2, '0');
  final mm = d.minute.toString().padLeft(2, '0');
  return '${d.day} ${_months[d.month - 1]}, $hh:$mm';
}

String fileExtension(String name) {
  final i = name.lastIndexOf('.');
  return i < 0 ? '' : name.substring(i + 1).toLowerCase();
}

/// Client-side pre-check so obvious problems are caught before uploading. The server re-validates
/// everything (contents, duration, MIME), so this is only a convenience. Returns null when OK.
String? validateVideoFile({
  required String name,
  required int sizeBytes,
  required List<String> allowedExtensions,
  required int maxMb,
}) {
  if (sizeBytes <= 0) return 'That file is empty.';
  final ext = fileExtension(name);
  if (!allowedExtensions.contains(ext)) {
    return 'Unsupported file type. Use ${allowedExtensions.map((e) => e.toUpperCase()).join(', ')}.';
  }
  if (sizeBytes > maxMb * 1024 * 1024) {
    return 'This video is ${formatBytes(sizeBytes)}. The limit is $maxMb MB.';
  }
  return null;
}
