import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:inmobiliariaapp/models/user.dart';
// --- IMPORTA AQUÍ TU MODELO DE USUARIO ---
// import 'package:inmobiliariaapp/models/user_model.dart'; 

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // --- 1. ESCUCHAR TODOS LOS USUARIOS (DEVUELVE LISTA DE USERMODEL) ---
  Stream<List<UserModel>> watchAllUsers() {
    return _firestore.collection('users').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => UserModel.fromSnapshot(doc)).toList();
    });
  }

  // --- 2. OBTENER UN USUARIO POR SU ID (DEVUELVE USERMODEL O NULL SI NO EXISTE) ---
  Future<UserModel?> getUserById(String userId) async {
    final doc = await _firestore.collection('users').doc(userId).get();
    if (!doc.exists) return null;
    return UserModel.fromSnapshot(doc);
  }

  // --- 3. ESCUCHAR FAVORITOS (MANTIENE QUERYSNAPSHOT PORQUE CONTIENE PROPIEDADES, NO USUARIOS) ---
  Stream<QuerySnapshot> watchUserFavorites(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('favorites')
        .snapshots();
  }

  // --- 4. ACTUALIZAR BORRADOR DE INGRESOS Y PROPIEDAD POSTULADA ---
  Future<void> updateIncomeAndApplication({
    required String uid,
    required String incomePdfUrl,
    required String propertyId,
  }) async {
    await _firestore.collection('users').doc(uid).update({
      'incomeDocUrl': incomePdfUrl,
      'hasAppliedTo': propertyId,
    });
  }

  // --- 5. GUARDAR O ACTUALIZAR EL TOKEN DE NOTIFICACIONES (FCM TOKEN) ---
  Future<void> updateFcmToken(String userId, String? token) async {
    await _firestore.collection('users').doc(userId).set({
      'fcmToken': token,
      'lastTokenUpdate': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // --- 6. REGISTRAR LA FECHA DEL ÚLTIMO INICIO DE SESIÓN ---
  Future<void> updateLastLogin(String uid) async {
    await _firestore.collection('users').doc(uid).update({
      'lastLogin': FieldValue.serverTimestamp(),
    });
  }

  // --- 7. OBTENER LA REFERENCIA DE UN DOCUMENTO DE FAVORITO ESPECÍFICO ---
  DocumentReference getFavoriteDocRef({
    required String userId,
    required String propertyId,
  }) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('favorites')
        .doc(propertyId);
  }

  // --- 8. OBTENER TODOS LOS FAVORITOS DE UN USUARIO (UNA SOLA VEZ) ---
  Future<QuerySnapshot> getUserFavoritesSnapshot(String userId) async {
    return await _firestore
        .collection('users')
        .doc(userId)
        .collection('favorites')
        .get();
  }
}