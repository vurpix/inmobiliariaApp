// ui/components/admin/admin_property_detail_screen.dart

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:inmobiliariaapp/bloc/signatureBloc/signature_bloc_bloc.dart';
import 'package:inmobiliariaapp/bloc/signatureBloc/signature_bloc_event.dart';
import 'package:inmobiliariaapp/bloc/signatureBloc/signature_bloc_state.dart';

import 'package:inmobiliariaapp/enum/payment_status.dart';
import 'package:inmobiliariaapp/models/user.dart';
import 'package:inmobiliariaapp/ui/components/global/custom_button.dart';
import 'package:inmobiliariaapp/ui/components/info_box_widget.dart';
import 'package:inmobiliariaapp/ui/components/shared/direct_download_button.dart';

// --- PROYECTO ---
import 'package:inmobiliariaapp/bloc/authBloc/auth_bloc.dart';
import 'package:inmobiliariaapp/bloc/authBloc/auth_state.dart';
import 'package:inmobiliariaapp/enum/contract_status.dart';
import 'package:inmobiliariaapp/models/candidate_model.dart';
import 'package:inmobiliariaapp/models/property_model.dart';
import 'package:inmobiliariaapp/models/contract_model.dart';
import 'package:inmobiliariaapp/services/property_service.dart';
import 'package:inmobiliariaapp/services/contract_service.dart';
import 'package:inmobiliariaapp/services/user_service.dart';
import 'package:inmobiliariaapp/services/viafirma_service.dart';
import 'package:inmobiliariaapp/ui/components/pdf/Pdf_view_screen.dart';
import 'package:inmobiliariaapp/utils/status_formatter.dart';
import 'package:inmobiliariaapp/enum/property_status.dart';
import 'package:inmobiliariaapp/utils/themes.dart';
import 'package:inmobiliariaapp/ui/components/global/custom_text.dart';
import 'package:inmobiliariaapp/ui/components/global/custom_text_button.dart';

class AdminPropertyDetailScreen extends StatefulWidget {
  final String propertyId;

  const AdminPropertyDetailScreen({
    super.key,
    required this.propertyId,
  });

  @override
  State<AdminPropertyDetailScreen> createState() =>
      _AdminPropertyDetailScreenState();
}

class _AdminPropertyDetailScreenState extends State<AdminPropertyDetailScreen> {
  final PropertyService _propertyService = PropertyService();
  final ContractService _contractService = ContractService();
  final UserService _userService = UserService();
  final ViafirmaService _viafirmaService = ViafirmaService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  late final Stream<PropertyModel?> _propertyStream;
  late final Stream<ContractModel?> _contractStream;
  late final Stream<QuerySnapshot> _applicationsStream;

  final Map<String, UserModel?> _userCache = {};
  final Map<String, bool> _loadingUsers = {};

  bool _isProcessing = false;
  bool _isProcessingNotificarUsuarios = false;
  bool _isProcessingSuccess = false;
  bool _isProcessingReject = false;
  File? _selectedContractFile;
  String? _downloadingUrl;

  void migrateVariablesInitState() {
    _propertyStream = _propertyService.watchPropertyById(widget.propertyId);

    _contractStream = _contractService.watchContractByProperty(
      widget.propertyId,
    );

    _applicationsStream = _firestore
        .collection('applications')
        .where('propertyId', isEqualTo: widget.propertyId)
        .limit(1)
        .snapshots();
  }

  @override
  void initState() {
    super.initState();
    migrateVariablesInitState();
  }

  // int _getGestionPrice(AppValuesModel config, double canonAmount) {
  //   for (var scale in config.priceScales) {
  //     if (canonAmount >= scale.min && canonAmount <= scale.max) {
  //       return scale.price;
  //     }
  //   }
  //   return 0;
  // }

