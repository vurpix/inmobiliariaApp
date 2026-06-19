import 'package:flutter/material.dart';
import 'package:inmobiliariaapp/enum/contract_status.dart';
import 'package:inmobiliariaapp/enum/property_status.dart';
import 'package:inmobiliariaapp/models/contract_model.dart';
import 'package:inmobiliariaapp/ui/components/pdf/Pdf_view_screen.dart';
import 'package:inmobiliariaapp/ui/components/pdf/pdf_action_buttons.dart';
import 'package:inmobiliariaapp/utils/format_extensions.dart';
import 'package:inmobiliariaapp/utils/themes.dart';
import 'package:inmobiliariaapp/ui/components/global/custom_text.dart';
// import 'package:inmobiliariaapp/enums/property_status_enum.dart';

class ContractDetailViewScreen extends StatelessWidget {
  final ContractModel contract;

  const ContractDetailViewScreen({super.key, required this.contract});

  @override
  Widget build(BuildContext context) {
    final bool isActive = contract.status == ContractStatus.active.name;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: CustomText(
          "Expediente de Contrato",
          baseFontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        backgroundColor:
            context.primaryColor, // Hereda el color principal del tema
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (isActive)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Icon(Icons.verified, color: Colors.greenAccent, size: 22),
            ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
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
                    valueColor: context.successColor,
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
            if (contract.tenant != null) ...[
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
                    if (contract.tenant!.extractPdfUrl != null &&
                        contract.tenant!.extractPdfUrl!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _buildFileAction(
                        context: context,
                        label: "Ver Extractos Bancarios",
                        url: contract.tenant!.extractPdfUrl!,
                        color: Colors.blueGrey,
                        icon: Icons.account_balance_wallet_outlined,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // SECCIÓN DE DOCUMENTOS Y FIRMAS
            _buildSection(
              title: "Documentos y Trazabilidad de Firmas",
              icon: Icons.history_edu_rounded,
              context: context,
              child: Column(
                children: [
                  _buildFileAction(
                    context: context,
                    label: "1. Borrador Original (Abogado)",
                    url: contract.baseContractPdfUrl ?? '',
                    color: context.secondaryColor,
                    icon: Icons.gavel,
                    enabled:
                        contract.baseContractPdfUrl != null &&
                        contract.baseContractPdfUrl!.isNotEmpty,
                  ),
                  const SizedBox(height: 10),
                  _buildFileAction(
                    context: context,
                    label: "2. Firmado por Arrendador",
                    url: contract.ownerSignedPdfUrl ?? '',
                    color: context.primaryColor,
                    icon: Icons.drive_file_rename_outline,
                    enabled:
                        contract.ownerSignedPdfUrl != null &&
                        contract.ownerSignedPdfUrl!.isNotEmpty,
                    subtitle:
                        contract.ownerSignedPdfUrl == null ||
                            contract.ownerSignedPdfUrl!.isEmpty
                        ? "Pendiente de firma del Propietario"
                        : "Firma cargada y registrada",
                  ),
                  const SizedBox(height: 10),
                  _buildFileAction(
                    context: context,
                    label: "3. Contrato Final (Inquilino)",
                    url: contract.tenantSignedPdfUrl ?? '',
                    color: context.successColor,
                    icon: Icons.assignment_turned_in_rounded,
                    enabled:
                        contract.tenantSignedPdfUrl != null &&
                        contract.tenantSignedPdfUrl!.isNotEmpty,
                    subtitle:
                        contract.tenantSignedPdfUrl == null ||
                            contract.tenantSignedPdfUrl!.isEmpty
                        ? "Esperando firma del inquilino"
                        : "Contrato Legalizado en Sistema",
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // --- WIDGETS AUXILIARES ---

  Widget _buildStatusHeader(BuildContext context) {
    final String status = contract.status;
    Color statusColor = Colors.blueGrey;
    String statusText = status.toUpperCase();

    // --- 1. ESTADOS DE ÉXITO o ACTIVOS (Verde) ---
    if (status == ContractStatus.active.name ||
        status == PropertyStatusEnum.active.name ||
        status == ContractStatus.approved.name ||
        status == 'approved') {
      statusColor = context.successColor;
      statusText = "CONTRATO ACTIVO";

      // --- 2. ESTADOS DE ERROR, RECHAZO o TERMINADOS (Rojo) ---
    } else if (status.contains('rejected') ||
        status == PropertyStatusEnum.rejected.name ||
        status == ContractStatus.signatureRejectedTenant.name ||
        status == PropertyStatusEnum.signatureRejectedTenant.name ||
        status == ContractStatus.signatureRejected.name ||
        status == PropertyStatusEnum.signatureRejected.name ||
        status == ContractStatus.terminated.name ||
        status == PropertyStatusEnum.inactive.name) {
      statusColor = context.errorColor;
      statusText = "RECHAZADO / REVISIÓN REQUERIDA";

      // --- 3. ESTADOS DE ALERTA, ACCIÓN DEL ADMIN o REVISIONES (Naranja) ---
    } else if (status == ContractStatus.signedPendingReview.name ||
        status == PropertyStatusEnum.signedPendingReview.name ||
        status == PropertyStatusEnum.paidPendingReview.name ||
        status == PropertyStatusEnum.pendingReview.name ||
        status == ContractStatus.waitingContract.name ||
        status == PropertyStatusEnum.waitingContract.name ||
        status == 'pendingReview') {
      statusColor = Colors.orange[800]!;
      statusText = "CONTRATO POR REVISAR";

      // --- 4. ESTADOS EN ESPERA DE FIRMAS O ACCIÓN DEL USUARIO (Azul) ---
    } else if (status == ContractStatus.waitingTenantSignature.name ||
        status == ContractStatus.waitingOwnerSignature.name ||
        status == PropertyStatusEnum.waitingSignature.name ||
        status == PropertyStatusEnum.approvedPendingPayment.name ||
        status == PropertyStatusEnum.pendingActivation.name ||
        status == 'pending_signature' ||
        status == 'waiting_signature') {
      statusColor = Colors.blue[600]!;
      statusText = "PROCESO DE FIRMAS EN CURSO";

      // --- 5. ESTADO INICIAL (Gris) ---
    } else if (status == ContractStatus.searchingCandidates.name ||
        status == 'searching_candidates') {
      statusColor = Colors.blueGrey;
      statusText = "BUSCANDO CANDIDATOS";
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: statusColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: statusColor.withOpacity(0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          const Icon(Icons.description_rounded, color: Colors.white, size: 36),
          const SizedBox(height: 8),
          CustomText(
            statusText,
            baseFontSize: 15,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          CustomText(
            "ID EXPEDIENTE: ${contract.id?.toUpperCase() ?? 'N/A'}",
            baseFontSize: 11,
            color: Colors.white.withOpacity(0.8),
            textAlign: TextAlign.center,
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
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: context.primaryColor, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: CustomText(
                  title,
                  baseFontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const Divider(height: 24, thickness: 0.8),
          child,
        ],
      ),
    );
  }

  Widget _infoTile(
    String label,
    String value,
    BuildContext context, {
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CustomText(label, baseFontSize: 13, color: Colors.grey[500]!),
          const SizedBox(width: 16),
          Expanded(
            child: CustomText(
              value,
              baseFontSize: 13,
              fontWeight: FontWeight.bold,
              color: valueColor ?? Colors.blueGrey.shade800,
              textAlign: Alignment.centerRight == Alignment.centerRight
                  ? TextAlign.end
                  : TextAlign.start,
              overflow: TextOverflow.ellipsis,
              maxLines:
                  2, // Permite dos líneas antes de cortar si la dirección es muy larga
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileAction({
    required BuildContext context,
    required String label,
    required String url,
    required Color color,
    required IconData icon,
    bool enabled = true,
    String? subtitle,
  }) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.45,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: enabled ? color.withOpacity(0.2) : Colors.grey.shade200,
          ),
          color: enabled ? color.withOpacity(0.04) : Colors.grey.shade50,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: enabled
                  ? () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PdfViewScreen(path: url),
                      ),
                    )
                  : null,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(icon, color: enabled ? color : Colors.grey, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 6,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CustomText(
                            label,
                            baseFontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: enabled ? color : Colors.grey.shade700,
                          ),
                          if (subtitle != null) ...[
                            const SizedBox(height: 2),
                            CustomText(
                              subtitle,
                              baseFontSize: 10,
                              color: Colors.grey[500]!,
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (enabled && url.isNotEmpty)
                      Expanded(
                        flex: 4,
                        child: Align(
                          alignment: Alignment.centerRight,
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
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
