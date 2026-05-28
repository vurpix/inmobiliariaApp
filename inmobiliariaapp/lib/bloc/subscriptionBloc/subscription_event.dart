// Eventos
abstract class SubscriptionEvent {}
class CalculateStudyCost extends SubscriptionEvent {
  final DateTime userCreatedAt;
  CalculateStudyCost(this.userCreatedAt);
}