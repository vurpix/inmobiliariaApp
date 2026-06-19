// ui/components/tenant_flow/tenant_favorites_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inmobiliariaapp/bloc/authBloc/auth_bloc.dart';
import 'package:inmobiliariaapp/bloc/authBloc/auth_state.dart';
import 'package:inmobiliariaapp/bloc/favoritesBloc/favorites_bloc.dart';
import 'package:inmobiliariaapp/bloc/favoritesBloc/favorites_event.dart';
import 'package:inmobiliariaapp/models/property_model.dart';
import 'package:inmobiliariaapp/models/application_model.dart';
import 'package:inmobiliariaapp/services/application_service.dart';
import 'package:inmobiliariaapp/services/user_service.dart';
import 'package:inmobiliariaapp/ui/components/property/property_detail_screen.dart';
import 'package:inmobiliariaapp/ui/components/tenant_flow/select_slot_screen.dart';
import 'package:inmobiliariaapp/ui/components/tenant_flow/tenant_apply_screen.dart';
import 'package:inmobiliariaapp/ui/components/tenant_flow/application_status_button.dart';
import 'package:inmobiliariaapp/utils/themes.dart';
import 'package:inmobiliariaapp/utils/format_extensions.dart'; // Tu extensión global de dinero y formatos nativos
import 'package:inmobiliariaapp/ui/components/global/custom_text.dart';

