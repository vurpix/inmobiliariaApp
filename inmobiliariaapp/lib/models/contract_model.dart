import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:inmobiliariaapp/models/candidate_model.dart';
import 'package:inmobiliariaapp/models/signature/signature_party_model.dart';

class ContractModel {
  final String? id;
  final String propertyId;
  final String address;
  final String ownerId;
  final CandidateModel? tenant;
  final String status;

  // URLs de los documentos en las diferentes etapas
  final String? baseContractPdfUrl;
  final String? ownerSignedPdfUrl;
  final String? tenantSignedPdfUrl;

  final double canonAmount;
  final double depositAmount;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? rejectionReason;
  final String? duration;

  // 🔴 NUEVAS PROPIEDADES TIPADAS DE VIAFIRMA SIN MAPAS SUCIOS
  final String? viafirmaSetCode;
  final String? viafirmaMessageCode;
  final String? viafirmaSignatureDocId;
  final String? signatureStatus;

  // Mapa indexado por UID que contiene la información de seguimiento detallada
  final Map<String, SignaturePartyModel>? signaturesTracking;

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
    // Inicializadores de las nuevas variables
    this.viafirmaSetCode,
    this.viafirmaMessageCode,
    this.viafirmaSignatureDocId,
    this.signatureStatus,
    this.signaturesTracking,
    this.extraData = const {},
  });

  // --- LÓGICA DE INTERPRETACIÓN PARA EL CONTADOR ---

  DateTime? get endDate {
    if (duration == null || duration!.isEmpty || duration == "Indefinido")
      return null;

    DateTime startDate = (status == 'active' && updatedAt != null)
        ? updatedAt!
        : createdAt;

    try {
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

  int get totalContractDays {
    final end = endDate;
    if (end == null) return 365;

    DateTime startDate = (status == 'active' && updatedAt != null)
        ? updatedAt!
        : createdAt;

    return end.difference(startDate).inDays;
  }

  // --- MÉTODOS DE FIREBASE ---

  Map<String, dynamic> toMap() {
    // Convertimos el mapa de objetos tipados a un mapa plano compatible con Firestore
    Map<String, dynamic>? trackingMap;
    if (signaturesTracking != null) {
      trackingMap = signaturesTracking!.map(
        (key, value) => MapEntry(key, value.toMap()),
      );
    }

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
      'duration': duration,
      // Persistencia de los nuevos campos de Viafirma
      'viafirmaSetCode': viafirmaSetCode,
      'viafirmaMessageCode': viafirmaMessageCode,
      'viafirmaSignatureDocId': viafirmaSignatureDocId,
      'signatureStatus': signatureStatus,
      'signaturesTracking': trackingMap,
      ...extraData,
    };
  }

  factory ContractModel.fromSnapshot(DocumentSnapshot snap) {
    // Si por alguna razón el snapshot viene vacío, evitamos el crash inmediato
    if (!snap.exists || snap.data() == null) {
      return ContractModel(
        id: snap.id,
        propertyId: '',
        ownerId: '',
        address: '',
        status: 'error_empty',
        canonAmount: 0.0,
        createdAt: DateTime.now(),
      );
    }

    var data = snap.data() as Map<String, dynamic>;

    DateTime getDateTime(dynamic field) {
      if (field is Timestamp) return field.toDate();
      if (field is String) {
        return DateTime.tryParse(field) ?? DateTime.now();
      }
      return DateTime.now();
    }

    // 🔴 ENFOQUE ULTRA SEGURO PARA EL MAPEO DE SIGNATURES TRACKING
    Map<String, SignaturePartyModel>? trackingData;

    try {
      if (data['signaturesTracking'] != null &&
          data['signaturesTracking'] is Map) {
        final Map<String, dynamic> rawTracking = Map<String, dynamic>.from(
          data['signaturesTracking'],
        );

        trackingData = {};

        rawTracking.forEach((key, value) {
          if (value is Map) {
            // Convertimos de forma segura asegurando que sea un mapa limpio de strings y dynamics
            final cleanUserMap = Map<String, dynamic>.from(value);
            trackingData![key] = SignaturePartyModel.fromMap(cleanUserMap);
          }
        });
      }
    } catch (e) {
      // Si el mapa de tracking de un contrato viejo está roto, no dejamos que rompa la app
      debugPrint(
        "⚠️ [MODEL WARNING] Error al procesar 'signaturesTracking' en contrato ${snap.id}: $e",
      );
      trackingData = null;
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
      'viafirmaSetCode',
      'viafirmaMessageCode',
      'viafirmaSignatureDocId',
      'signatureStatus',
      'signaturesTracking',
    ];

    // Separación segura de extraData
    final extra = Map<String, dynamic>.from(data)
      ..removeWhere((key, value) => knownKeys.contains(key));

    // 🔴 BLINDAJE EXTRA: Validación destructiva de mapas internos (tenant)
    CandidateModel? tenantModel;
    try {
      if (data['tenant'] != null && data['tenant'] is Map) {
        tenantModel = CandidateModel.fromMap(
          Map<String, dynamic>.from(data['tenant']),
        );
      }
    } catch (e) {
      debugPrint(
        "⚠️ [MODEL WARNING] El subobjeto 'tenant' está corrupto en contrato ${snap.id}: $e",
      );
      tenantModel = null;
    }

    return ContractModel(
      id: snap.id,
      propertyId: data['propertyId']?.toString() ?? '',
      ownerId: data['ownerId']?.toString() ?? '',
      address: data['address']?.toString() ?? '',
      tenant: tenantModel,
      status: data['status']?.toString() ?? 'waiting_owner_signature',
      baseContractPdfUrl: data['baseContractPdfUrl']?.toString(),
      ownerSignedPdfUrl: data['ownerSignedPdfUrl']?.toString(),
      tenantSignedPdfUrl: data['tenantSignedPdfUrl']?.toString(),
      // Conversión numérica blindada contra enteros puros de Firestore
      canonAmount: (data['canonAmount'] is num)
          ? (data['canonAmount'] as num).toDouble()
          : 0.0,
      depositAmount: (data['depositAmount'] is num)
          ? (data['depositAmount'] as num).toDouble()
          : 0.0,
      createdAt: getDateTime(data['createdAt']),
      updatedAt: data['updatedAt'] != null
          ? getDateTime(data['updatedAt'])
          : null,
      rejectionReason: data['rejectionReason']?.toString(),
      duration: data['duration']?.toString(),
      viafirmaSetCode: data['viafirmaSetCode']?.toString(),
      viafirmaMessageCode: data['viafirmaMessageCode']?.toString(),
      viafirmaSignatureDocId: data['viafirmaSignatureDocId']?.toString(),
      signatureStatus: data['signatureStatus']?.toString(),
      signaturesTracking: trackingData,
      extraData: extra,
    );
  }
}
