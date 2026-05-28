// models/user_model.dart
import 'package:equatable/equatable.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:inmobiliariaapp/enum/user_role.dart';

class UserModel extends Equatable {
  final String id;
  final String email;
  final String name;
  final UserRole role;
  final String? photoUrl;
  final String? phoneNumber;
  final DateTime? createdAt;
  final DateTime? lastLogin;
  final double rating;
  final int reviewCount;
  final List<String> propertyIds;

  // --- CAMPOS CIVILES Y DE ARRIENDO OBLIGATORIOS ---
  final String documentType;
  final String documentNumber;
  final String occupation;

  // Agregados para consistencia con los métodos del UserService
  final String? incomeDocUrl;
  final String? hasAppliedTo;
  final String? fcmToken;
  final DateTime? lastTokenUpdate;

  const UserModel({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    required this.documentType,
    required this.documentNumber,
    required this.occupation,
    this.photoUrl,
    this.phoneNumber,
    this.createdAt,
    this.lastLogin,
    this.rating = 0.0,
    this.reviewCount = 0,
    this.propertyIds = const [],
    this.incomeDocUrl,
    this.hasAppliedTo,
    this.fcmToken,
    this.lastTokenUpdate,
  });

  // --- CREAR MODELO DIRECTAMENTE DESDE UN DOCUMENTO DE FIRESTORE ---
  factory UserModel.fromSnapshot(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return UserModel.fromMap(data, doc.id);
  }

  // --- CONVERSIÓN DE MAPA A MODELO ---
  factory UserModel.fromMap(Map<String, dynamic> map, String documentId) {
    return UserModel(
      id: documentId,
      email: map['email'] ?? '',
      name: map['name'] ?? '',
      photoUrl: map['photoUrl'],
      phoneNumber: map['phoneNumber'],
      incomeDocUrl: map['incomeDocUrl'],
      hasAppliedTo: map['hasAppliedTo'],
      fcmToken: map['fcmToken'],
      role: UserRole.values.firstWhere(
        (e) => e.name == map['role'],
        orElse: () => UserRole.tenant,
      ),

      // --- MAPEO DE SEGURIDAD CORREGIDO PARA EVITAR CAÍDAS DE INTERFAZ ---
      documentType: map['documentType'] ?? 'Cédula de Ciudadanía',
      documentNumber:
          map['documentNumber'] ??
          '', // Cambiado a string vacío si no existe en BD
      occupation:
          map['occupation'] ?? '', // Cambiado a string vacío si no existe en BD

      createdAt: _toDateTime(map['createdAt']),
      lastLogin: _toDateTime(map['lastLogin']),
      lastTokenUpdate: _toDateTime(map['lastTokenUpdate']),
      rating: map['rating'] != null ? (map['rating'] as num).toDouble() : 0.0,
      reviewCount: map['reviewCount'] ?? 0,
      propertyIds: List<String>.from(map['propertyIds'] ?? []),
    );
  }

  // --- CONVERSIÓN DE MODELO A MAPA ---
  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'name': name,
      'role': role.name,
      'photoUrl': photoUrl,
      'phoneNumber': phoneNumber,
      'rating': rating,
      'reviewCount': reviewCount,
      'propertyIds': propertyIds,
      'incomeDocUrl': incomeDocUrl,
      'hasAppliedTo': hasAppliedTo,
      'fcmToken': fcmToken,

      // --- SERIALIZACIÓN DE CLAVES DE IDENTIDAD LEGAL ---
      'documentType': documentType,
      'documentNumber': documentNumber,
      'occupation': occupation,

      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
      'lastLogin': lastLogin ?? FieldValue.serverTimestamp(),
      'lastTokenUpdate': lastTokenUpdate,
    };
  }

  static DateTime? _toDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    return null;
  }

  // --- METODO COPYWITH ACTUALIZADO AL 100% ---
  UserModel copyWith({
    String? name,
    UserRole? role,
    String? photoUrl,
    String? phoneNumber,
    String? documentType,
    String? documentNumber,
    String? occupation,
    DateTime? lastLogin,
    double? rating,
    int? reviewCount,
    List<String>? propertyIds,
    String? incomeDocUrl,
    String? hasAppliedTo,
    String? fcmToken,
    DateTime? lastTokenUpdate,
  }) {
    return UserModel(
      id: id,
      email: email,
      name: name ?? this.name,
      role: role ?? this.role,
      photoUrl: photoUrl ?? this.photoUrl,
      phoneNumber: phoneNumber ?? this.phoneNumber,

      // Mapeos adaptativos del copyWith
      documentType: documentType ?? this.documentType,
      documentNumber: documentNumber ?? this.documentNumber,
      occupation: occupation ?? this.occupation,

      createdAt: createdAt,
      lastLogin: lastLogin ?? this.lastLogin,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      propertyIds: propertyIds ?? this.propertyIds,
      incomeDocUrl: incomeDocUrl ?? this.incomeDocUrl,
      hasAppliedTo: hasAppliedTo ?? this.hasAppliedTo,
      fcmToken: fcmToken ?? this.fcmToken,
      lastTokenUpdate: lastTokenUpdate ?? this.lastTokenUpdate,
    );
  }

  @override
  List<Object?> get props => [
    id,
    email,
    name,
    role,
    photoUrl,
    phoneNumber,
    documentType,
    documentNumber,
    occupation,
    createdAt,
    lastLogin,
    rating,
    reviewCount,
    propertyIds,
    incomeDocUrl,
    hasAppliedTo,
    fcmToken,
    lastTokenUpdate,
  ];
}
