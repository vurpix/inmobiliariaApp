// blocs/auth_bloc.dart
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inmobiliariaapp/bloc/authBloc/auth_event.dart';
import 'package:inmobiliariaapp/bloc/authBloc/auth_state.dart';
import 'package:inmobiliariaapp/services/auth_repository.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository _authRepository;

  AuthBloc({required AuthRepository authRepository})
    : _authRepository = authRepository,
      super(AuthInitial()) {
    // 1. INICIO DE LA APP
    on<AppStarted>((event, emit) async {
      try {
        final currentUser = _authRepository.currentUser;
        if (currentUser != null) {
          final userData = await _authRepository.getUserData(currentUser.uid);
          if (userData != null) {
            // OPTIMIZACIÓN: Actualiza el token al arrancar si el usuario ya está autenticado
            final String? token = await _authRepository.getFcmToken();
            await _authRepository.updateFcmToken(currentUser.uid, token);

            emit(Authenticated(userData));
            return;
          }
        }
        emit(Unauthenticated());
      } catch (_) {
        emit(Unauthenticated());
      }
    });

    // 2. SOLICITUD DE LOGIN
    on<ShowLoginScreenRequested>((event, emit) {
      emit(Unauthenticated());
      emit(AuthNavigatingToLogin());
    });

    // 3. GOOGLE SIGN IN
    on<GoogleSignInRequested>((event, emit) async {
      emit(AuthLoading());
      try {
        final credential = await _authRepository.signInWithGoogle();
        final user = credential.user;

        if (user != null) {
          final userData = await _authRepository.getUserData(user.uid);

          if (userData != null) {
            await _authRepository.updateLastLogin(user.uid);

            // DISPOSITIVO VINCULADO: El usuario ya existía, asociamos el token actual
            final String? token = await _authRepository.getFcmToken();
            await   _authRepository.updateFcmToken(user.uid, token);

            emit(Authenticated(userData));
          } else {
            // --- PROTECCIÓN DE LOGIN DIRECTO (ROLLBACK) ---
            if (!event.isRegister) {
              // Limpieza absoluta antes de destruir la instancia
              await _authRepository.updateFcmToken(user.uid, null);
              await user.delete();
              await _authRepository.signOut();
              emit(
                AuthFailure(
                  "⚠️ No encontramos ninguna cuenta vinculada a este correo. Regístrate primero.",
                ),
              );
              emit(AuthNavigatingToLogin());
              return;
            }

            if (!event.acceptedTerms) {
              await _authRepository.updateFcmToken(user.uid, null);
              await user.delete();
              await _authRepository.signOut();
              emit(
                AuthFailure(
                  "⚠️ Es obligatorio aceptar los términos y condiciones para crear una cuenta.",
                ),
              );
              emit(AuthNavigatingToLogin());
              return;
            }

            emit(
              AuthSocialFirstTime(
                uid: user.uid,
                email: user.email ?? "",
                name: user.displayName,
                photoUrl: user.photoURL,
              ),
            );
          }
        }
      } catch (e) {
        emit(
          AuthFailure("Error con Google: ${_mapFirebaseError(e.toString())}"),
        );
        emit(AuthNavigatingToLogin());
      }
    });

    // 4. APPLE SIGN IN
    on<AppleSignInRequested>((event, emit) async {
      emit(AuthLoading());
      try {
        final credential = await _authRepository.signInWithApple();
        final user = credential.user;

        if (user != null) {
          final userData = await _authRepository.getUserData(user.uid);

          if (userData != null) {
            await _authRepository.updateLastLogin(user.uid);

            // DISPOSITIVO VINCULADO
            final String? token = await _authRepository.getFcmToken();
            await _authRepository.updateFcmToken(user.uid, token);

            emit(Authenticated(userData));
          } else {
            // --- PROTECCIÓN DE LOGIN DIRECTO (ROLLBACK) ---
            if (!event.isRegister) {
              await _authRepository.updateFcmToken(user.uid, null);
              await user.delete();
              await _authRepository.signOut();
              emit(
                AuthFailure(
                  "⚠️ No encontramos ninguna cuenta vinculada a este correo. Regístrate primero.",
                ),
              );
              emit(AuthNavigatingToLogin());
              return;
            }

            if (!event.acceptedTerms) {
              await _authRepository.updateFcmToken(user.uid, null);
              await user.delete();
              await _authRepository.signOut();
              emit(
                AuthFailure(
                  "⚠️ Es obligatorio aceptar los términos y condiciones para crear una cuenta.",
                ),
              );
              emit(AuthNavigatingToLogin());
              return;
            }

            emit(
              AuthSocialFirstTime(
                uid: user.uid,
                email: user.email ?? "",
                name: user.displayName,
                photoUrl: null,
              ),
            );
          }
        }
      } catch (e) {
        emit(
          AuthFailure("Error con Apple: ${_mapFirebaseError(e.toString())}"),
        );
        emit(AuthNavigatingToLogin());
      }
    });

    // 5. FINALIZAR REGISTRO SOCIAL
    on<CompleteSocialSignUpRequested>((event, emit) async {
      emit(AuthLoading());
      try {
        final String finalName = _sanitizeName(event.name, event.email);

        await _authRepository.createUserInFirestore(
          uid: event.uid,
          email: event.email,
          name: finalName,
          photoUrl: event.photoUrl ?? "",
          role: event.role,
          documentType: "Cédula de Ciudadanía",
          documentNumber: "",
          occupation: "",
        );

        final userData = await _authRepository.getUserData(event.uid);
        if (userData != null) {
          // REGISTRO EXITOSO: Vinculamos el token al perfil recién estructurado en Firestore
          final String? token = await _authRepository.getFcmToken();
          await _authRepository.updateFcmToken(event.uid, token);

          emit(Authenticated(userData));
        } else {
          emit(AuthFailure("Error al crear el perfil funcional."));
        }
      } catch (e) {
        emit(AuthFailure(_mapFirebaseError(e.toString())));
      }
    });

    // 6. LOGIN TRADICIONAL
    on<LogInRequested>((event, emit) async {
      emit(AuthLoading());
      try {
        final credential = await _authRepository.signIn(
          event.email.trim(),
          event.password.trim(),
        );

        await _authRepository.updateLastLogin(credential.user!.uid);
        final userModel = await _authRepository.getUserData(
          credential.user!.uid,
        );

        if (userModel != null) {
          // DISPOSITIVO VINCULADO TRADICIONAL
          final String? token = await _authRepository.getFcmToken();
          await _authRepository.updateFcmToken(credential.user!.uid, token);

          emit(Authenticated(userModel));
        } else {
          emit(AuthFailure("No se encontró el perfil en el sistema."));
          emit(AuthNavigatingToLogin());
        }
      } catch (e) {
        emit(AuthFailure(_mapFirebaseError(e.toString())));
        emit(AuthNavigatingToLogin());
      }
    });

    // 7. REGISTRO TRADICIONAL
    on<SignUpRequested>((event, emit) async {
      emit(AuthLoading());
      try {
        final String finalName = _sanitizeName(event.name, event.email);

        await _authRepository.signUp(
          email: event.email.trim(),
          password: event.password.trim(),
          name: finalName,
          role: event.role,
          documentType: "Cédula de Ciudadanía",
          documentNumber: "",
          occupation: "",
        );

        final currentUser = _authRepository.currentUser;
        if (currentUser != null) {
          final userModel = await _authRepository.getUserData(currentUser.uid);
          if (userModel != null) {
            // REGISTRO TRADICIONAL EXITOSO
            final String? token = await _authRepository.getFcmToken();
            await _authRepository.updateFcmToken(currentUser.uid, token);

            emit(Authenticated(userModel));
          } else {
            emit(AuthFailure("Error al cargar el perfil nuevo."));
          }
        }
      } catch (e) {
        emit(AuthFailure(_mapFirebaseError(e.toString())));
      }
    });

    // 8. CIERRE DE SESIÓN (PROTECCIÓN DE TOKENS RESIDUALES)
    on<LogOutRequested>((event, emit) async {
      final currentUser = _authRepository.currentUser;
      if (currentUser != null) {
        // SEGURIDAD: Remueve el token en Firestore antes de limpiar la sesión local
        await _authRepository.updateFcmToken(currentUser.uid, null);
      }
      await _authRepository.signOut();
      emit(Unauthenticated());
    });
  }

  // --- FUNCIONES AUXILIARES ---
  String _sanitizeName(String? name, String email) {
    if (name != null && name.trim().isNotEmpty) return name.trim();
    if (email.contains('@')) return email.split('@')[0];
    return "Usuario";
  }

  String _mapFirebaseError(String error) {
    final lowerError = error.toLowerCase();
    if (lowerError.contains('invalid-credential'))
      return "El correo o la contraseña no coinciden.";
    if (lowerError.contains('user-not-found'))
      return "No existe una cuenta con este correo.";
    if (lowerError.contains('email-already-in-use'))
      return "Este correo ya está registrado.";
    if (lowerError.contains('network-request-failed'))
      return "Error de red. Revisa tu conexión.";
    return "Ocurrió un error inesperado.";
  }
}
