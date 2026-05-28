class PaymentRecord {
  final String id;
  final String userId;
  final String propertyId;
  final double amount;
  final String status; // 'pending', 'success', 'failed'
  final String reference; // Referencia de la pasarela
  final DateTime date;

  PaymentRecord({
    required this.id,
    required this.userId,
    required this.propertyId,
    required this.amount,
    required this.status,
    required this.reference,
    required this.date,
  });

  Map<String, dynamic> toMap() => {
    'userId': userId,
    'propertyId': propertyId,
    'amount': amount,
    'status': status,
    'reference': reference,
    'date': date,
  };
}
