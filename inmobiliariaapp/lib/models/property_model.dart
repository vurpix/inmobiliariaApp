// models/property_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:inmobiliariaapp/enum/payment_status.dart';
import 'package:inmobiliariaapp/enum/property_status.dart';

class PropertyModel {
  final String? id;
  final String ownerId;
  final String address;

  // --- NUEVOS CAMPOS GEOGRÁFICOS ---
  final String state; // Ej: "Santander", "Antioquia"
  final String city; // Ej: "Bucaramanga", "Medellín"

  final String description;
  final double canon;
  final String area;
  final bool hasAdmin;
  final double adminPrice;
  final List<String> amenities;
  final List<String> imageUrls;
  final List<String> docUrls;
  final String? paymentReceiptUrl;

  // --- TIEMPO DE ARRIENDO ---
  final String durationValue; // Ej: "6", "1"
  final String durationUnit; // Ej: "Meses", "Año"

  // --- MULTIMEDIA ---
  final String? videoUrl;

  // --- CONTRATOS Y LEGAL ---
  final String? currentContractId;

  // --- COMODÍN PARA CAMPOS EXTRA ---
  final Map<String, dynamic> extraData;

  // --- ESTADOS Y TIMESTAMPS ---
  final PaymentStatusEnum paymentStatus;
  final PropertyStatusEnum status;
  final DateTime createdAt;
  final DateTime? updatedAt;

  PropertyModel({
    this.id,
    required this.ownerId,
    required this.address,
    required this.state, // Requerido en la instanciación
    required this.city, // Requerido en la instanciación
    required this.description,
    required this.canon,
    required this.area,
    required this.hasAdmin,
    this.adminPrice = 0.0,
    this.amenities = const [],
    this.imageUrls = const [],
    this.docUrls = const [],
    this.paymentReceiptUrl,
    this.videoUrl,
    this.currentContractId,
    // Valores por defecto para evitar nulos
    this.durationValue = "1",
    this.durationUnit = "Año",
    this.extraData = const {},
    this.paymentStatus = PaymentStatusEnum.pendingVerify,
    this.status = PropertyStatusEnum.pendingReview,
    DateTime? createdAt,
    this.updatedAt,
  }) : this.createdAt = createdAt ?? DateTime.now();

  // --- CONVERTIR A MAPA PARA GUARDAR EN FIRESTORE ---
  Map<String, dynamic> toMap() {
    return {
      'ownerId': ownerId,
      'address': address,
      'state': state, // Guardado en Firestore
      'city': city, // Guardado en Firestore
      'description': description,
      'canon': canon,
      'area': area,
      'hasAdmin': hasAdmin,
      'adminPrice': adminPrice,
      'amenities': amenities,
      'imageUrls': imageUrls,
      'docUrls': docUrls,
      'paymentReceiptUrl': paymentReceiptUrl,
      'videoUrl': videoUrl,
      'currentContractId': currentContractId,
      'durationValue': durationValue,
      'durationUnit': durationUnit,
      'extraData': extraData,
      'paymentStatus': paymentStatus.name,
      'status': status.name,
      'createdAt': createdAt,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  // --- CREAR MODELO DESDE SNAPSHOT DE FIRESTORE ---
  factory PropertyModel.fromSnapshot(DocumentSnapshot snap) {
    final data = snap.data() as Map<String, dynamic>? ?? {};

    return PropertyModel(
      id: snap.id,
      ownerId: data['ownerId'] ?? '',
      address: data['address'] ?? '',
      state: data['state'] ?? '', // Mapeo seguro con fallback vacío
      city: data['city'] ?? '', // Mapeo seguro con fallback vacío
      description: data['description'] ?? '',
      canon: _toDouble(data['canon']),
      area: data['area']?.toString() ?? '',
      hasAdmin: data['hasAdmin'] ?? false,
      adminPrice: _toDouble(data['adminPrice']),
      amenities: List<String>.from(data['amenities'] ?? []),
      imageUrls: List<String>.from(data['imageUrls'] ?? []),
      docUrls: List<String>.from(data['docUrls'] ?? []),
      paymentReceiptUrl: data['paymentReceiptUrl'],
      videoUrl: data['videoUrl'],
      currentContractId: data['currentContractId'],

      durationValue: data['durationValue']?.toString() ?? '1',
      durationUnit: data['durationUnit'] ?? 'Año',

      extraData: Map<String, dynamic>.from(data['extraData'] ?? {}),

      paymentStatus: PaymentStatusEnum.values.firstWhere(
        (e) => e.name == data['paymentStatus'],
        orElse: () => PaymentStatusEnum.pendingVerify,
      ),
      status: PropertyStatusEnum.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => PropertyStatusEnum.pendingReview,
      ),

      createdAt: _toDateTime(data['createdAt']) ?? DateTime.now(),
      updatedAt: _toDateTime(data['updatedAt']),
    );
  }

  // --- GETTERS ÚTILES ---
  String get formattedDuration => "$durationValue $durationUnit";

  /// Devuelve la ubicación geográfica compacta para las tarjetas del inmueble
  /// Ej: "Bucaramanga, Santander"
  String get formattedLocation => "$city, $state";

  static double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  static DateTime? _toDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    return null;
  }
}
