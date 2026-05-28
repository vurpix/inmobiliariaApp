// blocs/contract_bloc.dart
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inmobiliariaapp/enum/application_status.dart';
import 'contract_event.dart';
import 'contract_state.dart';

class ContractBloc extends Bloc<ContractEvent, ContractState> {
  ContractBloc() : super(const ContractState()) {
    // --- 0. CARGA INICIAL (AHORA INDEPENDIENTE) ---
    on<LoadContractData>((event, emit) {
      emit(state.copyWith(isLoading: true));

      // Inicializamos el estado con valores por defecto o dinámicos basados en la petición
      emit(
        state.copyWith(
          status: ApplicationStatus.pendingReview, // Estado inicial por defecto
          pdfPath: null,
          propertyDocsPath: null,
          tenantDocsPath: null,
          isStudyPaid: false,
          canonAmount: 0.0,
          rejectionReason: null,
          isLoading: false,
        ),
      );
    });

    // --- 1. ARRENDADOR: DOCUMENTOS INMUEBLE ---
    on<UploadPropertyDocsEvent>((event, emit) {
      emit(state.copyWith(propertyDocsPath: event.path));
    });

    // --- 2. ARRENDADOR: PAGO RESERVA ---
    on<PayReservationEvent>((event, emit) {
      emit(
        state.copyWith(
          status: ApplicationStatus.waitingAdminReview,
          canonAmount: event.canon,
        ),
      );
    });

    // --- 3. INQUILINO: DOCUMENTOS PERSONALES ---
    on<UploadTenantDocsEvent>((event, emit) {
      emit(state.copyWith(tenantDocsPath: event.path));
    });

    // --- 4. INQUILINO: PAGO ESTUDIO ---
    on<PayTenantStudyEvent>((event, emit) {
      emit(state.copyWith(isStudyPaid: true));
    });

    // --- 5. ABOGADO: RECHAZO ---
    on<RejectContractEvent>((event, emit) {
      emit(
        state.copyWith(
          status: ApplicationStatus.rejected,
          rejectionReason: event.reason,
        ),
      );
    });

    // --- 6. ABOGADO: APROBACIÓN ---
    on<ApproveCandidacyEvent>((event, emit) {
      emit(state.copyWith(status: ApplicationStatus.draftPending));
    });

    // --- 7. ABOGADO: SUBIR CONTRATO ---
    on<UploadDraftEvent>((event, emit) {
      emit(
        state.copyWith(
          status: ApplicationStatus.waitingTenantSign,
          pdfPath: event.path,
        ),
      );
    });

    // --- 8. INQUILINO: FIRMA ---
    on<SignContractEvent>((event, emit) {
      emit(
        state.copyWith(
          status: ApplicationStatus.finalReview,
          signatureBytes: event.signatureBytes,
        ),
      );
    });

    // --- 9. FINALIZACIÓN ---
    on<FinalizeContractEvent>((event, emit) {
      emit(state.copyWith(status: ApplicationStatus.completed));
    });
  }
}
