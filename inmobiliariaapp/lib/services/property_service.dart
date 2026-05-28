import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/property_model.dart';
import '../enum/property_status.dart'; // Asegúrate de que apunte a tus enums

class PropertyService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String _collection = 'properties';

  // --- 1. SECCIÓN DE STREAMS (LECTURA REACTIVA) ---

  // Obtener propiedades de un Propietario específico (Landlord Dashboard)
  Stream<List<PropertyModel>> watchPropertiesByOwner(String ownerId) {
    return _db
        .collection(_collection)
        .where('ownerId', isEqualTo: ownerId)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => PropertyModel.fromSnapshot(doc))
              .toList(),
        );
  }

  // Obtener TODAS las propiedades (Admin Panel)
  Stream<List<PropertyModel>> watchAllProperties() {
    return _db
        .collection(_collection)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => PropertyModel.fromSnapshot(doc))
              .toList(),
        );
  }

  // Obtener propiedades activas (Para el Inquilino/Buscador)
  Stream<List<PropertyModel>> watchActiveProperties() {
    return _db
        .collection(_collection)
        .where('status', isEqualTo: 'active')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => PropertyModel.fromSnapshot(doc))
              .toList(),
        );
  }

  // Escuchar un solo documento de propiedad
  Stream<PropertyModel?> watchPropertyById(String propertyId) {
    return _db.collection(_collection).doc(propertyId).snapshots().map((doc) {
      if (doc.exists) return PropertyModel.fromSnapshot(doc);
      return null;
    });
  }

  // --- 2. SECCIÓN DE ACCIONES (ESCRITURA) ---

  // Guardar o Editar Propiedad
  Future<void> saveProperty(PropertyModel property) async {
    if (property.id == null || property.id!.isEmpty) {
      // Nueva
      await _db.collection(_collection).add(property.toMap());
    } else {
      // Edición
      await _db
          .collection(_collection)
          .doc(property.id)
          .set(property.toMap(), SetOptions(merge: true));
    }
  }

  // Actualizar estado (Usado por Admin para aprobar/rechazar)
  Future<void> updateStatus({
    required String propertyId,
    required PropertyStatusEnum newStatus,
    String? paymentStatus,
  }) async {
    final Map<String, dynamic> updateData = {
      'status': newStatus.name, // o .value según tu implementación
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (paymentStatus != null) updateData['paymentStatus'] = paymentStatus;

    await _db.collection(_collection).doc(propertyId).update(updateData);

  }

  // Actualizar PDF del contrato legal (Subido por abogado/admin)
  Future<void> updateLegalContractPdf(
    String propertyId,
    String downloadUrl,
  ) async {
    await _db.collection(_collection).doc(propertyId).update({
      'legalContractPdfUrl': downloadUrl,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Registrar pago de activación (Subido por Propietario)
  Future<void> registerPaymentReceipt({
    required String propertyId,
    required String receiptUrl,
  }) async {
    await _db.collection(_collection).doc(propertyId).update({
      'paymentReceiptUrl': receiptUrl,
      'status': 'paid_pending_review',
      'paymentStatus': 'pending_verify',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
