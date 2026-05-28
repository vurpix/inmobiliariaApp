// ui/components/auth_ux/social_role_selection_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inmobiliariaapp/bloc/authBloc/auth_bloc.dart';
import 'package:inmobiliariaapp/bloc/authBloc/auth_event.dart';
import 'package:inmobiliariaapp/enum/user_role.dart';
import 'package:inmobiliariaapp/ui/components/global/custom_text.dart'; // Componente de marca unificado
import 'package:inmobiliariaapp/utils/themes.dart';

class SocialRoleSelectionScreen extends StatefulWidget {
  final String tempUid;
  final String email;
  final String? name;
  final String? photoUrl;

  const SocialRoleSelectionScreen({
    super.key,
    required this.tempUid,
    required this.email,
    this.name,
    this.photoUrl,
  });

  @override
  State<SocialRoleSelectionScreen> createState() =>
      _SocialRoleSelectionScreenState();
}

class _SocialRoleSelectionScreenState extends State<SocialRoleSelectionScreen> {
  UserRole? _selectedRole;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.surfaceColor.withOpacity(0.96),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // --- ICONO DE BIENVENIDA PREMIUM ---
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: context.primaryColor.withOpacity(0.06),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: context.primaryColor.withOpacity(0.12),
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    Icons.badge_outlined,
                    size: 40,
                    color: context.primaryColor,
                  ),
                ),
                const SizedBox(height: 24),

                CustomText.title(
                  "¡Casi listo!",
                  baseFontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: context.primaryColor,
                ),
                const SizedBox(height: 8),
                CustomText(
                  "Para terminar de configurar tu cuenta, dinos cómo usarás la plataforma de Luxe Estate:",
                  baseFontSize: 14,
                  textAlign: TextAlign.center,
                  color: context.textSecondaryColor.withOpacity(0.6),
                ),
                const SizedBox(height: 36),

                // --- TARJETA OPTION 1: INQUILINO ---
                _buildRoleOption(
                  title: "Deseo buscar inmuebles",
                  subtitle: "Registrarme como Inquilino",
                  role: UserRole.tenant,
                  icon: Icons.person_search_rounded,
                ),
                const SizedBox(height: 16),

                // --- TARJETA OPTION 2: DUEÑO ---
                _buildRoleOption(
                  title: "Tengo propiedades para arrendar",
                  subtitle: "Registrarme como Propietario",
                  role: UserRole.landlord,
                  icon: Icons.holiday_village_outlined,
                ),

                const SizedBox(height: 40),

                // --- BOTÓN DE CONFIRMACIÓN ADAPTATIVO DINÁMICO ---
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: _selectedRole != null ? 1.0 : 0.0,
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: context.primaryColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: _selectedRole == null
                          ? null
                          : () {
                              context.read<AuthBloc>().add(
                                CompleteSocialSignUpRequested(
                                  uid: widget.tempUid,
                                  email: widget.email,
                                  name: widget.name,
                                  photoUrl: widget.photoUrl,
                                  role: _selectedRole!,
                                ),
                              );
                            },
                      child: const Text(
                        "FINALIZAR CONFIGURACIÓN",
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleOption({
    required String title,
    required String subtitle,
    required UserRole role,
    required IconData icon,
  }) {
    final bool isSelected = _selectedRole == role;

    return GestureDetector(
      onTap: () => setState(() => _selectedRole = role),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected
              ? context.primaryColor.withOpacity(0.05)
              : context.surfaceColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected
                ? context.primaryColor
                : context.textColor.withOpacity(0.06),
            width: isSelected ? 2 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(
                0xFF1A365D,
              ).withOpacity(isSelected ? 0.02 : 0.01),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected
                    ? context.primaryColor.withOpacity(0.1)
                    : context.textColor.withOpacity(0.02),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: isSelected
                    ? context.primaryColor
                    : context.textSecondaryColor.withOpacity(0.5),
                size: 26,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CustomText(
                    title,
                    fontWeight: FontWeight.bold,
                    baseFontSize: 14,
                    color: isSelected
                        ? context.primaryColor
                        : context.textColor,
                  ),
                  const SizedBox(height: 2),
                  CustomText(
                    subtitle,
                    baseFontSize: 12,
                    color: isSelected
                        ? context.primaryColor.withOpacity(0.8)
                        : context.textSecondaryColor.withOpacity(0.6),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle_rounded,
                color: context.primaryColor,
                size: 22,
              ),
          ],
        ),
      ),
    );
  }
}
