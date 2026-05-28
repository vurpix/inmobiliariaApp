// ui/screens/tenant/stories_viewer_page.dart
import 'package:flutter/material.dart';
import 'package:inmobiliariaapp/models/story_model.dart';
import 'package:video_player/video_player.dart';
import 'package:inmobiliariaapp/ui/components/global/custom_text.dart';

class StoriesViewerPage extends StatefulWidget {
  final List<StoryModel> stories;
  final int initialIndex;
  final bool
  isSingleMode; // Flag para saber si es reproductor de video único o carrusel

  const StoriesViewerPage({
    super.key,
    required this.stories,
    this.initialIndex = 0,
    this.isSingleMode =
        false, // Por defecto se comporta como carrusel de deslizamiento
  });

  @override
  State<StoriesViewerPage> createState() => _StoriesViewerPageState();
}

class _StoriesViewerPageState extends State<StoriesViewerPage>
    with SingleTickerProviderStateMixin {
  late PageController _pageController;
  VideoPlayerController? _videoController;
  int _currentIndex = 0;

  // Controlador de animación para las barritas superiores
  AnimationController? _animController;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    // Vinculamos el PageController pasándole el índice inicial de la burbuja tocada
    _pageController = PageController(initialPage: widget.initialIndex);
    _animController = AnimationController(vsync: this);

    _initVideoPlayer(_currentIndex);
  }

  void _initVideoPlayer(int index) async {
    // Liberación estricta de controladores previos para evitar congelamientos o sonidos cruzados
    _videoController?.dispose();
    _videoController = null;
    _animController?.stop();
    _animController?.reset();

    if (index >= widget.stories.length || index < 0) return;

    final story = widget.stories[index];
    _videoController = VideoPlayerController.networkUrl(
      Uri.parse(story.videoUrl),
    );

    try {
      await _videoController!.initialize();
      if (!mounted) return;
      setState(() {});

      _videoController!.play();

      if (widget.isSingleMode) {
        _videoController!.setLooping(true);
      } else {
        // Sincronizar barrita superior con la duración exacta del video cargado
        _animController!.duration = _videoController!.value.duration;
        _animController!.forward();

        // Escuchar cuando el video termine de forma natural para pasar al siguiente automáticamente
        _videoController!.addListener(_videoListener);
      }
    } catch (e) {
      debugPrint("Error al inicializar video story: $e");
    }
  }

  void _videoListener() {
    if (_videoController == null) return;
    if (_videoController!.value.position == _videoController!.value.duration) {
      _videoController!.removeListener(_videoListener);
      _onStoryComplete();
    }
  }

  void _onStoryComplete() {
    if (widget.isSingleMode) return;

    if (_currentIndex + 1 < widget.stories.length) {
      // Avanza el PageView físicamente mediante animación fluida
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      // Si era el último video de la lista completa, cerramos la pantalla
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _videoController?.removeListener(_videoListener);
    _pageController.dispose();
    _videoController?.dispose();
    _animController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Si estás en modo video único, desactivamos el swipe horizontal bloqueando la física del scroll
    final ScrollPhysics pagePhysics = widget.isSingleMode
        ? const NeverScrollableScrollPhysics()
        : const ClampingScrollPhysics();

    return Scaffold(
      backgroundColor: Colors.black,
      body: PageView.builder(
        controller: _pageController,
        physics: pagePhysics,
        itemCount: widget.stories.length,
        // --- COMPONENTE CRÍTICO: DETECTA EL SWIPE DEL USUARIO ---
        onPageChanged: (int newPageIndex) {
          setState(() {
            _currentIndex = newPageIndex;
          });
          // Se destruye el video anterior e inicializa el seleccionado al deslizar de forma transparente
          _initVideoPlayer(newPageIndex);
        },
        itemBuilder: (context, index) {
          // Solo renderizamos el contenido visual si es el índice actual para optimizar la GPU
          if (index != _currentIndex) {
            return Container(color: Colors.black);
          }

          if (_videoController == null ||
              !_videoController!.value.isInitialized) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
          }

          final currentStory = widget.stories[_currentIndex];

          return GestureDetector(
            // Toque simple: Pausa / Replay cómodo estilo Reels/TikTok
            onTapDown: (_) {
              setState(() {
                _videoController!.value.isPlaying
                    ? _videoController!.pause()
                    : _videoController!.play();
              });
            },
            child: Stack(
              children: [
                // 1. VIDEO A PANTALLA COMPLETA
                Center(
                  child: AspectRatio(
                    aspectRatio: _videoController!.value.aspectRatio,
                    child: VideoPlayer(_videoController!),
                  ),
                ),

                // 2. GRADIENTE OSCURO SUPERIOR PARA CONTRASTE
                Container(
                  height: 140,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.black54, Colors.transparent],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),

                // 3. CAPA DE INTERFAZ DEL USUARIO
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12.0,
                      vertical: 8.0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Barritas de progreso superiores segmentadas dinámicas
                        if (!widget.isSingleMode)
                          Row(
                            children: widget.stories.asMap().entries.map((
                              entry,
                            ) {
                              int idx = entry.key;
                              return Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 2.0,
                                  ),
                                  child: AnimatedBuilder(
                                    animation: _animController!,
                                    builder: (context, child) {
                                      double val = 0.0;
                                      if (idx < _currentIndex)
                                        val = 1.0; // Ya reproducido
                                      if (idx == _currentIndex)
                                        val = _animController!
                                            .value; // Viéndose actualmente

                                      return LinearProgressIndicator(
                                        value: val,
                                        backgroundColor: Colors.white30,
                                        color: Colors.white,
                                        minHeight: 2.5,
                                      );
                                    },
                                  ),
                                ),
                              );
                            }).toList(),
                          ),

                        SizedBox(height: widget.isSingleMode ? 4 : 12),

                        // Fila de metadatos e información corporativa
                        Row(
                          children: [
                            const CircleAvatar(
                              radius: 16,
                              backgroundColor: Colors.white24,
                              child: Icon(
                                Icons.business_rounded,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const CustomText(
                                  "SINMO",
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  baseFontSize: 13,
                                ),
                                if (currentStory.title.isNotEmpty)
                                  CustomText(
                                    currentStory.title,
                                    color: Colors.white70,
                                    baseFontSize: 11,
                                  ),
                              ],
                            ),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(
                                Icons.close_rounded,
                                color: Colors.white,
                                size: 24,
                              ),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
