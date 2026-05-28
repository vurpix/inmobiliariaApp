// ui/components/tenant_flow/property_detail_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inmobiliariaapp/bloc/authBloc/auth_bloc.dart';
import 'package:inmobiliariaapp/bloc/authBloc/auth_event.dart';
import 'package:inmobiliariaapp/bloc/authBloc/auth_state.dart';
import 'package:inmobiliariaapp/models/application_model.dart';
import 'package:inmobiliariaapp/models/property_model.dart';
import 'package:inmobiliariaapp/services/application_service.dart';
import 'package:inmobiliariaapp/ui/components/tenant_flow/application_status_button.dart';
import 'package:inmobiliariaapp/ui/components/tenant_flow/tenant_apply_screen.dart';
import 'package:inmobiliariaapp/ui/components/tenant_flow/select_slot_screen.dart';
import 'package:inmobiliariaapp/utils/format_extensions.dart';
import 'package:inmobiliariaapp/utils/themes.dart';
import 'package:video_player/video_player.dart';

class PropertyDetailScreen extends StatefulWidget {
  final PropertyModel property;

  const PropertyDetailScreen({super.key, required this.property});

  @override
  State<PropertyDetailScreen> createState() => _PropertyDetailScreenState();
}

final ApplicationService _applicationService = ApplicationService();

class _PropertyDetailScreenState extends State<PropertyDetailScreen> {
  late PageController _pageController;
  int _currentPage = 0;

