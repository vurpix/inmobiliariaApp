// ui/components/admin/views/admin_users_view.dart
import 'package:flutter/material.dart';
import 'package:inmobiliariaapp/models/user.dart';
import 'package:inmobiliariaapp/services/user_service.dart';
import 'package:inmobiliariaapp/ui/components/admin/views/admin_user_detail_screen.dart';
import 'package:inmobiliariaapp/utils/themes.dart';
import 'package:inmobiliariaapp/ui/components/global/custom_text.dart';
// IMPORTA AQUÍ TU PANTALLA DE DETALLES DE USUARIO
// import 'package:inmobiliariaapp/ui/components/admin/admin_user_detail_screen.dart';

class AdminUsersView extends StatefulWidget {
  final UserService userService;

  const AdminUsersView({super.key, required this.userService});

  @override
  State<AdminUsersView> createState() => _AdminUsersViewState();
}

class _AdminUsersViewState extends State<AdminUsersView> {
  String _searchQuery = "";
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // --- 1. MEJORA: BUSCADOR PREMIUM EN TIEMPO REAL ---
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Container(
            decoration: BoxDecoration(
              color: context.surfaceColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1A365D).withOpacity(0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                color: context.textColor,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                hintText: "Buscar por nombre o correo...",
                hintStyle: TextStyle(
                  color: context.textSecondaryColor.withOpacity(0.4),
                  fontSize: 13,
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: context.primaryColor,
                  size: 22,
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(
                          Icons.close_rounded,
                          color: context.textSecondaryColor,
                          size: 18,
                        ),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            _searchQuery = "";
                          });
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: context.textColor.withOpacity(0.04),
                    width: 1,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: context.primaryColor.withOpacity(0.4),
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),
        ),

        // --- LISTADO ASÍNCRONO ---
        Expanded(
          child: StreamBuilder<List<UserModel>>(
            stream: widget.userService.watchAllUsers(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(
                  child: CustomText(
                    "No se encontraron usuarios registrados.",
                    baseFontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                );
              }

              List<UserModel> users = snapshot.data!;

              // --- 2. MEJORA: ORDENAR POR FECHA DE CREACIÓN ---
              // Ordena de manera descendente (los más nuevos primero).
              // Si no tienes el campo en el modelo, puedes usar el fallback 'id' o crear la propiedad.
              users.sort((a, b) {
                final dateA =
                    a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
                final dateB =
                    b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
                return dateB.compareTo(dateA);
              });

              // Filtrado local según la query del buscador
              if (_searchQuery.isNotEmpty) {
                users = users.where((user) {
                  final nameMatch = user.name.toLowerCase().contains(
                    _searchQuery,
                  );
                  final emailMatch = user.email.toLowerCase().contains(
                    _searchQuery,
                  );
                  return nameMatch || emailMatch;
                }).toList();
              }

              if (users.isEmpty) {
                return const Center(
                  child: CustomText(
                    "No hay coincidencias para la búsqueda.",
                    baseFontSize: 13,
                    color: Colors.grey,
                  ),
                );
              }

              return ListView.builder(
                itemCount: users.length,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                itemBuilder: (context, index) {
                  final user = users[index];
                  final String rawRole = user.role
                      .toString()
                      .split('.')
                      .last
                      .toLowerCase();

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: context.surfaceColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: context.textColor.withOpacity(0.04),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF1A365D).withOpacity(0.03),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),

                      // --- 3. MEJORA: NAVIGATOR HACIA LA PANTALLA DE DETALLES ---
                      onTap: () {
                        // Reemplaza por el nombre real de tu pantalla detallada si es diferente
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                AdminUserDetailScreen(user: user),
                          ),
                        );
                      },
                      leading: CircleAvatar(
                        radius: 22,
                        backgroundColor: context.primaryColor.withOpacity(0.06),
                        backgroundImage:
                            user.photoUrl != null && user.photoUrl!.isNotEmpty
                            ? NetworkImage(user.photoUrl!)
                            : null,
                        child: user.photoUrl == null || user.photoUrl!.isEmpty
                            ? Icon(
                                Icons.person_outline_rounded,
                                color: context.primaryColor,
                                size: 22,
                              )
                            : null,
                      ),
                      title: CustomText(
                        user.name,
                        baseFontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: CustomText(
                          user.email,
                          baseFontSize: 12,
                          color: context.textSecondaryColor.withOpacity(0.6),
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildRoleBadge(context, rawRole),
                          const SizedBox(width: 6),
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 12,
                            color: context.textSecondaryColor.withOpacity(0.3),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRoleBadge(BuildContext context, String role) {
    Color badgeColor;
    String label;

    if (role.contains('admin')) {
      badgeColor = context.primaryColor;
      label = "ADMIN";
    } else if (role.contains('owner') || role.contains('landlord')) {
      badgeColor = const Color(0xFFE65100);
      label = "PROPIETARIO";
    } else {
      badgeColor = Colors.green[700]!;
      label = "INQUILINO";
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: badgeColor.withOpacity(0.2), width: 1),
      ),
      child: CustomText(
        label,
        color: badgeColor,
        baseFontSize: ResponsiveUtils.getFontSize(context, 10),
        fontWeight: FontWeight.w900,
      ),
    );
  }
}
