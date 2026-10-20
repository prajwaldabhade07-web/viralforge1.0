import 'dart:convert';

import 'format.dart';
import 'platform.dart';
import 'studio.dart';

const kNiches = ['Cooking', 'Fitness', 'Tech', 'Travel', 'Comedy', 'Beauty', 'Gaming', 'Education'];
const kAudiences = ['Students', 'Parents', 'Gen Z', 'Professionals', 'Small business owners'];
const kGoals = ['Grow my followers', 'Land brand deals', 'Make better videos', 'Just exploring'];

/// What Pip knows about the creator. Stored in this browser only.
class Profile {
  final String name;
  final String platform;
  final String niche;
  final String audience;
  final String goal;
  const Profile({this.name = '', this.platform = 'tiktok', this.niche = '', this.audience = '', this.goal = ''});

  Profile copyWith({String? name, String? platform, String? niche, String? audience, String? goal}) => Profile(
        name: name ?? this.name,
        platform: platform ?? this.platform,
        niche: niche ?? this.niche,
        audience: audience ?? this.audience,
        goal: goal ?? this.goal,
      );

  static Profile load() {
    final raw = readPref('vf_profile');
    if (raw == null) return const Profile();
    try {
      final m = jsonDecode(raw);
      if (m is Map) {
        final p = m['platform'] as String?;
        return Profile(
          name: (m['name'] as String?) ?? '',
          platform: (p != null && platformLabels.containsKey(p)) ? p : 'tiktok',
          niche: (m['niche'] as String?) ?? '',
          audience: (m['audience'] as String?) ?? '',
          goal: (m['goal'] as String?) ?? '',
        );
      }
    } catch (_) {}
    return const Profile();
  }

  /// Saves the profile, and keeps Quick Studio's defaults in step with it.
  void save() {
    writePref('vf_profile', jsonEncode({'name': name, 'platform': platform, 'niche': niche, 'audience': audience, 'goal': goal}));
    if (niche.trim().isNotEmpty && audience.trim().isNotEmpty) {
      StudioDefaults(platform: platform, niche: niche.trim(), audience: audience.trim()).save();
    }
  }
}

bool onboardingDone(String? email) => readPref('vf_onb_${email ?? ''}') == '1';

void markOnboarded(String? email) => writePref('vf_onb_${email ?? ''}', '1');