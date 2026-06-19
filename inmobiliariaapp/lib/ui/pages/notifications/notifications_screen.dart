// lib/ui/pages/notifications/notifications_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inmobiliariaapp/bloc/authBloc/auth_bloc.dart';
import 'package:inmobiliariaapp/bloc/authBloc/auth_state.dart';
import 'package:inmobiliariaapp/models/notification_model.dart';
import 'package:intl/intl.dart';
import 'package:inmobiliariaapp/utils/themes.dart';
import 'package:inmobiliariaapp/ui/components/global/custom_button.dart';
import 'package:inmobiliariaapp/ui/components/global/custom_text.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  // 1. CONFIGURACIÓN DE PAGINACIÓN INTERNA
  int _currentLimit = 8;
  final int _pagingStep =
      8; // Cuántas notificaciones extra se cargarán por click

  Future<void> _markAsRead(String userId, String notificationId) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .doc(notificationId)
        .update({'isRead': true});
  }

  Future<void> _deleteNotification(String userId, String notificationId) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .doc(notificationId)
        .delete();
  }

  // Método helper para aumentar el límite de la consulta
  void _loadMoreNotifications() {
    setState(() {
      _currentLimit += _pagingStep;
    });
  }

  @override
  Widget build(BuildContext context) {
    // EXTRAER EL ESTADO DE AUTENTICACIÓN
    final authState = context.read<AuthBloc>().state;

    if (authState is! Authenticated) {
      return const Scaffold(
        body: Center(
          child: CustomText(
            'Inicia sesión para visualizar tu historial de alertas.',
            baseFontSize: 14,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final userId = authState.user.id;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const CustomText(
          'Centro de Notificaciones',
          baseFontSize: 16,
          fontWeight: FontWeight.bold,
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: StreamBuilder<QuerySnapshot>(
        // 2. CONSULTA DINÁMICA CON LÍMITE CONTROLADO POR EL ESTADO
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('notifications')
            .orderBy('createdAt', descending: true)
            .limit(
              _currentLimit,
            ) // <-- Aquí reducimos la carga de la base de datos
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: CustomText(
                'Error al cargar notificaciones: ${snapshot.error}',
                baseFontSize: 14,
                color: context.errorColor,
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.notifications_off_outlined,
                      size: ResponsiveUtils.getWidth(context, 20),
                      color: Colors.grey[300],
                    ),
                    const SizedBox(height: 16),
                    const CustomText(
                      'Tu bandeja está limpia',
                      baseFontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    const SizedBox(height: 8),
                    CustomText(
                      'Aquí verás los avisos de tus contratos e inmuebles.',
                      baseFontSize: 13,
                      color: Colors.grey[400]!,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          final docs = snapshot.data!.docs;
          final notifications = docs
              .map((doc) => NotificationModel.fromFirestore(doc))
              .toList();

          // 3. SE DETERMINA SI QUEDAN MÁS DOCUMENTOS EN FIREBASE
          // Si el número de documentos actuales es igual al límite establecido,
          // asumimos que potencialmente hay más datos por leer en la colección.
          final bool hasMoreAvailable = docs.length == _currentLimit;

          return ListView.builder(
            // Sumamos 1 al conteo para renderizar el botón de "Cargar más" al final
            itemCount: hasMoreAvailable
                ? notifications.length + 1
                : notifications.length,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            itemBuilder: (context, index) {
              // 4. SI LLEGAMOS AL ELEMENTO EXTRA, RENDERIZAMOS EL BOTÓN DE CARGA
              if (index == notifications.length) {
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: CustomButton(
                    height: ResponsiveUtils.getHeight(context, 5.0),
                    backgroundColor: Colors.transparent,
                    borderSide: BorderSide(
                      color: context.primaryColor,
                      width: 1.2,
                    ),
                    borderRadius: 10,
                    onPressed: _loadMoreNotifications,
                    childText: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.arrow_downward_rounded,
                          size: 16,
                          color: context.primaryColor,
                        ),
                        const SizedBox(width: 8),
                        CustomText(
                          "Cargar más notificaciones",
                          baseFontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: context.primaryColor,
                        ),
                      ],
                    ),
                  ),
                );
              }

              final notification = notifications[index];

              return Dismissible(
                key: Key(notification.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: context.errorColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  child: const Icon(
                    Icons.delete_forever_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
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
                        : context.primaryColor.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: notification.isRead
                          ? Colors.grey.shade100
                          : context.primaryColor.withOpacity(0.12),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.01),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    leading: CircleAvatar(
                      radius: 20,
                      backgroundColor: _getIconBackgroundColor(
                        context,
                        notification.type,
                      ),
                      child: Icon(
                        _getIconType(notification.type),
                        color: _getIconColor(context, notification.type),
                        size: 20,
                      ),
                    ),
                    title: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: CustomText(
                            notification.title,
                            baseFontSize: 14,
                            fontWeight: notification.isRead
                                ? FontWeight.w600
                                : FontWeight.bold,
                          ),
                        ),
                        if (!notification.isRead)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: context.primaryColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        CustomText(
                          notification.body,
                          baseFontSize: 12,
                          color: Colors.grey[600]!,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        CustomText(
                          DateFormat(
                            'dd MMM yyyy • hh:mm a',
                          ).format(notification.createdAt),
                          baseFontSize: 10,
                          color: Colors.grey[400]!,
                        ),
                      ],
                    ),
                    onTap: () {
                      if (!notification.isRead) {
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

  Color _getIconColor(BuildContext context, String type) {
    if (type == 'property_created') return context.successColor;
    if (type == 'contract_active') return Colors.orange[800]!;
    return context.primaryColor;
  }

  Color _getIconBackgroundColor(BuildContext context, String type) {
    if (type == 'property_created')
      return context.successColor.withOpacity(0.08);
    if (type == 'contract_active') return Colors.orange[50]!;
    return context.primaryColor.withOpacity(0.08);
  }
}