class TenantFavoritesScreen extends StatelessWidget {
  const TenantFavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ApplicationService applicationService = ApplicationService();
    final UserService userService = UserService();

    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, authState) {
        if (authState is AuthLoading || authState is AuthInitial) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (authState is! Authenticated) {
          return Scaffold(
            backgroundColor: context.surfaceColor.withOpacity(0.96),
            body: const Center(
              child: CustomText(
                "Inicia sesión para visualizar tus favoritos.",
                baseFontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          );
        }

        final String userId = authState.user.id;

        return Scaffold(
          backgroundColor: context.surfaceColor.withOpacity(0.96),
          appBar: AppBar(
            backgroundColor: context.primaryColor,
            iconTheme: const IconThemeData(color: Colors.white),
            elevation: 0,
            title: CustomText(
              "Mis Favoritos",
              baseFontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          body: StreamBuilder<QuerySnapshot>(
            stream: userService.watchUserFavorites(userId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return _buildEmptyState();
              }

              final favoriteProperties = snapshot.data!.docs
                  .map((doc) => PropertyModel.fromSnapshot(doc))
                  .toList();

              return ListView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                itemCount: favoriteProperties.length,
                itemBuilder: (context, index) {
                  final property = favoriteProperties[index];
                  return _buildFavoritePropertyCard(
                    context,
                    property,
                    userId,
                    applicationService,
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.favorite_border_rounded,
            size: 70,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          const CustomText(
            "No tienes propiedades guardadas en favoritos",
            baseFontSize: 14,
            color: Colors.grey,
            fontWeight: FontWeight.w600,
          ),
        ],
      ),
    );
  }

  Widget _buildFavoritePropertyCard(
    BuildContext context,
    PropertyModel property,
    String userId,
    ApplicationService applicationService,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1A365D).withOpacity(0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- BLOQUE SUPERIOR: MULTIMEDIA HERO ---
            Stack(
              children: [
                GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PropertyDetailScreen(property: property),
                    ),
                  ),
                  child: AspectRatio(
                    aspectRatio: 16 / 10,
                    child: Image.network(
                      property.imageUrls.isNotEmpty
                          ? property.imageUrls.first
                          : 'https://via.placeholder.com/400x240',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                // Botón Flotante para Eliminar de Favoritos (Corazón Relleno Rojo)
                Positioned(
                  top: 12,
                  right: 12,
                  child: CircleAvatar(
                    backgroundColor: Colors.white.withOpacity(0.92),
                    radius: 18,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: const Icon(
                        Icons.favorite_rounded,
                        color: Colors.redAccent,
                        size: 20,
                      ),
                      onPressed: () {
                        context.read<FavoritesBloc>().add(
                          ToggleFavorite(userId, property),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),

            // --- BLOQUE INTERMEDIO: IDENTIFICACIÓN E INFO ---
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Conversión monetaria nativa usando tu extensión corregida .toCOP()
                      CustomText.title(
                        (property.canon as num).toInt().toCOP(),
                        baseFontSize: 16,
                        color: context.primaryColor,
                        fontWeight: FontWeight.w800,
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: context.primaryColor.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: CustomText(
                          property.formattedDuration,
                          baseFontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: context.primaryColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  CustomText(
                    property.address,
                    baseFontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                  const SizedBox(height: 8),

                  // Fila de Características (Metraje y Administración si aplica)
                  Row(
                    children: [
                      Icon(
                        Icons.square_foot_rounded,
                        size: 15,
                        color: context.textSecondaryColor.withOpacity(0.6),
                      ),
                      const SizedBox(width: 4),
                      CustomText(
                        "${property.area} m²",
                        baseFontSize: 12,
                        color: context.textSecondaryColor.withOpacity(0.6),
                      ),
                      if (property.hasAdmin) ...[
                        const SizedBox(width: 16),
                        Icon(
                          Icons.gavel_rounded,
                          size: 15,
                          color: context
                              .textSecondaryColor, // 👈 Color plano seguro sin opacidad conflictiva
                        ),
                        const SizedBox(width: 4),
                        CustomText(
                          "Admin: ${(property.adminPrice as num).toInt().toCOP()}",
                          baseFontSize: 12,
                          color: context.textSecondaryColor.withOpacity(0.6),
                        ),
                      ] else ...[
                        // 👈 AGREGAMOS EL ELSE AQUÍ
                        const SizedBox(width: 16),
                        Icon(
                          Icons
                              .gavel_rounded, // Puedes usar Icons.gavel_rounded o Icons.info_outline
                          size: 15,
                          color: Colors
                              .grey[400], // Color gris tenue para indicar que no aplica
                        ),
                        const SizedBox(width: 4),
                        CustomText(
                          "Sin administración",
                          baseFontSize: 12,
                          color: context.textSecondaryColor.withOpacity(
                            0.6,
                          ), // Texto limpio y estático
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 10),
                  CustomText(
                    property.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    baseFontSize: 13,
                    color: context.textSecondaryColor.withOpacity(0.6),
                  ),
                ],
              ),
            ),

            // --- BLOQUE INFERIOR: BOTONES MODULARES DE FLUJO ---
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  // Botón Izquierdo Compacto: Agenda de Visitas
                  Expanded(
                    child: SizedBox(
                      width: 56,
                      height: 48,
                      child: StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('available_slots')
                            .where('propertyId', isEqualTo: property.id)
                            .where('attendeesUids', arrayContains: userId)
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.hasData &&
                              snapshot.data!.docs.isNotEmpty) {
                            return ApplicationStatusButton(
                              propertyId: property.id ?? '',
                              propertyAddress: property.address,
                              userId: userId,
                              onApply: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => TenantApplyScreen(
                                      propertyId: property.id ?? '',
                                      propertyAddress: property.address,
                                      currentPropertyCanon: property.canon
                                          .toInt(),
                                    ),
                                  ),
                                );
                              },
                            );
                          }
                          return OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              padding: EdgeInsets.zero,
                              side: BorderSide(
                                color: context.textColor.withOpacity(0.08),
                                width: 1.5,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => SelectSlotScreen(
                                    propertyId: property.id ?? '',
                                    propertyAddress: property.address,
                                    userId: userId,
                                    userName: 'Usuario',
                                  ),
                                ),
                              );
                            },
                            child: Icon(
                              Icons.calendar_month_rounded,
                              color: context.primaryColor,
                              size: 22,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Botón Derecho Extendido: Estudio de Seguridad (Postularse)
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: StreamBuilder<ApplicationModel?>(
                        stream: applicationService.watchApplicationByProperty(
                          property.id!,
                        ),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return _baseApplyButton(
                              context,
                              property,
                              "POSTULARME",
                              context.primaryColor,
                            );
                          }
                          final myCandidate = applicationService
                              .getUserCandidate(snapshot.data!, userId);
                          if (myCandidate == null) {
                            return _baseApplyButton(
                              context,
                              property,
                              "POSTULARME",
                              context.primaryColor,
                            );
                          }

                          // Mapeo adaptativo de estados del Scoring Legal
                          switch (myCandidate.status) {
                            case 'pending_review':
                              return _statusIndicator(
                                Icons.search_rounded,
                                "EN REVISIÓN",
                                Colors.orange,
                              );
                            case 'approved':
                              return _statusIndicator(
                                Icons.check_circle_rounded,
                                "APROBADO",
                                Colors.green,
                              );
                            case 'rejected':
                              return _baseApplyButton(
                                context,
                                property,
                                "REINTENTAR ESTUDIO",
                                Colors.redAccent,
                              );
                            default:
                              return _statusIndicator(
                                Icons.info_outline_rounded,
                                "ESTADO: ${myCandidate.status.toUpperCase()}",
                                Colors.blueGrey,
                              );
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _baseApplyButton(
    BuildContext context,
    PropertyModel property,
    String label,
    Color color,
  ) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TenantApplyScreen(
              propertyId: property.id ?? '',
              propertyAddress: property.address,
              currentPropertyCanon: property.canon.toInt(),
            ),
          ),
        );
      },
      child: Text(
        label,
        style: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  Widget _statusIndicator(IconData icon, String label, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.25), width: 1.2),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Inter',
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 11,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
