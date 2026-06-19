// landlord_dashboard.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inmobiliariaapp/ui/components/auth_ux/notification_badge.dart';
import 'package:inmobiliariaapp/ui/components/global/custom_text.dart';
import 'package:inmobiliariaapp/ui/components/property/landlord_profile_header.dart';
import 'package:inmobiliariaapp/ui/components/property/landlord_property_card.dart';
import 'package:inmobiliariaapp/utils/format_extensions.dart';
import 'package:inmobiliariaapp/utils/themes.dart';

// Blocs y Modelos
import 'package:inmobiliariaapp/bloc/authBloc/auth_bloc.dart';
import 'package:inmobiliariaapp/bloc/authBloc/auth_event.dart';
import 'package:inmobiliariaapp/bloc/authBloc/auth_state.dart';
import 'package:inmobiliariaapp/bloc/propertyBloc/property_bloc.dart';
import 'package:inmobiliariaapp/bloc/propertyBloc/property_event.dart';
import 'package:inmobiliariaapp/bloc/propertyBloc/property_state.dart';
import 'package:inmobiliariaapp/enum/property_status.dart';
import 'package:inmobiliariaapp/models/property_model.dart';
import 'package:inmobiliariaapp/services/contract_service.dart';
import 'package:inmobiliariaapp/services/property_service.dart';

// Componentes Refactorizados Externos
import 'package:inmobiliariaapp/ui/components/property/addProperty_process_screen.dart';

class LandlordDashboard extends StatefulWidget {
  const LandlordDashboard({super.key});

  @override
  State<LandlordDashboard> createState() => _LandlordDashboardState();
}

class _LandlordDashboardState extends State<LandlordDashboard> {
  final ContractService _contractService = ContractService();
  final PropertyService _propertyService = PropertyService();

