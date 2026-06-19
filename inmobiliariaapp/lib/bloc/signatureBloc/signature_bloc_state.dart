import 'package:inmobiliariaapp/models/signature/signature_status_model.dart';

enum SignatureStatus {
  initial,
  loading,
  listening,
  refreshing,
  success,
  failure,
}

class SignatureState {
  final SignatureStatus status;
  final SignatureStatusModel? signature;
  final String? errorMessage;
  final bool isListening;
  final bool isRefreshing;

  SignatureState({
    this.status = SignatureStatus.initial,
    this.signature,
    this.errorMessage,
    this.isListening = false,
    this.isRefreshing = false,
  });

  SignatureState copyWith({
    SignatureStatus? status,
    SignatureStatusModel? signature,
    String? errorMessage,
    bool? isListening,
    bool? isRefreshing,
    bool clearError = false,
  }) {
    return SignatureState(
      status: status ?? this.status,
      signature: signature ?? this.signature,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      isListening: isListening ?? this.isListening,
      isRefreshing: isRefreshing ?? this.isRefreshing,
    );
  }
}