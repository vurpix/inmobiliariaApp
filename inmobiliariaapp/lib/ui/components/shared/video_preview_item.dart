import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class VideoPreviewWidget extends StatefulWidget {
  final String path;
  const VideoPreviewWidget({super.key, required this.path});

  @override
  State<VideoPreviewWidget> createState() => _VideoPreviewWidgetState();
}

class _VideoPreviewWidgetState extends State<VideoPreviewWidget> {
  VideoPlayerController? _controller;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _initController();
  }

  @override
  void didUpdateWidget(VideoPreviewWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) _initController();
  }

  Future<void> _initController() async {
    if (_controller != null) {
      await _controller!.pause();
      await _controller!.dispose();
      _controller = null;
    }

    if (mounted) setState(() => _initialized = false);

    // Detección de origen (Red o Local)
    final newController = widget.path.startsWith('http')
        ? VideoPlayerController.networkUrl(Uri.parse(widget.path))
        : VideoPlayerController.file(File(widget.path));

    try {
      await newController.initialize();
      _controller = newController;
      if (mounted) setState(() => _initialized = true);
    } catch (e) {
      debugPrint("Error video: $e");
    }
  }

  @override
  void dispose() {
    // CRÍTICO: Si no haces esto, el log seguirá apareciendo infinitamente
    _controller?.pause(); // Detén el audio/video antes
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    if (!_initialized ||
        controller == null ||
        !controller.value.isInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    // --- LÓGICA DE PROPORCIONES ---
    final size = controller.value.size;
    final bool isVertical = size.height > size.width;
    final double aspectRatio = controller.value.aspectRatio;

    return GestureDetector(
      onTap: () {
        setState(() {
          controller.value.isPlaying ? controller.pause() : controller.play();
        });
      },
      child: Container(
        // Si es vertical, le damos un límite de altura más alto, si no, que sea estándar
        constraints: BoxConstraints(maxHeight: isVertical ? 400 : 220),
        width: double.infinity,
        color: Colors.black,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // El AspectRatio asegura que no se deforme según la data real del video
            AspectRatio(
              aspectRatio: aspectRatio,
              child: VideoPlayer(controller),
            ),

            // Overlay oscuro y botón cuando está en pausa
            if (!controller.value.isPlaying) ...[
              Container(color: Colors.black26),
              const CircleAvatar(
                backgroundColor: Colors.black45,
                radius: 30,
                child: Icon(Icons.play_arrow, color: Colors.white, size: 40),
              ),
              Positioned(
                bottom: 10,
                right: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    isVertical ? "Vertical (9:16)" : "Horizontal (16:9)",
                    style: const TextStyle(color: Colors.white, fontSize: 10),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
