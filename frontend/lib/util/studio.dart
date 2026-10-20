import 'dart:convert';

import 'format.dart';
import 'platform.dart';

/// Name of the hidden project that holds videos analysed from the dashboard.
const kQuickProject = 'Quick analyses';

class StudioDefaults {
  final String platform;
  final String niche;
  final String audience;
  const StudioDefaults({this.platform = 'tiktok', this.niche = '', this.audience = ''});

  bool get complete => niche.trim().isNotEmpty && audience.trim().isNotEmpty;

  static StudioDefaults load() {
    final raw = readPref('vf_studio_defaults');
    if (raw == null) return const StudioDefaults();
    try {
      final m = jsonDecode(raw);
      if (m is Map) {
        final p = m['platform'] as String?;
        return StudioDefaults(
          platform: (p != null && platformLabels.containsKey(p)) ? p : 'tiktok',
          niche: (m['niche'] as String?) ?? '',
          audience: (m['audience'] as String?) ?? '',
        );
      }
    } catch (_) {}
    return const StudioDefaults();
  }

  void save() => writePref(
        'vf_studio_defaults',
        jsonEncode({'platform': platform, 'niche': niche, 'audience': audience}),
      );
}