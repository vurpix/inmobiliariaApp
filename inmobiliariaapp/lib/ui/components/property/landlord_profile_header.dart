// components/property/landlord_profile_header.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:inmobiliariaapp/models/user.dart';
import 'package:inmobiliariaapp/ui/components/auth_ux/user_reviews_history_screen.dart';
import 'package:inmobiliariaapp/ui/components/global/custom_text_button.dart';
import 'package:inmobiliariaapp/utils/themes.dart';
import 'package:inmobiliariaapp/ui/components/global/custom_text.dart'; // Tu componente global de texto

class LandlordProfileHeader extends StatelessWidget {
  final UserModel user;

  const LandlordProfileHeader({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      padding: const EdgeInsets.all(20), // Padding interno más amplio y aireado
      decoration: BoxDecoration(
        color: context
            .surfaceColor, // Fondo sutil con el color secundario de la marca
        borderRadius: BorderRadius.circular(24), // Bordes más curvos y modernos
        boxShadow: [
          BoxShadow(
            color: context.primaryColor.withOpacity(
              0.1,
            ), // Sombra sutil de la marca
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          // --- AVATAR MÁS GRANDE CON ANILLO DE DISEÑO COMPACTO ---
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: context.primaryColor.withOpacity(0.1),
                width: 3,
              ),
            ),
            child: CircleAvatar(
              radius: 38, // Dimensión aumentada para mayor impacto visual
              backgroundColor: context.primaryColor.withOpacity(0.08),
              backgroundImage: user.photoUrl != null
                  ? NetworkImage(user.photoUrl!)
                  : null,
              child: user.photoUrl == null
                  ? Icon(
                      Icons.person_outline_rounded,
                      color: context.primaryColor,
                      size: 38,
                    )
                  : null,
            ),
          ),
          const SizedBox(
            width: 20,
          ), // Mayor separación para que respire el texto
          // --- DETALLES DE IDENTIDAD Y CALIFICACIONES ---
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CustomText.title(
                  user.name,
                  baseFontSize:
                      20, // Nombre sustancialmente más grande y legible
                  color: context.primaryColor,
                  fontWeight: FontWeight.w800,
                ),
                const SizedBox(height: 6),

                // --- ESCUCHA EN TIEMPO REAL: REVIEWS SUB-COLLECTION ---
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .doc(user.id)
                      .collection('reviews')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            context.primaryColor.withOpacity(0.4),
                          ),
                        ),
                      );
                    }

                    final docs = snapshot.data?.docs ?? [];
                    final int reviewCount = docs.length;
                    double rating = 0.0;

                    if (reviewCount > 0) {
                      double totalStars = 0.0;
                      for (var doc in docs) {
                        final data = doc.data() as Map<String, dynamic>;
                        totalStars += (data['rating'] ?? 0).toDouble();
                      }
                      rating = totalStars / reviewCount;
                    }

                    final bool hasRatings = rating > 0;

                    return Row(
                      children: [
                        Icon(
                          Icons.star_rounded,
                          color: hasRatings
                              ? const Color(0xFFEDC111)
                              : Colors.grey[400],
                          size: 22, // Icono de estrella ligeramente más grande
                        ),
                        const SizedBox(width: 4),
                        CustomText(
                          hasRatings
                              ? rating.toStringAsFixed(1)
                              : "Sin calificaciones",
                          baseFontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: hasRatings
                              ? context.primaryColor
                              : context.textSecondaryColor.withOpacity(0.6),
                        ),
                        if (hasRatings) ...[
                          CustomTextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      UserReviewsHistoryScreen(
                                        targetUserId: user.id,
                                        targetUserName: user.name,
                                      ),
                                ),
                              );
                            },
                            "($reviewCount ${reviewCount == 1 ? 'reseña' : 'reseñas'})",
                            baseFontSize: 12,
                            color: context.textSecondaryColor.withOpacity(0.7),
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
