// ui/components/admin/admin_dashboard.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inmobiliariaapp/bloc/authBloc/auth_bloc.dart';
import 'package:inmobiliariaapp/bloc/authBloc/auth_event.dart';
import 'package:inmobiliariaapp/bloc/contractBloc/contract_state.dart';
import 'package:inmobiliariaapp/bloc/notificationBloc/notification_bloc.dart';
import 'package:inmobiliariaapp/bloc/notificationBloc/notification_event.dart';
import 'package:inmobiliariaapp/services/application_service.dart';
import 'package:inmobiliariaapp/services/user_service.dart';

// Otras pantallas importadas
import 'package:inmobiliariaapp/ui/components/admin/admin_appointments_screen.dart';
import 'package:inmobiliariaapp/ui/components/admin/views/config/admin_config_screen.dart';
import 'package:inmobiliariaapp/ui/components/admin/admin_final_contracts_screen.dart';
import 'package:inmobiliariaapp/ui/components/admin/views/admin_applications_view.dart';
import 'package:inmobiliariaapp/ui/components/admin/views/admin_properties_view.dart';
import 'package:inmobiliariaapp/ui/components/admin/views/admin_users_view.dart';
import 'package:inmobiliariaapp/ui/components/auth_ux/notification_badge.dart';
import 'package:inmobiliariaapp/ui/components/global/custom_text.dart';
import 'package:inmobiliariaapp/ui/pages/viafirma_test_screen.dart';
import 'package:inmobiliariaapp/utils/themes.dart';

class AdminDashboard extends StatefulWidget {
  final ContractState state;

  const AdminDashboard({
    super.key,
    required this.state,
  });

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  String _currentView = 'contracts';

  final ApplicationService _applicationService = ApplicationService();
  final UserService _userService = UserService();

  String _getTitle() {
    switch (_currentView) {
      case 'contracts':
        return "Solicitudes Activas";
      case 'final_contracts':
        return "Archivo de Contratos";
      case 'viafirma_test':
        return "Pruebas de Firma Digital";
      case 'properties':
        return "Gestión de Inmuebles";
      case 'users':
        return "Usuarios del Sistema";
      case 'appointments':
        return "Agenda Judicial";
      case 'config':
        return "Configuración Global";
      default:
        return "Solicitudes Activas";
    }
  }

  Widget _getContent() {
    switch (_currentView) {
      case 'contracts':
        return AdminApplicationsView(
          applicationService: _applicationService,
          emptyStateBuilder: _buildEmptyState,
        );

      case 'final_contracts':
        return const AdminFinalContractsScreen();

      case 'viafirma_test':
        return const ViafirmaTestScreen();

      case 'properties':
        return const AdminPropertiesView();

      case 'users':
        return AdminUsersView(
          userService: _userService,
        );

      case 'appointments':
        return const AdminAppointmentsScreen();

      case 'config':
        return const AdminConfigScreen();

      default:
        return AdminApplicationsView(
          applicationService: _applicationService,
          emptyStateBuilder: _buildEmptyState,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: AppBar(
        title: CustomText(
          _getTitle(),
          baseFontSize: ResponsiveUtils.getFontSize(context, 18),
          fontWeight: FontWeight.bold,
          color: context.surfaceColor,
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 5.0),
            child: NotificationBadge(
              iconColor: Colors.white,
            ),
          ),
        ],
        iconTheme: IconThemeData(
          color: context.surfaceColor,
          size: 28,
        ),
        backgroundColor: context.primaryColor,
        foregroundColor: context.textColor,
        elevation: 0,
      ),
      drawer: _buildDrawer(),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _getContent(),
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: BoxDecoration(
              color: context.primaryColor,
            ),
            currentAccountPicture: const CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(
                Icons.gavel,
                color: Colors.blue,
                size: 40,
              ),
            ),
            accountName: const Text("Panel Administrativo"),
            accountEmail: const Text("Gestión de Inmuebles"),
          ),

          _drawerItem(
            Icons.assignment,
            "Solicitudes Pendientes",
            'contracts',
          ),

          _drawerItem(
            Icons.verified_user_rounded,
            "Contratos Formalizados",
            'final_contracts',
          ),

          _drawerItem(
            Icons.draw,
            "Pruebas Firma Digital",
            'viafirma_test',
          ),

          _drawerItem(
            Icons.home_work,
            "Inmuebles",
            'properties',
          ),

          _drawerItem(
            Icons.people,
            "Usuarios",
            'users',
          ),

          _drawerItem(
            Icons.calendar_month,
            "Agenda General",
            'appointments',
          ),

          _drawerItem(
            Icons.settings,
            "Configuración",
            'config',
          ),

          const Spacer(),
          const Divider(),

          ListTile(
            leading: const Icon(
              Icons.logout,
              color: Colors.red,
            ),
            title: Text(
              "Cerrar Sesión",
              style: TextStyle(
                color: Colors.red,
                fontSize: ResponsiveUtils.getFontSize(context, 14),
              ),
            ),
            onTap: () {
              context.read<NotificationBloc>().add(
                    const ClearUserToken(),
                  );
              context.read<AuthBloc>().add(
                    LogOutRequested(),
                  );
            },
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _drawerItem(
    IconData icon,
    String title,
    String view,
  ) {
    final bool isSelected = _currentView == view;

    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? Colors.blue[900] : Colors.grey,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          fontSize: ResponsiveUtils.getFontSize(context, 14),
        ),
      ),
      selected: isSelected,
      onTap: () {
        setState(() {
          _currentView = view;
        });

        Navigator.pop(context);
      },
    );
  }

  Widget _buildEmptyState(
    IconData icon,
    String message,
  ) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 80,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: ResponsiveUtils.getFontSize(context, 16),
            ),
          ),
        ],
      ),
    );
  }
}