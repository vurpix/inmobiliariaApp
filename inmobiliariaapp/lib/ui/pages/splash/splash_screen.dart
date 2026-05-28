// ui/pages/splash/splash_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inmobiliariaapp/bloc/authBloc/auth_bloc.dart';
import 'package:inmobiliariaapp/bloc/authBloc/auth_state.dart';
import 'package:inmobiliariaapp/ui/components/global/custom_text.dart'; // Tu componente de texto global
import 'package:inmobiliariaapp/utils/themes.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthFailure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: CustomText(
                state.message,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
              backgroundColor:
                  context.errorColor, // Uso de tu extensión de color de error
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              duration: const Duration(seconds: 4),
            ),
          );
        }
      },
      child: Scaffold(
        backgroundColor:
            context.surfaceColor, // Adaptativo a modo claro y oscuro
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // --- ICONO DE MARCA LUXE ESTATE ---
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: context.primaryColor.withOpacity(0.06),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.holiday_village_outlined,
                  size: 72,
                  color: context.primaryColor,
                ),
              ),
              const SizedBox(height: 32),

              // --- INDICADOR DE CARGA ---
              SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  color: context.primaryColor,
                  strokeWidth: 3,
                ),
              ),
              const SizedBox(height: 20),

              // --- TEXTO DE BIENVENIDA ---
              CustomText(
                "Cargando...",
                baseFontSize: 14,
                fontWeight: FontWeight.w600,
                color: context.textSecondaryColor.withOpacity(0.7),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
