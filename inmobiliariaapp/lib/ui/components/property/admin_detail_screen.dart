import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inmobiliariaapp/bloc/contractBloc/contract_bloc.dart';
import 'package:inmobiliariaapp/bloc/contractBloc/contract_event.dart';
import 'package:inmobiliariaapp/bloc/contractBloc/contract_state.dart';
import 'package:inmobiliariaapp/enum/application_status.dart';
import 'package:inmobiliariaapp/ui/components/contract/contract_status_card.dart';
import 'package:inmobiliariaapp/ui/components/pdf/doc_tile.dart';
import 'package:inmobiliariaapp/ui/components/contract/upload_contract_card.dart';
import 'package:inmobiliariaapp/utils/format_extensions.dart';

class AdminDetailScreen extends StatelessWidget {
  final ContractState state;
  const AdminDetailScreen({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Gestión de Trámite")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Resumen Superior
            _buildHeader(),
            const SizedBox(height: 25),

            // SECCIÓN 1: DOCUMENTACIÓN TÉCNICA
            const Text(
              "Soportes del Trámite",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),

            // Documentos del Propietario
            DocTile(
              title: "Propiedad (Propietario)",
              path: state.propertyDocsPath,
              color: Colors.orange,
              icon: Icons.home_work,
            ),

            // Documentos del Inquilino (Extractos y Cédula)
            DocTile(
              title: "Solvencia (Inquilino)",
              path: state.tenantDocsPath,
              color: Colors.blue,
              icon: Icons.account_balance,
              subtitle: state.isStudyPaid
                  ? "PAGO ESTUDIO CONFIRMADO"
                  : "PAGO PENDIENTE",
            ),

            const SizedBox(height: 25),
            const Divider(),

            // SECCIÓN 2: ACCIONES DE ABOGADO
            const Text(
              "Acciones Administrativas",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 15),

            // Fase: Revisión inicial (Aprobar/Rechazar)
            if (state.status == ApplicationStatus.waitingAdminReview)
              _buildApprovalActions(context),

            // Fase: Subir contrato legal
            if (state.status == ApplicationStatus.draftPending)
              UploadContractCard(
                title: "Cargar Contrato Final",
                subtitle: "Este PDF será el que firmen las partes.",
                eventToDispatch: UploadDraftEvent(""),
              ),

            // Visualizar el contrato si ya existe
            if (state.pdfPath != null)
              DocTile(
                title: "Contrato Legal Generado",
                path: state.pdfPath,
                color: Colors.red,
                icon: Icons.gavel,
              ),

            const SizedBox(height: 20),
            // Fase: Seguimiento de firmas
            if (state.status == ApplicationStatus.waitingTenantSign ||
                state.status == ApplicationStatus.finalReview)
              ContractStatusCard(state: state),
          ],
        ),
      ),
    );
  }

  // --- COMPONENTES INTERNOS ---

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _infoRow("Dirección:", "Calle 100 #15-30"),
          _infoRow("Propietario:", "Juan Propietario"),
          _infoRow("Inquilino:", "Pedro Candidato"),
          _infoRow("Canon:", FormatUtils.formatCurrency(state.canonAmount)),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildApprovalActions(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              context.read<ContractBloc>().add(ApproveCandidacyEvent());
              Navigator.pop(context);
            },
            child: const Text("APROBAR TODO"),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              side: const BorderSide(color: Colors.red),
            ),
            onPressed: () => _showRejectDialog(context),
            child: const Text("RECHAZAR"),
          ),
        ),
      ],
    );
  }

  void _showRejectDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Rechazar Solicitud"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: "Motivo (ej: PDF ilegible)",
          ),
          maxLines: 2,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              context.read<ContractBloc>().add(
                RejectContractEvent(controller.text),
              );
              Navigator.pop(dialogContext);
            },
            child: const Text("Rechazar"),
          ),
        ],
      ),
    );
  }
}
