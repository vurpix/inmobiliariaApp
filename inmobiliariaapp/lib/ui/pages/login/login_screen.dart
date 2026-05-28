// ui/pages/login/login_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inmobiliariaapp/bloc/authBloc/auth_bloc.dart';
import 'package:inmobiliariaapp/bloc/authBloc/auth_event.dart';
import 'package:inmobiliariaapp/bloc/authBloc/auth_state.dart';
import 'package:inmobiliariaapp/ui/pages/login/register_screen.dart';
import 'package:inmobiliariaapp/ui/components/global/custom_text.dart';
import 'package:inmobiliariaapp/utils/themes.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthLoading) {
          setState(() => _isLoading = true);
        } else {
          setState(() => _isLoading = false);
        }

        if (state is AuthFailure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: CustomText(
                state.message,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
              backgroundColor: context.errorColor,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
      },
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          context.read<AuthBloc>().add(LogOutRequested());
        },
        child: Scaffold(
          backgroundColor: context.surfaceColor.withOpacity(0.96),
          body: Stack(
            children: [
              SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    // --- CORREGIDO: Comportamiento del teclado oficial de Flutter ---
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 24,
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: context.primaryColor.withOpacity(0.06),
                              border: Border.all(
                                color: context.primaryColor.withOpacity(0.12),
                                width: 2,
                              ),
                            ),
                            child: Icon(
                              Icons.holiday_village_outlined,
                              size: 38,
                              color: context.primaryColor,
                            ),
                          ),
                          const SizedBox(height: 20),
                          CustomText.title(
                            "SINMO",
                            baseFontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: context.primaryColor,
                          ),
                          const SizedBox(height: 6),
                          CustomText(
                            "Bienvenido de vuelta",
                            baseFontSize: 14,
                            color: context.textSecondaryColor.withOpacity(0.6),
                            fontWeight: FontWeight.w500,
                          ),
                          const SizedBox(height: 36),

                          _buildInputLabel("Correo electrónico"),
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 14,
                              color: context.textColor,
                              fontWeight: FontWeight.w600,
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return "Por favor ingresa tu correo electrónico";
                              }
                              final emailRegex = RegExp(
                                r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                              );
                              if (!emailRegex.hasMatch(value.trim())) {
                                return "El formato de correo no es válido";
                              }
                              return null;
                            },
                            decoration: _buildInputDecoration(
                              hint: "tu_correo@ejemplo.com",
                              icon: Icons.email_outlined,
                            ),
                          ),
                          const SizedBox(height: 20),

                          _buildInputLabel("Contraseña"),
                          TextFormField(
                            controller: _passController,
                            obscureText: _obscurePassword,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 14,
                              color: context.textColor,
                              fontWeight: FontWeight.w600,
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return "Por favor ingresa tu contraseña";
                              }
                              if (value.length < 6) {
                                return "La contraseña debe contener al menos 6 caracteres";
                              }
                              return null;
                            },
                            decoration: _buildInputDecoration(
                              hint: "••••••••",
                              icon: Icons.lock_outline_rounded,
                              suffix: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  color: context.primaryColor.withOpacity(0.6),
                                  size: 20,
                                ),
                                onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 30),

                          SizedBox(
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
                              onPressed: _isLoading
                                  ? null
                                  : () {
                                      if (_formKey.currentState!.validate()) {
                                        context.read<AuthBloc>().add(
                                          LogInRequested(
                                            _emailController.text.trim(),
                                            _passController.text,
                                          ),
                                        );
                                      }
                                    },
                              child: const Text(
                                "Iniciar Sesión",
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),

                          Row(
                            children: [
                              Expanded(
                                child: Divider(
                                  color: context.textColor.withOpacity(0.08),
                                  thickness: 1,
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                child: CustomText(
                                  "o continuar con",
                                  baseFontSize: 12,
                                  color: context.textSecondaryColor.withOpacity(
                                    0.4,
                                  ),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Expanded(
                                child: Divider(
                                  color: context.textColor.withOpacity(0.08),
                                  thickness: 1,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          _buildSocialButtons(context),
                          const SizedBox(height: 30),

                          GestureDetector(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const RegisterScreen(),
                              ),
                            ),
                            child: RichText(
                              text: TextSpan(
                                text: "¿No tienes una cuenta? ",
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  color: context.textSecondaryColor.withOpacity(
                                    0.6,
                                  ),
                                  fontSize: 14,
                                ),
                                children: [
                                  TextSpan(
                                    text: "Regístrate",
                                    style: TextStyle(
                                      color: context.primaryColor,
                                      fontWeight: FontWeight.bold,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),

                          CustomText(
                            "© 2026 SINMO. Todos los derechos reservados.",
                            baseFontSize: 11,
                            color: context.textSecondaryColor.withOpacity(0.3),
                            fontWeight: FontWeight.w500,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              if (_isLoading)
                Positioned.fill(
                  child: Container(
                    color: Colors.black,
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputLabel(String label) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8, left: 2),
        child: CustomText(
          label,
          baseFontSize: 12,
          fontWeight: FontWeight.w800,
          color: context.textColor.withOpacity(0.7),
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration({
    required String hint,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: context.textSecondaryColor.withOpacity(0.35),
        fontSize: 14,
        fontWeight: FontWeight.normal,
      ),
      filled: true,
      fillColor: context.surfaceColor,
      prefixIcon: Icon(
        icon,
        color: context.primaryColor.withOpacity(0.7),
        size: 20,
      ),
      suffixIcon: suffix,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: context.textColor.withOpacity(0.06),
          width: 1.5,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: context.primaryColor, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.redAccent, width: 2),
      ),
    );
  }

  Widget _buildSocialButtons(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _buildSocialCard(
            label: "Iniciar con Google",
            icon: Image.network(
              'https://cdns.iconmonstr.com/wp-content/releases/preview/2013/240/iconmonstr-google-1.png', // O una URL directa de confianza
              height: 20,
              width: 20,
              // Fallback de seguridad por si el dispositivo no tiene internet en ese instante
              errorBuilder: (context, error, stackTrace) => Icon(
                Icons.g_mobiledata_rounded,
                color: context.primaryColor,
                size: 24,
              ),
            ),
            onPressed: () {
              context.read<AuthBloc>().add(
                GoogleSignInRequested(acceptedTerms: true, isRegister: false),
              );
            },
          ),
        ),
        if (Theme.of(context).platform == TargetPlatform.iOS) ...[
          const SizedBox(width: 12),
          Expanded(
            child: _buildSocialCard(
              label: "Apple",
              icon: Icon(Icons.apple, size: 22, color: context.textColor),
              onPressed: () {
                context.read<AuthBloc>().add(
                  AppleSignInRequested(acceptedTerms: true, isRegister: false),
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSocialCard({
    required String label,
    required Widget icon,
    required VoidCallback onPressed,
  }) {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 50),
        side: BorderSide(
          color: context.textColor.withOpacity(0.06),
          width: 1.5,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: context.surfaceColor,
        elevation: 0,
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ), // Espaciado premium Luxe
      ),
      onPressed: onPressed,
      icon: icon,
      label: Text(
        label,
        style: TextStyle(
          fontFamily: 'Inter',
          color: context.textColor,
          fontSize: 13,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
