// ui/pages/tenant_flow/public_property_gallery.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inmobiliariaapp/bloc/authBloc/auth_bloc.dart';
import 'package:inmobiliariaapp/bloc/authBloc/auth_event.dart';
import 'package:inmobiliariaapp/bloc/authBloc/auth_state.dart';
import 'package:inmobiliariaapp/bloc/favoritesBloc/favorites_bloc.dart';
import 'package:inmobiliariaapp/bloc/favoritesBloc/favorites_event.dart';
import 'package:inmobiliariaapp/bloc/favoritesBloc/favorites_state.dart';
import 'package:inmobiliariaapp/enum/contract_status.dart';
import 'package:inmobiliariaapp/enum/property_status.dart';
import 'package:inmobiliariaapp/models/application_model.dart';
import 'package:inmobiliariaapp/models/property_model.dart';
import 'package:inmobiliariaapp/models/contract_model.dart';
import 'package:inmobiliariaapp/models/story_model.dart';
import 'package:inmobiliariaapp/services/application_service.dart';
import 'package:inmobiliariaapp/services/contract_service.dart';
import 'package:inmobiliariaapp/ui/components/auth_ux/notification_badge.dart';
import 'package:inmobiliariaapp/ui/components/property/property_detail_screen.dart';
import 'package:inmobiliariaapp/ui/components/tenant_flow/application_status_button.dart';
import 'package:inmobiliariaapp/ui/components/tenant_flow/gallery_navigation_drawer.dart';
import 'package:inmobiliariaapp/ui/components/contract/pending_signature_banner.dart';
import 'package:inmobiliariaapp/ui/components/contract/possession_contract_card.dart';
import 'package:inmobiliariaapp/ui/components/tenant_flow/select_slot_screen.dart';
import 'package:inmobiliariaapp/ui/components/tenant_flow/stories_viewer_page.dart';
import 'package:inmobiliariaapp/ui/components/tenant_flow/tenant_apply_screen.dart';
import 'package:inmobiliariaapp/utils/themes.dart';
import 'package:inmobiliariaapp/utils/format_extensions.dart';
import 'package:inmobiliariaapp/ui/components/global/custom_text.dart';
import 'package:inmobiliariaapp/ui/components/global/custom_text_button.dart';

class PublicPropertyGallery extends StatefulWidget {
  const PublicPropertyGallery({super.key});

  @override
  State<PublicPropertyGallery> createState() => _PublicPropertyGalleryState();
}

