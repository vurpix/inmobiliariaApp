// ui/components/auth_ux/user_reviews_history_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:inmobiliariaapp/ui/components/auth_ux/review_tile.dart';
import 'package:inmobiliariaapp/ui/components/global/custom_text.dart'; // Componente de texto global
import 'package:inmobiliariaapp/utils/themes.dart'; // Tus extensiones de temas corporativos

class UserReviewsHistoryScreen extends StatefulWidget {
  final String
  targetUserId; // El ID del usuario del cual queremos ver el historial
  final String targetUserName; // Nombre para colocar de título en la AppBar

  const UserReviewsHistoryScreen({
    super.key,
    required this.targetUserId,
    required this.targetUserName,
  });

  @override
  State<UserReviewsHistoryScreen> createState() =>
      _UserReviewsHistoryScreenState();
}

class _UserReviewsHistoryScreenState extends State<UserReviewsHistoryScreen> {
  final ScrollController _scrollController = ScrollController();
  final List<DocumentSnapshot> _reviews = [];

  bool _isLoading = false;
  bool _hasMore = true;
  DocumentSnapshot? _lastDocument;

  // Configuración de paginación
  final int _documentLimit = 10;

  @override
  void initState() {
    super.initState();
    _getReviewsHistory();

    // Oyente del scroll para detectar cuándo pedir más datos de forma inteligente
    _scrollController.addListener(() {
      double maxScroll = _scrollController.position.maxScrollExtent;
      double currentScroll = _scrollController.position.pixels;
      double delta =
          MediaQuery.of(context).size.height *
          0.2; // Alerta de recarga al faltar 20%

      if (maxScroll - currentScroll <= delta) {
        _getReviewsHistory();
      }
    });
  }

  Future<void> _getReviewsHistory() async {
    if (_isLoading || !_hasMore) return;

    setState(() => _isLoading = true);

    try {
      Query query = FirebaseFirestore.instance
          .collection('users')
          .doc(widget.targetUserId)
          .collection('reviews')
          .orderBy(
            'createdAt',
            descending: true,
          ) // Ordenado por fecha: más reciente primero
          .limit(_documentLimit);

      // Si ya hay documentos previos cargados, empezamos la consulta justo después del último
      if (_lastDocument != null) {
        query = query.startAfterDocument(_lastDocument!);
      }

      final querySnapshot = await query.get();

      if (querySnapshot.docs.length < _documentLimit) {
        _hasMore = false; // Ya no hay más registros en la base de datos
      }

      if (querySnapshot.docs.isNotEmpty) {
        _lastDocument = querySnapshot.docs.last;
        setState(() {
          _reviews.addAll(querySnapshot.docs);
        });
      }
    } catch (e) {
      debugPrint("Error cargando historial de reseñas: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _refreshList() async {
    // Método para pull-to-refresh
    setState(() {
      _reviews.clear();
      _lastDocument = null;
      _hasMore = true;
    });
    await _getReviewsHistory();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Extraer el primer nombre de forma segura
    final String shortName = widget.targetUserName.trim().isNotEmpty
        ? widget.targetUserName.trim().split(' ').first
        : "Usuario";

    return Scaffold(
      backgroundColor: context.surfaceColor.withOpacity(0.96),
      appBar: AppBar(
        title: CustomText(
          "Reseñas de $shortName",
          baseFontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        backgroundColor: context.primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _refreshList,
        color: context.primaryColor,
        backgroundColor: context.surfaceColor,
        child: _reviews.isEmpty && !_isLoading
            ? _buildEmptyState()
            : ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                itemCount: _reviews.length + (_hasMore ? 1 : 0),
                itemBuilder: (context, index) {
                  // Muestra indicador de carga inferior en la paginación
                  if (index == _reviews.length) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: context.primaryColor,
                            strokeWidth: 2.5,
                          ),
                        ),
                      ),
                    );
                  }

                  final data = _reviews[index].data() as Map<String, dynamic>;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: ReviewTile(reviewData: data),
                  );
                },
              ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      physics:
          const AlwaysScrollableScrollPhysics(), // Obliga al scroll a responder al RefreshIndicator
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.25),
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: context.textColor.withOpacity(0.02),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.rate_review_outlined,
                  size: 60,
                  color: context.textSecondaryColor.withOpacity(0.3),
                ),
              ),
              const SizedBox(height: 16),
              const CustomText(
                "Sin calificaciones por el momento",
                baseFontSize: 15,
                fontWeight: FontWeight.bold,
              ),
              const SizedBox(height: 4),
              CustomText(
                "Este usuario no registra historial de reseñas.",
                baseFontSize: 13,
                color: context.textSecondaryColor.withOpacity(0.5),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
