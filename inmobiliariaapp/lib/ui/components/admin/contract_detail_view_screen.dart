import 'package:flutter/material.dart';
import 'package:inmobiliariaapp/models/contract_model.dart';
import 'package:inmobiliariaapp/ui/components/pdf/Pdf_view_screen.dart';
import 'package:inmobiliariaapp/ui/components/pdf/pdf_action_buttons.dart';
import 'package:inmobiliariaapp/utils/format_extensions.dart';
import 'package:inmobiliariaapp/utils/themes.dart';

class ContractDetailViewScreen extends StatelessWidget {
  final ContractModel contract;

  const ContractDetailViewScreen({super.key, required this.contract});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          "Expediente de Contrato",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: ResponsiveUtils.getFontSize(context, 20),
          ),
        ),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
        actions: [
          if (contract.status == 'active')
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Icon(Icons.verified, color: Colors.greenAccent),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildStatusHeader(context),
            const SizedBox(height: 16),
            _buildSection(
              title: "Inmueble y Liquidación",
              icon: Icons.home_work_rounded,
              context: context,
              child: Column(
                children: [
                  _infoTile("Dirección", contract.address, context),
                  _infoTile(
                    "Canon Mensual",
                    FormatUtils.formatCurrency(contract.canonAmount),
                    context,
                  ),
                  _infoTile(
                    "Depósito/Garantía",
                    FormatUtils.formatCurrency(contract.depositAmount),
                    context,
                  ),
                  _infoTile(
                    "Fecha Creación",
                    contract.createdAt.toShortDate(),
                    context,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // SECCIÓN DEL CANDIDATO (TENANT)
            if (contract.tenant != null)
              _buildSection(
                title: "Información del Inquilino",
                icon: Icons.person_search_rounded,
                context: context,
                child: Column(
                  children: [
                    _infoTile("Nombre", contract.tenant!.nombre, context),
                    _infoTile("Email", contract.tenant!.email, context),
                    _infoTile(
                      "Promoción",
                      contract.tenant!.isFreePromotion
                          ? "Aplica (Gratis)"
                          : "No aplica (Pagó)",
                      context,
                    ),
                    const SizedBox(height: 10),
                    if (contract.tenant!.extractPdfUrl != null)
                      _buildFileAction(
                        context,
                        "Ver Extractos Bancarios",
                        contract.tenant!.extractPdfUrl!,
                        Colors.blueGrey,
                        Icons.account_balance_wallet_outlined,
                      ),
                  ],
                ),
              ),

            const SizedBox(height: 16),

            // SECCIÓN DE DOCUMENTOS Y FIRMAS
            _buildSection(
              title: "Documentos y Trazabilidad de Firmas",
              icon: Icons.history_edu_rounded,
              context: context,
              child: Column(
                children: [
                  _buildFileAction(
                    context,
                    "1. Borrador Original (Abogado)",
                    contract.baseContractPdfUrl ?? '',
                    Colors.redAccent,
                    Icons.gavel,
                    enabled: contract.baseContractPdfUrl != null,
                  ),
                  const SizedBox(height: 8),
                  _buildFileAction(
                    context,
                    "2. Firmado por Arrendador",
                    contract.ownerSignedPdfUrl ?? '',
                    const Color(0xFF1A237E),
                    Icons.drive_file_rename_outline,
                    enabled: contract.ownerSignedPdfUrl != null,
                    subtitle: contract.ownerSignedPdfUrl == null
                        ? "Pendiente de firma del Propietario"
                        : "Firma cargada",
                  ),
                  const SizedBox(height: 8),
                  _buildFileAction(
                    context,
                    "3. Contrato Final (Inquilino)",
                    contract.tenantSignedPdfUrl ?? '',
                    Colors.green[700]!,
                    Icons.assignment_turned_in_rounded,
                    enabled: contract.tenantSignedPdfUrl != null,
                    subtitle: contract.tenantSignedPdfUrl == null
                        ? "Esperando firma del inquilino"
                        : "Contrato Legalizado",
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  // --- WIDGETS AUXILIARES ---

  Widget _buildStatusHeader(BuildContext context) {
    Color statusColor = Colors.orange;
    String statusText = "EN PROCESO";

    if (contract.status == 'active') {
      statusColor = Colors.green;
      statusText = "CONTRATO ACTIVO";
    } else if (contract.status.contains('rejected')) {
      statusColor = Colors.red;
      statusText = "RECHAZADO / CORREGIR";
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: statusColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          const Icon(Icons.description, color: Colors.white, size: 40),
          const SizedBox(height: 10),
          Text(
            statusText,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: ResponsiveUtils.getFontSize(context, 18),
            ),
          ),
          Text(
            "ID: ${contract.id?.toUpperCase()}",
            style: TextStyle(
              color: Colors.white70,
              fontSize: ResponsiveUtils.getFontSize(context, 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required Widget child,
    required BuildContext context,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF1A237E), size: 20),
              const SizedBox(width: 10),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: ResponsiveUtils.getFontSize(context, 14),
                ),
              ),
            ],
          ),
          const Divider(height: 25),
          child,
        ],
      ),
    );
  }

  Widget _infoTile(String label, String value, BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey,
              fontSize: ResponsiveUtils.getFontSize(context, 13),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: ResponsiveUtils.getFontSize(context, 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileAction(
    BuildContext context,
    String label,
    String url,
    Color color,
    IconData icon, {
    bool enabled = true,
    String? subtitle,
  }) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.4,
      child: InkWell(
        onTap: enabled
            ? () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => PdfViewScreen(path: url)),
              )
            : null,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.3)),
            color: color.withOpacity(0.05),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 12),
              Expanded(
                flex: 7,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: ResponsiveUtils.getFontSize(context, 10),
                        color: color,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: ResponsiveUtils.getFontSize(context, 9),
                          color: Colors.grey,
                        ),
                      ),
                  ],
                ),
              ),

              if (enabled)
                Expanded(
                  flex: 3,
                  child: PdfActionButtons(
                    url: url,
                    title: label,
                    propertyAddress: contract.address,
                    color: color,
                    downloadIcon: Icons.download_outlined,
                    viewIcon: Icons.visibility_outlined,
                    downloadIconSize: 16,
                    viewIconSize: 16,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
