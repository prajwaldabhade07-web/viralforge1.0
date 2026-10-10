import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_dropzone/flutter_dropzone.dart';

import '../api/api_client.dart';
import '../theme.dart';

/// Drag-and-drop target with a file-picker fallback (the whole area is also a button).
class VideoDropArea extends StatefulWidget {
  final void Function(PickedVideo video) onPicked;
  final void Function(String message) onError;
  final bool enabled;
  final String limitsText;
  const VideoDropArea({
    super.key,
    required this.onPicked,
    required this.onError,
    required this.limitsText,
    this.enabled = true,
  });

  @override
  State<VideoDropArea> createState() => _VideoDropAreaState();
}

class _VideoDropAreaState extends State<VideoDropArea> {
  bool _hover = false;
  DropzoneViewController? _ctl;

  Future<void> _pick() async {
    if (!widget.enabled) return;
    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['mp4', 'webm', 'mov'],
        withData: true,
      );
      if (res == null || res.files.isEmpty) return;
      final f = res.files.first;
      if (f.bytes == null) {
        widget.onError('Could not read that file. Try another one.');
        return;
      }
      widget.onPicked(PickedVideo.fromPlatformFile(f));
    } catch (_) {
      widget.onError('Could not open the file picker. Try dragging the video in instead.');
    }
  }

  Future<void> _dropped(dynamic ev) async {
    setState(() => _hover = false);
    if (!widget.enabled || _ctl == null) return;
    try {
      final name = await _ctl!.getFilename(ev);
      final data = await _ctl!.getFileData(ev);
      widget.onPicked(PickedVideo(name, data));
    } catch (_) {
      widget.onError('Could not read the dropped file. Try the "Choose a file" button instead.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      if (kIsWeb)
        Positioned.fill(
          child: DropzoneView(
            operation: DragOperation.copy,
            onCreated: (c) => _ctl = c,
            onHover: () => setState(() => _hover = true),
            onLeave: () => setState(() => _hover = false),
            onDrop: _dropped,
          ),
        ),
      Semantics(
        button: true,
        label: 'Choose a video file to upload',
        child: InkWell(
          borderRadius: BorderRadius.circular(Tk.radius),
          onTap: widget.enabled ? _pick : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 36),
            decoration: BoxDecoration(
              color: _hover ? Tk.ultraSoft : Tk.gate,
              borderRadius: BorderRadius.circular(Tk.radius),
              border: Border.all(color: _hover ? Tk.ultra : Tk.line, width: _hover ? 2 : 1.5),
            ),
            child: Column(children: [
              Icon(Icons.movie_creation_outlined, size: 36, color: _hover ? Tk.ultra : Tk.mute),
              const SizedBox(height: 12),
              Text(_hover ? 'Release to add this video' : 'Drop a video here', style: display(19)),
              const SizedBox(height: 4),
              const Text('or choose a file from your device', style: TextStyle(color: Tk.mute)),
              const SizedBox(height: 14),
              OutlinedButton(onPressed: widget.enabled ? _pick : null, child: const Text('Choose a file')),
              const SizedBox(height: 12),
              Text(widget.limitsText, style: const TextStyle(color: Tk.mute, fontSize: 13), textAlign: TextAlign.center),
            ]),
          ),
        ),
      ),
    ]);
  }
}
