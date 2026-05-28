// lib/ui/components/global/notification_badge.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inmobiliariaapp/bloc/authBloc/auth_bloc.dart'; // Asegúrate de importar tu AuthBloc
import 'package:inmobiliariaapp/bloc/authBloc/auth_state.dart';
import 'package:inmobiliariaapp/ui/pages/notifications/notifications_screen.dart';

class NotificationBadge extends StatelessWidget {
  final Color? iconColor;
  final double iconSize;

  // MODIFICADO: Ya no pide el userId en el constructor
  const NotificationBadge({super.key, this.iconColor, this.iconSize = 26.0});

  @override
  Widget build(BuildContext context) {
    // Escuchamos el estado de autenticación directamente aquí
    final authState = context.watch<AuthBloc>().state;

    // Si el usuario no está logueado, no intentamos leer Firestore para evitar errores catastróficos
    if (authState is! Authenticated) {
      return IconButton(
        icon: Icon(
          Icons.notifications_outlined,
          color: Colors.grey,
          size: iconSize,
        ),
        onPressed: null, // Deshabilitado si no hay sesión
      );
    }

    final userId = authState.user.id;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .where('isRead', isEqualTo: false)
          .snapshots(),
      builder: (context, snapshot) {
        int unreadCount = 0;

        if (snapshot.hasData && snapshot.data != null) {
          unreadCount = snapshot.data!.docs.length;
        }

        return Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            IconButton(
              icon: Icon(
                unreadCount > 0
                    ? Icons.notifications_active_outlined
                    : Icons.notifications_outlined,
                color: iconColor ?? Colors.black87,
                size: iconSize,
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        const NotificationsScreen(), // Tampoco requiere parámetro
                  ),
                );
              },
            ),
            if (unreadCount > 0)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 18,
                    minHeight: 18,
                  ),
                  child: Center(
                    child: Text(
                      unreadCount > 9 ? '9+' : '$unreadCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
