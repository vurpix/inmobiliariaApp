// lib/services/viafirma_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class ViafirmaService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// NUEVA ESTRATEGIA: En lugar de un http.post que genera error 404,
  /// insertamos o actualizamos el documento en la colección 'contracts'.
  ///
  /// Al guardar el campo 'baseContractPdfUrl', el Trigger del backend
  /// (onContractPdfReadyCreateSignature) se ejecutará automáticamente.
  Future<void> createSignatureRequest({
    required String contractId,
    required String propertyId,
    required String propertyAddress,
    required String pdfUrl,
    required Map<String, dynamic> tenant,
    required Map<String, dynamic> owner,
  }) async {
    try {
      // 1. Armamos el payload con la estructura exacta que espera recibir tu backend
      final Map<String, dynamic> contractData = {
        'id': contractId,
        'propertyId': propertyId,
        'propertyAddress': propertyAddress,
        'baseContractPdfUrl': pdfUrl, // 👈 Este campo es el "interruptor" que enciende el backend
        'tenant': tenant,
        'owner': owner,
        'ownerId': owner['uid'],      // 👈 Forzamos la copia en la raíz para blindar la lectura de Node.js
        'tenantId': tenant['uid'],    // 👈 Forzamos la copia en la raíz para blindar la lectura de Node.js
        'signatureStatus': 'pending', // Estado inicial informativo
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // 2. Guardamos en la colección usando merge: true para no borrar otros campos del contrato
      await _firestore
          .collection('contracts')
          .doc(contractId)
          .set(contractData, SetOptions(merge: true));

    } catch (e) {
      throw Exception('Fallo local al escribir la solicitud de firma en Firestore: $e');
    }
  }

  /// Consulta el estado actual de la firma leyendo el documento de auditoría
  /// que crea tu backend en la colección 'signatures'.
  Stream<DocumentSnapshot> watchSignatureStatus(String contractId) {
    // Es mucho más eficiente escuchar un Stream en tiempo real en lugar de hacer un http.get repetitivo
    return _firestore
        .collection('contracts')
        .doc(contractId)
        .snapshots();
  }
}