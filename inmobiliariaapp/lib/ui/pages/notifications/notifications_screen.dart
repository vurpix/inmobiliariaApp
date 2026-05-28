// lib/ui/pages/notifications/notifications_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inmobiliariaapp/bloc/authBloc/auth_bloc.dart'; // Importación de tu bloque de autenticación
import 'package:inmobiliariaapp/bloc/authBloc/auth_state.dart';
import 'package:inmobiliariaapp/models/notification_model.dart';
import 'package:intl/intl.dart';

class NotificationsScreen extends StatelessWidget {
  // MODIFICADO: Ya no requiere recibir la propiedad ni guardarla de manera rígida
  const NotificationsScreen({super.key});

  // Método para marcar la notificación como leída en Firestore
  Future<void> _markAsRead(String userId, String notificationId) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .doc(notificationId)
        .update({'isRead': true});
  }

  // Método para eliminar una notificación individual (Deslizar para borrar)
  Future<void> _deleteNotification(String userId, String notificationId) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .doc(notificationId)
        .delete();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;

    // 1. EXTRAER EL ESTADO DE AUTENTICACIÓN
    final authState = context.read<AuthBloc>().state;

    // Control de flujo por si acaso la vista se monta sin credenciales válidas
    if (authState is! Authenticated) {
      return const Scaffold(
        body: Center(
          child: Text('Inicia sesión para visualizar tu historial de alertas.'),
        ),
      );
    }

    final userId = authState.user.id;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Centro de Notificaciones',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: StreamBuilder<QuerySnapshot>(
        // 2. CONEXIÓN EN TIEMPO REAL CON LA VARIABLE COMPARTIDA EN EL CONTEXTO
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('notifications')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text('Error al cargar notificaciones: ${snapshot.error}'),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_off_outlined,
                    size: 80,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Tu bandeja está limpia',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Aquí verás los avisos de tus contratos e inmuebles.',
                    style: TextStyle(fontSize: 14, color: Colors.grey[400]),
                  ),
                ],
              ),
            );
          }

          final notifications = snapshot.data!.docs
              .map((doc) => NotificationModel.fromFirestore(doc))
              .toList();

          return ListView.builder(
            itemCount: notifications.length,
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemBuilder: (context, index) {
              final notification = notifications[index];

              return Dismissible(
                key: Key(notification.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  color: Colors.red,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  child: const Icon(
                    Icons.delete_forever,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                // Ajustado: Pasamos el userId al método asíncrono
                onDismissed: (direction) =>
                    _deleteNotification(userId, notification.id),
                child: Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: notification.isRead
                        ? Colors.white
                        : Colors.blue[50]?.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.02),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    leading: CircleAvatar(
                      backgroundColor: _getIconBackgroundColor(
                        notification.type,
                        primaryColor,
                      ),
                      child: Icon(
                        _getIconType(notification.type),
                        color: _getIconColor(notification.type, primaryColor),
                      ),
                    ),
                    title: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: TextStyle(
                              fontWeight: notification.isRead
                                  ? FontWeight.w600
                                  : FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        if (!notification.isRead)
                          Container(
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(
                              color: Colors.blue,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 6),
                        Text(
                          notification.body,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 13,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          DateFormat(
                            'dd MMM yyyy • hh:mm a',
                          ).format(notification.createdAt),
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    onTap: () {
                      if (!notification.isRead) {
                        // Ajustado: Pasamos el userId al método asíncrono
                        _markAsRead(userId, notification.id);
                      }
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  IconData _getIconType(String type) {
    switch (type) {
      case 'property_created':
        return Icons.home_work_outlined;
      case 'contract_active':
        return Icons.gavel_rounded;
      case 'general':
      default:
        return Icons.notifications_none_outlined;
    }
  }

  Color _getIconColor(String type, Color primaryColor) {
    if (type == 'property_created') return Colors.green;
    if (type == 'contract_active') return Colors.orange;
    return primaryColor;
  }

  Color _getIconBackgroundColor(String type, Color primaryColor) {
    if (type == 'property_created') return Colors.green[50]!;
    if (type == 'contract_active') return Colors.orange[50]!;
    return primaryColor.withOpacity(0.1);
  }
}
