import 'package:equatable/equatable.dart';
import 'package:inmobiliariaapp/models/user.dart';

abstract class AuthState extends Equatable {
  const AuthState();
  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {}

// Estado de carga para mostrar un CircularProgressIndicator
class AuthLoading extends AuthState {}

class Unauthenticated extends AuthState {}

class AuthNavigatingToLogin extends AuthState {}

class Authenticated extends AuthState {
  final UserModel user;
  const Authenticated(this.user);

  @override
  List<Object?> get props => [user];
}

/// ESTADO CRUCIAL: Indica que el login social fue exitoso pero el usuario no tiene ROL
class AuthSocialFirstTime extends AuthState {
  final String uid;
  final String email;
  final String? name;
  final String? photoUrl;

  const AuthSocialFirstTime({
    required this.uid,
    required this.email,
    this.name,
    this.photoUrl,
  });
}

// NUEVO: Captura errores de Firebase para mostrarlos en la UI
class AuthFailure extends AuthState {
  final String message;
  const AuthFailure(this.message);

  @override
  List<Object?> get props => [message];
}
