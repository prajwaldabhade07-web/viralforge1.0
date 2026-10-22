import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../util/platform.dart';

/// Text size for the whole app: 1.0 (Normal) or 1.2 (Large). Saved in this browser.
class TextScaleController extends StateNotifier<double> {
  TextScaleController() : super(_load());

  static double _load() => (double.tryParse(readPref('vf_text') ?? '') ?? 1.0) >= 1.2 ? 1.2 : 1.0;

  void set(double v) {
    state = v;
    writePref('vf_text', '$v');
  }
}

final textScaleProvider = StateNotifierProvider<TextScaleController, double>((ref) => TextScaleController());