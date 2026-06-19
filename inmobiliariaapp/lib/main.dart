import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:inmobiliariaapp/bloc/notificationBloc/notification_bloc.dart';
import 'package:inmobiliariaapp/bloc/notificationBloc/notification_event.dart';
import 'package:inmobiliariaapp/bloc/notificationBloc/notification_state.dart';
import 'package:inmobiliariaapp/bloc/signatureBloc/signature_bloc_bloc.dart';

// Repositorios
import 'package:inmobiliariaapp/services/auth_repository.dart';
import 'package:inmobiliariaapp/services/property_repository.dart';

// Blocs
import 'package:inmobiliariaapp/bloc/authBloc/auth_bloc.dart';
import 'package:inmobiliariaapp/bloc/authBloc/auth_event.dart';
import 'package:inmobiliariaapp/bloc/authBloc/auth_state.dart';
import 'package:inmobiliariaapp/bloc/contractBloc/contract_bloc.dart';
import 'package:inmobiliariaapp/bloc/favoritesBloc/favorites_bloc.dart';
import 'package:inmobiliariaapp/bloc/paymentBloc/payment_bloc.dart';
import 'package:inmobiliariaapp/bloc/propertyBloc/property_bloc.dart';
import 'package:inmobiliariaapp/bloc/scheduleBloc/schedule_bloc.dart';
import 'package:inmobiliariaapp/bloc/subscriptionBloc/subscription_bloc.dart';

// Pantallas
import 'package:inmobiliariaapp/ui/components/auth_ux/social_role_selection_screen.dart';
import 'package:inmobiliariaapp/ui/components/startup_video_gate.dart';
import 'package:inmobiliariaapp/ui/pages/home/home_screen.dart';
import 'package:inmobiliariaapp/ui/pages/login/login_screen.dart';
import 'package:inmobiliariaapp/ui/pages/splash/splash_screen.dart';

// Utils
import 'package:inmobiliariaapp/utils/themes.dart';
import 'package:intl/date_symbol_data_local.dart';

// --- CONFIGURACIÓN DE NOTIFICACIONES EN SEGUNDO PLANO ---
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Debe inicializarse Firebase dentro del handler de fondo
  await Firebase.initializeApp();
  debugPrint("Notificación recibida en background: ${message.messageId}");
}

class SimpleBlocObserver extends BlocObserver {
  @override
  void onChange(BlocBase bloc, Change change) {
    super.onChange(bloc, change);
    debugPrint('${bloc.runtimeType} $change');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown, // Opcional (si se gira 180° de cabeza)
  ]);
  // 1. Inicialización de Firebase y Formatos
  await initializeDateFormatting('es', null);
  await Firebase.initializeApp();

  // 2. Handler de mensajes en segundo plano
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // 3. Configuración de Canales Locales (Android)
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'high_importance_channel',
    'Notificaciones Importantes',
    description: 'Este canal se usa para avisos de contratos.',
    importance: Importance.max,
  );

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Inicialización de settings del plugin local
  await flutterLocalNotificationsPlugin.initialize(
    // AÑADE ESTA LÍNEA:
    settings: const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    ),
    // Opcional: Manejadores de respuesta al tocar la notificación
    onDidReceiveNotificationResponse: (details) {
      debugPrint("Notificación tocada: ${details.payload}");
    },
  );
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(channel);

  // 4. Solicitar permisos de sistema (Android 13+ y iOS)
  await FirebaseMessaging.instance.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  Bloc.observer = SimpleBlocObserver();

  final authRepository = AuthRepository();
  final propertyRepository = PropertyRepository();

  runApp(
    MyApp(
      authRepository: authRepository,
      propertyRepository: propertyRepository,
      channel: channel,
    ),
  );
}

class MyApp extends StatefulWidget {
  final AuthRepository authRepository;
  final PropertyRepository propertyRepository;
  final AndroidNotificationChannel channel;

  const MyApp({
    super.key,
    required this.authRepository,
    required this.propertyRepository,
    required this.channel,
  });

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    _setupForegroundNotifications();
  }

  // --- ESCUCHAR NOTIFICACIONES CON LA APP ABIERTA ---
  void _setupForegroundNotifications() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      RemoteNotification? notification = message.notification;
      AndroidNotification? android = message.notification?.android;

      if (notification != null && android != null) {
        FlutterLocalNotificationsPlugin().show(
          // 1. Añadimos el nombre de los parámetros
          id: notification.hashCode,
          title: notification.title,
          body: notification.body,
          notificationDetails: NotificationDetails(
            android: AndroidNotificationDetails(
              widget.channel.id,
              widget.channel.name,
              channelDescription: widget.channel.description,
              // Asegúrate de que el icono sea el correcto
              icon: android.smallIcon ?? '@mipmap/ic_launcher',
            ),
          ),
          // Puedes pasar data extra aquí si la necesitas para navegar
          payload: message.data['propertyId'],
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) =>
              AuthBloc(authRepository: widget.authRepository)
                ..add(AppStarted()),
        ),
        BlocProvider(
          create: (context) => PropertyBloc(widget.propertyRepository),
        ),
        BlocProvider(
          create: (context) => PaymentBloc(widget.propertyRepository),
        ),
        BlocProvider(create: (context) => ContractBloc()),
        BlocProvider(create: (context) => ScheduleBloc()),
        BlocProvider(create: (context) => SignatureBloc()),
        BlocProvider(create: (context) => FavoritesBloc()),
        BlocProvider(create: (context) => SubscriptionBloc()),
        BlocProvider(create: (context) => NotificationBloc()),
      ],
      child: MaterialApp(
        title: 'Inmobiliaria App',
        debugShowCheckedModeBanner: false,
        theme: AppThemes.lightTheme,
        darkTheme: AppThemes.darkTheme,
        themeMode: ThemeMode.system,

        home: StartupVideoGate(
          child: MultiBlocListener(
            listeners: [
              BlocListener<AuthBloc, AuthState>(
                listener: (context, state) {
                  if (state is Authenticated) {
                    context.read<NotificationBloc>().add(
                      UpdateUserToken(
                        userId: state.user.id,
                        role: state.user.role.name,
                      ),
                    );
                  }
                },
              ),
              BlocListener<NotificationBloc, NotificationState>(
                listener: (context, state) {
                  if (state is NotificationReceived) {
                    debugPrint(
                      "Notificación recibida en el Listener: ${state.message.notification?.title}",
                    );
                  }
                },
              ),
            ],
            child: BlocBuilder<AuthBloc, AuthState>(
              builder: (context, state) {
                if (state is Unauthenticated ||
                    state is AuthFailure ||
                    state is AuthNavigatingToLogin) {
                  return const LoginScreen();
                }

                if (state is AuthSocialFirstTime) {
                  return SocialRoleSelectionScreen(
                    tempUid: state.uid,
                    email: state.email,
                    name: state.name,
                    photoUrl: state.photoUrl,
                  );
                }

                if (state is Authenticated) {
                  return const HomeScreen();
                }

                return const SplashScreen();
              },
            ),
          ),
        ),
      ),
    );
  }
}
