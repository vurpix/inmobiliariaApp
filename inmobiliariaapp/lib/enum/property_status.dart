enum PropertyStatusEnum {
  pendingReview,
  rejected,
  approvedPendingPayment,
  paidPendingReview,
  waitingContract,
  waitingSignature,     // <-- Nuevo: Propietario debe firmar
  signedPendingReview,  // <-- Nuevo: Admin debe revisar firma
  signatureRejected,  // <-- Nuevo: Admin debe revisar firma
  signatureRejectedTenant,  // <-- Nuevo: Admin debe revisar firma
  active,
  pendingActivation, // <-- Nuevo: Propiedad pendiente de reactivación
  inactive
}