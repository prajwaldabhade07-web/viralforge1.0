// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
// Web implementation: localStorage, browser notifications and local video probing.
import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

import 'platform_types.dart';

export 'platform_types.dart';

String? readPref(String key) {
  try {
    return html.window.localStorage[key];
  } catch (_) {
    return null;
  }
}

void writePref(String key, String value) {
  try {
    html.window.localStorage[key] = value;
  } catch (_) {}
}

Future<bool> requestNotifyPermission() async {
  try {
    if (!html.Notification.supported) return false;
    final current = html.Notification.permission;
    if (current == 'granted') return true;
    if (current == 'denied') return false;
    return (await html.Notification.requestPermission()) == 'granted';
  } catch (_) {
    return false;
  }
}

void notifyDone(String title, String body) {
  try {
    final dynamic doc = html.document;
    final hidden = doc.hidden == true;
    if (!hidden) return; // only interrupt people who are looking at another tab
    if (html.Notification.supported && html.Notification.permission == 'granted') {
      html.Notification(title, body: body);
    }
  } catch (_) {}
}

Future<VideoProbe?> probeVideo(Uint8List bytes, String mime) async {
  try {
    final blob = html.Blob([bytes], mime);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final video = html.VideoElement()
      ..preload = 'metadata'
      ..muted = true
      ..src = url;
    final done = Completer<double?>();
    video.onLoadedMetadata.first.then((_) {
      final d = video.duration;
      if (!done.isCompleted) done.complete(d.isFinite ? d.toDouble() : null);
    });
    video.onError.first.then((_) {
      if (!done.isCompleted) done.complete(null);
    });
    final seconds = await done.future.timeout(const Duration(seconds: 6), onTimeout: () => null);
    video.removeAttribute('src');
    video.load();
    return VideoProbe(seconds, url);
  } catch (_) {
    return null;
  }
}

void releaseObjectUrl(String url) {
  try {
    html.Url.revokeObjectUrl(url);
  } catch (_) {}
}