// EVENTOS
abstract class PaymentEvent {
  const PaymentEvent(); // Agrega esto
}

class ProcessRegistrationPayment extends PaymentEvent {
  final Map<String, dynamic> propertyData;
  final String userId;

  // Al poner las llaves {}, permites el uso de propertyData: y userId:
  ProcessRegistrationPayment({
    required this.propertyData,
    required this.userId,
  });
}
class UpdatePropertyPaymentOnly extends PaymentEvent {
  final String propertyId;
  final String screenshotPath;

  const UpdatePropertyPaymentOnly({
    required this.propertyId,
    required this.screenshotPath,
  });
}