  // --- VARIABLES PARA EXTRAER LA MINIATURA REAL DEL VIDEO ---
  VideoPlayerController? _thumbnailVideoController;
  bool _isThumbnailLoaded = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _generateVideoThumbnail();
  }

  // --- NUEVO: Extrae de forma ultra-ligera el fotograma 0 del video ---
  Future<void> _generateVideoThumbnail() async {
    if (widget.property.videoUrl == null || widget.property.videoUrl!.isEmpty)
      return;

    try {
      _thumbnailVideoController = VideoPlayerController.networkUrl(
        Uri.parse(widget.property.videoUrl!),
      );
      await _thumbnailVideoController!.initialize();
      if (mounted) {
        setState(() {
          _isThumbnailLoaded = true;
        });
      }
    } catch (e) {
      debugPrint("No se pudo generar miniatura del video: $e");
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _thumbnailVideoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {


    final bool modelHasVideo =
        widget.property.videoUrl != null &&
        widget.property.videoUrl!.isNotEmpty;
    final int totalMediaCount =
        (modelHasVideo ? 1 : 0) + widget.property.imageUrls.length;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // --- HEADER MULTIMEDIA DE PORTADA ---
          SliverAppBar(
            expandedHeight: 350,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                children: [
                  PageView.builder(
                    controller: _pageController,
                    onPageChanged: (index) =>
                        setState(() => _currentPage = index),
                    itemCount: totalMediaCount,
                    itemBuilder: (context, index) {
                      // CASO 1: Es la ranura del video, mostramos la miniatura del video real
                      if (modelHasVideo && index == 0) {
                        return _buildVideoThumbnailCover(context);
                      }
                      // CASO 2: Es una foto normal de la galería
                      final imageIndex = modelHasVideo ? index - 1 : index;
                      return GestureDetector(
                        onTap: () => _openMultimediaDialog(context, index),
                        child: Image.network(
                          widget.property.imageUrls[imageIndex],
                          fit: BoxFit.cover,
                        ),
                      );
                    },
                  ),
                  _buildMediaIndicator(totalMediaCount),
                ],
              ),
            ),
          ),

          // --- INFORMACIÓN DE LA PROPIEDAD ---
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          widget.property.address,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Text(
                        FormatUtils.formatCurrency(widget.property.canon),
                        style: TextStyle(
                          fontSize: 20,
                          color: Colors.blue[800],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on,
                        size: 16,
                        color: Colors.grey,
                      ),
                      const Text(
                        " Bucaramanga, Santander",
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(width: 20),
                      const Icon(
                        Icons.square_foot,
                        size: 16,
                        color: Colors.grey,
                      ),
                      Text(
                        " ${widget.property.area} m²",
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                  const Divider(height: 40),
                  const Text(
                    "Descripción",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    widget.property.description,
                    style: const TextStyle(
                      fontSize: 15,
                      color: Colors.black87,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 30),
                  const Text(
                    "Amenidades",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: widget.property.amenities
                        .map(
                          (item) => Chip(
                            label: Text(item),
                            backgroundColor: Colors.blue[50],
                            labelStyle: TextStyle(
                              color: Colors.blue[900],
                              fontSize: 12,
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 150),
                ],
              ),
            ),
          ),
        ],
      ),

      // --- BARRA INFERIOR DE ACCIONES ---
      bottomSheet: Container(
        padding: const EdgeInsets.fromLTRB(20, 15, 20, 40),
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 10,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: BlocBuilder<AuthBloc, AuthState>(
          builder: (context, authState) {
            final bool isAuthenticated = authState is Authenticated;
            final String userId = isAuthenticated ? authState.user.id : '';

            return Row(
              children: [
                SizedBox(
                  width: 160,
                  height: 54,
                  child: !isAuthenticated
                      ? _buildSquareAction(
                          context,
                          Icons.calendar_month,
                          Colors.grey[600]!,
                          () =>
                              _showLoginRequiredDialog(context, "agendar cita"),
                        )
                      : StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('available_slots')
                              .where(
                                'propertyId',
                                isEqualTo: widget.property.id,
                              )
                              .where('attendeesUids', arrayContains: userId)
                              .snapshots(),
                          builder: (context, snapshot) {
                            final bool hasApp =
                                snapshot.hasData &&
                                snapshot.data!.docs.isNotEmpty;
                            if (hasApp) {
                              return ApplicationStatusButton(
                                propertyId: widget.property.id ?? '',
                                propertyAddress: widget.property.address,
                                userId: userId,
                                onApply: () => _navigateToApply(context),
                              );
                            } else {
                              return _buildSquareAction(
                                context,
                                Icons.calendar_month,
                                context.primaryColor,
                                () => _navigateToSchedule(
                                  context,
                                  userId,
                                  (authState).user.name,
                                ),
                              );
                            }
                          },
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDynamicApplyButton(
                    context,
                    isAuthenticated,
                    userId,
                    widget.property,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // --- COMPONENTE PORTADA: Muestra la miniatura real tomada del video ---
  Widget _buildVideoThumbnailCover(BuildContext context) {
    return GestureDetector(
      onTap: () => _openMultimediaDialog(context, 0),
      child: Stack(
        alignment: Alignment.center,
        children: [
          _isThumbnailLoaded && _thumbnailVideoController != null
              ? AspectRatio(
                  aspectRatio: _thumbnailVideoController!.value.aspectRatio,
                  child: VideoPlayer(_thumbnailVideoController!),
                )
              : Container(
                  color: Colors.black87,
                  child: const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                ),
          Container(color: Colors.black.withOpacity(0.15)), // Filtro cinemático
          const Icon(Icons.play_circle_fill, size: 75, color: Colors.white),
          Positioned(
            top: 20,
            left: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.video_collection_rounded,
                    color: Colors.white,
                    size: 14,
                  ),
                  SizedBox(width: 6),
                  Text(
                    "REPRODUCIR VIDEO",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- NUEVO: Muestra todo el contenido multimedia unificado en un diálogo fullscreen ---
  void _openMultimediaDialog(BuildContext context, int initialPage) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => _MultimediaFullscreenDialog(
        property: widget.property,
        initialPage: initialPage,
      ),
    );
  }

  Widget _buildMediaIndicator(int total) {
    return Positioned(
      bottom: 20,
      right: 20,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          "${_currentPage + 1} / $total",
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  // --- RESTO DE MÉTODOS DE COMPORTAMIENTO ---
  Widget _buildDynamicApplyButton(
    BuildContext context,
    bool auth,
    String uid,
    PropertyModel prop,
  ) {
    if (!auth)
      return _baseApplyButton(
        context,
        prop,
        "POSTULARME",
        const Color(0xFF1A237E),
        true,
      );
    return StreamBuilder<ApplicationModel?>(
      stream: _applicationService.watchApplicationByProperty(prop.id!),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return _baseApplyButton(
            context,
            prop,
            "POSTULARME",
            const Color(0xFF1A237E),
            false,
          );
        final application = snapshot.data;
        final myCandidate = _applicationService.getUserCandidate(
          application,
          uid,
        );
        if (myCandidate == null)
          return _baseApplyButton(
            context,
            prop,
            "POSTULARME",
            const Color(0xFF1A237E),
            false,
          );

        switch (myCandidate.status) {
          case 'pending_review':
            return _statusIndicator(Icons.search, "EN REVISIÓN", Colors.orange);
          case 'approved':
            return _statusIndicator(
              Icons.check_circle,
              "APROBADO",
              Colors.green,
            );
          case 'rejected':
            return _baseApplyButton(
              context,
              prop,
              "RECHAZADO",
              Colors.red,
              false,
            );
          default:
            return _statusIndicator(
              Icons.info,
              "ESTADO: ${myCandidate.status.toUpperCase()}",
              Colors.blueGrey,
            );
        }
      },
    );
  }

  Widget _baseApplyButton(
    BuildContext context,
    PropertyModel prop,
    String label,
    Color color,
    bool guest,
  ) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(vertical: 16),
        elevation: 0,
      ),
      onPressed: () => guest
          ? _showLoginRequiredDialog(context, "postularte")
          : _navigateToApply(context),
      child: Text(
        label,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _statusIndicator(IconData icon, String label, Color color) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSquareAction(
    BuildContext context,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200, width: 2),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Center(child: Icon(icon, color: color, size: 28)),
      ),
    );
  }

  void _showLoginRequiredDialog(BuildContext context, String action) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("¿Deseas $action?"),
        content: const Text("Inicia sesión para realizar esta acción."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cerrar"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<AuthBloc>().add(ShowLoginScreenRequested());
            },
            child: const Text("Login"),
          ),
        ],
      ),
    );
  }

  void _navigateToSchedule(BuildContext context, String uid, String name) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SelectSlotScreen(
          propertyId: widget.property.id ?? '',
          propertyAddress: widget.property.address,
          userId: uid,
          userName: name,
        ),
      ),
    );
  }

  void _navigateToApply(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TenantApplyScreen(
          propertyId: widget.property.id ?? '',
          propertyAddress: widget.property.address,
          currentPropertyCanon: widget.property.canon.toInt(),
        ),
      ),
    );
  }
}

