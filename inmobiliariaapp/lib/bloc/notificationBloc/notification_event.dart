import 'package:firebase_messaging/firebase_messaging.dart';

sealed class NotificationEvent {
  const NotificationEvent();
}

// 1. Para pedir permisos e inicializar los listeners (se llama al abrir la app en el main)
class InitializeNotifications extends NotificationEvent {}

// 2. MODIFICADO: Agregamos el rol para saber si debemos suscribirlo o no al Topic masivo
class UpdateUserToken extends NotificationEvent {
  final String userId;
  final String role; // <--- 'tenant', 'admin', 'owner'

  const UpdateUserToken({required this.userId, required this.role});
}

// 3. Evento interno que se dispara cuando llega una notificación en primer plano (Foreground)
class OnNotificationReceived extends NotificationEvent {
  final RemoteMessage message;

  const OnNotificationReceived(this.message);
}

// 4. CORREGIDO: Evento para desuscribir del Topic y limpiar estados al cerrar sesión (Logout)
// No requiere userId porque la desuscripción al canal de Google se hace sobre el dispositivo físico.
class ClearUserToken extends NotificationEvent {
  const ClearUserToken();
}
