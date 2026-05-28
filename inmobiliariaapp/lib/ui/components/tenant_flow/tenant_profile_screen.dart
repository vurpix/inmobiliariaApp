// ui/pages/profile/tenant_profile_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inmobiliariaapp/bloc/authBloc/auth_bloc.dart';
import 'package:inmobiliariaapp/bloc/authBloc/auth_state.dart';
import 'package:inmobiliariaapp/ui/components/auth_ux/user_reviews_history_screen.dart';
import 'package:inmobiliariaapp/ui/components/global/custom_text.dart';
import 'package:inmobiliariaapp/ui/components/global/custom_text_button.dart';
import 'package:inmobiliariaapp/utils/themes.dart';

class TenantProfileScreen extends StatefulWidget {
  const TenantProfileScreen({super.key});

  @override
  State<TenantProfileScreen> createState() => _TenantProfileScreenState();
}

class _TenantProfileScreenState extends State<TenantProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedDocType;
  late TextEditingController _docNumberController;
  late TextEditingController _occupationController;
  bool _isSaving = false;

  final List<String> _docTypes = [
    "Cédula de Ciudadanía",
    "Cédula de Extranjería",
    "Pasaporte",
  ];

  @override
  void initState() {
    super.initState();
    final authState = context.read<AuthBloc>().state;
    String initialNumber = "";
    String initialOccupation = "";

    if (authState is Authenticated) {
      _selectedDocType = _docTypes.contains(authState.user.documentType)
          ? authState.user.documentType
          : _docTypes.first;

      initialNumber = authState.user.documentNumber;
      initialOccupation = authState.user.occupation;
    }

    _docNumberController = TextEditingController(text: initialNumber);
    _occupationController = TextEditingController(text: initialOccupation);
  }

  @override
  void dispose() {
    _docNumberController.dispose();
    _occupationController.dispose();
    super.dispose();
  }

  Future<void> _saveProfileData(String uid) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'documentType': _selectedDocType,
        'documentNumber': _docNumberController.text.trim(),
        'occupation': _occupationController.text.trim(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const CustomText(
              "Perfil legal actualizado con éxito",
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
            backgroundColor: Colors.green[700],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: CustomText("Error al guardar: $e", color: Colors.white),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;

    if (authState is! Authenticated) {
      return Scaffold(
        body: Center(
          child: CustomText(
            "Acceso denegado. Inicie sesión nuevamente.",
            color: context.textColor,
          ),
        ),
      );
    }

    final user = authState.user;
    final String rawRole = user.role.toString().split('.').last.toLowerCase();

    return Scaffold(
      backgroundColor: context.surfaceColor.withOpacity(0.96),
      appBar: AppBar(
        title: CustomText(
          "Mi Perfil Legal",
          baseFontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        backgroundColor: context.primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: _isSaving
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  // --- TARJETA SUPERIOR: DATOS DE PERFIL (SOLO LECTURA) ---
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: context.surfaceColor,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF1A365D).withOpacity(0.04),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 30,
                          backgroundColor: context.primaryColor.withOpacity(
                            0.06,
                          ),
                          backgroundImage:
                              user.photoUrl != null && user.photoUrl!.isNotEmpty
                              ? NetworkImage(user.photoUrl!)
                              : null,
                          child: user.photoUrl == null || user.photoUrl!.isEmpty
                              ? Icon(
                                  Icons.person_outline_rounded,
                                  color: context.primaryColor,
                                  size: 26,
                                )
                              : null,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CustomText.title(
                                user.name,
                                baseFontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                              const SizedBox(height: 4),
                              CustomText(
                                user.email,
                                baseFontSize: 12,
                                color: context.textSecondaryColor.withOpacity(
                                  0.6,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    Icons.star_rounded,
                                    color: user.rating > 0
                                        ? const Color(0xFFEDC111)
                                        : Colors.grey[300],
                                    size: 16,
                                  ),
                                  const SizedBox(width: 4),
                                  CustomText(
                                    "${user.rating.toStringAsFixed(1)} ",
                                    baseFontSize:ResponsiveUtils.getFontSize(context, 11),
                                    fontWeight: FontWeight.bold,
                                  ),
                                  CustomTextButton(
                                    "(${user.reviewCount} reseñas)",
                                    baseFontSize: ResponsiveUtils.getFontSize(context, 11),
                                    color: context.textSecondaryColor,
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              UserReviewsHistoryScreen(
                                                targetUserId: user.id,
                                                targetUserName: user.name,
                                              ),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        _buildRoleBadge(context, rawRole),
                      ],
                    ),
                  ),
                  const SizedBox(height: 25),

                  // Cabecera descriptiva de los campos editables
                  CustomText.title(
                    "Información de Contratación",
                    baseFontSize: 16,
                    color: context.primaryColor,
                    fontWeight: FontWeight.w900,
                  ),
                  const SizedBox(height: 6),
                  CustomText(
                    "Complete los siguientes campos obligatorios para agilizar el estudio de seguridad y la firma digital de contratos.",
                    baseFontSize: 13,
                    color: context.textSecondaryColor.withOpacity(0.6),
                  ),
                  const SizedBox(height: 20),

                  // 1. INPUT: Tipo de Documento
                  _buildFieldLabel("Tipo de Documento"),
                  DropdownButtonFormField<String>(
                    value: _selectedDocType,
                    items: _docTypes
                        .map(
                          (type) =>
                              DropdownMenuItem(value: type, child: Text(type)),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setState(() => _selectedDocType = value),
                    icon: Icon(
                      Icons.expand_more_rounded,
                      color: context.primaryColor,
                    ),
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      color: context.textColor,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: _buildInputDecoration(
                      hint: "Seleccione un documento",
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 2. INPUT: Número de Identificación
                  _buildFieldLabel("Número de Identificación"),
                  TextFormField(
                    controller: _docNumberController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (value) => value == null || value.trim().isEmpty
                        ? "Este campo es requerido"
                        : null,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      color: context.textColor,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: _buildInputDecoration(hint: "Ej: 1098XXXXXX"),
                  ),
                  const SizedBox(height: 20),

                  // 3. INPUT: Profesión / Ocupación Laboral
                  _buildFieldLabel("Ocupación o Actividad Laboral"),
                  TextFormField(
                    controller: _occupationController,
                    keyboardType: TextInputType.text,
                    textCapitalization: TextCapitalization.sentences,
                    validator: (value) => value == null || value.trim().isEmpty
                        ? "Este campo es requerido"
                        : null,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      color: context.textColor,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: _buildInputDecoration(
                      hint: "Ej: Ingeniero, Comerciante",
                    ),
                  ),
                  const SizedBox(height: 35),

                  // --- BOTÓN DE ENVIAR ---
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => _saveProfileData(user.id),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: context.primaryColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: CustomText(
                        "GUARDAR INFORMACIÓN LEGAL",
                        baseFontSize: ResponsiveUtils.getFontSize(context, 14),
                        fontWeight: FontWeight.bold,
                        color: context.surfaceColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
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
        border: Border.all(color: badgeColor.withOpacity(0.2)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Inter',
          color: badgeColor,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 2),
      child: CustomText(
        label,
        baseFontSize: 12,
        fontWeight: FontWeight.w800,
        color: context.textColor.withOpacity(0.8),
      ),
    );
  }

  InputDecoration _buildInputDecoration({required String hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: context.textSecondaryColor.withOpacity(0.4),
        fontSize: 13,
        fontWeight: FontWeight.normal,
      ),
      filled: true,
      fillColor: context.textColor.withOpacity(0.01),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: context.textColor.withOpacity(0.08),
          width: 1.5,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: context.primaryColor, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.redAccent, width: 2),
      ),
    );
  }
}
