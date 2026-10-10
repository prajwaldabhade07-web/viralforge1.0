import 'package:flutter_test/flutter_test.dart';
import 'package:viralforge_experiment/util/format.dart';

void main() {
  test('formatBytes', () {
    expect(formatBytes(512), '512 B');
    expect(formatBytes(2048), '2 KB');
    expect(formatBytes(5 * 1024 * 1024), '5.0 MB');
  });

  test('formatDuration', () {
    expect(formatDuration(12.4), '12s');
    expect(formatDuration(75), '1:15 min');
  });

  test('formatDateTime handles bad input', () {
    expect(formatDateTime(null), '');
    expect(formatDateTime('nonsense'), '');
    expect(formatDateTime('2026-03-02T10:05:00+00:00'), isNotEmpty);
  });

  group('validateVideoFile', () {
    const allowed = ['mp4', 'webm', 'mov'];
    String? check(String name, int size) =>
        validateVideoFile(name: name, sizeBytes: size, allowedExtensions: allowed, maxMb: 50);

    test('accepts supported types within the limit', () {
      expect(check('clip.mp4', 1000), isNull);
      expect(check('CLIP.WEBM', 1000), isNull);
      expect(check('a.mov', 50 * 1024 * 1024), isNull);
    });

    test('rejects empty, wrong type, and oversized files', () {
      expect(check('clip.mp4', 0), contains('empty'));
      expect(check('clip.exe', 1000), contains('Unsupported'));
      expect(check('noextension', 1000), contains('Unsupported'));
      expect(check('big.mp4', 51 * 1024 * 1024), contains('50 MB'));
    });
  });
}