  String _getFriendlyStatusName(PropertyStatusEnum status) {
    switch (status) {
      case PropertyStatusEnum.pendingReview:
        return "EN REVISIÓN";
      case PropertyStatusEnum.rejected:
        return "POR CORREGIR";
      case PropertyStatusEnum.approvedPendingPayment:
        return "PENDIENTE DE PAGO";
      case PropertyStatusEnum.paidPendingReview:
        return "PAGO EN VERIFICACIÓN";
      case PropertyStatusEnum.waitingContract:
        return "GENERANDO CONTRATO";
      case PropertyStatusEnum.waitingSignature:
      case PropertyStatusEnum.signedPendingReview:
        return "PENDIENTE DE FIRMA";
      case PropertyStatusEnum.signatureRejected:
        return "FIRMA RECHAZADA";
      case PropertyStatusEnum.signatureRejectedTenant:
        return "FIRMA RECHAZADA";
      case PropertyStatusEnum.pendingActivation:
        return "PENDIENTE DE ACTIVACIÓN";
      case PropertyStatusEnum.active:
        return "PUBLICADA / ACTIVA";
      case PropertyStatusEnum.inactive:
        return "INACTIVA";
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    final bool isAuthenticated = authState is Authenticated;
    final String userId = isAuthenticated ? authState.user.id : '';

    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        centerTitle: false,
        title: CustomText.title(
          "Mis Propiedades",
          baseFontSize: ResponsiveUtils.getFontSize(context, 20),
          color: context.primaryColor,
          fontWeight: FontWeight.w900,
        ),
        actions: [
          NotificationBadge(iconColor: context.primaryColor),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
            onPressed: () => context.read<AuthBloc>().add(LogOutRequested()),
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: CustomScrollView(
        physics: const ClampingScrollPhysics(),
        slivers: [
          // 1. SECCIÓN DE PERFIL Y PUNTAJE DEL PROPIETARIO LOGUEADO
          if (isAuthenticated)
            SliverToBoxAdapter(
              child: LandlordProfileHeader(user: authState.user),
            ),

          // 2. SECCIÓN DE BORRADORES PENDIENTES (BLOC)
          BlocBuilder<PropertyBloc, PropertyState>(
            builder: (context, state) {
              final data = state.formData;
              if (data['address'] == null ||
                  data['address'].isEmpty ||
                  state.isEditing) {
                return const SliverToBoxAdapter(child: SizedBox.shrink());
              }
              return SliverToBoxAdapter(
                child: _buildDraftSection(context, data),
              );
            },
          ),

          // 3. SECCIÓN DE LISTADO FLUJO STREAM DE PROPIEDADES AGRUPADAS
          StreamBuilder<List<PropertyModel>>(
            stream: _propertyService.watchPropertiesByOwner(userId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.only(top: 50),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                );
              }

              final properties = snapshot.data ?? [];
              if (properties.isEmpty) return _buildEmptyState();

              properties.sort((a, b) => b.createdAt.compareTo(a.createdAt));

              Map<String, Map<String, List<PropertyModel>>> groupedData = {};
              for (var prop in properties) {
                String monthKey = prop.createdAt.toMonthYear();
                int weekOfMonth = ((prop.createdAt.day - 1) / 7).floor() + 1;
                String weekKey = "Semana $weekOfMonth";

                groupedData.putIfAbsent(monthKey, () => {});
                groupedData[monthKey]!.putIfAbsent(weekKey, () => []);
                groupedData[monthKey]![weekKey]!.add(prop);
              }

              List<Widget> sliverItems = [];
              groupedData.forEach((month, weeks) {
                // --- 1. CABECERA DEL MES CON LÍNEA DIVISORIA HORIZONTAL EXTENDIDA ---
                sliverItems.add(
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                      child: Row(
                        children: [
                          CustomText.title(
                            month.toUpperCase(),
                            baseFontSize:
                                20, // Escalado tipográfico premium para el mes
                            color: context.primaryColor,
                            fontWeight: FontWeight.w800,
                          ),
                          const SizedBox(width: 16),
                          // Línea divisoria elegante que ocupa el resto del ancho disponible
                          const Expanded(
                            child: Divider(
                              thickness: 0.8,
                              color: Color(
                                0xFFE2E8F0,
                              ), // Gris suave de tu paleta base
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );

                weeks.forEach((week, propsInWeek) {
                  // --- 2. INDICADOR DE SEMANA EN FORMATO PILL COMPACTO ---
                  sliverItems.add(
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 6, 20, 16),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFFEDF2F7,
                                ), // Gris de fondo para los chips de tu manual
                                borderRadius: BorderRadius.circular(
                                  20,
                                ), // Forma totalmente redondeada (Pill)
                              ),
                              child: CustomText(
                                week.toUpperCase(),
                                baseFontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: context
                                    .textSecondaryColor, // Texto secundario nítido
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                  sliverItems.add(
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => LandlordPropertyCard(
                            property: propsInWeek[index],
                            contractService: _contractService,
                            friendlyStatusFormatter: _getFriendlyStatusName,
                            onEdit: () =>
                                _editProperty(context, propsInWeek[index]),
                          ),
                          childCount: propsInWeek.length,
                        ),
                      ),
                    ),
                  );
                });
              });

              return SliverMainAxisGroup(slivers: sliverItems);
            },
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
      floatingActionButton: _buildCustomFAB(context),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildDraftSection(BuildContext context, Map<String, dynamic> data) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 10, 20, 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.orange[400]!, Colors.orange[700]!],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const Icon(Icons.edit_document, color: Colors.white, size: 24),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Borrador pendiente",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: ResponsiveUtils.getFontSize(context, 14),
                  ),
                ),
                Text(
                  data['address'] ?? 'Sin dirección',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: ResponsiveUtils.getFontSize(context, 12),
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const AddPropertyProcessScreen(),
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.orange[800],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              "CONTINUAR",
              style: TextStyle(
                fontSize: ResponsiveUtils.getFontSize(context, 10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomFAB(BuildContext context) {
    return Container(
      height: 54,
      width: 200,
      margin: const EdgeInsets.only(bottom: 10),
      child: FloatingActionButton.extended(
        backgroundColor: context.primaryColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        onPressed: () {
          context.read<PropertyBloc>().add(ClearPropertyCacheRequested());
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddPropertyProcessScreen()),
          );
        },
        icon: const Icon(
          Icons.add_circle_outline,
          color: Colors.white,
          size: 24,
        ),
        label: Text(
          "NUEVA PROPIEDAD",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
            fontSize: ResponsiveUtils.getFontSize(context, 12),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.home_work_outlined, size: 70, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            "No tienes propiedades aún",
            style: TextStyle(
              fontSize: ResponsiveUtils.getFontSize(context, 16),
              color: Colors.grey[600],
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  void _editProperty(BuildContext context, PropertyModel property) {
    context.read<PropertyBloc>().add(EditPropertyStarted(property));
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddPropertyProcessScreen()),
    );
  }
}
