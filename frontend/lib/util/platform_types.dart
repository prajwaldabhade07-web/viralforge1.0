/// Result of reading a local video's metadata in the browser (web only).
class VideoProbe {
  final double? seconds;
  final String url;
  const VideoProbe(this.seconds, this.url);
}

/// Outcome of asking the browser to open its share sheet.
enum ShareResult { shared, cancelled, unsupported }
