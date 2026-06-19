// ui/components/auth_ux/user_review_dialog.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:inmobiliariaapp/models/review_model.dart';
import 'package:inmobiliariaapp/ui/components/global/custom_text.dart'; // Componente de marca unificado
import 'package:inmobiliariaapp/utils/themes.dart';

class UserReviewDialog {
  /// MODIFICADO: Añadido targetUserName para inyectar dinámicamente el nombre de la persona a calificar
  static Future<void> show({
    required BuildContext context,
    required String targetUserId, // UID de la persona a la que vas a calificar
    required String
    targetUserName, // CORREGIDO: Nombre de la persona a calificar
    required String fromUserId, // Tu propio UID
    required String fromName, // Tu propio nombre
    required String fromRole, // Tu propio rol de usuario
    required String contractId, // ID del contrato cerrado
    required List<String> defaultTags, // Respuestas automáticas sugeridas
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return _ReviewBottomSheetContent(
          targetUserId: targetUserId,
          targetUserName: targetUserName,
          fromUserId: fromUserId,
          fromName: fromName,
          fromRole: fromRole,
          contractId: contractId,
          defaultTags: defaultTags,
        );
      },
    );
  }
}

class _ReviewBottomSheetContent extends StatefulWidget {
  final String targetUserId;
  final String targetUserName;
  final String fromUserId;
  final String fromName;
  final String fromRole;
  final String contractId;
  final List<String> defaultTags;

  const _ReviewBottomSheetContent({
    required this.targetUserId,
    required this.targetUserName,
    required this.fromUserId,
    required this.fromName,
    required this.fromRole,
    required this.contractId,
    required this.defaultTags,
  });

  @override
  State<_ReviewBottomSheetContent> createState() =>
      _ReviewBottomSheetContentState();
}

class _ReviewBottomSheetContentState extends State<_ReviewBottomSheetContent> {
  int _selectedStars = 0;
  final List<String> _selectedTags = [];
  final TextEditingController _commentController = TextEditingController();
  bool _isSaving = false;

  void _toggleTag(String tag) {
    setState(() {
      if (_selectedTags.contains(tag)) {
        _selectedTags.remove(tag);
      } else {
        _selectedTags.add(tag);
      }
    });
  }

  Future<void> _submitReview() async {
    if (_selectedStars == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const CustomText(
            "Por favor, selecciona al menos una estrella para calificar",
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
          backgroundColor: Colors.amber[800],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final review = ReviewModel(
        fromUserId: widget.fromUserId,
        fromName: widget.fromName,
        fromRole: widget.fromRole,
        contractId: widget.contractId,
        rating: _selectedStars,
        comment: _commentController.text.trim(),
        predefinedAnswers: _selectedTags,
      );

      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.targetUserId)
          .collection('reviews')
          .add(review.toMap());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const CustomText(
              "¡Calificación guardada y enviada con éxito!",
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
            backgroundColor: Colors.green[700],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: CustomText(
              "Error al guardar la reseña: $e",
              color: Colors.white,
            ),
            backgroundColor: context.errorColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final keyboardPadding = MediaQuery.of(context).viewInsets.bottom;

    // Extraer el primer nombre de forma segura
    final String cleanTargetName = widget.targetUserName.trim().isNotEmpty
        ? widget.targetUserName.trim().split(' ').first
        : "Usuario";

    return Padding(
      padding: EdgeInsets.only(
        top: 16,
        left: 24,
        right: 24,
        bottom: keyboardPadding + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4.5,
                decoration: BoxDecoration(
                  color: context.textColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // --- CORREGIDO: Ahora muestra de forma impecable el nombre del calificado ---
            CustomText.title(
              'Calificar a $cleanTargetName',
                 baseFontSize: ResponsiveUtils.getFontSize(context, 20),
              fontWeight: FontWeight.w900,
              color: context.primaryColor,
            ),
            const SizedBox(height: 6),
            CustomText(
              "Cuéntanos tu experiencia de arriendo. Tu opinión ayuda a mantener la transparencia y seguridad en Luxe Estate.",
              baseFontSize: ResponsiveUtils.getFontSize(context, 14),
              color: context.textSecondaryColor,
            ),
            const SizedBox(height: 24),

            // --- SELECTOR DE ESTRELLAS PREMIUM ---
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(5, (index) {
                  final int starValue = index + 1;
                  final bool isSelected = starValue <= _selectedStars;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedStars = starValue),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(
                        isSelected
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        size: 44,
                        color: isSelected
                            ? const Color(0xFFEDC111)
                            : context.textColor.withOpacity(0.15),
                      ),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 24),

            // --- LISTADO DE CHOICES CHIPS (TAGS) ---
            if (widget.defaultTags.isNotEmpty) ...[
              CustomText(
                "Características destacadas:",
                baseFontSize: 13,
                fontWeight: FontWeight.w800,
                color: context.textColor.withOpacity(0.8),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: widget.defaultTags.map((tag) {
                  final bool isSelected = _selectedTags.contains(tag);
                  return FilterChip(
                    label: Text(tag),
                    selected: isSelected,
                    selectedColor: context.primaryColor,
                    checkmarkColor: Colors.white,
                    labelStyle: TextStyle(
                      fontFamily: 'Inter',
                      color: isSelected ? Colors.white : context.textColor,
                      fontSize: 12,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                    backgroundColor: context.textColor.withOpacity(0.02),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 2,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(
                        color: isSelected
                            ? Colors.transparent
                            : context.textColor.withOpacity(0.06),
                      ),
                    ),
                    onSelected: (_) => _toggleTag(tag),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
            ],

            // --- INPUT COMPORTAMIENTO DE TEXTO ---
            TextField(
              controller: _commentController,
              maxLines: 3,
              maxLength: 250,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                color: context.textColor,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                hintText: "Escribe comentarios u observaciones adicionales...",
                hintStyle: TextStyle(
                  color: context.textSecondaryColor.withOpacity(0.35),
                  fontSize: 13,
                ),
                labelText: "Mensaje u observaciones (Opcional)",
                labelStyle: TextStyle(
                  color: context.primaryColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
                filled: true,
                fillColor: context.textColor.withOpacity(0.005),
                contentPadding: const EdgeInsets.all(14),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: context.textColor.withOpacity(0.06),
                    width: 1.5,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: context.primaryColor, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // --- BOTÓN ENVIAR ACCIÓN ---
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _submitReview,
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.primaryColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        "ENVIAR CALIFICACIÓN",
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          letterSpacing: 0.2,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