class _PublicPropertyGalleryState extends State<PublicPropertyGallery> {
  final ContractService _contractService = ContractService();
  final ApplicationService _applicationService = ApplicationService();
  bool _showPossessionView = true;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, authState) {
        final bool isAuthenticated = authState is Authenticated;
        final String userId = isAuthenticated ? authState.user.id : '';
        final String? userName = isAuthenticated ? authState.user.name : null;

        if (isAuthenticated) {
          context.read<FavoritesBloc>().add(LoadFavorites(userId));
        }

        return StreamBuilder<List<ContractModel>>(
          stream: _contractService.watchAllContracts(),
          builder: (context, contractSnapshot) {
            final allContracts = contractSnapshot.data ?? [];

            // 1. Contratos activos del inquilino
            final myActiveContracts = allContracts
                .where(
                  (c) =>
                      c.tenant?.uid == userId &&
                      (c.status == ContractStatus.approved.name ||
                          c.status == ContractStatus.active.name),
                )
                .toList();

            // 2. CORREGIDO: Ahora incluye la evaluación de rechazo con validación de URL nula
            final myPendingSignatureContract = allContracts
                .cast<ContractModel?>()
                .firstWhere((c) {
                  if (c == null || c.tenant?.uid != userId) return false;

                  // Caso A: Esperando firma inicial del inquilino
                  final bool isWaitingSign =
                      c.status == ContractStatus.waitingTenantSignature.name;

                  // Caso C: El documento fue rechazado Y el inquilino limpió o no ha subido el nuevo PDF
                  final bool isRejectedAndEmpty =
                      c.status == ContractStatus.signatureRejected.name &&
                      c.tenantSignedPdfUrl == null;

                  return isWaitingSign || isRejectedAndEmpty;
                }, orElse: () => null);

            // --- ESCENARIO A: MUESTRA LA VISTA DE MIS INMUEBLES (MODULAR) ---
            if (myActiveContracts.isNotEmpty && _showPossessionView) {
              return Scaffold(
                backgroundColor: context.surfaceColor.withOpacity(0.96),
                appBar: AppBar(
                  backgroundColor: context.primaryColor,
                  iconTheme: const IconThemeData(color: Colors.white),
                  title: const CustomText(
                    "Mis Inmuebles",
                    baseFontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  elevation: 0,

                  actions: [NotificationBadge(iconColor: Colors.white)],
                ),

                drawer: GalleryNavigationDrawer(
                  hasAssignedResidence: true,
                  isAuthenticated: isAuthenticated,
                  showPossessionView: _showPossessionView,
                  onPossessionViewChanged: (val) =>
                      setState(() => _showPossessionView = val),
                ),
                body: ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  itemCount: myActiveContracts.length,
                  itemBuilder: (context, index) => PossessionContractCard(
                    contract: myActiveContracts[index],
                    userId: userId,
                    userName: userName ?? 'Inquilino',
                  ),
                ),
              );
            }

            // --- ESCENARIO B: MUESTRA LA GALERÍA PÚBLICA NORMAL ---
            return Scaffold(
              backgroundColor: context.surfaceColor.withOpacity(0.96),
              appBar: AppBar(
                backgroundColor: context.primaryColor,
                iconTheme: const IconThemeData(color: Colors.white),
                elevation: 0,
                actions: [NotificationBadge(iconColor: Colors.white)],
                title: CustomText(
                  isAuthenticated
                      ? "Hola, ${userName?.split(' ')[0]}"
                      : "SINMO",
                  baseFontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              drawer: GalleryNavigationDrawer(
                hasAssignedResidence: myActiveContracts.isNotEmpty,
                isAuthenticated: isAuthenticated,
                showPossessionView: _showPossessionView,
                onPossessionViewChanged: (val) =>
                    setState(() => _showPossessionView = val),
              ),
              body: Column(
                children: [
                  if (myPendingSignatureContract != null)
                    PendingSignatureBanner(
                      contract: myPendingSignatureContract,
                    ),

                  // --- LISTA HORIZONTAL ESTÁTICA DE VIDEOS INFORMATIVOS ---
                  _buildStoriesSection(),

                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('properties')
                          .where(
                            'status',
                            isEqualTo: PropertyStatusEnum.waitingContract.name,
                          )
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                          return const Center(
                            child: CustomText(
                              "No hay propiedades disponibles por el momento.",
                              baseFontSize: 14,
                            ),
                          );
                        }

                        final availableProperties = snapshot.data!.docs
                            .map((doc) => PropertyModel.fromSnapshot(doc))
                            .where((property) {
                              return !allContracts.any(
                                (contract) =>
                                    contract.propertyId == property.id &&
                                    contract.tenant != null &&
                                    (contract.status == 'active' ||
                                        contract.status ==
                                            'signedPendingReview'),
                              );
                            })
                            .toList();

                        return ListView.builder(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          itemCount: availableProperties.length + 1,
                          itemBuilder: (context, index) {
                            if (index == 0) {
                              return _buildHeader(
                                context,
                                isAuthenticated,
                                userName,
                                availableProperties.length,
                              );
                            }
                            return _buildPropertyCard(
                              context,
                              availableProperties[index - 1],
                              isAuthenticated,
                              userId,
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // --- COMPONENTE BARRA DE HISTORIAS INFORMÁTICAS INDEPENDIENTES ---
  Widget _buildStoriesSection() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('stories')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }

        final List<StoryModel> storiesList = snapshot.data!.docs.map((doc) {
          return StoryModel.fromMap(doc.id, doc.data() as Map<String, dynamic>);
        }).toList();

        return Container(
          height: 105,
          width: double.infinity,
          margin: const EdgeInsets.only(top: 8),
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: storiesList.length,
            itemBuilder: (context, index) {
              final story = storiesList[index];

              // Comprobación de existencia de miniatura personalizada en tu StoryModel
              // Si no tienes este campo en el modelo, resolverá automáticamente el icono por defecto.
              final String? thumbnailUrl =
                  (story as dynamic).toMap().containsKey('thumbnailUrl')
                  ? (story as dynamic).thumbnailUrl
                  : null;

              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => StoriesViewerPage(
                        stories: [story],
                        initialIndex: 0,
                        isSingleMode: true,
                      ),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.only(right: 14.0),
                  child: Column(
                    children: [
                      // Anillo exterior con degradado dinámico (Estilo Instagram)
                      Container(
                        padding: const EdgeInsets.all(2.5),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              context.primaryColor,
                              Colors.blueAccent,
                              const Color(0xFF1565C0),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: context.surfaceColor,
                            shape: BoxShape.circle,
                          ),
                          child: CircleAvatar(
                            radius: 28,
                            backgroundColor: context.primaryColor.withOpacity(
                              0.08,
                            ),
                            // --- MANEJO INTELIGENTE DE MINIATURA O ICONO ---
                            backgroundImage:
                                thumbnailUrl != null && thumbnailUrl.isNotEmpty
                                ? NetworkImage(thumbnailUrl)
                                : null,
                            child: Container(
                              width: double.infinity,
                              height: double.infinity,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                // Si hay miniatura, oscurece un poco el fondo para que el icono blanco resalte
                                color:
                                    thumbnailUrl != null &&
                                        thumbnailUrl.isNotEmpty
                                    ? Colors.black26
                                    : Colors.transparent,
                              ),
                              child: Icon(
                                thumbnailUrl != null && thumbnailUrl.isNotEmpty
                                    ? Icons.play_arrow_rounded
                                    : Icons.play_circle_fill_rounded,
                                color:
                                    thumbnailUrl != null &&
                                        thumbnailUrl.isNotEmpty
                                    ? Colors.white
                                    : context.primaryColor,
                                size:
                                    thumbnailUrl != null &&
                                        thumbnailUrl.isNotEmpty
                                    ? 24
                                    : 28,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        width: 68,
                        child: CustomText(
                          story.title.isNotEmpty ? story.title : "Info",
                          baseFontSize: 10,
                          fontWeight: FontWeight.w600,
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildHeader(
    BuildContext context,
    bool isAuth,
    String? name,
    int count,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CustomText.title(
            isAuth ? "Bienvenido, $name" : "Explora Inmuebles",
            baseFontSize: 22,
            color: context.primaryColor,
            fontWeight: FontWeight.w800,
          ),
          const SizedBox(height: 4),
          CustomText(
            "Hay $count propiedades listas para arrendar",
            baseFontSize: 13,
            color: context.textSecondaryColor.withOpacity(0.6),
          ),
        ],
      ),
    );
  }

  Widget _buildPropertyCard(
    BuildContext context,
    PropertyModel property,
    bool isAuth,
    String uId,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1A365D).withOpacity(0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PropertyDetailScreen(property: property),
                    ),
                  ),
                  child: AspectRatio(
                    aspectRatio: 16 / 10,
                    child: Image.network(
                      property.imageUrls.isNotEmpty
                          ? property.imageUrls.first
                          : 'https://via.placeholder.com/400x240',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                Positioned(
                  top: 14,
                  left: 14,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2E7D32),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      "DISPONIBLE",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: BlocBuilder<FavoritesBloc, FavoritesState>(
                    builder: (context, favState) {
                      bool isFav =
                          favState is FavoritesLoaded &&
                          favState.favoriteIds.contains(property.id);
                      return CircleAvatar(
                        backgroundColor: Colors.white.withOpacity(0.9),
                        radius: 18,
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          icon: Icon(
                            isFav
                                ? Icons.favorite
                                : Icons.favorite_border_rounded,
                            color: isFav ? Colors.redAccent : Colors.grey[600],
                            size: 20,
                          ),
                          onPressed: () => isAuth
                              ? context.read<FavoritesBloc>().add(
                                  ToggleFavorite(uId, property),
                                )
                              : _showLoginRequiredDialog(
                                  context,
                                  "guardar favoritos",
                                ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: CustomText.title(
                          property.address,
                          baseFontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 8),
                      CustomText.title(
                        (property.canon as num).toInt().toCOP(),
                        baseFontSize: 16,
                        color: context.primaryColor,
                        fontWeight: FontWeight.w800,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  CustomText(
                    property.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    baseFontSize: 13,
                    color: context.textSecondaryColor.withOpacity(0.6),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      width: 56,
                      height: 48,
                      child: !isAuth
                          ? OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                padding: EdgeInsets.zero,
                                side: BorderSide(
                                  color: context.textColor.withOpacity(0.08),
                                  width: 1.5,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: () => _showLoginRequiredDialog(
                                context,
                                "agendar cita",
                              ),
                              child: Icon(
                                Icons.calendar_month_rounded,
                                color: context.primaryColor,
                                size: 22,
                              ),
                            )
                          : StreamBuilder<QuerySnapshot>(
                              stream: FirebaseFirestore.instance
                                  .collection('available_slots')
                                  .where('propertyId', isEqualTo: property.id)
                                  .where('attendeesUids', arrayContains: uId)
                                  .snapshots(),
                              builder: (context, snap) {
                                if (snap.hasData &&
                                    snap.data!.docs.isNotEmpty) {
                                  return ApplicationStatusButton(
                                    propertyId: property.id ?? '',
                                    propertyAddress: property.address,
                                    userId: uId,
                                    onApply: () =>
                                        _navigateToApply(context, property),
                                  );
                                }
                                return OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    side: BorderSide(
                                      color: context.textColor.withOpacity(
                                        0.08,
                                      ),
                                      width: 1.5,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  onPressed: () =>
                                      _navigateToSchedule(context, property),
                                  child: Icon(
                                    Icons.calendar_month_rounded,
                                    color: context.primaryColor,
                                    size: 22,
                                  ),
                                );
                              },
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: !isAuth
                          ? ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: context.primaryColor,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: () => _showLoginRequiredDialog(
                                context,
                                "postularte",
                              ),
                              child: const Text(
                                "POSTULARME",
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            )
                          : StreamBuilder<ApplicationModel?>(
                              stream: _applicationService
                                  .watchApplicationByProperty(property.id!),
                              builder: (context, snap) {
                                if (!snap.hasData) {
                                  return ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: context.primaryColor,
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    onPressed: () =>
                                        _navigateToApply(context, property),
                                    child: const Text(
                                      "POSTULARME",
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  );
                                }
                                final myCand = _applicationService
                                    .getUserCandidate(snap.data!, uId);
                                if (myCand == null) {
                                  return ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: context.primaryColor,
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    onPressed: () =>
                                        _navigateToApply(context, property),
                                    child: const Text(
                                      "POSTULARME",
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  );
                                }

                                switch (myCand.status) {
                                  case 'pending_review':
                                    return _buildStatusContainer(
                                      Colors.orange,
                                      Icons.search_rounded,
                                      "EN REVISIÓN",
                                    );
                                  case 'approved':
                                    return _buildStatusContainer(
                                      Colors.green,
                                      Icons.check_circle_rounded,
                                      "APROBADO",
                                    );
                                  case 'rejected':
                                    return ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.redAccent,
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                      ),
                                      onPressed: () =>
                                          _navigateToApply(context, property),
                                      child: const Text(
                                        "RECHAZADO (REINTENTAR)",
                                        style: TextStyle(
                                          fontFamily: 'Inter',
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    );
                                  default:
                                    return _buildStatusContainer(
                                      Colors.blueGrey,
                                      Icons.info_outline_rounded,
                                      "ESTADO: ${myCand.status.toUpperCase()}",
                                    );
                                }
                              },
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusContainer(Color color, IconData icon, String text) {
    return Container(
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3), width: 1.2),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontFamily: 'Inter',
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 11,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToSchedule(BuildContext context, PropertyModel property) {
    final auth = context.read<AuthBloc>().state as Authenticated;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SelectSlotScreen(
          propertyId: property.id ?? '',
          propertyAddress: property.address,
          userId: auth.user.id,
          userName: auth.user.name,
        ),
      ),
    );
  }

  void _navigateToApply(BuildContext context, PropertyModel property) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TenantApplyScreen(
          propertyId: property.id ?? '',
          propertyAddress: property.address,
          currentPropertyCanon: property.canon.toInt(),
        ),
      ),
    );
  }

  void _showLoginRequiredDialog(BuildContext context, String action) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: CustomText.title(
          "Acción Requerida",
          baseFontSize: 16,
          fontWeight: FontWeight.bold,
        ),
        content: CustomText(
          "Para poder $action, es necesario iniciar sesión de forma segura.",
          baseFontSize: 14,
          color: context.textSecondaryColor,
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        actions: [
          CustomTextButton.muted(
            "CERRAR",
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<AuthBloc>().add(ShowLoginScreenRequested());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: context.primaryColor,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text("INICIAR SESIÓN"),
          ),
        ],
      ),
    );
  }
}
