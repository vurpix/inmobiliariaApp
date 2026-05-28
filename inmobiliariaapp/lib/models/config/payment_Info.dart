// 2. Información de Pagos (Nequi, QR)
import 'package:cloud_firestore/cloud_firestore.dart';

class PaymentInfo {
  final String digitalKey;
  final String nequiPhone;
  final String qrImageUrl;

  PaymentInfo({
    required this.digitalKey,
    required this.nequiPhone,
    required this.qrImageUrl,
  });

  factory PaymentInfo.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return PaymentInfo(
      digitalKey: data['digitalKey'] ?? '',
      nequiPhone: data['nequiPhone'] ?? '',
      qrImageUrl: data['qrImageUrl'] ?? '',
    );
  }
}