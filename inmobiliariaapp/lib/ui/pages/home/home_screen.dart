import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inmobiliariaapp/bloc/contractBloc/contract_bloc.dart';
import 'package:inmobiliariaapp/bloc/contractBloc/contract_state.dart';
import 'package:inmobiliariaapp/bloc/authBloc/auth_bloc.dart';
import 'package:inmobiliariaapp/bloc/authBloc/auth_state.dart';
import 'package:inmobiliariaapp/enum/user_role.dart';
import 'package:inmobiliariaapp/ui/components/property/public_property_gallery.dart';
import 'package:inmobiliariaapp/ui/pages/home/admin/admin_dashboard.dart';
import 'package:inmobiliariaapp/ui/pages/home/landlord/landlord_dashboard.dart';
import 'package:inmobiliariaapp/ui/pages/login/login_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, authState) {
      
        // 1. CASO: USUARIO AUTENTICADO (Tu flujo actual)
        if (authState is Authenticated) {
          final user = authState.user;
          return PopScope(
            canPop: false, // Bloqueamos la salida automática de la app
            onPopInvokedWithResult: (didPop, result) {
              if (didPop) return;

              // En lugar de salir, le decimos al Bloc que vuelva a la galería
              // context.read<AuthBloc>().add(LogOutRequested());
            },
            child: SafeArea(
              child: Scaffold(
                body: BlocBuilder<ContractBloc, ContractState>(
                  builder: (context, contractState) {
                    switch (user.role) {
                      case UserRole.admin:
                        return AdminDashboard(state: contractState);
                      case UserRole.landlord:
                        return LandlordDashboard();
                      case UserRole.tenant:
                        return PublicPropertyGallery();
                    }
                  },
                ),
              ),
            ),
          );
        }

        // 2. CASO: USUARIO NO AUTENTICADO (Vista Pública)
        // Aquí mostramos la galería de propiedades aprobadas
        return const LoginScreen();
      },
    );
  }
}
