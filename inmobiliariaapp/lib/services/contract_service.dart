import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:inmobiliariaapp/enum/property_status.dart';
import 'package:inmobiliariaapp/models/candidate_model.dart';
import '../models/contract_model.dart';

class ContractService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String _collection = 'contracts';

  // --- 1. SECCIÓN DE LECTURA (STREAMS Y FUTURES) ---

  // Escucha todos los contratos ordenados por fecha
  Stream<List<ContractModel>> watchAllContracts() {
    return _db
        .collection(_collection)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ContractModel.fromSnapshot(doc))
              .toList(),
        );
  }

  // Escucha el contrato de una propiedad específica (Stream reactivo)
  Stream<ContractModel?> watchContractByProperty(String propertyId) {
    return _db
        .collection(_collection)
        .where('propertyId', isEqualTo: propertyId)
        .snapshots()
        .map((snapshot) {
          if (snapshot.docs.isNotEmpty) {
            return ContractModel.fromSnapshot(snapshot.docs.first);
          }
          return null;
        });
  }

  // Carga inicial de datos de contrato
  Future<ContractModel?> getContractData(String propertyId) async {
    final query = await _db
        .collection(_collection)
        .where('propertyId', isEqualTo: propertyId)
        .limit(1)
        .get();

    if (query.docs.isNotEmpty) {
      return ContractModel.fromSnapshot(query.docs.first);
    }
    return null;
  }

  // --- 2. SECCIÓN DE ESCRITURA Y ACTUALIZACIÓN ---

  // NUEVO: Método para inicializar el contrato cuando el abogado sube el borrador
  // Maneja la creación si no existe o actualización si ya existe.
  Future<void> saveInitialContract(ContractModel contract) async {
    await _db
        .collection(_collection)
        .doc(contract.id)
        .set(contract.toMap(), SetOptions(merge: true));
  }

  // Finaliza el proceso de carga de documentos del inquilino
  Future<void> finalizeContractDocuments({
    required String contractId,
    required String idDocumentUrl,
    required String paymentReceiptUrl,
  }) async {
    await _db.collection(_collection).doc(contractId).update({
      'idDocumentUrl': idDocumentUrl,
      'studyPaymentUrl': paymentReceiptUrl,
      'status': 'waitingAdminReview',
      'paymentDate': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<ContractModel?> getContractByProperty(String propertyId) async {
    try {
      final querySnapshot = await _db
          .collection(
            'contracts',
          ) // Asegúrate de que el nombre sea igual a tu colección
          .where('propertyId', isEqualTo: propertyId)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        return ContractModel.fromSnapshot(querySnapshot.docs.first);
      }
      return null;
    } catch (e) {
      print("Error obteniendo contrato: $e");
      return null;
    }
  }

  // Actualizar solo el estado
  Future<void> updateContractStatus(String contractId, String newStatus) async {
    await _db.collection(_collection).doc(contractId).update({
      'status': newStatus,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Aprobación de candidato: Vincula al inquilino con el contrato
  Future<void> approveCandidateProcess({
    required String propertyId,
    required String candidateUid,
    required String candidateName,
    required String applicationDocId,
    required List<CandidateModel> updatedCandidates,
  }) async {
    // 1. BUSCAR AL GANADOR
    CandidateModel? winner;
    try {
      winner = updatedCandidates.firstWhere(
        (c) => c.uid == candidateUid && c.status == 'approved',
      );
    } catch (_) {
      winner = null;
    }

    // 2. SI NO HAY GANADOR, SOLO GUARDAMOS LOS CAMBIOS DE LA LISTA (RECHAZOS MANUALES)
    if (winner == null) {
      await _db.collection('applications').doc(applicationDocId).update({
        'candidates': updatedCandidates.map((c) => c.toMap()).toList(),
        'lastUpdate': FieldValue.serverTimestamp(),
      });
      return;
    }

    // --- LÓGICA DE AUTO-RECHAZO ---
    final List<CandidateModel> finalCandidatesList = updatedCandidates.map((c) {
      if (c.uid == winner!.uid) {
        return c;
      } else {
        return c.copyWith(status: 'rejected');
      }
    }).toList();

    // 4. PROCEDEMOS CON EL BATCH ATÓMICO
    WriteBatch batch = _db.batch();

    // Actualizar Aplicaciones
    DocumentReference appRef = _db
        .collection('applications')
        .doc(applicationDocId);
    batch.update(appRef, {
      'candidates': finalCandidatesList.map((c) => c.toMap()).toList(),
      'lastUpdate': FieldValue.serverTimestamp(),
    });

    // 5. GESTIÓN DEL CONTRATO (BUSCAR O CREAR)
    final contractQuery = await _db
        .collection('contracts')
        .where('propertyId', isEqualTo: propertyId)
        .where(
          'status',
          whereIn: [
            'searching_candidates',
            'waiting_contract',
            'signature_rejected',
          ],
        )
        .limit(1)
        .get();

    if (contractQuery.docs.isNotEmpty) {
      // --- ACTUALIZAR CONTRATO EXISTENTE ---
      DocumentReference contractRef = contractQuery.docs.first.reference;
      batch.update(contractRef, {
        'tenant': winner.toMap(),
        'status': PropertyStatusEnum.approvedPendingPayment.name, // Esperando que el abogado suba el PDF
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else {
      // --- CREAR CONTRATO NUEVO ---
      // Obtenemos datos de la propiedad para que el contrato no nazca vacío
      final propertySnap = await _db
          .collection('properties')
          .doc(propertyId)
          .get();

      if (propertySnap.exists) {
        final propData = propertySnap.data()!;
        DocumentReference newContractRef = _db.collection('contracts').doc();

        batch.set(newContractRef, {
          'id': newContractRef.id,
          'propertyId': propertyId,
          'ownerId': propData['ownerId'] ?? '',
          'address': propData['address'] ?? '',
          'canonAmount': propData['canon'] ?? 0.0,
          'duration':
              "${propData['durationValue']} ${propData['durationUnit']}",
          'tenant': winner.toMap(),
          'ownerSignedPdfUrl': null,
          'rejectionReason': null,
          'tenantSignedPdfUrl': null, 
          'status': PropertyStatusEnum.approvedPendingPayment.name,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'baseContractPdfUrl': null, // Lo subirá el abogado después
        });
      }
    }

    // 6. ACTUALIZAR ESTADO DE LA PROPIEDAD
    // La propiedad pasa a un estado donde el admin sabe que debe subir el PDF
    DocumentReference propRef = _db.collection('properties').doc(propertyId);
    batch.update(propRef, {
      'status': PropertyStatusEnum.approvedPendingPayment.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // 7. EJECUTAR BATCH
    await batch.commit();

    print("✅ Proceso completado: Inquilino vinculado y contrato preparado.");
  }

  // Sube el contrato firmado por el inquilino y actualiza la propiedad
  Future<void> submitSignedContract({
    required String contractId,
    required String propertyId,
    required String downloadUrl,
  }) async {
    WriteBatch batch = _db.batch();

    // 1. Actualizar el contrato
    DocumentReference contractRef = _db.collection(_collection).doc(contractId);
    batch.update(contractRef, {
      'signedContractPdfUrl': downloadUrl,
      'status': 'signedPendingReview',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // 2. Actualizar la propiedad
    DocumentReference propertyRef = _db
        .collection('properties')
        .doc(propertyId);
    batch.update(propertyRef, {
      'status': 'signedPendingReview',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  // --- 3. SECCIÓN DINÁMICA Y UTILIDADES ---

  // Actualizar cualquier campo flexible
  Future<void> updateFields(
    String contractId,
    Map<String, dynamic> data,
  ) async {
    // 1. Obtenemos la referencia del contrato
    DocumentReference contractRef = _db.collection(_collection).doc(contractId);

    // 2. Si el estado que estamos enviando es 'active', debemos desactivar la propiedad
    if (data['status'] == 'active') {
      WriteBatch batch = _db.batch();

      // Obtenemos el documento del contrato para sacar el propertyId
      DocumentSnapshot contractSnap = await contractRef.get();

      if (contractSnap.exists) {
        String propertyId = contractSnap.get('propertyId');
        DocumentReference propertyRef = _db
            .collection('properties')
            .doc(propertyId);

        // A. Actualizamos el contrato
        batch.update(contractRef, {
          ...data,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // B. Actualizamos la propiedad a 'inactive' (ya arrendada)
        batch.update(propertyRef, {
          'status': 'inactive', // O el estado que uses para "Ocupado"
          'updatedAt': FieldValue.serverTimestamp(),
        });

        await batch.commit();
        return;
      }
    }

    // 3. Si no es una activación final, solo actualizamos los campos del contrato normalmente
    await contractRef.update({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Simular la firma del contrato (Pruebas)
  Future<void> simulateSignature(String ownerId) async {
    final query = await _db
        .collection(_collection)
        .where('ownerId', isEqualTo: ownerId)
        .limit(1)
        .get();

    if (query.docs.isEmpty) throw "No hay contrato para este ownerId";

    await query.docs.first.reference.update({
      'status': 'signedPendingReview',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
