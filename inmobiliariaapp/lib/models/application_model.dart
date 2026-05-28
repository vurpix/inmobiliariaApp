import 'package:cloud_firestore/cloud_firestore.dart';
import 'candidate_model.dart'; // Importa el modelo anterior

class ApplicationModel {
  final String propertyId;
  final String address;
  final DateTime lastUpdate;
  final String status;
  final List<CandidateModel> candidates;

  ApplicationModel({
    required this.propertyId,
    required this.address,
    required this.lastUpdate,
    required this.status,
    required this.candidates,
  });

  // Convertir de Objeto a Map (para guardar en Firestore)
  Map<String, dynamic> toMap() {
    return {
      'propertyId': propertyId,
      'address': address,
      'lastUpdate':
          FieldValue.serverTimestamp(), // Firestore maneja la hora del servidor
      'status': status,
      'candidates': candidates.map((c) => c.toMap()).toList(),
    };
  }

  // Crear objeto desde Firestore (DocumentSnapshot o Map)
  factory ApplicationModel.fromMap(Map<String, dynamic> map) {
    return ApplicationModel(
      propertyId: map['propertyId'] ?? '',
      address: map['address'] ?? 'Sin dirección',
      lastUpdate: (map['lastUpdate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: map['status'] ?? 'searching_candidates',
      candidates:
          (map['candidates'] as List<dynamic>?)
              ?.map((c) => CandidateModel.fromMap(c as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  // Método para actualizar campos específicos manteniendo la inmutabilidad
  ApplicationModel copyWith({
    String? status,
    List<CandidateModel>? candidates,
    String? address,
  }) {
    return ApplicationModel(
      propertyId: propertyId,
      address: address ?? this.address,
      lastUpdate: DateTime.now(),
      status: status ?? this.status,
      candidates: candidates ?? this.candidates,
    );
  }
}
