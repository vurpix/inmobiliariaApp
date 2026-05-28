// subscription_state.dart
import 'package:inmobiliariaapp/models/config/price_scale.dart'; // Importación obligatoria de tu modelo

abstract class SubscriptionState {}

class SubscriptionInitial extends SubscriptionState {}

class SubscriptionLoading extends SubscriptionState {}

class SubscriptionLoaded extends SubscriptionState {
  // CORREGIDO: Cambiamos 'currentCost' por la lista fuertemente tipada de tus escalas
  final List<PriceScale> priceScales;
  final bool isFreePeriod;
  final DateTime? freePeriodUntil;

  SubscriptionLoaded({
    required this.priceScales,
    required this.isFreePeriod,
    this.freePeriodUntil,
  });
}

class SubscriptionError extends SubscriptionState {
  final String message;
  SubscriptionError(this.message);
}
