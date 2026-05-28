import 'package:flutter/material.dart';

class StatusFormatter {
  // --- 1. TRADUCCIÓN DE TEXTOS PARA PROPIEDADES ---
  static String formatPropertyStatus(String status) {
    switch (status.toLowerCase().replaceAll('_', '')) {
      // Fase de Revisión Inicial
      case 'pendingreview':
        return "Revisión Jurídica Pendiente";
      case 'rejected':
        return "Documentación Rechazada";

      // Fase de Pagos de Activación
      case 'approvedpendingpayment':
        return "Aprobado (Esperando Pago)";
      case 'paidpendingreview':
        return "Pago Recibido (Validar)";

      // Fase de Contratación Pública
      case 'waitingcontract':
        return "En Contratación";

      // Fase Legal y de Firmas
      case 'waitingsignature':
        return "Firma de Contrato Pendiente";
      case 'signedpendingreview':
        return "Firma Entregada (En Verificación)";
      case 'signaturerejected':
        return "Firma Rechazada (Corregir)";

      // Estados Finales y de Salida
      case 'active':
        return "Publicado / Activo";
      case 'pendingactivation':
        return "Pendiente de Activación";
      case 'inactive':
        return "Publicación Inactiva";

      default:
        return status.replaceAll('_', ' ').toUpperCase();
    }
  }

  // --- 2. COLORES SEGÚN EL ESTADO (Para Badges o Iconos) ---
  static Color getPropertyStatusColor(String status) {
    switch (status.toLowerCase().replaceAll('_', '')) {
      case 'active':
        return Colors.green;

      case 'pendingreview':
      case 'paidpendingreview':
      case 'signedpendingreview':
        return Colors.orange; // Procesos que esperan revisión del staff/admin

      case 'approvedpendingpayment':
      case 'pendingactivation':
        return Colors
            .blue; // Requieren acción económica/de activación del Propietario

      case 'waitingsignature':
      case 'waitingcontract':
        return Colors.teal; // Proceso legal de firmas

      case 'rejected':
      case 'signaturerejected':
        return Colors.red; // Alertas de rechazo o corrección

      case 'inactive':
      default:
        return Colors.grey;
    }
  }

  // --- 3. TRADUCCIÓN PARA CONTRATOS / APLICACIONES ---
  static String formatApplicationStatus(String status) {
    switch (status.toLowerCase().replaceAll('_', '')) {
      case 'paymentpending':
        return "Pendiente de Pago";
      case 'waitingadminreview':
        return "En Revisión Legal";
      case 'pendingreview':
        return "En Estudio de Crédito"; // Ajustado a tu requerimiento previo de "En Estudio"
      case 'approved':
        return "Perfil Aprobado";
      case 'completed':
        return "Finalizado / Firmado";
      case 'rejected':
        return "Solicitud Rechazada";
      default:
        return status.replaceAll('_', ' ').toUpperCase();
    }
  }
}
