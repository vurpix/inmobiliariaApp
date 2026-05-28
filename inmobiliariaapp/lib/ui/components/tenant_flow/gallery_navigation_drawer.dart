// components/gallery_navigation_drawer.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inmobiliariaapp/bloc/authBloc/auth_bloc.dart';
import 'package:inmobiliariaapp/bloc/authBloc/auth_event.dart';
import 'package:inmobiliariaapp/bloc/authBloc/auth_state.dart'; // Importación necesaria para leer el estado del usuario
import 'package:inmobiliariaapp/bloc/notificationBloc/notification_bloc.dart';
import 'package:inmobiliariaapp/bloc/notificationBloc/notification_event.dart';
import 'package:inmobiliariaapp/ui/components/tenant_flow/tenant_favorites_screen.dart';
import 'package:inmobiliariaapp/ui/components/tenant_flow/tenant_profile_screen.dart';
// IMPORTA AQUÍ TU PANTALLA DE EDICIÓN DE PERFIL (La crearemos abajo)
// import 'package:inmobiliariaapp/ui/pages/profile/tenant_profile_screen.dart';
import 'package:inmobiliariaapp/utils/themes.dart';
import 'package:inmobiliariaapp/ui/components/global/custom_text.dart';

class GalleryNavigationDrawer extends StatelessWidget {
  final bool hasAssignedResidence;
  final bool isAuthenticated;
  final bool showPossessionView;
  final ValueChanged<bool> onPossessionViewChanged;

  const GalleryNavigationDrawer({
    super.key,
    required this.hasAssignedResidence,
    required this.isAuthenticated,
    required this.showPossessionView,
    required this.onPossessionViewChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: context.surfaceColor,
      child: Column(
        children: [
          // --- 1. CABECERA DINÁMICA CON FOTO Y DATOS DEL USUARIO ---
          BlocBuilder<AuthBloc, AuthState>(
            builder: (context, state) {
              String name = "Menú de Navegación";
              String email = "Estate App";
              String? photoUrl;

              if (state is Authenticated) {
                name = state.user.name;
                email = state.user.email;
                photoUrl = state.user.photoUrl;
              }

              return UserAccountsDrawerHeader(
                decoration: BoxDecoration(color: context.primaryColor),
                currentAccountPicture: CircleAvatar(
                  backgroundColor: Colors.white,
                  backgroundImage: photoUrl != null && photoUrl.isNotEmpty
                      ? NetworkImage(photoUrl)
                      : null,
                  child: photoUrl == null || photoUrl.isEmpty
                      ? Icon(
                          Icons.person_outline_rounded,
                          color: context.primaryColor,
                          size: 36,
                        )
                      : null,
                ),
                accountName: Text(
                  name,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                accountEmail: Text(
                  email,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    color: Colors.white.withOpacity(0.70),
                    fontSize: 13,
                  ),
                ),
              );
            },
          ),

          // --- OPCIÓN 1: GALERÍA DE INMUEBLES ---
          _buildDrawerItem(
            context: context,
            icon: Icons.gite_outlined,
            title: "Galería de Inmuebles",
            isSelected: !showPossessionView || !hasAssignedResidence,
            onTap: () {
              onPossessionViewChanged(false);
              Navigator.pop(context);
            },
          ),

          // --- OPCIÓN 2: MIS FAVORITOS ---
          _buildDrawerItem(
            context: context,
            icon: Icons.favorite_border_rounded,
            title: "Mis Favoritos",
            iconColor: Colors.redAccent,
            isSelected: false,
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const TenantFavoritesScreen(),
                ),
              );
            },
          ),

          // --- OPCIÓN 3: MIS INMUEBLES ASIGNADOS ---
          _buildDrawerItem(
            context: context,
            icon: Icons.home_work_outlined,
            title: "Mis Inmuebles Asignados",
            iconColor: hasAssignedResidence ? Colors.green : Colors.grey[400],
            isSelected: showPossessionView && hasAssignedResidence,
            enabled: hasAssignedResidence,
            subtitle: !hasAssignedResidence
                ? "No tienes inmuebles activos aún"
                : null,
            onTap: () {
              onPossessionViewChanged(true);
              Navigator.pop(context);
            },
          ),

          // --- NUEVA OPCIÓN 4: MI PERFIL EDITABLE ---
          if (isAuthenticated)
            _buildDrawerItem(
              context: context,
              icon: Icons.badge_outlined,
              title: "Mi Perfil Legal",
              isSelected: false,
              onTap: () {
                Navigator.pop(context);
                // Desentañar cuando crees el archivo físico de la UI de edición

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const TenantProfileScreen(),
                  ),
                );
              },
            ),

          const Spacer(),
          const Divider(height: 1),

          // --- BOTÓN DE SESIÓN ACCIÓN INFERIOR ---
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: ListTile(
              leading: Icon(
                isAuthenticated ? Icons.logout_rounded : Icons.login_rounded,
                color: isAuthenticated
                    ? Colors.redAccent
                    : context.primaryColor,
              ),
              title: CustomText(
                isAuthenticated ? "Cerrar Sesión" : "Iniciar Sesión",
                fontWeight: FontWeight.bold,
                color: isAuthenticated
                    ? Colors.redAccent
                    : context.primaryColor,
              ),
              onTap: () {
                Navigator.pop(context);
                if (isAuthenticated) {
                  context.read<NotificationBloc>().add(const ClearUserToken());
                  context.read<AuthBloc>().add(LogOutRequested());
                } else {
                  context.read<AuthBloc>().add(ShowLoginScreenRequested());
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  // --- MAQUETADOR DE ITEMS REUTILIZABLE CON ESTILO ---
  Widget _buildDrawerItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
    Color? iconColor,
    bool enabled = true,
    String? subtitle,
  }) {
    return ListTile(
      enabled: enabled,
      selected: isSelected,
      selectedTileColor: context.primaryColor.withOpacity(0.05),
      leading: Icon(
        icon,
        color: isSelected
            ? context.primaryColor
            : (iconColor ?? context.textSecondaryColor.withOpacity(0.7)),
      ),
      title: CustomText(
        title,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
        color: isSelected
            ? context.primaryColor
            : (enabled
                  ? context.textColor
                  : context.textSecondaryColor.withOpacity(0.4)),
      ),
      subtitle: subtitle != null
          ? CustomText(
              subtitle,
              baseFontSize: 11,
              color: context.textSecondaryColor.withOpacity(0.5),
            )
          : null,
      onTap: onTap,
    );
  }
}
