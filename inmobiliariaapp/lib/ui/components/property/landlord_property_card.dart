// components/property/landlord_property_card.dart
import 'package:flutter/material.dart';
import 'package:inmobiliariaapp/enum/property_status.dart';
import 'package:inmobiliariaapp/models/contract_model.dart';
import 'package:inmobiliariaapp/models/property_model.dart';
import 'package:inmobiliariaapp/services/contract_service.dart';
import 'package:inmobiliariaapp/ui/components/global/custom_button.dart';
import 'package:inmobiliariaapp/ui/components/property/landlord_property_detail_screen.dart';
import 'package:inmobiliariaapp/ui/components/property/property_detail_screen.dart';
import 'package:inmobiliariaapp/ui/pages/payment/property_payment_screen.dart';
import 'package:inmobiliariaapp/utils/format_extensions.dart';
import 'package:inmobiliariaapp/utils/status_formatter.dart';
import 'package:inmobiliariaapp/utils/themes.dart';
import 'package:inmobiliariaapp/ui/components/global/custom_text.dart';

class LandlordPropertyCard extends StatelessWidget {
  final PropertyModel property;
  final ContractService contractService;
  final Function(PropertyStatusEnum) friendlyStatusFormatter;
  final VoidCallback onEdit;

  const LandlordPropertyCard({
    super.key,
    required this.property,
    required this.contractService,
    required this.friendlyStatusFormatter,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ContractModel?>(
      stream: contractService.watchContractByProperty(property.id!),
      builder: (context, snapshot) {
        final contract = snapshot.data;

        // Determinamos el estado y texto del contrato dinámicamente para el botón
        String contractButtonText = "Sin Contrato";
        if (contract != null) {
          if (contract.status == "signedPendingReview")
            contractButtonText = "En Revisión";
          if (contract.status == "active") contractButtonText = "Activo";
          if (contract.status == "waitingSignature")
            contractButtonText = "Pendiente Firma";
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            color: context.surfaceColor,
            borderRadius: BorderRadius.circular(8),
            border: null,
            boxShadow: [
              BoxShadow(
                color: context.primaryColor.withOpacity(0.12),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              // Si hay contrato, toda la tarjeta también te lleva al detalle al pulsarla
              onTap: contract == null
                  ? () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            PropertyDetailScreen(property: property),
                      ),
                    )
                  : () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => LandlordPropertyDetailScreen(
                          contract: contract,
                          property: property,
                        ),
                      ),
                    ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- 1. SECCIÓN SUPERIOR: HERO IMAGE 16:9 ---
                  Stack(
                    children: [
                      AspectRatio(
                        aspectRatio: 16 / 9,
                        child: Container(
                          decoration: BoxDecoration(
                            image: DecorationImage(
                              image: NetworkImage(
                                property.imageUrls.isNotEmpty
                                    ? property.imageUrls.first
                                    : 'https://via.placeholder.com/600x400',
                              ),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 14,
                        left: 14,
                        child: _buildStatusBadge(context, property.status),
                      ),
                    ],
                  ),

                  // --- 2. SECCIÓN INTERMEDIA: DATOS DE LA PROPIEDAD ---
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CustomText.title(
                                    property.address,
                                    baseFontSize: ResponsiveUtils.getFontSize(
                                      context,
                                      16,
                                    ),
                                    color: context.primaryColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  Row(
                                    children: [
                                      CustomText(
                                        property.state,
                                        baseFontSize:
                                            ResponsiveUtils.getFontSize(
                                              context,
                                              12,
                                            ),
                                        color: context.textSecondaryColor,
                                      ),
                                      const SizedBox(width: 4),
                                      CustomText(
                                        property.city,
                                        baseFontSize:
                                            ResponsiveUtils.getFontSize(
                                              context,
                                              12,
                                            ),
                                        color: context.textSecondaryColor,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            CustomText.title(
                              property.canon.toCOP(),
                              baseFontSize: ResponsiveUtils.getFontSize(
                                context,
                                16,
                              ),
                              color: context.primaryColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        CustomText(
                          "Area: ${property.area} m²",
                          baseFontSize: 12,
                          color: context.textSecondaryColor,
                        ),
                      ],
                    ),
                  ),

                  // --- 3. BANNERS MODULARES DE PAGOS O RECHAZOS ---
                  _buildDynamicActionBanner(context),

                  // --- 4. ACCIONES PARALELAS INFERIORES (EDIT DETAILS / CONTRATO DINÁMICO) ---
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: CustomButton(
                            height: ResponsiveUtils.getHeight(context, 5.5),
                            backgroundColor: context.surfaceColor,
                            boxShadow: [
                              BoxShadow(
                                color: context.primaryColor.withOpacity(0.2),
                                blurRadius: 6,
                                offset: const Offset(0, 3),
                              ),
                            ], //
                            childText: CustomText(
                              "Editar Detalles",
                              baseFontSize: ResponsiveUtils.getFontSize(
                                context,
                                13,
                              ),
                              fontWeight: FontWeight.bold,
                              color: context.textColor,
                            ),
                            isLoading: false,
                            onPressed: onEdit,
                          ),
                        ),

                        const SizedBox(width: 12),

                        // Acción Derecha REFACTORIZADA: Botón de Contrato con Estados e Inyección de Ruta
                        Expanded(
                          child: CustomButton(
                            height: ResponsiveUtils.getHeight(context, 5.5),
                            backgroundColor: context.primaryColor,
                            boxShadow: [
                              BoxShadow(
                                color: context.primaryColor.withOpacity(0.2),
                                blurRadius: 6,
                                offset: const Offset(0, 3),
                              ),
                            ], //
                            childText: CustomText(
                              contractButtonText,
                              baseFontSize: ResponsiveUtils.getFontSize(
                                context,
                                13,
                              ),
                              maxLines: 1,
                              fontWeight: FontWeight.bold,
                              color: context.textColorWhite,
                            ),
                            isLoading: false,
                            onPressed: contract == null
                                ? null
                                : () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          LandlordPropertyDetailScreen(
                                            contract: contract,
                                            property: property,
                                          ),
                                    ),
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
        );
      },
    );
  }

  Widget _buildStatusBadge(BuildContext context, PropertyStatusEnum status) {
    final color = StatusFormatter.getPropertyStatusColor(status.name, context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        friendlyStatusFormatter(status),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Widget _buildDynamicActionBanner(BuildContext context) {
    if (property.status == PropertyStatusEnum.approvedPendingPayment) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: _buildBannerTemplate(
          context,
          label:
              "PENDIENTE DE PAGO\n El contrato se elabora 24 horas después de realizado el pago de los honorarios",
          icon: Icons.error_outline_rounded,
          color: context.errorColor,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PropertyPaymentScreen(property: property),
            ),
          ),
        ),
      );
    }
    if (property.status == PropertyStatusEnum.rejected) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: _buildBannerTemplate(
          context,
          label: "POR CORREGIR",
          icon: Icons.build_circle_outlined,
          color: Colors.orange[700]!,
          onTap: onEdit,
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildBannerTemplate(
    BuildContext context, {
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: CustomText(
                label,
                baseFontSize: 11,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, size: 10, color: color),
          ],
        ),
      ),
    );
  }
}
