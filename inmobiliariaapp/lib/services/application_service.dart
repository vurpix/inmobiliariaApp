import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:inmobiliariaapp/models/application_model.dart'; // Tu modelo de Aplicación
import 'package:inmobiliariaapp/models/candidate_model.dart'; // Tu modelo de Candidato

class ApplicationService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String _collection = 'applications';

  // --- 1. SECCIÓN DE LECTURA (STREAMS) ---

  /// Escucha todas las aplicaciones activas (Para el panel de Admin)
  Stream<List<ApplicationModel>> watchAllApplications() {
    return _db.collection(_collection).snapshots().map((snapshot) {
      return snapshot.docs
          .map(
            (doc) =>
                ApplicationModel.fromMap(doc.data()),
          )
          .toList();
    });
  }

  /// Escucha una aplicación específica por el ID de la propiedad
  Stream<ApplicationModel?> watchApplicationByProperty(String propertyId) {
    return _db.collection(_collection).doc(propertyId).snapshots().map((doc) {
      if (doc.exists && doc.data() != null) {
        return ApplicationModel.fromMap(doc.data() as Map<String, dynamic>);
      }
      return null;
    });
  }

  // --- 2. SECCIÓN DE ESCRITURA ---

  /// Crea o actualiza una aplicación añadiendo un candidato (Postulación)
  Future<void> applyToProperty({
    required String propertyId,
    required String propertyAddress,
    required CandidateModel candidate,
  }) async {
    final docRef = _db.collection(_collection).doc(propertyId);

    await docRef.set({
      'propertyId': propertyId,
      'address': propertyAddress,
      'lastUpdate': FieldValue.serverTimestamp(),
      'status': 'searching_candidates',
      'candidates': FieldValue.arrayUnion([candidate.toMap()]),
    }, SetOptions(merge: true));
  }

  /// Actualiza la lista completa de candidatos (Usado para aprobar/rechazar uno específico)
  Future<void> updateCandidatesList({
    required String propertyId,
    required List<CandidateModel> updatedCandidates,
  }) async {
    await _db.collection(_collection).doc(propertyId).update({
      'candidates': updatedCandidates.map((c) => c.toMap()).toList(),
      'lastUpdate': FieldValue.serverTimestamp(),
    });
  }

  // --- 3. LÓGICA DE NEGOCIO HELPER ---

  /// Obtiene el estado de un usuario específico dentro de una aplicación
  /// Útil para los condicionales de los botones (Postularme vs Estado)
  CandidateModel? getUserCandidate(
    ApplicationModel? application,
    String userId,
  ) {
    if (application == null) return null;
    try {
      return application.candidates.firstWhere((c) => c.uid == userId);
    } catch (_) {
      return null;
    }
  }
}
