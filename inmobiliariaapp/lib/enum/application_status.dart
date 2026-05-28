enum ApplicationStatus {
  pendingReview,       // Esperando pago del estudio por el inquilino
  paymentPending,       // Esperando pago del estudio por el inquilino
  waitingAdminReview,   // Abogado revisando documentos y pago
  underInvestigation,   // En estudio de seguridad/crédito
  approved,             // Perfil aprobado, listo para contrato
  draftPending,         // Abogado redactando/subiendo el PDF
  waitingTenantSign,    // Esperando firma del arrendatario
  finalReview,          // Abogado validando firmas
  completed,            // ¡Contrato firmado y entregado!
  rejected,             // Rechazado en cualquier punto
  cancelled             // Cancelado por el usuario
}