import 'package:flutter/material.dart';
import 'package:inmobiliariaapp/enum/contract_status.dart';
import 'package:inmobiliariaapp/enum/property_status.dart';
import 'package:inmobiliariaapp/models/contract_model.dart';
import 'package:inmobiliariaapp/services/contract_service.dart';
import 'package:inmobiliariaapp/ui/components/pdf/Pdf_view_screen.dart';
import 'package:inmobiliariaapp/ui/components/admin/contract_detail_view_screen.dart';
import 'package:inmobiliariaapp/utils/format_extensions.dart';
import 'package:inmobiliariaapp/utils/themes.dart';
import 'package:inmobiliariaapp/ui/components/global/custom_button.dart';
import 'package:inmobiliariaapp/ui/components/global/custom_text.dart'; // Asumo que usas este para textos globales

class AdminFinalContractsScreen extends StatefulWidget {
  const AdminFinalContractsScreen({super.key});

  @override
  State<AdminFinalContractsScreen> createState() =>
      _AdminFinalContractsScreenState();
}

class _AdminFinalContractsScreenState extends State<AdminFinalContractsScreen> {
  final ContractService _contractService = ContractService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          Colors.grey[50], // Mantiene un fondo neutro premium limpio
      body: StreamBuilder<List<ContractModel>>(
        stream: _contractService.watchAllContracts(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final contracts = snapshot.data ?? [];

          if (contracts.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.gavel_rounded,
                      size: ResponsiveUtils.getWidth(context, 20),
                      color: Colors.grey[300],
                    ),
                    const SizedBox(height: 16),
                    CustomText(
                      "No hay contratos registrados",
                      baseFontSize: 14,
                      color: context.textSecondaryColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ],
                ),
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

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ContractDetailViewScreen(contract: contract),
                ),
              );
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- ENCABEZADO TIPO CERTIFICADO ---
                Container(
                  padding: const EdgeInsets.all(16),
                  color: _getStatusColor(context, status).withOpacity(0.08),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: CircleAvatar(
                          radius: 18,
                          backgroundColor: _getStatusColor(context, status),
                          child: const Icon(
                            Icons.gavel_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 5,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CustomText(
                              "CONTRATO: ${contract.id?.substring(0, 8).toUpperCase() ?? 'N/A'}",
                              baseFontSize: ResponsiveUtils.getFontSize(
                                context,
                                14,
                              ),
                              fontWeight: FontWeight.w900,
                            ),
                            const SizedBox(height: 2),
                            CustomText(
                              "Creado el: ${createdAt.toFullDateTime()}",
                              baseFontSize: ResponsiveUtils.getFontSize(
                                context,
                                12,
                              ),
                              color: context.textSecondaryColor,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 4,
                        child: _buildStatusBadge(context, status),
                      ),
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
                          CustomText(
                            "Valor del Canon:",
                            baseFontSize: 13,
                            color: context.textSecondaryColor,
                          ),
                          CustomText(
                            FormatUtils.formatCurrency(contract.canonAmount),
                            baseFontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: context.successColor,
                          ),
                        ],
                      ),
                      const Divider(height: 24, thickness: 0.8),

                      // Participantes usando el modelo
                      _buildParticipantRow(
                        context: context,
                        label: "ID Propietario:",
                        id: contract.ownerId,
                        icon: Icons.account_circle_outlined,
                      ),
                      const SizedBox(height: 10),
                      _buildParticipantRow(
                        context: context,
                        label: "Nombre Inquilino:",
                        id: contract.tenant?.nombre ?? "Pendiente por asignar",
                        icon: Icons.person_pin_circle_outlined,
                      ),
                      const SizedBox(height: 10),
                      _buildParticipantRow(
                        context: context,
                        label: "ID Inquilino:",
                        id: contract.tenant?.uid ?? "Pendiente",
                        icon: Icons.fingerprint,
                      ),
                    ],
                  ),
                ),

                // --- BOTONES DE DOCUMENTOS (MIGRADO A CUSTOMBUTTON RESPONSIVE) ---
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    border: Border(
                      top: BorderSide(color: Colors.grey.shade100),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: CustomButton(
                          height: ResponsiveUtils.getHeight(context, 5.0),
                          backgroundColor: Colors.transparent,
                          borderSide: BorderSide(
                            color: Colors.blueGrey.shade300,
                            width: 1.2,
                          ),
                          borderRadius: 10,
                          onPressed:
                              (contract.baseContractPdfUrl != null &&
                                  contract.baseContractPdfUrl!.isNotEmpty)
                              ? () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => PdfViewScreen(
                                      path: contract.baseContractPdfUrl!,
                                    ),
                                  ),
                                )
                              : null,
                          childText: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.picture_as_pdf_rounded,
                                size: 16,
                                color: Colors.blueGrey.shade700,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: CustomText(
                                  "CONTRATO BASE",
                                  baseFontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blueGrey.shade700,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: CustomButton(
                          height: ResponsiveUtils.getHeight(context, 5.0),
                          backgroundColor: context.primaryColor,
                          borderRadius: 10,
                          onPressed:
                              (contract.tenantSignedPdfUrl != null &&
                                  contract.tenantSignedPdfUrl!.isNotEmpty)
                              ? () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => PdfViewScreen(
                                      path: contract.tenantSignedPdfUrl!,
                                    ),
                                  ),
                                )
                              : null,
                          childText: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.draw_rounded,
                                size: 16,
                                color: context.textColorWhite,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: CustomText(
                                  "FIRMADO",
                                  baseFontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: context.textColorWhite,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildParticipantRow({
    required BuildContext context,
    required String label,
    required String id,
    required IconData icon,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[400]),
        const SizedBox(width: 8),
        CustomText(
          label,
          baseFontSize: 12,
          fontWeight: FontWeight.normal,
          color: context.textSecondaryColor,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: CustomText(
            id,
            baseFontSize: 11,
            color: Colors.blueGrey.shade600,
            overflow: TextOverflow.ellipsis,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(BuildContext context, String status) {
    String text = "";

    // 1. EVALUACIÓN CONTRA PROPERTYSTATUSENUM
    if (status == PropertyStatusEnum.pendingReview.name) {
      text = "EN REVISIÓN";
    } else if (status == PropertyStatusEnum.rejected.name) {
      text = "RECHAZADO";
    } else if (status == PropertyStatusEnum.approvedPendingPayment.name) {
      text = "PENDIENTE DE PAGO";
    } else if (status == PropertyStatusEnum.paidPendingReview.name) {
      text = "PAGO POR REVISAR";
    } else if (status == PropertyStatusEnum.pendingActivation.name) {
      text = "PEND. ACTIVACIÓN";
    } else if (status == PropertyStatusEnum.inactive.name) {
      text = "INACTIVO";

      // 2. EVALUACIÓN CONTRA CONTRACTSTATUS
    } else if (status == ContractStatus.searchingCandidates.name) {
      text = "BUSCANDO CANDIDATOS";
    } else if (status == ContractStatus.waitingContract.name ||
        status == PropertyStatusEnum.waitingContract.name) {
      text = "ESPERANDO CONTRATO";
    } else if (status == ContractStatus.waitingTenantSignature.name) {
      text = "PEND. FIRMA INQUILINO";
    } else if (status == ContractStatus.waitingOwnerSignature.name ||
        status == PropertyStatusEnum.waitingSignature.name) {
      text = "PEND. FIRMA DUEÑO";
    } else if (status == ContractStatus.signedPendingReview.name ||
        status == PropertyStatusEnum.signedPendingReview.name) {
      text = "CONTRATO POR REVISAR";
    } else if (status == ContractStatus.signatureRejectedTenant.name ||
        status == PropertyStatusEnum.signatureRejectedTenant.name) {
      text = "FIRMA RECHAZADA INQ.";
    } else if (status == ContractStatus.signatureRejected.name ||
        status == PropertyStatusEnum.signatureRejected.name) {
      text = "FIRMA RECHAZADA ADM.";
    } else if (status == ContractStatus.active.name ||
        status == PropertyStatusEnum.active.name) {
      text = "ACTIVO";
    } else if (status == ContractStatus.approved.name) {
      text = "APROBADO";
    } else if (status == ContractStatus.terminated.name) {
      text = "FINALIZADO";

      // 3. RESPALDO PARA STRINGS ANTIGUOS (SNAKE_CASE)
    } else if (status == 'pending_signature' || status == 'waiting_signature') {
      text = "PENDIENTE FIRMA";
    } else if (status == 'searching_candidates') {
      text = "BUSCANDO CANDIDATOS";
    } else {
      text = status.toUpperCase();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _getStatusColor(context, status),
        borderRadius: BorderRadius.circular(12),
      ),
      child: CustomText(
        text,
        baseFontSize: 9,
        fontWeight: FontWeight.bold,
        color: context.textColorWhite,
        textAlign: TextAlign.center,
      ),
    );
  }

  Color _getStatusColor(BuildContext context, String status) {
    // --- ESTADOS DE ÉXITO / ACTIVOS ---
    if (status == ContractStatus.active.name ||
        status == PropertyStatusEnum.active.name ||
        status == ContractStatus.approved.name) {
      return context.successColor;
    }

    // --- ESTADOS DE ERROR / RECHAZO / INACTIVOS ---
    if (status == ContractStatus.signatureRejected.name ||
        status == PropertyStatusEnum.signatureRejected.name ||
        status == ContractStatus.signatureRejectedTenant.name ||
        status == PropertyStatusEnum.signatureRejectedTenant.name ||
        status == PropertyStatusEnum.rejected.name ||
        status == ContractStatus.terminated.name ||
        status == PropertyStatusEnum.inactive.name ||
        status == 'rejected') {
      return context.errorColor;
    }

    // --- ESTADOS DE ADVERTENCIA / ACCIÓN DEL ADMINISTRADOR ---
    if (status == ContractStatus.signedPendingReview.name ||
        status == PropertyStatusEnum.signedPendingReview.name ||
        status == PropertyStatusEnum.paidPendingReview.name ||
        status == PropertyStatusEnum.pendingReview.name ||
        status == ContractStatus.waitingContract.name ||
        status == PropertyStatusEnum.waitingContract.name) {
      return Colors.orange[800]!;
    }

    // --- ESTADOS EN ESPERA DE ACCIÓN DEL USUARIO (Firmas / Pagos) ---
    if (status == ContractStatus.waitingTenantSignature.name ||
        status == ContractStatus.waitingOwnerSignature.name ||
        status == PropertyStatusEnum.waitingSignature.name ||
        status == PropertyStatusEnum.approvedPendingPayment.name ||
        status == PropertyStatusEnum.pendingActivation.name ||
        status == 'pending_signature' ||
        status == 'waiting_signature') {
      return Colors.blue[600]!;
    }

    // Color gris neutral por defecto (ej. searchingCandidates)
    return Colors.blueGrey;
  }
}
