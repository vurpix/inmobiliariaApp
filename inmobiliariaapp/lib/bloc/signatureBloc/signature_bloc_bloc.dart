import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inmobiliariaapp/bloc/signatureBloc/signature_bloc_event.dart';
import 'package:inmobiliariaapp/bloc/signatureBloc/signature_bloc_state.dart';
import 'package:inmobiliariaapp/services/signature_service.dart';

class SignatureBloc extends Bloc<SignatureEvent, SignatureState> {
  final SignatureService _signatureService;
  StreamSubscription? _signatureSubscription;

  String? _currentContractId;

  SignatureBloc({
    SignatureService? signatureService,
  })  : _signatureService = signatureService ?? SignatureService(),
        super(SignatureState()) {
    on<WatchContractSignatureRequested>(_onWatchContractSignatureRequested);
    on<SignatureSnapshotReceived>(_onSignatureSnapshotReceived);
    on<RefreshSignatureStatusRequested>(_onRefreshSignatureStatusRequested);
    on<RefreshCurrentSignatureStatusRequested>(
      _onRefreshCurrentSignatureStatusRequested,
    );
    on<StopWatchingSignatureRequested>(_onStopWatchingSignatureRequested);
  }

  Future<void> _onWatchContractSignatureRequested(
    WatchContractSignatureRequested event,
    Emitter<SignatureState> emit,
  ) async {
    _currentContractId = event.contractId;

    emit(
      state.copyWith(
        status: SignatureStatus.loading,
        isListening: false,
        clearError: true,
      ),
    );

    await _signatureSubscription?.cancel();

    _signatureSubscription = _signatureService
        .watchContractSignature(event.contractId)
        .listen(
      (signature) {
        add(SignatureSnapshotReceived(signature));
      },
      onError: (error) {
        emit(
          state.copyWith(
            status: SignatureStatus.failure,
            errorMessage: error.toString(),
            isListening: false,
          ),
        );
      },
    );

    emit(
      state.copyWith(
        status: SignatureStatus.listening,
        isListening: true,
      ),
    );
  }

  void _onSignatureSnapshotReceived(
    SignatureSnapshotReceived event,
    Emitter<SignatureState> emit,
  ) {
    if (event.signature == null) {
      emit(
        state.copyWith(
          status: SignatureStatus.failure,
          errorMessage: 'No se encontró información de firma para el contrato.',
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        status: SignatureStatus.success,
        signature: event.signature,
        isListening: true,
        isRefreshing: false,
        clearError: true,
      ),
    );
  }

  Future<void> _onRefreshSignatureStatusRequested(
    RefreshSignatureStatusRequested event,
    Emitter<SignatureState> emit,
  ) async {
    _currentContractId = event.contractId;

    emit(
      state.copyWith(
        status: SignatureStatus.refreshing,
        isRefreshing: true,
        clearError: true,
      ),
    );

    try {
      await _signatureService.refreshViafirmaStatus(
        contractId: event.contractId,
      );

      emit(
        state.copyWith(
          status: SignatureStatus.success,
          isRefreshing: false,
          clearError: true,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: SignatureStatus.failure,
          isRefreshing: false,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  Future<void> _onRefreshCurrentSignatureStatusRequested(
    RefreshCurrentSignatureStatusRequested event,
    Emitter<SignatureState> emit,
  ) async {
    final contractId = _currentContractId;

    if (contractId == null || contractId.isEmpty) {
      return;
    }

    add(RefreshSignatureStatusRequested(contractId));
  }

  Future<void> _onStopWatchingSignatureRequested(
    StopWatchingSignatureRequested event,
    Emitter<SignatureState> emit,
  ) async {
    await _signatureSubscription?.cancel();
    _signatureSubscription = null;
    _currentContractId = null;

    emit(
      state.copyWith(
        status: SignatureStatus.initial,
        isListening: false,
      ),
    );
  }

  @override
  Future<void> close() {
    _signatureSubscription?.cancel();
    return super.close();
  }
}