// =========================================================================
// --- COMPONENTE SUB-CLASE CORREGIDO: DIÁLOGO CON CAPA OSCURA AL PAUSAR ---
// =========================================================================
class _MultimediaFullscreenDialog extends StatefulWidget {
  final PropertyModel property;
  final int initialPage;

  const _MultimediaFullscreenDialog({
    required this.property,
    required this.initialPage,
  });

  @override
  State<_MultimediaFullscreenDialog> createState() =>
      _MultimediaFullscreenDialogState();
}

class _MultimediaFullscreenDialogState
    extends State<_MultimediaFullscreenDialog> {
  VideoPlayerController? _fullscreenVideoController;
  bool _isVideoInitialized = false;

  @override
  void initState() {
    super.initState();
    if (widget.property.videoUrl != null &&
        widget.property.videoUrl!.isNotEmpty) {
      _fullscreenVideoController =
          VideoPlayerController.networkUrl(Uri.parse(widget.property.videoUrl!))
            ..initialize().then((_) {
              setState(() {
                _isVideoInitialized = true;
              });
              // Solo auto-reproduce si el usuario abrió el diálogo directamente en la página del video
              if (widget.initialPage == 0) {
                _fullscreenVideoController!.play();
              }
            });
    }
  }

  @override
  void dispose() {
    _fullscreenVideoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool hasVideo =
        widget.property.videoUrl != null &&
        widget.property.videoUrl!.isNotEmpty;
    final int totalItems =
        (hasVideo ? 1 : 0) + widget.property.imageUrls.length;

    return Dialog(
      backgroundColor: Colors.black,
      insetPadding: EdgeInsets.zero,
      child: Stack(
        children: [
          PageView.builder(
            itemCount: totalItems,
            controller: PageController(initialPage: widget.initialPage),
            onPageChanged: (index) {
              if (hasVideo &&
                  index != 0 &&
                  _fullscreenVideoController != null &&
                  _fullscreenVideoController!.value.isPlaying) {
                _fullscreenVideoController!.pause();
                setState(
                  () {},
                ); // Forzar redibujado para que se vea la capa de pausa inmediatamente al deslizar
              }
            },
            itemBuilder: (context, index) {
              if (hasVideo && index == 0) {
                return _isVideoInitialized
                    ? GestureDetector(
                        onTap: () {
                          setState(() {
                            _fullscreenVideoController!.value.isPlaying
                                ? _fullscreenVideoController!.pause()
                                : _fullscreenVideoController!.play();
                          });
                        },
                        child: Center(
                          child: AspectRatio(
                            aspectRatio:
                                _fullscreenVideoController!.value.aspectRatio,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // 1. El contenedor del Video
                                VideoPlayer(_fullscreenVideoController!),

                                // 2. Capa oscura transparente e icono de pausa/play (Solo visibles si está pausado)
                                if (!_fullscreenVideoController!
                                    .value
                                    .isPlaying) ...[
                                  Container(
                                    color: Colors.black.withOpacity(
                                      0.4,
                                    ), // Pantalla negra transparente
                                  ),
                                  const Icon(
                                    Icons
                                        .play_circle_outline, // Icono claro de que está listo para reproducir
                                    size: 80,
                                    color: Colors.white70,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      )
                    : const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      );
              }

              final imgIndex = hasVideo ? index - 1 : index;
              return InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Center(
                  child: Image.network(
                    widget.property.imageUrls[imgIndex],
                    fit: BoxFit.contain,
                  ),
                ),
              );
            },
          ),
          Positioned(
            top: 40,
            right: 20,
            child: CircleAvatar(
              backgroundColor: Colors.white24,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
