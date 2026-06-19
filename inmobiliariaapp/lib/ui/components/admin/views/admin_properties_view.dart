// ui/components/admin/views/admin_properties_view.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:inmobiliariaapp/ui/components/global/custom_text_button.dart';
import 'package:inmobiliariaapp/utils/format_extensions.dart';
import 'package:inmobiliariaapp/ui/components/admin/admin_property_detail_screen.dart';
import 'package:inmobiliariaapp/ui/components/admin/admin_property_schedule_screen.dart';
import 'package:inmobiliariaapp/utils/status_formatter.dart';
import 'package:inmobiliariaapp/utils/themes.dart';
import 'package:inmobiliariaapp/ui/components/auth_ux/user_reviews_history_screen.dart';
import 'package:inmobiliariaapp/ui/components/global/custom_text.dart'; // Componente global de texto

class AdminPropertiesView extends StatelessWidget {
  const AdminPropertiesView({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('properties')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return const Center(
            child: CustomText(
              "No hay propiedades registradas",
              baseFontSize: 14,
            ),
          );
        }

        Map<String, Map<String, List<QueryDocumentSnapshot>>> groupedData = {};

        for (var doc in docs) {
          final data = doc.data() as Map<String, dynamic>;
          final DateTime date =
              (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();

          // Reutilizamos tu extensión global optimizada de fecha
          String monthKey = date.toMonthYear();
          String weekKey = date.toWeekFormat().toUpperCase();

          groupedData.putIfAbsent(monthKey, () => {});
          groupedData[monthKey]!.putIfAbsent(weekKey, () => []);
          groupedData[monthKey]![weekKey]!.add(doc);
        }

        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: groupedData.entries.map((monthEntry) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- CABECERA DE MES PREMIUM ---
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 20, 4, 12),
                  child: CustomText.title(
                    monthEntry.key,
                    baseFontSize: 18,
                    color: context.primaryColor,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                ...monthEntry.value.entries.map((weekEntry) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // --- BADGE DE SEMANA MODERNO ---
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        margin: const EdgeInsets.only(bottom: 16, left: 4),
                        decoration: BoxDecoration(
                          color: context.primaryColor.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: CustomText(
                          weekEntry.key,
                          baseFontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: context.primaryColor,
                        ),
                      ),
                      ...weekEntry.value
                          .map((doc) => _buildPropertyCard(context, doc))
                          .toList(),
                      const SizedBox(height: 8),
                    ],
                  );
                }).toList(),
                const Divider(height: 30, thickness: 1),
              ],
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildPropertyCard(BuildContext context, QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final String propertyId = doc.id;
    final String status = data['status'] ?? 'pendingReview';
    final String address = data['address'] ?? 'Sin dirección';
    final String city = data['city'] ?? '';
    final String state = data['state'] ?? '';
    final String ownerId = data['ownerId'] ?? '';
    final num canon = data['canon'] ?? 0;
    final String area = data['area']?.toString() ?? '0';
    final String? imageUrl = (data['imageUrls'] as List?)?.isNotEmpty == true
        ? (data['imageUrls'] as List).first
        : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1A365D).withOpacity(0.05),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    AdminPropertyDetailScreen(propertyId: propertyId),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- 1. SECCIÓN SUPERIOR: HERO IMAGE CON RELACIÓN DE ASPECTO 16:9 ---
                Stack(
                  children: [
                    AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          image: imageUrl != null
                              ? DecorationImage(
                                  image: NetworkImage(imageUrl),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: imageUrl == null
                            ? Icon(
                                Icons.home_work_outlined,
                                size: 48,
                                color: Colors.grey[400],
                              )
                            : null,
                      ),
                    ),
                    // Badge del estado de la propiedad estilizado
                    Positioned(
                      top: 14,
                      left: 14,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: StatusFormatter.getPropertyStatusColor(status, context),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          StatusFormatter.formatPropertyStatus(
                            status,
                          ).toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                // --- 2. SECCIÓN INTERMEDIA: DATOS DE LA PROPIEDAD ---
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Fila de Dirección y Canon de Arriendo
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CustomText.title(
                                  address,
                                  baseFontSize: 16,
                                  color: context.primaryColor,
                                  fontWeight: FontWeight.w800,
                                ),
                                const SizedBox(height: 2),
                                CustomText(
                                  city.isNotEmpty && state.isNotEmpty
                                      ? "$city, $state"
                                      : "Ubicación no asignada",
                                  baseFontSize: 12,
                                  color: context.textSecondaryColor.withOpacity(
                                    0.7,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          CustomText.title(
                            canon.toCOP(),
                            baseFontSize: 16,
                            color: context.primaryColor,
                            fontWeight: FontWeight.w800,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Métrica de analíticas sutiles (Vistas e Inquiries simulados) + Área real
                      Row(
                        children: [
                          Icon(
                            Icons.remove_red_eye_outlined,
                            size: 14,
                            color: context.textSecondaryColor.withOpacity(0.5),
                          ),
                          const SizedBox(width: 4),
                          CustomText(
                            "1.2K vistas",
                            baseFontSize: 12,
                            color: context.textSecondaryColor.withOpacity(0.8),
                          ),
                          const SizedBox(width: 16),
                          Icon(
                            Icons.chat_bubble_outline_rounded,
                            size: 13,
                            color: context.secondaryColor,
                          ),
                          const SizedBox(width: 4),
                          CustomText(
                            "14 INTERESADOS",
                            baseFontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: context.secondaryColor,
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: context.textSecondaryColor.withOpacity(
                                0.06,
                              ),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: CustomText(
                              "$area m²",
                              baseFontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: context.textSecondaryColor,
                            ),
                          ),
                        ],
                      ),

                      // --- 3. SECCIÓN REPUTACIÓN DEL PROPIETARIO (INTEGRADA DENTRO DEL CONTENIDO) ---
                      if (ownerId.isNotEmpty) ...[
                        const Divider(height: 24, thickness: 0.8),
                        StreamBuilder<DocumentSnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('users')
                              .doc(ownerId)
                              .snapshots(),
                          builder: (context, userSnapshot) {
                            if (!userSnapshot.hasData)
                              return const SizedBox.shrink();

                            final userData =
                                userSnapshot.data!.data()
                                    as Map<String, dynamic>? ??
                                {};
                            final String ownerName =
                                userData['name'] ?? 'Propietario';

                            return StreamBuilder<QuerySnapshot>(
                              stream: FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(ownerId)
                                  .collection('reviews')
                                  .snapshots(),
                              builder: (context, reviewSnapshot) {
                                final reviewDocs =
                                    reviewSnapshot.data?.docs ?? [];
                                final int reviewCount = reviewDocs.length;
                                double rating = 0.0;

                                if (reviewCount > 0) {
                                  double totalStars = 0.0;
                                  for (var rDoc in reviewDocs) {
                                    final rData =
                                        rDoc.data() as Map<String, dynamic>;
                                    totalStars += (rData['rating'] ?? 0)
                                        .toDouble();
                                  }
                                  rating = totalStars / reviewCount;
                                }

                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    CustomText(
                                      "Arrendador: $ownerName",
                                      baseFontSize: ResponsiveUtils.getFontSize(
                                        context,
                                        12,
                                      ),
                                      color: context.textSecondaryColor,
                                          fontWeight: FontWeight.w600,
                                    ),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.star_rounded,
                                                color: rating > 0
                                                    ? const Color(0xFFEDC111)
                                                    : Colors.grey[400],
                                                size: 20,
                                              ),
                                              const SizedBox(width: 4),
                                              CustomText(
                                                rating > 0
                                                    ? rating.toStringAsFixed(1)
                                                    : "0.0",
                                                baseFontSize: ResponsiveUtils.getFontSize(
                                                  context,
                                                  12,
                                                ),
                                                fontWeight: FontWeight.bold,
                                                color: context.textColor,
                                              ),
                                              const SizedBox(width: 6),
                                              CustomTextButton(
                                                onPressed: () {
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (_) =>
                                                          UserReviewsHistoryScreen(
                                                            targetUserId:
                                                                ownerId,
                                                            targetUserName:
                                                                ownerName,
                                                          ),
                                                    ),
                                                  );
                                                },
                                                "($reviewCount ${reviewCount == 1 ? 'reseña' : 'reseñas'})",
                                                baseFontSize: ResponsiveUtils.getFontSize(
                                                  context,
                                                  12,
                                                ),
                                                color: context
                                                    .textSecondaryColor
                                                    .withOpacity(0.7),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                        ),
                      ],

                      // --- 4. ALERTA MODULAR DE CALENDARIO INCOMPLETO ---
                      _buildCalendarAlert(context, propertyId),
                    ],
                  ),
                ),

                // --- 5. LÍNEA DE ACCIÓN INFERIOR PARALELA ---
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Row(
                    children: [
                      // Botón: Ver detalles de Auditoría
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.analytics_outlined, size: 16),
                          label: const Text("Revisar Detalles"),
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AdminPropertyDetailScreen(
                                propertyId: propertyId,
                              ),
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            side: BorderSide(
                              color: context.textColor.withOpacity(0.08),
                              width: 1.5,
                            ),
                            foregroundColor: context.primaryColor,
                            textStyle: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Botón: Gestionar Agenda de Visitas
                      IconButton(
                        icon: const Icon(Icons.calendar_month_rounded),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AdminPropertyScheduleScreen(
                              propertyId: propertyId,
                              address: address,
                            ),
                          ),
                        ),
                        style: IconButton.styleFrom(
                          backgroundColor: context.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.all(12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCalendarAlert(BuildContext context, String propertyId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('available_slots')
          .where('propertyId', isEqualTo: propertyId)
          .snapshots(),
      builder: (context, slotSnapshot) {
        if (slotSnapshot.hasData && slotSnapshot.data!.docs.isEmpty) {
          return Container(
            margin: const EdgeInsets.only(top: 14),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.amber.withOpacity(0.3),
                width: 1.2,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  size: 18,
                  color: Colors.amber[800],
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: CustomText(
                    "Alerta: Falta asignar horarios al calendario de visitas.",
                    baseFontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.amber[900]!,
                  ),
                ),
              ],
            ),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }
}
