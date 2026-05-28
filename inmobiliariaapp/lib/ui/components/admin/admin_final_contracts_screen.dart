import 'package:flutter/material.dart';
import 'package:inmobiliariaapp/models/contract_model.dart';
import 'package:inmobiliariaapp/services/contract_service.dart';
import 'package:inmobiliariaapp/ui/components/pdf/Pdf_view_screen.dart';
import 'package:inmobiliariaapp/ui/components/admin/contract_detail_view_screen.dart';
import 'package:inmobiliariaapp/utils/format_extensions.dart';

class AdminFinalContractsScreen extends StatefulWidget {
  const AdminFinalContractsScreen({super.key});

  @override
  State<AdminFinalContractsScreen> createState() =>
      _AdminFinalContractsScreenState();
}

class _AdminFinalContractsScreenState extends State<AdminFinalContractsScreen> {
  final ContractService _contractService = ContractService();

  // Formateador de moneda


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: StreamBuilder<List<ContractModel>>(
        stream: _contractService.watchAllContracts(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final contracts = snapshot.data ?? [];

          if (contracts.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.gavel_rounded, size: 80, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  const Text(
                    "No hay contratos registrados",
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: contracts.length,
            itemBuilder: (context, index) {
              return _buildContractLegalCard(context, contracts[index]);
            },
          );
        },
      ),
    );
  }

  Widget _buildContractLegalCard(BuildContext context, ContractModel contract) {
    final DateTime createdAt = contract.createdAt;
    final String status = contract.status;

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ContractDetailViewScreen(contract: contract),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          children: [
            // --- ENCABEZADO TIPO CERTIFICADO ---
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _getStatusColor(status).withOpacity(0.1),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: _getStatusColor(status),
                    child: const Icon(
                      Icons.gavel_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "CONTRATO: ${contract.id?.substring(0, 8).toUpperCase() ?? 'N/A'}",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            letterSpacing: 1,
                          ),
                        ),
                        Text(
                          "Creado el: ${createdAt.toFullDateTime()}",
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildStatusBadge(status),
                ],
              ),
            ),

            // --- CUERPO DEL CONTRATO ---
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Info del Canon
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Valor del Canon:",
                        style: TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                      Text(
                        FormatUtils.formatCurrency(contract.canonAmount),
                        style: TextStyle(
                          color: Colors.green[700],
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),

                  // Participantes usando el modelo
                  _buildParticipantRow(
                    "ID Propietario:",
                    contract.ownerId,
                    Icons.account_circle_outlined,
                  ),
                  const SizedBox(height: 8),
                  _buildParticipantRow(
                    "Nombre Inquilino:",
                    contract.tenant?.nombre ?? "Pendiente por asignar",
                    Icons.person_pin_circle_outlined,
                  ),
                  const SizedBox(height: 4),
                  _buildParticipantRow(
                    "ID Inquilino:",
                    contract.tenant?.uid ?? "Pendiente",
                    Icons.fingerprint,
                  ),
                ],
              ),
            ),

            // --- BOTONES DE DOCUMENTOS (PDF) ---
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(20),
                ),
              ),
              child: IntrinsicHeight(
                child: Row(
                  children: [
                    Expanded(
                      child: _buildPdfActionButton(
                        context,
                        "CONTRATO BASE",
                        contract.baseContractPdfUrl,
                        Colors.blueGrey,
                      ),
                    ),
                    const VerticalDivider(width: 1, indent: 10, endIndent: 10),
                    Expanded(
                      child: _buildPdfActionButton(
                        context,
                        "CONTRATO FIRMADO",
                        contract.tenantSignedPdfUrl,
                        Colors.indigo,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildParticipantRow(String label, String id, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            id,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.blueGrey,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(String status) {
    String text = "";
    switch (status) {
      case 'signedPendingReview':
        text = "POR REVISAR";
        break;
      case 'active':
        text = "ACTIVO";
        break;
      case 'pending_signature':
        text = "PEND. FIRMA";
        break;
      case 'searching_candidates':
        text = "BUSCANDO CANDIDATOS";
        break;
      case 'waiting_signature':
        text = "ESPERANDO FIRMA";
        break;
      default:
        text = status.toUpperCase();
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _getStatusColor(status),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'signedPendingReview':
        return Colors.orange[800]!;
      case 'active':
        return Colors.green[700]!;
      case 'rejected':
        return Colors.red;
      case 'pending_signature':
        return Colors.blue[600]!;
      default:
        return Colors.blueGrey;
    }
  }

  Widget _buildPdfActionButton(
    BuildContext context,
    String label,
    String? url,
    Color color,
  ) {
    bool hasUrl = url != null && url.isNotEmpty;
    return TextButton.icon(
      onPressed: hasUrl
          ? () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => PdfViewScreen(path: url)),
            )
          : null,
      icon: Icon(
        Icons.picture_as_pdf_rounded,
        size: 18,
        color: hasUrl ? color : Colors.grey[400],
      ),
      label: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: hasUrl ? color : Colors.grey[400],
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
