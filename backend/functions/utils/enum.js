const ApplicationStatus = Object.freeze({
  paymentPending: "paymentPending", // Esperando pago del estudio por el inquilino
  waitingAdminReview: "waitingAdminReview", // Abogado revisando documentos y pago
  underInvestigation: "underInvestigation", // En estudio de seguridad/crédito
  approved: "approved", // Perfil aprobado, listo para contrato
  draftPending: "draftPending", // Abogado redactando/subiendo el PDF
  waitingTenantSign: "waitingTenantSign", // Esperando firma del arrendatario
  finalReview: "finalReview", // Abogado validando firmas
  completed: "completed", // ¡Contrato firmado y entregado!
  rejected: "rejected", // Rechazado en cualquier punto
  cancelled: "cancelled", // Cancelado por el usuario
});

const ContractStatus = Object.freeze({
  searchingCandidates: "searchingCandidates", // Buscando postulantes para la propiedad
  waitingContract: "waitingContract", // El administrador está cargando el borrador legal (Abogado)
  waitingSignature: "waitingSignature", // El contrato fue enviado al propietario y espera su firma
  signedPendingReview: "signedPendingReview", // El propietario ya firmó y el administrador debe revisar el documento
  signatureRejected: "signatureRejected", // La firma fue rechazada por el administrador (requiere corrección)
  active: "active", // El contrato está legalizado y la propiedad está ocupada
  terminated: "terminated", // El contrato ha finalizado o ha sido cancelado
});

const PaymentStatusEnum = Object.freeze({
  pendingVerify: "pendingVerify",
  approved: "approved",
  rejected: "rejected",
});

const PropertyStatusEnum = Object.freeze({
  pendingReview: "pendingReview",
  rejected: "rejected",
  approvedPendingPayment: "approvedPendingPayment",
  paidPendingReview: "paidPendingReview",
  waitingContract: "waitingContract",
  waitingSignature: "waitingSignature", // Propietario debe firmar
  signedPendingReview: "signedPendingReview", // Admin debe revisar firma
  signatureRejected: "signatureRejected", // Firma rechazada
  active: "active",
  pendingActivation: "pendingActivation", // Propiedad pendiente de reactivación
  inactive: "inactive",
});

const UserRole = Object.freeze({
  admin: "admin",
  landlord: "landlord",
  tenant: "tenant",
});

// --- EXPORTACIÓN OFICIAL (CommonJS para Node.js plano) ---
module.exports = {
  ApplicationStatus,
  ContractStatus,
  PaymentStatusEnum,
  PropertyStatusEnum,
  UserRole,
};
