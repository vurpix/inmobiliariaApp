import 'package:inmobiliariaapp/enum/user_role.dart';

abstract class AuthEvent {}

class AppStarted extends AuthEvent {}

class LogInRequested extends AuthEvent {
  final String email;
  final String password;
  LogInRequested(this.email, this.password);
}

// NUEVO: Para crear una cuenta real en Firebase
class SignUpRequested extends AuthEvent {
  final String email;
  final String password;
  final String name;
  final UserRole role; // Importar tu UserRole enum

  SignUpRequested({
    required this.email,
    required this.password,
    required this.name,
    required this.role,
  });
}

class CreateAdminRequested extends AuthEvent {
  final String email;
  final String password;
  final String name;

  CreateAdminRequested({
    required this.email,
    required this.password,
    required this.name,
  });
}

class GoogleSignInRequested extends AuthEvent {
  final bool acceptedTerms;
  final bool isRegister; // <-- AÑADIR ESTO

  GoogleSignInRequested({required this.acceptedTerms, this.isRegister = false});
}

class AppleSignInRequested extends AuthEvent {
  final bool acceptedTerms;
  final bool isRegister; // <-- AÑADIR ESTO

  AppleSignInRequested({required this.acceptedTerms, this.isRegister = false});
}

/// Se dispara cuando el usuario es nuevo y ya eligió su rol en la pantalla intermedia
class CompleteSocialSignUpRequested extends AuthEvent {
  final String uid;
  final String email;
  final String? name;
  final String? photoUrl;
  final UserRole role;

  CompleteSocialSignUpRequested({
    required this.uid,
    required this.email,
    required this.role,
    this.name,
    this.photoUrl,
  });
}

class ShowLoginScreenRequested extends AuthEvent {}

class LogOutRequested extends AuthEvent {}
