import 'dart:typed_data';

import 'platform_types.dart';

export 'platform_types.dart';

final Map<String, String> _mem = {};

String? readPref(String key) => _mem[key];

void writePref(String key, String value) => _mem[key] = value;

Future<bool> requestNotifyPermission() async => false;

void notifyDone(String title, String body) {}

Future<VideoProbe?> probeVideo(Uint8List bytes, String mime) async => null;

void releaseObjectUrl(String url) {}