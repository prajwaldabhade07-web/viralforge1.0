import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../theme.dart';
import 'fx.dart';

/// Small looping, muted preview of a local clip (blob URL). Tap to play or pause.
class VideoPreview extends StatefulWidget {
  final String url;
  const VideoPreview({super.key, required this.url});

  @override
  State<VideoPreview> createState() => _VideoPreviewState();
}

class _VideoPreviewState extends State<VideoPreview> {
  VideoPlayerController? _c;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final c = VideoPlayerController.networkUrl(Uri.parse(widget.url));
      await c.initialize();
      if (!mounted) {
        await c.dispose();
        return;
      }
      await c.setLooping(true);
      await c.setVolume(0);
      setState(() => _c = c);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final c = _c;
    Widget body;
    if (_failed) {
      body = Center(child: Icon(Icons.movie_outlined, color: p.mute, size: 32));
    } else if (c == null) {
      body = const Skeleton(radius: 0, height: 100);
    } else {
      body = GestureDetector(
        onTap: () => setState(() => c.value.isPlaying ? c.pause() : c.play()),
        child: Stack(alignment: Alignment.center, children: [
          FittedBox(
            fit: BoxFit.cover,
            clipBehavior: Clip.hardEdge,
            child: SizedBox(width: c.value.size.width, height: c.value.size.height, child: VideoPlayer(c)),
          ),
          if (!c.value.isPlaying) Icon(Icons.play_circle_fill, color: p.onHero, size: 36),
        ]),
      );
    }
    return Semantics(
      label: 'Preview of your clip',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: ColoredBox(color: p.surfaceAlt, child: body),
      ),
    );
  }
}