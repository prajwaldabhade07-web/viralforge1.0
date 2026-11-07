// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
// Web implementation: localStorage, browser notifications and local video probing.
import 'dart:async';
import 'dart:html' as html;
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
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

/// Saves [content] as a file through the browser's normal download (no server involved).
Future<bool> downloadTextFile(String filename, String content, String mimeType) async {
  try {
    final blob = html.Blob([content], mimeType);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final link = html.AnchorElement(href: url)
      ..download = filename
      ..style.display = 'none';
    html.document.body?.append(link);
    link.click();
    link.remove();
    Timer(const Duration(seconds: 2), () => html.Url.revokeObjectUrl(url));
    return true;
  } catch (_) {
    return false;
  }
}

/// Opens the device's share sheet (phones, tablets and recent desktop browsers). Returns
/// [ShareResult.unsupported] when the browser has none, so the caller can fall back to copying.
Future<ShareResult> shareText(String title, String text) async {
  try {
    final nav = globalContext['navigator'];
    if (nav == null || !nav.isA<JSObject>()) return ShareResult.unsupported;
    final navigator = nav as JSObject;
    if (!navigator.has('share')) return ShareResult.unsupported;
    final data = {'title': title, 'text': text}.jsify();
    final result = navigator.callMethod<JSAny?>('share'.toJS, data);
    if (result != null) await (result as JSPromise<JSAny?>).toDart;
    return ShareResult.shared;
  } catch (e) {
    return '$e'.contains('AbortError') ? ShareResult.cancelled : ShareResult.unsupported;
  }
}

/// Opens a standalone HTML page in a new tab (used with a page that prints itself, so people can
/// choose "Save as PDF"). Returns false when the browser blocked the new tab.
bool openPrintableHtml(String content) {
  try {
    final blob = html.Blob([content], 'text/html');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.window.open(url, '_blank');
    Timer(const Duration(minutes: 1), () => html.Url.revokeObjectUrl(url));
    return true;
  } catch (_) {
    return false;
  }
}
