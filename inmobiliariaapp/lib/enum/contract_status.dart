// enums/contract_status.dart

enum ContractStatus {
  /// Buscando postulantes para la propiedad
  searchingCandidates,

  /// El administrador está cargando el borrador legal (Abogado)
  waitingContract,

  /// El contrato fue enviado al Arrendatario (Inquilino) y espera su firma
  waitingTenantSignature,

  /// El contrato fue aprobado por el inquilino y ahora espera la firma del Propietario (Dueño)
  waitingOwnerSignature,

  /// El propietario ya firmó y el administrador debe revisar el documento final
  signedPendingReview,
  signatureRejectedTenant,

  /// La firma fue rechazada por el administrador (requiere corrección)
  signatureRejected,

  /// El contrato está legalizado y la propiedad está ocupada (Activa en el sistema)
  active,
  approved,

  /// El contrato ha finalizado o ha sido cancelado
  terminated,
}