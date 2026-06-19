import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:inmobiliariaapp/models/signature/signature_status_model.dart';

class SignatureService {
  final FirebaseFirestore _firestore;

  SignatureService({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  static const String refreshViafirmaStatusUrl =
      'https://us-central1-inmobiliariaarmandomarin.cloudfunctions.net/refreshViafirmaStatus';

  Stream<SignatureStatusModel?> watchContractSignature(String contractId) {
    return _firestore.collection('contracts').doc(contractId).snapshots().map(
      (snapshot) {
        if (!snapshot.exists || snapshot.data() == null) return null;

        return SignatureStatusModel.fromMap(
          contractId: contractId,
          data: snapshot.data()!,
        );
      },
    );
  }

  Future<Map<String, dynamic>> refreshViafirmaStatus({
    required String contractId,
  }) async {
    final uri = Uri.parse(refreshViafirmaStatusUrl).replace(
      queryParameters: {
        'contractId': contractId,
      },
    );

    final response = await http.get(uri);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Error actualizando estado Viafirma: ${response.statusCode} ${response.body}',
      );
    }

    return Map<String, dynamic>.from(jsonDecode(response.body));
  }
}