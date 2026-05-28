// components/pending_signature_banner.dart
import 'package:flutter/material.dart';
import 'package:inmobiliariaapp/models/contract_model.dart';
import 'package:inmobiliariaapp/enum/contract_status.dart'; // Tu enum de estados
import 'package:inmobiliariaapp/ui/components/contract/tenant_contract_details_screen.dart';
import 'package:inmobiliariaapp/ui/components/global/custom_text.dart'; // Componente de marca unificado
import 'package:inmobiliariaapp/utils/themes.dart';

class PendingSignatureBanner extends StatelessWidget {
  final ContractModel contract;

  const PendingSignatureBanner({super.key, required this.contract});

  @override
  Widget build(BuildContext context) {
    // 1. EVALUACIÓN DE CONTROL: Detectamos si el documento fue rechazado por el abogado
    final bool isRejected =
        contract.status == ContractStatus.signatureRejected.name;

    // 2. CONFIGURACIÓN VISUAL DINÁMICA
    final Color backgroundColor = isRejected
        ? context.errorColor
        : Colors.green[600]!;
    final Color buttonForegroundColor = isRejected
        ? context.errorColor
        : Colors.green[800]!;
    final IconData bannerIcon = isRejected
        ? Icons.gavel_rounded
        : Icons.assignment_turned_in_rounded;

    final String bannerText = isRejected
        ? "Tu firma fue rechazada por inconsistencias. Por favor, revisa y vuelve a subir el PDF."
        : "¡Felicidades! Has sido aprobado. Firma tu contrato legal de arriendo ahora.";

    final String buttonText = isRejected ? "CORREGIR" : "FIRMAR";

    return AnimatedContainer(
      duration: const Duration(
        milliseconds: 250,
      ), // Suaviza la transición si el estado cambia en caliente
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      color: backgroundColor,
      child: Row(
        children: [
          Icon(bannerIcon, color: Colors.white, size: 24),
          const SizedBox(width: 14),
          Expanded(
            child: CustomText(
              bannerText,
              color: Colors.white,
              fontWeight: FontWeight.bold,
              baseFontSize: 13,
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            height: 38,
            child: ElevatedButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      TenantContractDetailsScreen(contract: contract),
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: buttonForegroundColor,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                textStyle: const TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  letterSpacing: 0.3,
                ),
              ),
              child: Text(buttonText),
            ),
          ),
        ],
      ),
    );
  }
}
