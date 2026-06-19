// ui/components/admin/admin_user_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:inmobiliariaapp/models/user.dart';
import 'package:inmobiliariaapp/ui/components/auth_ux/user_reviews_history_screen.dart';
import 'package:inmobiliariaapp/ui/components/global/custom_text_button.dart';
import 'package:inmobiliariaapp/utils/themes.dart';
import 'package:inmobiliariaapp/utils/format_extensions.dart'; // Tus extensiones de fechas globales
import 'package:inmobiliariaapp/ui/components/global/custom_text.dart';

class AdminUserDetailScreen extends StatelessWidget {
  final UserModel user;

  const AdminUserDetailScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final String rawRole = user.role.toString().split('.').last.toLowerCase();

    return Scaffold(
      backgroundColor: context.surfaceColor.withOpacity(0.96),
      appBar: AppBar(
        title: CustomText(
          "Expediente del Usuario",
          baseFontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        backgroundColor: context.primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // --- 1. TARJETA CABECERA DE PERFIL (FOTO, NOMBRE, ROL Y CALIFICACIÓN) ---
            _buildProfileHeaderCard(context, rawRole),
            const SizedBox(height: 20),
            _buildRoleBadge(context, rawRole),
            const SizedBox(height: 20),

            // --- 2. SECCIÓN ADAPTADA: INFORMACIÓN CIVIL Y LEGAL ---
            _buildSectionCard(
              title: "Identidad Legal y Perfil",
              context: context,
              child: Column(
                children: [
                  _buildDetailRow(
                    "Tipo de Documento",
                    user.documentType.toUpperCase(),
                    context: context,
                  ),
                  _buildDetailRow(
                    "Número de Documento",
                    user.documentNumber,
                    context: context,
                  ),
                  _buildDetailRow(
                    "Ocupación / Actividad",
                    user.occupation,
                    context: context,
                  ),
                  _buildDetailRow(
                    "Teléfono de Contacto",
                    user.phoneNumber ?? "No asignado",
                    context: context,
                  ),
                  _buildDetailRow(
                    "Correo Electrónico",
                    user.email,
                    context: context,
                  ),
                ],
              ),
            ),

            // --- 3. SECCIÓN: CONTROL OPERATIVO Y SEGURIDAD ---
            _buildSectionCard(
              title: "Telemetria Y Sistema",
              context: context,
              child: Column(
                children: [
                  _buildDetailRow(
                    "ID de Usuario",
                    user.id,
                    isCompact: true,
                    context: context,
                  ),
                  // Usando tus extensiones de fecha .toFullDateTime()
                  _buildDetailRow(
                    "Fecha de Registro",
                    user.createdAt?.toFullDateTime() ?? "Sin registro",
                    context: context,
                  ),
                  _buildDetailRow(
                    "Última Conexión",
                    user.lastLogin?.toFullDateTime() ?? "Sin registro",
                    context: context,
                  ),
                  _buildDetailRow(
                    "Token Push FCM",
                    user.fcmToken != null ? "Dispositivo enlazado" : "Inactivo",
                    valueColor: user.fcmToken != null
                        ? Colors.green
                        : Colors.grey,
                    context: context,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // --- COMPONENTES VISUALES INTERNOS (ESTILO PREMIUM ) ---
  // =========================================================================

  Widget _buildProfileHeaderCard(BuildContext context, String rawRole) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: context.primaryColor.withOpacity(0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 34,
            backgroundColor: context.primaryColor.withOpacity(0.06),
            backgroundImage: user.photoUrl != null && user.photoUrl!.isNotEmpty
                ? NetworkImage(user.photoUrl!)
                : null,
            child: user.photoUrl == null || user.photoUrl!.isEmpty
                ? Icon(
                    Icons.person_outline_rounded,
                    color: context.primaryColor,
                    size: 30,
                  )
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                CustomText(
                  user.name,
                  baseFontSize: ResponsiveUtils.getFontSize(context, 18),
                  fontWeight: FontWeight.w800,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      Icons.star_rounded,
                      color: user.rating > 0
                          ? const Color(0xFFEDC111)
                          : Colors.grey[300],
                      size: 18,
                    ),
                    const SizedBox(width: 4),
                    CustomText(
                      "${user.rating.toStringAsFixed(1)} ",
                      baseFontSize: ResponsiveUtils.getFontSize(context, 12),
                      fontWeight: FontWeight.bold,
                    ),
                    CustomTextButton(
                      " reseñas (${user.reviewCount})",
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => UserReviewsHistoryScreen(
                              targetUserId: user.id,
                              targetUserName: user.name,
                            ),
                          ),
                        );
                      },
                      baseFontSize: ResponsiveUtils.getFontSize(context, 12),
                      color: context.textSecondaryColor.withOpacity(0.6),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleBadge(BuildContext context, String role) {
    Color badgeColor = context.primaryColor;
    String label = "INQUILINO";

    if (role.contains('admin')) {
      badgeColor = context.primaryColor;
      label = "ADMIN";
    } else if (role.contains('owner') || role.contains('landlord')) {
      badgeColor = context.secondaryColor;
      label = "PROPIETARIO";
    } else {
      badgeColor = context.successColor;
      label = "INQUILINO";
    }

    return Container(
      width: ResponsiveUtils.getWidth(context, 30),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: badgeColor.withOpacity(0.2)),
      ),
      child: CustomText(
        label,
        baseFontSize: ResponsiveUtils.getFontSize(context, 12),
        color: badgeColor,
        fontWeight: FontWeight.w700,
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required BuildContext context,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.textColor.withOpacity(0.03)),
        boxShadow: [
          BoxShadow(
            color: context.primaryColor.withOpacity(0.015),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CustomText(
            title,
            baseFontSize: ResponsiveUtils.getFontSize(context, 14),
            fontWeight: FontWeight.w800,
            color: context.primaryColor,
          ),
          const Padding(
            padding: EdgeInsets.only(top: 6, bottom: 10),
            child: Divider(height: 1, thickness: 0.6),
          ),
          child,
        ],
      ),
    );
  }

  Widget _buildDetailRow(
    String label,
    String value, {
    Color? valueColor,
    required BuildContext context,
    bool isCompact = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          CustomText(
            label,
            baseFontSize: ResponsiveUtils.getFontSize(context, 12),
            color: context.textSecondaryColor,
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: CustomText(
                value,
                baseFontSize: isCompact
                    ? ResponsiveUtils.getFontSize(context, 12)
                    : ResponsiveUtils.getFontSize(context, 12),
                fontWeight: FontWeight.w700,
                color: valueColor,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
