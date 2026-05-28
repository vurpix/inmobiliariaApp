import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inmobiliariaapp/bloc/notificationBloc/notification_event.dart';
import 'package:inmobiliariaapp/bloc/notificationBloc/notification_state.dart';
import 'package:inmobiliariaapp/enum/user_role.dart';
import 'package:inmobiliariaapp/services/user_service.dart';

class NotificationBloc extends Bloc<NotificationEvent, NotificationState> {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final UserService _userService = UserService();

  NotificationBloc() : super(const NotificationInitial()) {
    // 1. INICIALIZAR PERMISOS Y LISTENERS BÁSICOS
    on<InitializeNotifications>((event, emit) async {
      emit(const NotificationLoading());

      NotificationSettings settings = await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      final isAuthorized =
          settings.authorizationStatus == AuthorizationStatus.authorized;

      // Escuchar mensajes en primer plano (Foreground)
      FirebaseMessaging.onMessage.listen((message) {
        add(OnNotificationReceived(message));
      });

      // Escuchar si el token cambia automáticamente de fondo en el dispositivo
      _fcm.onTokenRefresh.listen((newToken) {
        // Nota: Si mantienes guardado el userId de alguna forma o necesitas re-vincularlo,
        // puedes disparar un evento interno aquí.
      });

      emit(
        NotificationReady(
          token: await _fcm.getToken() ?? '',
          permissions: isAuthorized,
        ),
      );
    });

    // 2. ACTUALIZAR TOKEN Y GESTIONAR SUSCRIPCIÓN POR ROL
    on<UpdateUserToken>((event, emit) async {
      try {
        String? token = await _fcm.getToken();
        if (token != null) {
          // Guardamos el token en Firestore mediante el servicio existente
          await _userService.updateFcmToken(event.userId, token);

          // === LÓGICA DE TOPIC INTEGRADA ===
          if (event.role == UserRole.tenant.name) {
            // Si es inquilino, se suscribe al canal masivo de nuevos inmuebles
            await _fcm.subscribeToTopic('nuevos_inmuebles');
          } else {
            // Si entra como admin o propietario, lo desuscribimos por seguridad
            await _fcm.unsubscribeFromTopic('nuevos_inmuebles');
          }

          emit(
            NotificationReady(token: token, permissions: state.hasPermissions),
          );
        }
      } catch (e) {
        emit(NotificationError(message: e.toString()));
      }
    });

    // 3. NUEVO: MANEJAR EL LOGOUT (CIERRE DE SESIÓN)
    on<ClearUserToken>((event, emit) async {
      try {
        // Al cerrar sesión quitamos obligatoriamente la suscripción del teléfono
        await _fcm.unsubscribeFromTopic('nuevos_inmuebles');

        emit(
          NotificationReady(
            token: state.fcmToken!,
            permissions: state.hasPermissions,
          ),
        );
      } catch (e) {
        emit(NotificationError(message: e.toString()));
      }
    });

    // 4. RECEPCIÓN DE NOTIFICACIÓN EN PRIMER PLANO
    on<OnNotificationReceived>((event, emit) {
      emit(
        NotificationReceived(
          message: event.message,
          token: state.fcmToken,
          permissions: state.hasPermissions,
        ),
      );
    });
  }
}
