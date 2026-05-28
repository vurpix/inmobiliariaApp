// ui/screens/global/splash_video_screen.dart
import 'package:flutter/material.dart';
import 'package:inmobiliariaapp/utils/themes.dart';
import 'package:video_player/video_player.dart';

class SplashVideoScreen extends StatefulWidget {
  final VoidCallback onFinished;

  const SplashVideoScreen({super.key, required this.onFinished});

  @override
  State<SplashVideoScreen> createState() => _SplashVideoScreenState();
}

class _SplashVideoScreenState extends State<SplashVideoScreen> {
  late VideoPlayerController
  _controller; // Ajustado: removido el 'final' para compatibilidad asíncrona en red
  bool _finished = false;

  @override
  void initState() {
    super.initState();

    // 1. ASIGNACIÓN DE LA URL REMOTA DE FIREBASE STORAGE
    _controller = VideoPlayerController.networkUrl(
      Uri.parse(
        'https://firebasestorage.googleapis.com/v0/b/inmobiliariaarmandomarin.firebasestorage.app/o/native_data%2Fintro_human_bionics_movile.mp4?alt=media&token=95955c71-468c-44bf-961a-142a65ac8e7a',
      ),
    );

    // Inicialización del buffer de red
    _controller.initialize().then((_) {
      if (!mounted) return;

      setState(() {});
      _controller.play();
    });

    _controller.addListener(_videoListener);
  }

  void _videoListener() {
    if (!_controller.value.isInitialized) return;
    if (_finished) return;

    final position = _controller.value.position;
    final duration = _controller.value.duration;

    // Control preciso de finalización del video en red
    if (duration != Duration.zero && position >= duration) {
      _finished = true;
      _controller.removeListener(
        _videoListener,
      ); // Detiene el listener antes de saltar
      widget.onFinished();
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_videoListener);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // MODIFICADO: Mientras el video se descarga de Storage, mostramos un loading elegante
    if (!_controller.value.isInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          child: Container(
            padding: EdgeInsets.only(
              left: ResponsiveUtils.getWidth(context, 15),
            ),
            width: _controller.value.size.width,
            height: _controller.value.size.height,
            child: VideoPlayer(_controller),
          ),
        ),
      ),
    );
  }
}
