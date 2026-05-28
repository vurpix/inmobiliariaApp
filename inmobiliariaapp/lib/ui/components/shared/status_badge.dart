import 'package:flutter/material.dart';
import 'package:inmobiliariaapp/enum/application_status.dart';

class StatusBadge extends StatelessWidget {
  final ApplicationStatus status;
  const StatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    // Definimos el color y el texto según el estado real del contrato
    Color backgroundColor;
    Color textColor;
    String label;

    switch (status) {
      case ApplicationStatus.pendingReview:
        backgroundColor = Colors.grey[200]!;
        textColor = Colors.grey[700]!;
        label = "PENDIENTE DE REVISIÓN";
        break;
      case ApplicationStatus.paymentPending:
        backgroundColor = Colors.grey[200]!;
        textColor = Colors.grey[700]!;
        label = "PENDIENTE DE PAGO";
        break;
      case ApplicationStatus.waitingAdminReview:
        backgroundColor = Colors.orange[100]!;
        textColor = Colors.orange[900]!;
        label = "EN REVISIÓN LEGAL";
        break;
      // --- CASOS FALTANTES AGREGADOS AQUÍ ---
      case ApplicationStatus.underInvestigation:
        backgroundColor = Colors.indigo[100]!;
        textColor = Colors.indigo[900]!;
        label = "EN ESTUDIO DE CRÉDITO";
        break;
      case ApplicationStatus.approved:
        backgroundColor = Colors.lightGreen[100]!;
        textColor = Colors.lightGreen[900]!;
        label = "PERFIL APROBADO";
        break;
      case ApplicationStatus.cancelled:
        backgroundColor = Colors.blueGrey[100]!;
        textColor = Colors.blueGrey[800]!;
        label = "CANCELADO";
        break;
      // --------------------------------------
      case ApplicationStatus.rejected:
        backgroundColor = Colors.red[100]!;
        textColor = Colors.red[900]!;
        label = "RECHAZADO";
        break;
      case ApplicationStatus.draftPending:
        backgroundColor = Colors.purple[100]!;
        textColor = Colors.purple[900]!;
        label = "REDACTANDO CONTRATO";
        break;
      case ApplicationStatus.waitingTenantSign:
        backgroundColor = Colors.blue[100]!;
        textColor = Colors.blue[900]!;
        label = "ESPERANDO FIRMA";
        break;
      case ApplicationStatus.finalReview:
        backgroundColor = Colors.cyan[100]!;
        textColor = Colors.cyan[900]!;
        label = "VERIFICANDO FIRMAS";
        break;
      case ApplicationStatus.completed:
        backgroundColor = Colors.green[100]!;
        textColor = Colors.green[900]!;
        label = "ARRENDADO / FINALIZADO";
        break;
    }

    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20), // Estilo "Pill" más moderno
        border: Border.all(color: textColor.withOpacity(0.2)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.bold,
          color: textColor,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
