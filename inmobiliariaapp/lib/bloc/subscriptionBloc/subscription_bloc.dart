import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inmobiliariaapp/bloc/subscriptionBloc/subscription_event.dart';
import 'package:inmobiliariaapp/bloc/subscriptionBloc/subscription_state.dart';
import 'package:inmobiliariaapp/models/config/price_scale.dart'; // Tu modelo PriceScale

class SubscriptionBloc extends Bloc<SubscriptionEvent, SubscriptionState> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  SubscriptionBloc() : super(SubscriptionInitial()) {
    on<CalculateStudyCost>(_onCalculateCost);
  }

  Future<void> _onCalculateCost(
    CalculateStudyCost event,
    Emitter<SubscriptionState> emit,
  ) async {
    emit(SubscriptionLoading());
    try {
      // 1. CORREGIDO: Apuntar exactamente a la colección 'subscriptions' y documento 'config'
      final subDoc = await _firestore
          .collection('subscriptions')
          .doc('config')
          .get();

      if (!subDoc.exists) {
        emit(
          SubscriptionError(
            "El documento de configuración no existe en Firestore.",
          ),
        );
        return;
      }

      final data = subDoc.data() ?? {};

      // 2. Extraer y mapear la lista interna usando el factory de tu modelo PriceScale
      final List<dynamic> rawScales =
          data['priceScales'] as List<dynamic>? ?? [];
      final List<PriceScale> scalesList = rawScales
          .map((item) => PriceScale.fromMap(item as Map<String, dynamic>))
          .toList();

      // 3. Extraer los días libres de cortesía desde el documento mapeado de forma segura
      int freeDays = (data['freeDays'] as num?)?.toInt() ?? 0;

      final DateTime freeUntil = event.userCreatedAt.add(
        Duration(days: freeDays),
      );
      final bool isFree = DateTime.now().isBefore(freeUntil);

      // 4. Emitir el estado pasándole la lista completa de objetos PriceScale
      emit(
        SubscriptionLoaded(
          priceScales:
              scalesList, // Aquí viaja toda la lista de rangos [min, max, price]
          isFreePeriod: isFree,
          freePeriodUntil: freeUntil,
        ),
      );
    } catch (e) {
      emit(SubscriptionError("Error al cargar la lista de honorarios: $e"));
    }
  }
}
