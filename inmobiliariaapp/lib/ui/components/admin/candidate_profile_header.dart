// ui/components/admin/components/candidate_profile_header.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:inmobiliariaapp/models/candidate_model.dart';
import 'package:inmobiliariaapp/ui/components/auth_ux/user_reviews_history_screen.dart';
import 'package:inmobiliariaapp/utils/themes.dart';

class CandidateProfileHeader extends StatelessWidget {
  final CandidateModel candidate;
  final String currentStatus;
  final String Function(String?) getDisplayStatus;
  final Color Function(String?) getStatusColor;

  const CandidateProfileHeader({
    super.key,
    required this.candidate,
    required this.currentStatus,
    required this.getDisplayStatus,
    required this.getStatusColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
      decoration: BoxDecoration(
        color: Colors.blue[900],
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Column(
        children: [
          const CircleAvatar(
            radius: 40,
            backgroundColor: Colors.white24,
            child: Icon(Icons.person, size: 50, color: Colors.white),
          ),
          const SizedBox(height: 12),
          Text(
            candidate.nombre,
            style: TextStyle(
              color: Colors.white,
              fontSize: ResponsiveUtils.getFontSize(context, 22),
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            candidate.email,
            style: TextStyle(
              color: Colors.blue[100],
              fontSize: ResponsiveUtils.getFontSize(context, 14),
            ),
          ),
          const SizedBox(height: 10),

          // --- COMPONENTE EN TIEMPO REAL: CALIFICACIÓN DEL CANDIDATO ---
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(candidate.uid)
                .collection('reviews')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: Colors.white,
                  ),
                );
              }

              final docs = snapshot.data?.docs ?? [];
              int reviewCount = docs.length;
              double rating = 0.0;

              if (reviewCount > 0) {
                double totalStars = 0.0;
                for (var doc in docs) {
                  final data = doc.data() as Map<String, dynamic>;
                  totalStars += (data['rating'] ?? 0).toDouble();
                }
                rating = totalStars / reviewCount;
              }

              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.star_rounded,
                    color: rating > 0 ? Colors.amber : Colors.white54,
                    size: 18,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    rating > 0
                        ? rating.toStringAsFixed(1)
                        : "Sin calificaciones",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: ResponsiveUtils.getFontSize(context, 13),
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 6),
                  TextButton(
                    onPressed: () {
                      // --- INTEGRADO: Navegación directa al historial de reseñas del candidato ---
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => UserReviewsHistoryScreen(
                            targetUserId:
                                candidate.uid, // El UID del inquilino/candidato
                            targetUserName: candidate
                                .nombre, // Su nombre para el título del AppBar
                          ),
                        ),
                      );
                    },
                    child: Text(
                      "($reviewCount ${reviewCount == 1 ? 'reseña' : 'reseñas'})",
                      style: TextStyle(
                        fontSize: ResponsiveUtils.getFontSize(context, 11),
                        color: Colors.blue[100],
                        decoration: TextDecoration
                            .underline, // Opcional: Le da un toque visual de enlace clickeable
                        decorationColor: Colors.blue[100],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: getStatusColor(currentStatus).withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: getStatusColor(currentStatus),
                width: 1.5,
              ),
            ),
            child: Text(
              getDisplayStatus(currentStatus).toUpperCase(),
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: ResponsiveUtils.getFontSize(context, 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
