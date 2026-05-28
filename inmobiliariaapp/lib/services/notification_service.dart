import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:developer';

import 'package:inmobiliariaapp/services/user_service.dart';

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final UserService _userService = UserService();

  static Future<void> updateTokenInFirestore(String userId) async {
    try {
      // 1. Solicitar permisos (Android 13+ y iOS)
      NotificationSettings settings = await _messaging.requestPermission();

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        // 2. Obtener el token único del dispositivo
        String? token = await _messaging.getToken();

        if (token != null) {
          // 3. Guardarlo en el documento del usuario
          await _userService.updateFcmToken(userId, token);
          log("FCM Token actualizado para el usuario: $userId");
        }
      }
    } catch (e) {
      log("Error al configurar FCM Token: $e");
    }
  }
}
