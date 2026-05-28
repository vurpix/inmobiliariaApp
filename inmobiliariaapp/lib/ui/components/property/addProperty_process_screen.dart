import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

// Blocs
import 'package:inmobiliariaapp/bloc/authBloc/auth_bloc.dart';
import 'package:inmobiliariaapp/bloc/authBloc/auth_state.dart';
import 'package:inmobiliariaapp/bloc/propertyBloc/property_bloc.dart';
import 'package:inmobiliariaapp/bloc/propertyBloc/property_event.dart';
import 'package:inmobiliariaapp/bloc/propertyBloc/property_state.dart';
// Components
import 'package:inmobiliariaapp/ui/components/step_add_properties/step_basic_info.dart';
import 'package:inmobiliariaapp/ui/components/step_add_properties/step_documents.dart';
import 'package:inmobiliariaapp/ui/components/step_add_properties/step_media.dart';
import 'package:inmobiliariaapp/utils/themes.dart';

class AddPropertyProcessScreen extends StatefulWidget {
  const AddPropertyProcessScreen({super.key});

  @override
  State<AddPropertyProcessScreen> createState() =>
      _AddPropertyProcessScreenState();
}

class _AddPropertyProcessScreenState extends State<AddPropertyProcessScreen> {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  final int _totalSteps = 3;

  @override
  void initState() {
    super.initState();
    final bloc = context.read<PropertyBloc>();
    if (!bloc.state.isEditing) {
      bloc.add(LoadPropertyCacheRequested());
    }
  }

  void _updateData(String key, dynamic value) {
    context.read<PropertyBloc>().add(UpdatePropertyData(key, value));
  }

  // Método centralizado para manejar la salida
  Future<void> _handleBackNavigation(bool isEditing) async {
    if (_currentStep > 0) {
      _prevPage();
    } else {
      final bool shouldExit = await _showExitConfirmation(context);
      if (shouldExit && mounted) {
        // Al salir, limpiamos para que el siguiente inicio sea limpio
        context.read<PropertyBloc>().add(ClearPropertyCacheRequested());
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<PropertyBloc, PropertyState>(
      listener: (context, state) {
        if (state.status == PropertyStatus.loading) {
          _showLoadingDialog(
            context,
            state.isEditing
                ? "Guardando cambios..."
                : "Registrando inmueble...",
          );
        } else if (state.status == PropertyStatus.failure) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.errorMessage ?? "Error en el proceso"),
              backgroundColor: Colors.red,
            ),
          );
        } else if (state.status == PropertyStatus.success) {
          Navigator.pop(context);
          context.read<PropertyBloc>().add(ClearPropertyCacheRequested());
          Navigator.of(context).popUntil((route) => route.isFirst);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                state.isEditing
                    ? "✅ Cambios guardados correctamente"
                    : "✅ Registro enviado a revisión jurídica",
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      },
      child: BlocBuilder<PropertyBloc, PropertyState>(
        builder: (context, state) {
          return PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, result) async {
              if (didPop) return;
              await _handleBackNavigation(state.isEditing);
            },
            child: Scaffold(
              appBar: AppBar(
                // Cambio visual: Flecha en lugar de X
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => _handleBackNavigation(state.isEditing),
                ),
                centerTitle: true,
                title: Column(
                  children: [
                    Text(
                      state.isEditing ? "EDITAR PROPIEDAD" : "NUEVA PROPIEDAD",
                      style: TextStyle(
                        fontSize: ResponsiveUtils.getFontSize(context, 18),
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    Text(
                      "Paso ${_currentStep + 1} de $_totalSteps",
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              body: Column(
                children: [
                  LinearProgressIndicator(
                    value: (_currentStep + 1) / _totalSteps,
                    backgroundColor: Colors.grey[200],
                    color: state.isEditing ? Colors.orange : Colors.blue,
                  ),
                  Expanded(
                    child: PageView(
                      controller: _pageController,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        StepBasicInfo(
                          data: state.formData,
                          onUpdate: _updateData,
                        ),
                        StepMedia(data: state.formData, onUpdate: _updateData),
                        StepDocuments(
                          data: state.formData,
                          onUpdate: _updateData,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              bottomNavigationBar: _buildBottomBar(state),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBottomBar(PropertyState state) {
    bool isStepValid = true;
    final data = state.formData;

    if (_currentStep == 0) {
      isStepValid =
          data['address'].toString().isNotEmpty && (data['canon'] ?? 0) > 0 && (data['description'] ?? '').toString().isNotEmpty;
    } else if (_currentStep == 1) {
      final images = List<String>.from(data['images'] ?? []);
      isStepValid = images.isNotEmpty;
    } else if (_currentStep == 2) {
      final docs = List<String>.from(data['docs'] ?? []);
      final bool accepted = data['acceptTerms'] ?? false;
      isStepValid = docs.isNotEmpty && accepted;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 50),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(double.infinity, 55),
          backgroundColor: !isStepValid
              ? Colors.grey
              : (state.isEditing ? Colors.orange[800] : Colors.blue[900]),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: !isStepValid
            ? null
            : () {
                if (_currentStep < 2) {
                  _nextPage();
                } else {
                  _handleFinalSubmission();
                }
              },
        child: Text(
          _currentStep < 2
              ? "SIGUIENTE"
              : (state.isEditing ? "GUARDAR CAMBIOS" : "FINALIZAR Y ENVIAR"),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  void _handleFinalSubmission() {
    final authState = context.read<AuthBloc>().state;
    if (authState is Authenticated) {
      context.read<PropertyBloc>().add(
        SubmitPropertyRequested(authState.user.id),
      );
    }
  }

  void _nextPage() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.ease,
    );
    setState(() => _currentStep++);
  }

  void _prevPage() {
    _pageController.previousPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.ease,
    );
    setState(() => _currentStep--);
  }

  Future<bool> _showExitConfirmation(BuildContext context) async {
    return await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("¿Salir del proceso?"),
            content: const Text(
              "Se perderán los cambios que no se hayan guardado en el servidor.",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text("CANCELAR"),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text("SALIR", style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _showLoadingDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 20),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