  Future<void> _pickAndPreviewContract(ContractModel? existingContract) async {
    try {
      FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _selectedContractFile = File(result.files.single.path!);
        });
      }
    } catch (e) {
      _showError("Error al seleccionar archivo: $e");
    }
  }

  Future<void> _deleteContractPdf(ContractModel? contract) async {
    setState(() => _isProcessing = true);

    try {
      if (contract != null && contract.baseContractPdfUrl != null) {
        await FirebaseStorage.instance
            .refFromURL(contract.baseContractPdfUrl!)
            .delete();

        await _contractService.updateFields(contract.id!, {
          'baseContractPdfUrl': null,
        });
      }

      setState(() => _selectedContractFile = null);
    } catch (e) {
      debugPrint("Error eliminando: $e");
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _rejectSignature(ContractModel contract, bool isOwner) async {
    setState(() => _isProcessingReject = true);

    try {
      Map<String, dynamic> updateData = {
        'status': isOwner
            ? ContractStatus.signatureRejected.name
            : ContractStatus.signatureRejectedTenant.name,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (isOwner) {
        updateData['ownerSignedPdfUrl'] = null;
      } else {
        updateData['tenantSignedPdfUrl'] = null;
      }

      await _contractService.updateFields(contract.id!, updateData);

      _showToast("Acción registrada con éxito", isError: false);
    } catch (e) {
      _showError("Error al rechazar: $e");
    } finally {
      if (mounted) setState(() => _isProcessingReject = false);
    }
  }

  Future<void> _confirmAndSendToSignature(
    PropertyModel property,
    ContractModel? existingContract,
    CandidateModel? winner,
  ) async {
    if (winner == null) return;

    if (_selectedContractFile == null &&
        existingContract?.baseContractPdfUrl == null) {
      return;
    }

    setState(() => _isProcessingNotificarUsuarios = true);

    try {
      String? finalPdfUrl = existingContract?.baseContractPdfUrl;

      if (_selectedContractFile != null) {
        String fileName =
            'contracts/final/${widget.propertyId}_base_${DateTime.now().millisecondsSinceEpoch}.pdf';

        TaskSnapshot uploadTask = await FirebaseStorage.instance
            .ref()
            .child(fileName)
            .putFile(_selectedContractFile!);

        finalPdfUrl = await uploadTask.ref.getDownloadURL();
      }

      if (finalPdfUrl == null || finalPdfUrl.isEmpty) {
        throw Exception(
          "No se pudo obtener un enlace válido para el documento PDF.",
        );
      }

      final String contractId =
          existingContract?.id ?? _firestore.collection('contracts').doc().id;

      final ownerUser = await _userService.getUserById(property.ownerId);

      if (ownerUser == null) {
        throw Exception(
          "No se encontraron los datos de perfil del propietario.",
        );
      }

      await _viafirmaService.createSignatureRequest(
        contractId: contractId,
        propertyId: property.id!,
        propertyAddress: property.address,
        pdfUrl: finalPdfUrl,
        tenant: {
          'uid': winner.uid,
          'name': winner.nombre,
          'email': winner.email,
        },
        owner: {
          'uid': property.ownerId,
          'name': ownerUser.name,
          'email': ownerUser.email,
        },
      );

      await _propertyService.updateStatus(
        propertyId: widget.propertyId,
        newStatus: PropertyStatusEnum.waitingSignature,
      );

      setState(() => _selectedContractFile = null);

      _showToast("¡Flujo de firma iniciado exitosamente!");

      try {
        if (mounted) {
          context.read<SignatureBloc>().add(
                RefreshSignatureStatusRequested(contractId),
              );
        }
      } catch (_) {
        // Si el bloc aún no está disponible, el usuario podrá recargar manualmente.
      }
    } catch (e) {
      _showError("Error al procesar el envío de firmas: $e");
    } finally {
      if (mounted) setState(() => _isProcessingNotificarUsuarios = false);
    }
  }

  // Future<bool> _checkIfAlreadyReviewed(ContractModel currentContract) async {
  //   if (currentContract.tenant == null) return false;

  //   try {
  //     final query = await FirebaseFirestore.instance
  //         .collection('users')
  //         .doc(currentContract.tenant!.uid)
  //         .collection('reviews')
  //         .where('contractId', isEqualTo: currentContract.id)
  //         .where('fromUserId', isEqualTo: currentContract.ownerId)
  //         .limit(1)
  //         .get();

  //     return query.docs.isNotEmpty;
  //   } catch (e) {
  //     debugPrint("Error verifying previous review: $e");
  //     return false;
  //   }
  // }

  void _preloadUserData(String userId) async {
    if (_userCache.containsKey(userId) || _loadingUsers[userId] == true) {
      return;
    }

    _loadingUsers[userId] = true;

    try {
      final user = await _userService.getUserById(userId);

      if (mounted) {
        setState(() {
          _userCache[userId] = user;
          _loadingUsers[userId] = false;
        });
      }
    } catch (_) {
      _loadingUsers[userId] = false;
    }
  }

  CandidateModel? _getApprovedCandidate(DocumentSnapshot applicationDoc) {
    if (!applicationDoc.exists) return null;

    final data = applicationDoc.data() as Map<String, dynamic>;
    final List candidatesData = data['candidates'] ?? [];

    for (var c in candidatesData) {
      if (c['status'] == 'approved') {
        return CandidateModel.fromMap(c);
      }
    }

    return null;
  }

  String _sanitizeFileName(String address, String suffix) {
    final cleanAddress = address
        .replaceAll(RegExp(r'[^\w\s\-]'), '')
        .replaceAll(' ', '_');

    return "${cleanAddress}_$suffix.pdf";
  }

  String? _readContractString(ContractModel? contract, String key) {
    if (contract == null) return null;

    try {
      final dynamic dynamicContract = contract;
      final dynamic map = dynamicContract.toMap();

      if (map is Map && map[key] != null) {
        return map[key].toString();
      }
    } catch (_) {}

    try {
      final dynamic dynamicContract = contract;

      switch (key) {
        case 'signatureStatus':
          return dynamicContract.signatureStatus?.toString();
        case 'viafirmaSetCode':
          return dynamicContract.viafirmaSetCode?.toString();
        case 'viafirmaMessageCode':
          return dynamicContract.viafirmaMessageCode?.toString();
        case 'viafirmaSignatureDocId':
          return dynamicContract.viafirmaSignatureDocId?.toString();
      }
    } catch (_) {}

    return null;
  }

  String _getLocalPartyStatus(ContractModel? contract, String userId) {
    if (contract == null ||
        contract.signaturesTracking == null ||
        !contract.signaturesTracking!.containsKey(userId)) {
      return 'PENDING';
    }

    return contract.signaturesTracking![userId]!.status;
  }

  bool _isSignedStatus(String status) {
    return status == 'SIGNED' || status == 'COMPLETED' || status == 'FINISHED';
  }

  bool _areBothPartiesSigned(ContractModel? contract, CandidateModel? winner) {
    if (contract == null || winner == null) return false;

    final ownerStatus = _getLocalPartyStatus(contract, contract.ownerId);
    final tenantStatus = _getLocalPartyStatus(contract, winner.uid);

    return _isSignedStatus(ownerStatus) && _isSignedStatus(tenantStatus);
  }

  Widget _buildPartyStatusBadge(ContractModel? contract, String userId) {
    if (contract == null ||
        contract.signaturesTracking == null ||
        !contract.signaturesTracking!.containsKey(userId)) {
      return _inlineBadge("PENDIENTE", Colors.grey);
    }

    final party = contract.signaturesTracking![userId]!;

    return _badgeFromStatus(party.status);
  }

  Widget _buildPartyStatusBadgeReactive(
    ContractModel? contract,
    String userId,
  ) {
    try {
      return BlocBuilder<SignatureBloc, SignatureState>(
        builder: (context, state) {
          if (state.signature != null) {
            final status = state.signature!.statusForUser(userId);
            return _badgeFromStatus(status);
          }

          return _buildPartyStatusBadge(contract, userId);
        },
      );
    } catch (_) {
      return _buildPartyStatusBadge(contract, userId);
    }
  }

  Widget _badgeFromStatus(String status) {
    switch (status) {
      case 'SIGNED':
      case 'COMPLETED':
      case 'FINISHED':
        return _inlineBadge("✅ FIRMADO", Colors.green);

      case 'REJECTED':
        return _inlineBadge("❌ RECHAZADO", Colors.red);

      case 'WAITING':
        return _inlineBadge("⏳ ESPERANDO", Colors.blueGrey);

      case 'PENDING':
      case 'RECEIVED':
      default:
        return _inlineBadge("⏳ EN ESPERA", Colors.orange);
    }
  }

  Widget _inlineBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PropertyModel?>(
      stream: _propertyStream,
      builder: (context, propSnapshot) {
        if (!propSnapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final property = propSnapshot.data!;

        return StreamBuilder<ContractModel?>(
          stream: _contractStream,
          builder: (context, contractSnapshot) {
            final contract = contractSnapshot.data;

            return StreamBuilder<QuerySnapshot>(
              stream: _applicationsStream,
              builder: (context, appSnapshot) {
                CandidateModel? approvedCandidate;

                if (appSnapshot.hasData && appSnapshot.data!.docs.isNotEmpty) {
                  approvedCandidate = _getApprovedCandidate(
                    appSnapshot.data!.docs.first,
                  );
                }

                final String currentStatus =
                    contract?.status ?? property.status.name;

                if (contract?.id != null && contract!.id!.isNotEmpty) {
                  return BlocProvider(
                    key: ValueKey('signature_bloc_${contract.id}'),
                    create: (_) => SignatureBloc()
                      ..add(WatchContractSignatureRequested(contract.id!)),
                    child: _buildAdminScaffold(
                      property: property,
                      contract: contract,
                      approvedCandidate: approvedCandidate,
                      currentStatus: currentStatus,
                    ),
                  );
                }

                return _buildAdminScaffold(
                  property: property,
                  contract: contract,
                  approvedCandidate: approvedCandidate,
                  currentStatus: currentStatus,
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildAdminScaffold({
    required PropertyModel property,
    required ContractModel? contract,
    required CandidateModel? approvedCandidate,
    required String currentStatus,
  }) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: CustomText(
          "Gestión Administrativa",
          baseFontSize: 16,
          fontWeight: FontWeight.bold,
          color: context.textColorWhite,
        ),
        backgroundColor: context.primaryColor,
        iconTheme: IconThemeData(color: context.textColorWhite),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStatusHeader(currentStatus),

              const SizedBox(height: 24),

              _sectionTitle("Participantes del Proceso"),

              _buildUserCard(
                property.ownerId,
                "Propietario Registrado",
                context.primaryColor,
                trailingWidget: _buildPartyStatusBadgeReactive(
                  contract,
                  property.ownerId,
                ),
              ),

              if (approvedCandidate != null)
                _buildUserCard(
                  approvedCandidate.uid,
                  "Inquilino Postulado",
                  context.successColor,
                  trailingWidget: _buildPartyStatusBadgeReactive(
                    contract,
                    approvedCandidate.uid,
                  ),
                )
              else
                buildInfoBox(
                  "No hay un inquilino aprobado en este momento.",
                  context.primaryColor,
                ),

              const SizedBox(height: 24),

              _sectionTitle("Archivos de Multimedia"),

              _buildImageGallery(property.imageUrls),

              if (property.docUrls.isNotEmpty)
                _buildSectionCard(
                  title: "Documentos del Propietario",
                  subtitle: "Soportes de tradición, libertad y legalidad",
                  color: context.primaryColor,
                  icon: Icons.folder_shared_outlined,
                  child: Column(
                    children: property.docUrls
                        .map(
                          (url) => _buildPdfCard(
                            context,
                            url,
                            "DOCUMENTO_PROPIETARIO",
                            context.primaryColor,
                            property: property,
                          ),
                        )
                        .toList(),
                  ),
                ),

              _buildSectionCard(
                title: "Comprobante de Pago",
                subtitle: "Verificación manual de la pasarela de pago",
                color: Colors.orange[800]!,
                icon: Icons.receipt_long_outlined,
                child: _buildPaymentReceiptWidget(
                  context,
                  property.paymentReceiptUrl,
                ),
              ),

              if (property.paymentStatus == PaymentStatusEnum.approved)
                _buildSectionCard(
                  title: "Contrato y firmas digitales",
                  subtitle: "Gestión del PDF y auditoría de firmas",
                  color: Colors.indigo,
                  icon: Icons.history_edu_outlined,
                  child: _buildContractManagementUI(
                    property,
                    contract,
                    approvedCandidate,
                  ),
                ),

              const SizedBox(height: 30),

              BlocBuilder<AuthBloc, AuthState>(
                builder: (context, authState) {
                  bool isAdmin = (authState is Authenticated &&
                      authState.user.role
                          .toString()
                          .toLowerCase()
                          .contains('admin'));

                  return isAdmin
                      ? _buildAdminActions(
                          context,
                          property,
                          contract,
                          approvedCandidate,
                        )
                      : buildInfoBox(
                          "Modo lectura administrativo habilitado",
                          Colors.grey,
                        );
                },
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required String subtitle,
    required Color color,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      margin: const EdgeInsets.only(top: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.01),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 2,
            ),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            title: CustomText(
              title,
              baseFontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 1),
              child: CustomText(
                subtitle,
                baseFontSize: 12,
                color: Colors.grey[500]!,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _buildContractManagementUI(
    PropertyModel property,
    ContractModel? contract,
    CandidateModel? approvedCandidate,
  ) {
    String? remotePdf = contract?.baseContractPdfUrl;
    bool isActive = contract?.status == ContractStatus.active.name ||
        contract?.status == 'active';

    bool canManagePdf = approvedCandidate != null ||
        isActive ||
        contract?.status == 'waiting_owner_signature' ||
        contract?.status == 'waiting_tenant_signature' ||
        contract?.status == 'waitingSignature';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _smallSectionLabel("Documento base del contrato"),

        if (!canManagePdf)
          buildInfoBox(
            "⚠️ Los flujos documentales se habilitarán cuando la propiedad sea aprobada, pagada y cuente con un inquilino seleccionado.",
            Colors.orange[800]!,
          )
        else ...[
          if (_selectedContractFile != null)
            _buildLocalPdfPreviewCard(property)
          else if (remotePdf != null)
            _buildPdfCard(
              context,
              remotePdf,
              "BORRADOR_LEGAL",
              Colors.indigo,
              onDelete: !isActive ? () => _deleteContractPdf(contract) : null,
              property: property,
            )
          else
            buildInfoBox(
              "Aún no se ha cargado el borrador legal del contrato.",
              Colors.blueGrey,
            ),

          if (!isActive)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: _actionButton(
                _selectedContractFile == null
                    ? "CARGAR BORRADOR PDF"
                    : "REEMPLAZAR BORRADOR EN MEMORIA",
                context.primaryColor,
                () => _pickAndPreviewContract(contract),
                _isProcessing,
              ),
            ),
        ],

        const SizedBox(height: 18),

        if (contract?.ownerSignedPdfUrl != null ||
            contract?.tenantSignedPdfUrl != null) ...[
          _smallSectionLabel("Documentos firmados cargados"),
          if (contract?.ownerSignedPdfUrl != null)
            _buildPdfCardWithReject(
              context,
              contract!.ownerSignedPdfUrl!,
              "FIRMA_DEL_PROPIETARIO",
              const Color(0xFFE65100),
              property: property,
              onReject: isActive ? null : () => _rejectSignature(contract, true),
            ),
          if (contract?.tenantSignedPdfUrl != null)
            _buildPdfCardWithReject(
              context,
              contract!.tenantSignedPdfUrl!,
              "FIRMA_DEL_INQUILINO",
              context.successColor,
              property: property,
              onReject: isActive ? null : () => _rejectSignature(contract, false),
            ),
        ],

        const SizedBox(height: 18),

        _buildViafirmaAuditPanel(contract, approvedCandidate),
      ],
    );
  }

  Widget _buildViafirmaAuditPanel(
    ContractModel? contract,
    CandidateModel? approvedCandidate,
  ) {
    if (contract == null || contract.id == null) {
      return buildInfoBox(
        "Todavía no existe un contrato creado para consultar Viafirma.",
        Colors.blueGrey,
      );
    }

    try {
      return BlocBuilder<SignatureBloc, SignatureState>(
        builder: (context, state) {
          final signature = state.signature;

          final String globalStatus = signature?.signatureStatus ??
              _readContractString(contract, 'signatureStatus') ??
              contract.status;

          final String ownerStatus = signature?.statusForUser(contract.ownerId) ??
              _getLocalPartyStatus(contract, contract.ownerId);

          final String tenantStatus = approvedCandidate != null
              ? signature?.statusForUser(approvedCandidate.uid) ??
                  _getLocalPartyStatus(contract, approvedCandidate.uid)
              : 'PENDING';

          // final String? viafirmaSetCode = signature?.viafirmaSetCode ??
          //     _readContractString(contract, 'viafirmaSetCode');

          // final String? viafirmaMessageCode = signature?.viafirmaMessageCode ??
          //     _readContractString(contract, 'viafirmaMessageCode');

          // final String? viafirmaSignatureDocId =
          //     signature?.viafirmaSignatureDocId ??
          //         _readContractString(contract, 'viafirmaSignatureDocId');

          final bool isRefreshing = state.isRefreshing;

          final bool bothSigned =
              _isSignedStatus(ownerStatus) && _isSignedStatus(tenantStatus);

          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.indigo.withOpacity(0.035),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.indigo.withOpacity(0.14)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.indigo.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.hub_outlined,
                        color: Colors.indigo,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CustomText(
                            "Auditoría Viafirma",
                            baseFontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.indigo,
                          ),
                          SizedBox(height: 2),
                          CustomText(
                            "Vista local. Solo se consulta la API al presionar recargar.",
                            baseFontSize: 11,
                            color: Colors.grey,
                          ),
                        ],
                      ),
                    ),
                    if (isRefreshing)
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                  ],
                ),

                const SizedBox(height: 14),

                _buildMainViafirmaStatus(
                  globalStatus: globalStatus,
                  bothSigned: bothSigned,
                ),

                const SizedBox(height: 14),

                Row(
                  children: [
                    Expanded(
                      child: _buildSignerStatusCard(
                        title: "Inquilino",
                        subtitle: approvedCandidate?.nombre ?? "Firmante 1",
                        status: tenantStatus,
                        color: _colorForViafirmaStatus(tenantStatus),
                        icon: Icons.person_outline_rounded,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildSignerStatusCard(
                        title: "Propietario",
                        subtitle: "Firmante 2",
                        status: ownerStatus,
                        color: _colorForViafirmaStatus(ownerStatus),
                        icon: Icons.home_work_outlined,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // _buildViafirmaCodesBox(
                //   viafirmaSetCode: viafirmaSetCode,
                //   viafirmaMessageCode: viafirmaMessageCode,
                //   viafirmaSignatureDocId: viafirmaSignatureDocId,
                // ),

                if (state.errorMessage != null) ...[
                  const SizedBox(height: 10),
                  CustomText(
                    "⚠️ ${state.errorMessage}",
                    baseFontSize: 12,
                    color: context.errorColor,
                    fontWeight: FontWeight.bold,
                  ),
                ],

                const SizedBox(height: 14),

                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: isRefreshing
                        ? const SizedBox(
                            width: 17,
                            height: 17,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.sync),
                    label: const Text("Recargar estado real en Viafirma"),
                    onPressed: isRefreshing
                        ? null
                        : () {
                            context.read<SignatureBloc>().add(
                                  RefreshSignatureStatusRequested(contract.id!),
                                );
                          },
                  ),
                ),
              ],
            ),
          );
        },
      );
    } catch (_) {
      return buildInfoBox(
        "Panel Viafirma disponible cuando exista un flujo de firma activo.",
        Colors.blueGrey,
      );
    }
  }

  Widget _buildMainViafirmaStatus({
    required String globalStatus,
    required bool bothSigned,
  }) {
    final Color color =
        bothSigned ? Colors.green : _colorForViafirmaStatus(globalStatus);

    final String title =
        bothSigned ? "FIRMAS COMPLETADAS" : _formatViafirmaStatus(globalStatus);

    final String subtitle = bothSigned
        ? "Ambas partes completaron la firma digital."
        : "El proceso aún no ha finalizado completamente.";

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.22)),
      ),
      child: Row(
        children: [
          Icon(
            bothSigned ? Icons.verified_rounded : Icons.pending_actions_rounded,
            color: color,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CustomText(
                  title,
                  baseFontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
                const SizedBox(height: 3),
                CustomText(
                  subtitle,
                  baseFontSize: 11,
                  color: Colors.grey[700]!,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignerStatusCard({
    required String title,
    required String subtitle,
    required String status,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.055),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          CustomText(title, baseFontSize: 12, fontWeight: FontWeight.bold),
          const SizedBox(height: 2),
          CustomText(
            subtitle,
            baseFontSize: 10,
            color: Colors.grey[600]!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.10),
              borderRadius: BorderRadius.circular(8),
            ),
            child: CustomText(
              _formatViafirmaStatus(status),
              baseFontSize: 10,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // Widget _buildViafirmaCodesBox({
  //   required String? viafirmaSetCode,
  //   required String? viafirmaMessageCode,
  //   required String? viafirmaSignatureDocId,
  // }) {
  //   return Container(
  //     width: double.infinity,
  //     padding: const EdgeInsets.all(12),
  //     decoration: BoxDecoration(
  //       color: Colors.white.withOpacity(0.75),
  //       borderRadius: BorderRadius.circular(14),
  //       border: Border.all(color: Colors.grey.shade200),
  //     ),
  //     child: Column(
  //       crossAxisAlignment: CrossAxisAlignment.start,
  //       children: [
  //         CustomText(
  //           "Identificadores técnicos",
  //           baseFontSize: 12,
  //           fontWeight: FontWeight.bold,
  //           color: Colors.grey[800]!,
  //         ),
  //         const SizedBox(height: 8),
  //         _buildSmallCodeLine("Set Code", viafirmaSetCode),
  //         _buildSmallCodeLine("Message Code", viafirmaMessageCode),
  //         _buildSmallCodeLine("Signature Doc ID", viafirmaSignatureDocId),
  //       ],
  //     ),
  //   );
  // }

  // Widget _buildSmallCodeLine(String label, String? value) {
  //   final text = value == null || value.isEmpty ? "No disponible" : value;

  //   return Padding(
  //     padding: const EdgeInsets.only(bottom: 5),
  //     child: SelectableText(
  //       "$label: $text",
  //       style: TextStyle(
  //         fontSize: 11,
  //         color: value == null || value.isEmpty
  //             ? Colors.grey[500]
  //             : Colors.grey[700],
  //         fontWeight: FontWeight.w500,
  //       ),
  //     ),
  //   );
  // }

  String _formatViafirmaStatus(String status) {
    switch (status) {
      case 'SIGNED':
      case 'COMPLETED':
      case 'FINISHED':
        return 'FIRMADO';
      case 'REJECTED':
        return 'RECHAZADO';
      case 'WAITING':
        return 'ESPERANDO';
      case 'PENDING':
        return 'PENDIENTE';
      case 'RECEIVED':
        return 'RECIBIDO';
      case 'created':
        return 'CREADO';
      case 'signatureInProgress':
        return 'EN FIRMA';
      case 'waitingOwnerSignature':
        return 'ESPERANDO PROPIETARIO';
      case 'signedPendingReview':
        return 'REVISIÓN ADMIN';
      case 'active':
        return 'ACTIVO';
      default:
        return status.toUpperCase();
    }
  }

  Color _colorForViafirmaStatus(String status) {
    switch (status) {
      case 'SIGNED':
      case 'COMPLETED':
      case 'FINISHED':
        return Colors.green;
      case 'REJECTED':
        return Colors.red;
      case 'WAITING':
        return Colors.blueGrey;
      case 'PENDING':
      case 'RECEIVED':
      case 'created':
        return Colors.orange;
      case 'signatureInProgress':
      case 'waitingOwnerSignature':
        return Colors.indigo;
      case 'active':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Widget _smallSectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 2),
      child: CustomText(
        text,
        baseFontSize: 12,
        fontWeight: FontWeight.w900,
        color: Colors.grey[700]!,
      ),
    );
  }

  Widget _buildLocalPdfPreviewCard(PropertyModel property) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: context.primaryColor.withOpacity(0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: context.primaryColor.withOpacity(0.2),
          width: 1.2,
        ),
      ),
      child: ListTile(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PdfViewScreen(
              path: _selectedContractFile!.path,
              title: "Borrador Cargado",
            ),
          ),
        ),
        leading: Icon(
          Icons.picture_as_pdf_rounded,
          color: context.primaryColor,
        ),
        title: CustomText(
          "Borrador Seleccionado",
          baseFontSize: 13,
          fontWeight: FontWeight.bold,
          color: context.primaryColor,
        ),
        subtitle: CustomText(
          "Documento retenido listo para enviar",
          baseFontSize: 11,
          color: Colors.grey[600]!,
        ),
        trailing: SizedBox(
          width: 80,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Expanded(
                child: IconButton(
                  icon: Icon(
                    Icons.visibility_outlined,
                    size: 18,
                    color: context.primaryColor,
                  ),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PdfViewScreen(
                        path: _selectedContractFile!.path,
                        title: "Previsualizar Contrato",
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: IconButton(
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    size: 18,
                    color: context.errorColor,
                  ),
                  onPressed: () => setState(() => _selectedContractFile = null),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPdfCardWithReject(
    BuildContext context,
    String url,
    String title,
    Color color, {
    required PropertyModel property,
    VoidCallback? onReject,
  }) {
    final bool isThisDownloading = _downloadingUrl == url;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.12)),
      ),
      child: Column(
        children: [
          ListTile(
            leading: Icon(Icons.picture_as_pdf_rounded, color: color, size: 24),
            title: CustomText(
              title.replaceAll('_', ' '),
              baseFontSize: 13,
              fontWeight: FontWeight.bold,
            ),
            trailing: SizedBox(
              width: 80,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Expanded(
                    child: IconButton(
                      icon: isThisDownloading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.blueGrey,
                              ),
                            )
                          : Icon(
                              Icons.file_download_outlined,
                              size: 20,
                              color: color,
                            ),
                      onPressed: isThisDownloading
                          ? null
                          : () async {
                              setState(() => _downloadingUrl = url);

                              final generatedName = _sanitizeFileName(
                                property.address,
                                title,
                              );

                              await DirectDownloadButton.downloadSilently(
                                context: context,
                                url: url,
                                fileName: generatedName,
                              );

                              if (mounted) {
                                setState(() => _downloadingUrl = null);
                              }
                            },
                    ),
                  ),
                  Expanded(
                    child: IconButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PdfViewScreen(path: url),
                        ),
                      ),
                      icon: Icon(
                        Icons.open_in_new_rounded,
                        color: color,
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (onReject != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 12, 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  CustomTextButton.danger(
                    "RECHAZAR FIRMA",
                    baseFontSize: 12,
                    onPressed: onReject,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPdfCard(
    BuildContext context,
    String url,
    String title,
    Color color, {
    required PropertyModel property,
    VoidCallback? onDelete,
  }) {
    final bool isThisDownloading = _downloadingUrl == url;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.12)),
      ),
      child: ListTile(
        leading: Icon(Icons.picture_as_pdf_rounded, color: color, size: 24),
        title: CustomText(
          title.replaceAll('_', ' '),
          baseFontSize: 13,
          fontWeight: FontWeight.bold,
          color: color,
        ),
        trailing: SizedBox(
          width: onDelete != null ? 100 : 80,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (onDelete != null)
                Expanded(
                  child: IconButton(
                    icon: const Icon(
                      Icons.delete_sweep_outlined,
                      color: Colors.red,
                      size: 18,
                    ),
                    onPressed: onDelete,
                  ),
                ),
              Expanded(
                child: IconButton(
                  icon: isThisDownloading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.blueGrey,
                          ),
                        )
                      : Icon(
                          Icons.file_download_outlined,
                          size: 18,
                          color: color,
                        ),
                  onPressed: isThisDownloading
                      ? null
                      : () async {
                          setState(() => _downloadingUrl = url);

                          final generatedName = _sanitizeFileName(
                            property.address,
                            title,
                          );

                          await DirectDownloadButton.downloadSilently(
                            context: context,
                            url: url,
                            fileName: generatedName,
                          );

                          if (mounted) {
                            setState(() => _downloadingUrl = null);
                          }
                        },
                ),
              ),
              Expanded(
                child: IconButton(
                  icon: Icon(Icons.open_in_new_rounded, color: color, size: 18),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => PdfViewScreen(path: url)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentReceiptWidget(BuildContext context, String? url) {
    if (url == null || url.isEmpty) {
      return buildInfoBox("Soporte de pago ausente.", context.errorColor);
    }

    return Row(
      children: [
        GestureDetector(
          onTap: () => showDialog(
            context: context,
            builder: (context) => Dialog(
              backgroundColor: Colors.black,
              child: InteractiveViewer(child: Image.network(url)),
            ),
          ),
          child: Container(
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(10)),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                url,
                height: 90,
                width: 68,
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: CustomText(
            "Recibo oficial de transferencia. Verifique que los campos de cuenta y valor en COP concuerden.",
            baseFontSize: 12,
            color: Colors.grey[600]!,
          ),
        ),
      ],
    );
  }

  Widget _buildAdminActions(
    BuildContext context,
    PropertyModel property,
    ContractModel? contract,
    CandidateModel? winner,
  ) {
    final status = contract?.status ?? property.status.name;

    if (status == 'pendingReview') {
      return _actionButton(
        "APROBAR DOCUMENTOS DE PROPIEDAD",
        context.primaryColor,
        () => _propertyService.updateStatus(
          propertyId: widget.propertyId,
          newStatus: PropertyStatusEnum.approvedPendingPayment,
        ),
        _isProcessing,
      );
    }

    if (status == 'approvedPendingPayment') {
      return buildInfoBox(
        "⏳ Esperando la confirmación de la pasarela de pagos del propietario.",
        Colors.orange[800]!,
      );
    }

    if (status == 'paidPendingReview') {
      return Row(
        children: [
          Expanded(
            child: CustomButton(
              height: 48.0,
              backgroundColor: context.errorColor,
              isLoading: _isProcessingReject,
              onPressed: () async {
                try {
                  setState(() => _isProcessingReject = true);

                  await _propertyService.updateStatus(
                    propertyId: widget.propertyId,
                    newStatus: PropertyStatusEnum.approvedPendingPayment,
                    paymentStatus: 'rejected',
                  );

                  if (contract != null) {
                    await _contractService.updateContractStatus(
                      contract.id!,
                      PropertyStatusEnum.approvedPendingPayment.name,
                    );
                  }

                  await _propertyService.updatePropertyFields(
                    propertyId: widget.propertyId,
                    fieldsToUpdate: {'paymentReceiptUrl': null},
                  );
                } catch (e) {
                  _showError("Error al rechazar el pago: $e");
                } finally {
                  if (mounted) setState(() => _isProcessingReject = false);
                }
              },
              childText: const CustomText(
                "Rechazar Pago",
                baseFontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: CustomButton(
              height: 48.0,
              backgroundColor: context.successColor,
              isLoading: _isProcessingSuccess,
              onPressed: () async {
                try {
                  setState(() => _isProcessingSuccess = true);

                  await _propertyService.updateStatus(
                    propertyId: widget.propertyId,
                    newStatus: PropertyStatusEnum.waitingSignature,
                    paymentStatus: 'approved',
                  );

                  if (contract != null) {
                    await _contractService.updateContractStatus(
                      contract.id!,
                      PropertyStatusEnum.waitingSignature.name,
                    );
                  }
                } catch (e) {
                  _showError("Error al convalidar pago: $e");
                } finally {
                  if (mounted) setState(() => _isProcessingSuccess = false);
                }
              },
              childText: const CustomText(
                "Confirmar Pago",
                baseFontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      );
    }

    if (status == ContractStatus.waitingContract.name ||
        status == ContractStatus.signatureRejected.name ||
        status == 'waitingSignature') {
      return _confirmAndSendToSignatureButton(property, contract, winner);
    }

    if (_areBothPartiesSigned(contract, winner) &&
        contract?.status != ContractStatus.active.name) {
      return Column(
        children: [
          buildInfoBox(
            "Ambas partes han completado la firma digital en Viafirma. Ya puedes aprobar el contrato y activar la propiedad.",
            context.successColor,
          ),
          const SizedBox(height: 12),
          _actionButton(
            "APROBAR Y EMITIR ACTA DE ACTIVACIÓN",
            context.successColor,
            () => _handleFinalActivation(contract!),
            _isProcessing,
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  Widget _confirmAndSendToSignatureButton(
    PropertyModel property,
    ContractModel? contract,
    CandidateModel? winner,
  ) {
    final bool hasPdf =
        (contract?.baseContractPdfUrl != null) || (_selectedContractFile != null);

    final bool canSend = hasPdf && winner != null;

    return Column(
      children: [
        buildInfoBox(
          canSend
              ? "Expediente listo. Pulse para aperturar el flujo de firmas."
              : winner == null
                  ? "Flujo suspendido: Esperando la selección de un arrendatario calificado."
                  : "Acción requerida: Cargue el documento base en PDF para firmas.",
          canSend ? context.successColor : Colors.orange[800]!,
        ),
        const SizedBox(height: 12),
        _actionButton(
          "NOTIFICAR USUARIOS PARA FIRMAS",
          canSend ? context.primaryColor : Colors.grey[400]!,
          canSend ? () => _confirmAndSendToSignature(property, contract, winner) : null,
          _isProcessingNotificarUsuarios,
        ),
      ],
    );
  }

  Widget _buildUserCard(
    String userId,
    String label,
    Color color, {
    Widget? trailingWidget,
  }) {
    _preloadUserData(userId);

    final userData = _userCache[userId];

    if (userData == null) {
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        height: 72,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: CircleAvatar(
          radius: 22,
          backgroundColor: color.withOpacity(0.08),
          backgroundImage: userData.photoUrl != null && userData.photoUrl!.isNotEmpty
              ? NetworkImage(userData.photoUrl!)
              : null,
          child: userData.photoUrl == null || userData.photoUrl!.isEmpty
              ? Icon(Icons.person_outline_rounded, color: color)
              : null,
        ),
        title: CustomText(
          userData.name,
          baseFontSize: 14,
          fontWeight: FontWeight.bold,
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 2),
          child: CustomText(
            label,
            baseFontSize: 12,
            color: color,
            fontWeight: FontWeight.w800,
          ),
        ),
        trailing: trailingWidget,
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 2),
      child: CustomText(
        title,
        baseFontSize: 14,
        fontWeight: FontWeight.w800,
        color: context.primaryColor,
      ),
    );
  }

  Widget _buildStatusHeader(String status) {
    final Color color = StatusFormatter.getPropertyStatusColor(status, context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color, width: 1.5),
      ),
      child: CustomText(
        StatusFormatter.formatPropertyStatus(status).toUpperCase(),
        textAlign: TextAlign.center,
        color: color,
        baseFontSize: 13,
        maxLines: 1,
        fontWeight: FontWeight.w900,
      ),
    );
  }

  Widget _buildImageGallery(List<String> imageUrls) {
    if (imageUrls.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 110,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: imageUrls.length,
        itemBuilder: (context, index) => Container(
          margin: const EdgeInsets.only(right: 12),
          width: 110,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            image: DecorationImage(
              image: NetworkImage(imageUrls[index]),
              fit: BoxFit.cover,
            ),
          ),
        ),
      ),
    );
  }

  Widget _actionButton(
    String label,
    Color color,
    VoidCallback? onTap,
    bool isLoading,
  ) {
    return CustomButton(
      height: 48.0,
      backgroundColor: color,
      borderRadius: 8.0,
      isLoading: isLoading,
      onPressed: onTap,
      childText: CustomText(
        label,
        baseFontSize: 13,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    );
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: CustomText(
            message,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
          backgroundColor: context.errorColor,
          behavior: SnackBarBehavior.floating,
        ),
      );

      setState(() => _isProcessing = false);
    }
  }

  void _showToast(String message, {bool isError = false}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: CustomText(
            message,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
          backgroundColor: isError ? context.errorColor : context.successColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _handleFinalActivation(ContractModel contract) async {
    setState(() => _isProcessing = true);

    try {
      await _contractService.updateContractStatus(
        contract.id!,
        ContractStatus.active.name,
      );

      await _propertyService.updateStatus(
        propertyId: widget.propertyId,
        newStatus: PropertyStatusEnum.active,
      );

      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint("Error activando: $e");
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }
}