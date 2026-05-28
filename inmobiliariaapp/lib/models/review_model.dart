import 'package:cloud_firestore/cloud_firestore.dart';

class ReviewModel {
  final String? id;
  final String fromUserId; // Quién califica (UID)
  final String fromName; // Nombre de quién califica
  final String fromRole; // Rol de quién califica (landlord / tenant)
  final String contractId; // Contrato asociado que finalizó
  final int rating; // Estrellas (1 al 5)
  final String comment; // Comentario de texto libre
  final List<String> predefinedAnswers; // Tags predeterminados seleccionados
  final DateTime? createdAt; // Fecha de creación

  ReviewModel({
    this.id,
    required this.fromUserId,
    required this.fromName,
    required this.fromRole,
    required this.contractId,
    required this.rating,
    required this.comment,
    required this.predefinedAnswers,
    this.createdAt,
  });

  // Convertir el modelo a un mapa JSON para subirlo con éxito a Firestore
  Map<String, dynamic> toMap() {
    return {
      'fromUserId': fromUserId,
      'fromName': fromName,
      'fromRole': fromRole,
      'contractId': contractId,
      'rating': rating,
      'comment': comment,
      'predefinedAnswers': predefinedAnswers,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
    };
  }
}
