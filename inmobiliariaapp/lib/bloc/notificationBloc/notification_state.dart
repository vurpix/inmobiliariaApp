import 'package:firebase_messaging/firebase_messaging.dart';

sealed class NotificationState {
  final String? fcmToken;
  final bool hasPermissions;

  const NotificationState({this.fcmToken, this.hasPermissions = false});
}

// Estado inicial antes de hacer nada
final class NotificationInitial extends NotificationState {
  const NotificationInitial() : super(fcmToken: null, hasPermissions: false);
}

// Mientras se procesa la solicitud de permisos o el guardado del token
final class NotificationLoading extends NotificationState {
  const NotificationLoading() : super(fcmToken: null, hasPermissions: false);
}

// El sistema está listo para recibir notificaciones
final class NotificationReady extends NotificationState {
  const NotificationReady({required String token, required bool permissions})
    : super(fcmToken: token, hasPermissions: permissions);
}

// Estado temporal para avisar a la UI que acaba de llegar un mensaje
final class NotificationReceived extends NotificationState {
  final RemoteMessage message;

  const NotificationReceived({
    required this.message,
    String? token,
    bool permissions = true,
  }) : super(fcmToken: token, hasPermissions: permissions);
}

// Si algo falla (ej. el usuario deniega los permisos permanentemente)
final class NotificationError extends NotificationState {
  final String message;

  const NotificationError({
    required this.message,
    String? token,
    bool permissions = false,
  }) : super(fcmToken: token, hasPermissions: permissions);
}
