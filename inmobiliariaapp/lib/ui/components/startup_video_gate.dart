import 'package:flutter/material.dart';
import 'package:inmobiliariaapp/ui/pages/splash/splash_video_screen.dart';

class StartupVideoGate extends StatefulWidget {
  final Widget child;

  const StartupVideoGate({super.key, required this.child});

  @override
  State<StartupVideoGate> createState() => _StartupVideoGateState();
}

class _StartupVideoGateState extends State<StartupVideoGate> {
  bool _showVideo = true;

  void _finishVideo() {
    if (!mounted) return;

    setState(() {
      _showVideo = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_showVideo) {
      return SplashVideoScreen(onFinished: _finishVideo);
    }

    return widget.child;
  }
}
