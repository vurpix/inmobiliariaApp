import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inmobiliariaapp/bloc/authBloc/auth_bloc.dart';
import 'package:inmobiliariaapp/bloc/authBloc/auth_event.dart';
import 'package:inmobiliariaapp/bloc/notificationBloc/notification_bloc.dart';
import 'package:inmobiliariaapp/bloc/notificationBloc/notification_event.dart';
import 'package:inmobiliariaapp/utils/themes.dart';

class AdminDrawer extends StatelessWidget {
  final Function(String) onDestinationSelected;

  const AdminDrawer({super.key, required this.onDestinationSelected});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: BoxDecoration(color: Colors.blue[900]),
            currentAccountPicture: const CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(Icons.gavel, color: Colors.blue, size: 40),
            ),
            accountName: Text(
              "Panel Administrativo",
              style: TextStyle(
                color: context.textColor,
                fontWeight: FontWeight.bold,
                fontSize: ResponsiveUtils.getFontSize(context, 15),
              ),
            ),
            accountEmail: Text(
              "Abogado / Administrador",
              style: TextStyle(
                color: context.textColor,
                fontWeight: FontWeight.bold,
                fontSize: ResponsiveUtils.getFontSize(context, 15),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.dashboard),
            title: Text(
              "Solicitudes y Contratos",
              style: TextStyle(
                color: context.textColor,
                fontWeight: FontWeight.bold,
                fontSize: ResponsiveUtils.getFontSize(context, 15),
              ),
            ),
            onTap: () => onDestinationSelected('contracts'),
          ),
          ListTile(
            leading: const Icon(Icons.home_work),
            title: Text(
              "Gestión de Inmuebles",
              style: TextStyle(
                color: context.textColor,
                fontWeight: FontWeight.bold,
                fontSize: ResponsiveUtils.getFontSize(context, 12),
              ),
            ),
            onTap: () => onDestinationSelected('properties'),
          ),
          ListTile(
            leading: const Icon(Icons.people),
            title: Text(
              "Usuarios Registrados",
              style: TextStyle(
                color: context.textColor,
                fontWeight: FontWeight.bold,
                fontSize: ResponsiveUtils.getFontSize(context, 12),
              ),
            ),
            onTap: () => onDestinationSelected('users'),
          ),
          ListTile(
            leading: const Icon(Icons.calendar_month),
            title: Text(
              "Citas Programadas",
              style: TextStyle(
                color: context.textColor,
                fontWeight: FontWeight.bold,
                fontSize: ResponsiveUtils.getFontSize(context, 12),
              ),
            ),
            onTap: () => onDestinationSelected('appointments'),
          ),
          const Spacer(),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text(
              "Cerrar Sesión",
              style: TextStyle(color: Colors.red),
            ),
            onTap: () {
              context.read<NotificationBloc>().add(const ClearUserToken());
              context.read<AuthBloc>().add(LogOutRequested());
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
