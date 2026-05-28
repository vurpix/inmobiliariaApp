import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inmobiliariaapp/main.dart';
import 'package:inmobiliariaapp/services/auth_repository.dart';
import 'package:inmobiliariaapp/services/property_repository.dart';

void main() {
  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    // 1. Creamos una instancia del repositorio para el test
    final authRepository = AuthRepository();
    final propertyRepository = PropertyRepository();
    // 2. Pasamos el repositorio a MyApp
    await tester.pumpWidget(
      MyApp(
        authRepository: authRepository,
        propertyRepository: propertyRepository,
        channel: AndroidNotificationChannel(
          'high_importance_channel',
          'Notificaciones Importantes',
        ),
      ),
    );

    // El resto del test probablemente falle si quitaste el contador
    // de la plantilla inicial de Flutter, pero así se quita el error de compilación.
    expect(find.text('0'), findsOneWidget);
  });
}
