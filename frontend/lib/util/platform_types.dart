/// Result of reading a local video's metadata in the browser (web only).
class VideoProbe {
  final double? seconds;
  final String url;
  const VideoProbe(this.seconds, this.url);
}