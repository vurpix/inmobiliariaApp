// ui/pages/login/register_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inmobiliariaapp/bloc/authBloc/auth_bloc.dart';
import 'package:inmobiliariaapp/bloc/authBloc/auth_event.dart';
import 'package:inmobiliariaapp/bloc/authBloc/auth_state.dart';
import 'package:inmobiliariaapp/enum/user_role.dart';
import 'package:inmobiliariaapp/ui/components/auth_ux/social_role_selection_screen.dart';
import 'package:inmobiliariaapp/ui/pages/home/home_screen.dart';
import 'package:inmobiliariaapp/ui/components/pdf/Pdf_view_screen.dart';
import 'package:inmobiliariaapp/ui/components/global/custom_text.dart';
import 'package:inmobiliariaapp/utils/themes.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passController = TextEditingController();
  UserRole _selectedRole = UserRole.tenant;
  bool _acceptedTerms = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passController.dispose();
    super.dispose();
  }

  void _showTermsAlert() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const CustomText(
          "⚠️ Debes aceptar los términos y condiciones antes de registrarte.",
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
        backgroundColor: Colors.orange[800],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _handleEmailRegister() {
    if (!_acceptedTerms) {
      _showTermsAlert();
      return;
    }

    if (_formKey.currentState!.validate()) {
      final name = _nameController.text.trim();
      final email = _emailController.text.trim();
      final password = _passController.text.trim();

      context.read<AuthBloc>().add(
        SignUpRequested(
          email: email,
          password: password,
          name: name,
          role: _selectedRole,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.surfaceColor.withOpacity(0.96),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: BackButton(color: context.primaryColor),
        scrolledUnderElevation: 0,
      ),
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
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

          if (state is Authenticated) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const HomeScreen()),
              (route) => false,
            );
          }

          if (state is AuthSocialFirstTime) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SocialRoleSelectionScreen(
                  tempUid: state.uid,
                  email: state.email,
                  name: state.name,
                  photoUrl: state.photoUrl,
                ),
              ),
            );
          }
        },
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              // --- CORREGIDO: Comportamiento del teclado nativo oficial ---
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CustomText.title(
                      "Crea tu cuenta",
                      baseFontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: context.primaryColor,
                    ),
                    const SizedBox(height: 6),
                    CustomText(
                      "Únete a la plataforma inmobiliaria más exclusiva",
                      baseFontSize: 14,
                      color: context.textSecondaryColor.withOpacity(0.6),
                    ),
                    const SizedBox(height: 32),

                    _buildInputLabel("Nombre completo"),
                    TextFormField(
                      controller: _nameController,
                      keyboardType: TextInputType.name,
                      textCapitalization: TextCapitalization.words,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        color: context.textColor,
                        fontWeight: FontWeight.w600,
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return "El nombre es obligatorio";
                        }
                        if (value.trim().length < 3) {
                          return "El nombre debe tener al menos 3 letras";
                        }
                        return null;
                      },
                      decoration: _buildInputDecoration(
                        hint: "Ej: Juan Pérez",
                        icon: Icons.person_outline_rounded,
                      ),
                    ),
                    const SizedBox(height: 20),

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
                          return "El correo es obligatorio";
                        }
                        final emailRegex = RegExp(
                          r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                        );
                        if (!emailRegex.hasMatch(value.trim())) {
                          return "Ingresa un correo electrónico válido";
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
                          return "La contraseña es obligatoria";
                        }
                        if (value.length < 6) {
                          return "La contraseña debe tener mínimo 6 caracteres";
                        }
                        return null;
                      },
                      decoration: _buildInputDecoration(
                        hint: "Mínimo 6 caracteres",
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
                    const SizedBox(height: 24),

                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 2, bottom: 12),
                        child: CustomText(
                          "¿Cómo usarás la app?",
                          baseFontSize: ResponsiveUtils.getFontSize(
                            context,
                            11,
                          ),
                          fontWeight: FontWeight.w800,
                          color: context.textColor.withOpacity(0.7),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: _roleCard(
                            "Inquilino",
                            Icons.person_outline_rounded,
                            UserRole.tenant,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _roleCard(
                            "Propietario",
                            Icons.holiday_village_outlined,
                            UserRole.landlord,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // --- CHECKBOX DE TÉRMINOS Y CONDICIONES ---
                    StreamBuilder<DocumentSnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('config')
                          .doc('legal_info')
                          .snapshots(),
                      builder: (context, snapshot) {
                        String policyUrl = "";
                        if (snapshot.hasData && snapshot.data!.exists) {
                          final legalData =
                              snapshot.data!.data() as Map<String, dynamic>? ??
                              {};
                          policyUrl = legalData['privacyPolicyUrl'] ?? "";
                        }

                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 24,
                              height: 24,
                              child: Checkbox(
                                value: _acceptedTerms,
                                activeColor: context.primaryColor,
                                checkColor: Colors.white,
                                side: BorderSide(
                                  color: context.textColor.withOpacity(0.2),
                                  width: 1.5,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                onChanged: (bool? val) {
                                  setState(() => _acceptedTerms = val ?? false);
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  CustomText(
                                    "Acepto los ",
                                    baseFontSize: ResponsiveUtils.getFontSize(
                                      context,
                                      11,
                                    ),
                                    color: context.textColor.withOpacity(0.7),
                                    fontWeight: FontWeight.w500,
                                  ),
                                  GestureDetector(
                                    onTap: policyUrl.isEmpty
                                        ? null
                                        : () => Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => PdfViewScreen(
                                                path: policyUrl,
                                                title: "Términos Legales",
                                              ),
                                            ),
                                          ),
                                    // --- CORREGIDO: Usamos Text nativo de Flutter para mapear la propiedad decoration sin errores ---
                                    child: Text(
                                      "términos y condiciones legales",
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: ResponsiveUtils.getFontSize(
                                          context,
                                          11,
                                        ),
                                        color: context.primaryColor,
                                        fontWeight: FontWeight.bold,
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 28),

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
                        onPressed: _handleEmailRegister,
                        child: const Text(
                          "Registrarse con Correo",
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.2,
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
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: CustomText(
                            "O regístrate con",
                            baseFontSize: 12,
                            color: context.textSecondaryColor.withOpacity(0.4),
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

                    _buildSocialButton(
                      label: "Continuar con Google",
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
                      color: context.surfaceColor,
                      textColor: context.textColor,
                      onPressed: () {
                        if (!_acceptedTerms) {
                          _showTermsAlert();
                          return;
                        }
                        context.read<AuthBloc>().add(
                          GoogleSignInRequested(
                            acceptedTerms: _acceptedTerms,
                            isRegister: true,
                          ),
                        );
                      },
                    ),
                    if (Theme.of(context).platform == TargetPlatform.iOS) ...[
                      const SizedBox(height: 12),
                      _buildSocialButton(
                        label: "Continuar con Apple",
                        icon: Icon(
                          Icons.apple,
                          size: 22,
                          color: context.textColor,
                        ),
                        color: context.surfaceColor,
                        textColor: context.textColor,
                        onPressed: () {
                          if (!_acceptedTerms) {
                            _showTermsAlert();
                            return;
                          }
                          context.read<AuthBloc>().add(
                            AppleSignInRequested(
                              acceptedTerms: _acceptedTerms,
                              isRegister: true,
                            ),
                          );
                        },
                      ),
                    ],
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
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

  Widget _buildSocialButton({
    required String label,
    required Widget icon,
    required Color color,
    required Color textColor,
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
        backgroundColor: color,
        foregroundColor: textColor,
        elevation: 0,
      ),
      onPressed: onPressed,
      icon: icon,
      label: Text(
        label,
        style: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 13,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _roleCard(String label, IconData icon, UserRole role) {
    bool isSelected = _selectedRole == role;
    return GestureDetector(
      onTap: () => setState(() => _selectedRole = role),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? context.primaryColor.withOpacity(0.05)
              : context.surfaceColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? context.primaryColor
                : context.textColor.withOpacity(0.06),
            width: isSelected ? 2 : 1.5,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected
                  ? context.primaryColor
                  : context.textSecondaryColor.withOpacity(0.5),
              size: 24,
            ),
            const SizedBox(height: 6),
            CustomText(
              label,
              fontWeight: FontWeight.bold,
              baseFontSize: 13,
              color: isSelected
                  ? context.primaryColor
                  : context.textSecondaryColor.withOpacity(0.7),
            ),
          ],
        ),
      ),
    );
  }
}
