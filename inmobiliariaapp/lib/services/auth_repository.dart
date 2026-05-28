// services/auth_repository.dart
import 'dart:async';
import 'dart:developer';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart'; // NUEVA INYECCIÓN
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:inmobiliariaapp/models/user.dart';
import 'package:inmobiliariaapp/enum/user_role.dart';

class AuthRepository {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  final FirebaseMessaging _messaging =
      FirebaseMessaging.instance; // INSTANCIA NATIVA

  User? get currentUser => _auth.currentUser;

  AuthRepository() {
    unawaited(
      _googleSignIn
          .initialize()
          .then((_) {
            // Inicialización asíncrona v7.x
          })
          // ignore: invalid_return_type_for_catch_error
          .catchError((e) => log("Error inicializando GoogleSignIn: $e")),
    );
  }

  // --- 0. GESTIÓN EXCLUSIVA DE TOKENS FCM (NUEVOS MÉTODOS) ---

  /// Recupera de manera segura el identificador APNS/GCM del dispositivo actual
  Future<String?> getFcmToken() async {
    try {
      return await _messaging.getToken();
    } catch (e) {
      log("Error recuperando FCM Token: $e");
      return null;
    }
  }

  /// Registra o limpia un token en el documento del usuario usando merge adaptativo
  Future<void> updateFcmToken(String userId, String? token) async {
    try {
      await _firestore.collection('users').doc(userId).set({
        'fcmToken': token,
        'lastTokenUpdate': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      log("Error actualizando FCM Token en Firestore: $e");
    }
  }

  // --- 1. REGISTRO TRADICIONAL ACTUALIZADO ---
  Future<void> signUp({
    required String email,
    required String password,
    required String name,
    required UserRole role,
    required String documentType,
    required String documentNumber,
    required String occupation,
  }) async {
    try {
      UserCredential credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      await createUserInFirestore(
        uid: credential.user!.uid,
        email: email,
        name: name,
        role: role,
        documentType: documentType,
        documentNumber: documentNumber,
        occupation: occupation,
      );
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  // --- 2. INICIO DE SESIÓN TRADICIONAL ---
  Future<UserCredential> signIn(String email, String password) async {
    return await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  // --- 3. GOOGLE SIGN IN ---
  Future<UserCredential> signInWithGoogle() async {
    try {
      GoogleSignInAccount? googleUser;
      if (await _googleSignIn.supportsAuthenticate()) {
        googleUser = await _googleSignIn.authenticate();
      }

      if (googleUser == null) throw Exception("Inicio de sesión cancelado");

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.idToken,
        idToken: googleAuth.idToken,
      );

      return await _auth.signInWithCredential(credential);
    } catch (e) {
      throw Exception("Error Google: $e");
    }
  }

  // --- 4. APPLE SIGN IN ---
  Future<UserCredential> signInWithApple() async {
    try {
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final OAuthProvider oAuthProvider = OAuthProvider('apple.com');
      final credential = oAuthProvider.credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      );

      return await _auth.signInWithCredential(credential);
    } catch (e) {
      throw Exception("Error Apple: $e");
    }
  }

  // --- 5. MÉTODO UNIFICADO PARA FIRESTORE ---
  Future<void> createUserInFirestore({
    required String uid,
    required String email,
    required String name,
    required UserRole role,
    required String documentType,
    required String documentNumber,
    required String occupation,
    String? photoUrl,
  }) async {
    final newUser = UserModel(
      id: uid,
      email: email,
      name: name,
      role: role,
      photoUrl: photoUrl,
      documentType: documentType,
      documentNumber: documentNumber,
      occupation: occupation,
      createdAt: DateTime.now(),
      lastLogin: DateTime.now(),
      rating: 0.0,
      propertyIds: const [],
    );

    await _firestore.collection('users').doc(uid).set(newUser.toMap());
  }

  // --- 6. GESTIÓN DE PERFIL ---
  Future<UserModel?> getUserData(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (doc.exists && doc.data() != null) {
      return UserModel.fromMap(doc.data()!, doc.id);
    }
    return null;
  }

  Future<void> updateLastLogin(String uid) async {
    await _firestore.collection('users').doc(uid).update({
      'lastLogin': FieldValue.serverTimestamp(),
    });
  }

  // --- 7. CUENTAS ADMINISTRATIVAS ---
  Future<void> createAdminAccount({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      UserCredential credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      await createUserInFirestore(
        uid: credential.user!.uid,
        email: email,
        name: name,
        role: UserRole.admin,
        documentType: "CC",
        documentNumber: "ADMIN_INTERNAL",
        occupation: "Administrador de Plataforma",
      );
    } catch (e) {
      throw Exception("Error creando Admin: $e");
    }
  }

  // --- 8. CIERRE DE SESIÓN ---
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _auth.signOut();
    } catch (e) {
      await _auth.signOut();
    }
  }
}
