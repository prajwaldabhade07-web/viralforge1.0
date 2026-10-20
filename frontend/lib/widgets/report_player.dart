import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../state/providers.dart';
import '../theme.dart';
import '../util/evidence.dart';
import 'common.dart';
import 'fx.dart';

class PlayerMarker {
  final double seconds;
  final String label;
  const PlayerMarker(this.seconds, this.label);
}

/// Lets other parts of the report ask the player to jump to a moment.
class ReportSeek {
  Future<void> Function(double seconds)? handler;
  Future<void> seek(double seconds) async => handler?.call(seconds);
}

/// The report's video. Fetches a short-lived signed URL and refreshes it before it expires.
class ReportPlayer extends ConsumerStatefulWidget {
  final String videoId;
  final List<PlayerMarker> markers;
  final ReportSeek seek;
  const ReportPlayer({super.key, required this.videoId, required this.markers, required this.seek});

  @override
  ConsumerState<ReportPlayer> createState() => _ReportPlayerState();
}

class _ReportPlayerState extends ConsumerState<ReportPlayer> {
  VideoPlayerController? _c;
  String? _error;
  bool _loading = true;
  DateTime _fetchedAt = DateTime.fromMillisecondsSinceEpoch(0);
  int _ttl = 300;

  @override
  void initState() {
    super.initState();
    widget.seek.handler = _seekTo;
    _open();
  }

  bool get _expired => DateTime.now().difference(_fetchedAt).inSeconds > _ttl - 30;

  void _onTick() {
    if (mounted) setState(() {});
  }

  Future<void> _open({Duration? resumeAt, bool play = false}) async {
    try {
      final signed = await ref.read(apiProvider).getVideoUrl(widget.videoId);
      final c = VideoPlayerController.networkUrl(Uri.parse(signed.url));
      await c.initialize();
      if (!mounted) {
        await c.dispose();
        return;
      }
      if (resumeAt != null) await c.seekTo(resumeAt);
      if (play) await c.play();
      c.addListener(_onTick);
      final old = _c;
      setState(() {
        _c = c;
        _fetchedAt = DateTime.now();
        _ttl = signed.expiresIn;
        _loading = false;
        _error = null;
      });
      if (old != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          old.removeListener(_onTick);
          old.dispose();
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'The video could not be loaded. Your report is still complete.';
        });
      }
    }
  }

  Future<void> _seekTo(double seconds) async {
    final c = _c;
    if (c == null) return;
    final d = Duration(milliseconds: (seconds * 1000).round());
    if (_expired || c.value.hasError) {
      await _open(resumeAt: d, play: true);
      return;
    }
    await c.seekTo(d);
    await c.play();
  }

  Future<void> _seekPlain(Duration d) async {
    final c = _c;
    if (c == null) return;
    if (_expired || c.value.hasError) {
      await _open(resumeAt: d);
    } else {
      await c.seekTo(d);
    }
  }

  Future<void> _toggle() async {
    final c = _c;
    if (c == null) return;
    if (c.value.isPlaying) {
      await c.pause();
    } else if (_expired || c.value.hasError) {
      await _open(resumeAt: c.value.position, play: true);
    } else {
      await c.play();
    }
  }

  @override
  void dispose() {
    widget.seek.handler = null;
    final c = _c;
    c?.removeListener(_onTick);
    c?.dispose();
    super.dispose();
  }

  Widget _scrub(VideoPlayerController c) {
    final p = context.pal;
    final dur = c.value.duration.inMilliseconds;
    final pos = c.value.position.inMilliseconds;
    return LayoutBuilder(builder: (context, cons) {
      final w = cons.maxWidth;
      double xOf(double secs) => dur <= 0 ? 0 : (secs * 1000 / dur).clamp(0.0, 1.0) * w;
      void seekAt(double dx) {
        if (dur <= 0 || w <= 0) return;
        final f = (dx / w).clamp(0.0, 1.0);
        _seekPlain(Duration(milliseconds: (f * dur).round()));
      }

      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (d) => seekAt(d.localPosition.dx),
        onHorizontalDragUpdate: (d) => seekAt(d.localPosition.dx),
        child: SizedBox(
          height: 32,
          child: Stack(clipBehavior: Clip.none, children: [
            Positioned(
              left: 0,
              right: 0,
              top: 13,
              child: Container(height: 6, decoration: BoxDecoration(color: p.track, borderRadius: BorderRadius.circular(3))),
            ),
            Positioned(
              left: 0,
              top: 13,
              child: Container(
                width: dur <= 0 ? 0 : (pos / dur).clamp(0.0, 1.0) * w,
                height: 6,
                decoration: BoxDecoration(color: p.ultra, borderRadius: BorderRadius.circular(3)),
              ),
            ),
            for (final m in widget.markers)
              Positioned(
                left: xOf(m.seconds) - 9,
                top: 4,
                child: Tooltip(
                  message: '${formatClock(m.seconds)}  ${m.label}',
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => widget.seek.seek(m.seconds),
                    child: SizedBox(
                      width: 18,
                      height: 24,
                      child: Center(
                        child: Container(
                          width: 8,
                          height: 16,
                          decoration: BoxDecoration(
                            color: p.sodium,
                            borderRadius: BorderRadius.circular(3),
                            border: Border.all(color: p.text.withValues(alpha: 0.4)),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ]),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final ty = context.ty;
    final c = _c;
    if (_loading) {
      return const Panel(padding: EdgeInsets.zero, child: AspectRatio(aspectRatio: 16 / 9, child: Skeleton(radius: 0, height: 200)));
    }
    if (c == null) {
      return Panel(
        child: Row(children: [
          Icon(Icons.videocam_off_outlined, color: p.mute),
          const SizedBox(width: 12),
          Expanded(child: Text(_error ?? 'The video is not available.', style: ty.body.copyWith(color: p.mute))),
        ]),
      );
    }
    final dur = c.value.duration;
    final pos = c.value.position;
    return Panel(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(kRadius),
        child: Column(children: [
          GestureDetector(
            onTap: _toggle,
            child: Container(
              color: Colors.black,
              width: double.infinity,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 420),
                  child: AspectRatio(
                    aspectRatio: c.value.aspectRatio == 0 ? 16 / 9 : c.value.aspectRatio,
                    child: VideoPlayer(c),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 16, 6),
            child: Row(children: [
              IconButton(
                tooltip: c.value.isPlaying ? 'Pause' : 'Play',
                icon: Icon(c.value.isPlaying ? Icons.pause : Icons.play_arrow),
                onPressed: _toggle,
              ),
              Text('${formatClock(pos.inMilliseconds / 1000)} / ${formatClock(dur.inMilliseconds / 1000)}', style: ty.caption),
              const SizedBox(width: 12),
              Expanded(child: _scrub(c)),
            ]),
          ),
          if (widget.markers.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final m in widget.markers)
                    ActionChip(
                      avatar: Icon(Icons.play_arrow, size: 16, color: p.ultra),
                      label: Text('${formatClock(m.seconds)}  ${m.label}'),
                      onPressed: () => widget.seek.seek(m.seconds),
                    ),
                ]),
              ),
            ),
        ]),
      ),
    );
  }
}