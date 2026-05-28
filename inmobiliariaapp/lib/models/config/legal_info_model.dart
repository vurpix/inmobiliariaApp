import 'package:cloud_firestore/cloud_firestore.dart';

class LegalInfoModel {
  final String contractModelUrl;
  final String privacyPolicyUrl;
  final String termsConditionsUrl;

  LegalInfoModel({
    required this.contractModelUrl,
    required this.privacyPolicyUrl,
    required this.termsConditionsUrl,
  });

  factory LegalInfoModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return LegalInfoModel(
      contractModelUrl: data['contractModelUrl'] ?? '',
      privacyPolicyUrl: data['privacyPolicyUrl'] ?? '',
      termsConditionsUrl: data['termsConditionsUrl'] ?? '',
    );
  }
}
