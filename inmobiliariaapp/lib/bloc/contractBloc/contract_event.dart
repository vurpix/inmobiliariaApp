abstract class ContractEvent {}

// 0. CARGA INICIAL
class LoadContractData extends ContractEvent {
  final String contractId;
  LoadContractData(this.contractId);
}

// 1. ARRENDADOR: SUBIDA DE DOCUMENTOS (Escrituras, etc.)
class UploadPropertyDocsEvent extends ContractEvent {
  final String path;
  UploadPropertyDocsEvent(this.path);
}

// 2. ARRENDADOR: PAGO RESERVA Y CANON
class PayReservationEvent extends ContractEvent {
  final double canon; 
  PayReservationEvent(this.canon);
}

// 3. INQUILINO: SUBIDA DE DOCUMENTOS (Cédula, Laboral)
class UploadTenantDocsEvent extends ContractEvent {
  final String path;
  UploadTenantDocsEvent(this.path);
}

// 4. INQUILINO: PAGO DE ESTUDIO ($60,000)
class PayTenantStudyEvent extends ContractEvent {}

// 5. ABOGADO: APROBACIÓN INICIAL (Revisa ambos documentos)
class ApproveCandidacyEvent extends ContractEvent {}

// 6. ABOGADO: RECHAZO
class RejectContractEvent extends ContractEvent {
  final String reason;
  RejectContractEvent(this.reason);
}

// 7. ABOGADO: SUBE CONTRATO FINAL
class UploadDraftEvent extends ContractEvent {
  final String path;
  UploadDraftEvent(this.path);
}

// 8. INQUILINO: FIRMA
class SignContractEvent extends ContractEvent {
  final List<int> signatureBytes;
  SignContractEvent(this.signatureBytes);
}

// 9. ABOGADO: FINALIZACIÓN
class FinalizeContractEvent extends ContractEvent {}