import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:inmobiliariaapp/models/candidate_model.dart';

class ContractModel {
  final String? id;
  final String propertyId;
  final String address;
  final String ownerId;

  // Objeto completo del inquilino aprobado
  final CandidateModel? tenant;

  final String
  status; // 'waiting_owner_signature', 'waiting_tenant_signature', 'active', etc.

  // URLs de los documentos en las diferentes etapas
  final String? baseContractPdfUrl; // Borrador original
  final String? ownerSignedPdfUrl; // Firmado por el Propietario
  final String? tenantSignedPdfUrl; // Firmado por el inquilino (Final)

  final double canonAmount;
  final double depositAmount;

  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? rejectionReason;

  // Nueva propiedad: Duración (ej: "6 Meses", "1 Año")
  final String? duration;

  final Map<String, dynamic> extraData;

  ContractModel({
    this.id,
    required this.propertyId,
    required this.address,
    required this.ownerId,
    this.tenant,
    required this.status,
    this.baseContractPdfUrl,
    this.ownerSignedPdfUrl,
    this.tenantSignedPdfUrl,
    required this.canonAmount,
    this.depositAmount = 0,
    required this.createdAt,
    this.updatedAt,
    this.rejectionReason,
    this.duration,
    this.extraData = const {},
  });

  // --- LÓGICA DE INTERPRETACIÓN PARA EL CONTADOR ---

  /// Calcula la fecha exacta de finalización del contrato
  DateTime? get endDate {
    if (duration == null || duration!.isEmpty || duration == "Indefinido")
      return null;

    // El tiempo empieza a contar desde que el contrato se activa (firma final)
    // Si aún no es activo, calculamos una estimación desde la creación.
    DateTime startDate = (status == 'active' && updatedAt != null)
        ? updatedAt!
        : createdAt;

    try {
      // Extraemos el número (6, 1, 2...)
      int value = int.parse(duration!.split(' ')[0]);

      if (duration!.toLowerCase().contains('mes')) {
        return DateTime(startDate.year, startDate.month + value, startDate.day);
      } else if (duration!.toLowerCase().contains('año')) {
        return DateTime(startDate.year + value, startDate.month, startDate.day);
      }
    } catch (e) {
      return null;
    }
    return null;
  }

  /// Calcula cuántos días dura el contrato en total para el progreso del círculo
  int get totalContractDays {
    final end = endDate;
    if (end == null) return 365; // Valor por defecto para cálculos circulares

    DateTime startDate = (status == 'active' && updatedAt != null)
        ? updatedAt!
        : createdAt;

    return end.difference(startDate).inDays;
  }

  // --- MÉTODOS DE FIREBASE ---

  Map<String, dynamic> toMap() {
    return {
      'propertyId': propertyId,
      'address': address,
      'ownerId': ownerId,
      'tenant': tenant?.toMap(),
      'status': status,
      'baseContractPdfUrl': baseContractPdfUrl,
      'ownerSignedPdfUrl': ownerSignedPdfUrl,
      'tenantSignedPdfUrl': tenantSignedPdfUrl,
      'canonAmount': canonAmount,
      'depositAmount': depositAmount,
      'createdAt': createdAt,
      'updatedAt': updatedAt ?? FieldValue.serverTimestamp(),
      'rejectionReason': rejectionReason,
      'duration': duration, // Guardamos la selección del Admin
      ...extraData,
    };
  }

  factory ContractModel.fromSnapshot(DocumentSnapshot snap) {
    var data = snap.data() as Map<String, dynamic>;

    DateTime getDateTime(dynamic field) {
      if (field is Timestamp) return field.toDate();
      if (field is String) return DateTime.parse(field);
      return DateTime.now();
    }

    // Identificamos llaves conocidas para separar los metadatos de extraData
    final knownKeys = [
      'propertyId',
      'ownerId',
      'address',
      'tenant',
      'status',
      'baseContractPdfUrl',
      'ownerSignedPdfUrl',
      'tenantSignedPdfUrl',
      'canonAmount',
      'depositAmount',
      'createdAt',
      'updatedAt',
      'rejectionReason',
      'duration',
    ];

    final extra = Map<String, dynamic>.from(data)
      ..removeWhere((key, value) => knownKeys.contains(key));

    return ContractModel(
      id: snap.id,
      propertyId: data['propertyId'] ?? '',
      ownerId: data['ownerId'] ?? '',
      address: data['address'] ?? '',
      tenant: data['tenant'] != null
          ? CandidateModel.fromMap(data['tenant'])
          : null,
      status: data['status'] ?? 'waiting_owner_signature',
      baseContractPdfUrl: data['baseContractPdfUrl'],
      ownerSignedPdfUrl: data['ownerSignedPdfUrl'],
      tenantSignedPdfUrl: data['tenantSignedPdfUrl'],
      canonAmount: (data['canonAmount'] as num?)?.toDouble() ?? 0.0,
      depositAmount: (data['depositAmount'] as num?)?.toDouble() ?? 0.0,
      createdAt: getDateTime(data['createdAt']),
      updatedAt: data['updatedAt'] != null
          ? getDateTime(data['updatedAt'])
          : null,
      rejectionReason: data['rejectionReason'],
      duration: data['duration'], // Mapeamos la duración desde Firebase
      extraData: extra,
    );
  }
}
