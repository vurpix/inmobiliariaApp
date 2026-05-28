// ui/components/admin/admin_property_detail_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:inmobiliariaapp/models/user.dart';
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
import 'package:inmobiliariaapp/ui/components/pdf/Pdf_view_screen.dart';
import 'package:inmobiliariaapp/utils/status_formatter.dart';
import 'package:inmobiliariaapp/enum/property_status.dart';
import 'package:inmobiliariaapp/utils/themes.dart';
import 'package:inmobiliariaapp/ui/components/global/custom_text.dart'; // Componente de texto global
import 'package:inmobiliariaapp/ui/components/global/custom_text_button.dart'; // Componente de botón global

class AdminPropertyDetailScreen extends StatefulWidget {
  final String propertyId;

  const AdminPropertyDetailScreen({super.key, required this.propertyId});

  @override
  State<AdminPropertyDetailScreen> createState() =>
      _AdminPropertyDetailScreenState();
}

class _AdminPropertyDetailScreenState extends State<AdminPropertyDetailScreen> {
  final PropertyService _propertyService = PropertyService();
  final ContractService _contractService = ContractService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final UserService _userService = UserService();

  bool _isProcessing = false;
  File? _selectedContractFile;
  String? _downloadingUrl;

  Future<UserModel?> _getUserData(String? userId) async {
    if (userId == null || userId.isEmpty) return null;
    return await _userService.getUserById(userId);
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

  Future<void> _rejectSignature(ContractModel contract, bool isOwner) async {
    setState(() => _isProcessing = true);
    try {
      Map<String, dynamic> updateData = {
        'status': ContractStatus.signatureRejected.name,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (isOwner) {
        updateData['ownerSignedPdfUrl'] = null;
      } else {
        updateData['tenantSignedPdfUrl'] = null;
      }

      await _contractService.updateFields(contract.id!, updateData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: CustomText(
              "Firma del ${isOwner ? 'Propietario' : 'Inquilino'} rechazada. Se ha solicitado nueva carga.",
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      _showError("Error al rechazar: $e");
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Widget _buildUserCard(String userId, String label, Color color) {
    return FutureBuilder<UserModel?>(
      future: _getUserData(userId),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data == null) {
          return const SizedBox.shrink();
        }
        final userData = snapshot.data!;
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: context.surfaceColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.12), width: 1.2),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 6,
            ),
            leading: CircleAvatar(
              radius: 22,
              backgroundColor: color.withOpacity(0.08),
              backgroundImage: userData.photoUrl != null
                  ? NetworkImage(userData.photoUrl!)
                  : null,
              child: userData.photoUrl == null
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
                baseFontSize: 10,
                color: color,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        );
      },
    );
  }

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
      setState(() {
        _selectedContractFile = null;
      });
    } catch (e) {
      debugPrint("Error eliminando: $e");
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _confirmAndSendToSignature(
    PropertyModel property,
    ContractModel? existingContract,
    CandidateModel? winner,
  ) async {
    if (winner == null) return;
    if (_selectedContractFile == null &&
        existingContract?.baseContractPdfUrl == null)
      return;

    setState(() => _isProcessing = true);
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

      final String durationString =
          "${property.durationValue} ${property.durationUnit}";
      String nextStatus = ContractStatus.waitingTenantSignature.name;

      if (existingContract != null) {
        await _contractService.updateFields(existingContract.id!, {
          'tenant': winner.toMap(),
          'baseContractPdfUrl': finalPdfUrl,
          'status': nextStatus,
          'duration': durationString,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        final newContract = ContractModel(
          id: _firestore.collection('contracts').doc().id,
          propertyId: property.id!,
          address: property.address,
          ownerId: property.ownerId,
          tenant: winner,
          status: nextStatus,
          baseContractPdfUrl: finalPdfUrl,
          canonAmount: property.canon,
          depositAmount: property.adminPrice,
          createdAt: DateTime.now(),
          duration: durationString,
        );
        await _contractService.saveInitialContract(newContract);
      }

      await _propertyService.updateStatus(
        propertyId: widget.propertyId,
        newStatus: PropertyStatusEnum.waitingSignature,
      );

      setState(() {
        _selectedContractFile = null;
      });
    } catch (e) {
      _showError("Error al procesar el envío: $e");
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PropertyModel?>(
      stream: _propertyService.watchPropertyById(widget.propertyId),
      builder: (context, propSnapshot) {
        if (!propSnapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final property = propSnapshot.data!;

        return StreamBuilder<ContractModel?>(
          stream: _contractService.watchContractByProperty(widget.propertyId),
          builder: (context, contractSnapshot) {
            final contract = contractSnapshot.data;
            return StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('applications')
                  .where('propertyId', isEqualTo: widget.propertyId)
                  .limit(1)
                  .snapshots(),
              builder: (context, appSnapshot) {
                CandidateModel? approvedCandidate;
                if (appSnapshot.hasData && appSnapshot.data!.docs.isNotEmpty) {
                  approvedCandidate = _getApprovedCandidate(
                    appSnapshot.data!.docs.first,
                  );
                }
                final String currentStatus =
                    contract?.status ?? property.status.name;

                return Scaffold(
                  backgroundColor: context.surfaceColor.withOpacity(0.96),
                  appBar: AppBar(
                    title: CustomText(
                      "Gestión Administrativa",
                      baseFontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    backgroundColor: context.primaryColor,
                    iconTheme: const IconThemeData(color: Colors.white),
                    elevation: 0,
                  ),
                  body: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildStatusHeader(currentStatus),
                          const SizedBox(height: 24),
                          _sectionTitle("👥 Participantes del Proceso"),
                          _buildUserCard(
                            property.ownerId,
                            "PROPIETARIO REGISTRADO",
                            context.primaryColor,
                          ),
                          if (approvedCandidate != null)
                            _buildUserCard(
                              approvedCandidate.uid,
                              "INQUILINO POSTULADO",
                              Colors.green,
                            )
                          else
                            _buildInfoBox(
                              "No hay un inquilino aprobado en este momento.",
                              Colors.orange,
                            ),

                          const SizedBox(height: 24),
                          _sectionTitle("📸 Archivos de Multimedia"),
                          _buildImageGallery(property.imageUrls),

                          if (property.docUrls.isNotEmpty)
                            _buildSectionCard(
                              title: "📂 DOCUMENTOS DEL PROPIETARIO",
                              subtitle:
                                  "Soportes de tradición, libertad y legalidad",
                              color: Colors.blueGrey,
                              icon: Icons.folder_shared_outlined,
                              child: Column(
                                children: property.docUrls
                                    .map(
                                      (url) => _buildPdfCard(
                                        context,
                                        url,
                                        "DOCUMENTO_PROPIETARIO",
                                        Colors.blueGrey,
                                        property: property,
                                      ),
                                    )
                                    .toList(),
                              ),
                            ),

                          _buildSectionCard(
                            title: "💳 COMPROBANTE DE ACTIVACIÓN",
                            subtitle:
                                "Verificación manual de la pasarela de pago",
                            color: Colors.orange[800]!,
                            icon: Icons.receipt_long_outlined,
                            child: _buildPaymentReceiptWidget(
                              context,
                              property.paymentReceiptUrl,
                            ),
                          ),

                          _buildSectionCard(
                            title: "📝 CONTRATO INTERNO Y FIRMAS DIGITALES",
                            subtitle:
                                "Habilite y audite los flujos documentales",
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
                              bool isAdmin =
                                  (authState is Authenticated &&
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
                                  : _buildInfoBox(
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
              },
            );
          },
        );
      },
    );
  }

  Widget _buildContractManagementUI(
    PropertyModel property,
    ContractModel? contract,
    CandidateModel? approvedCandidate,
  ) {
    String? remotePdf = contract?.baseContractPdfUrl;
    bool isActive = contract?.status == 'active';

    bool canManagePdf =
        approvedCandidate != null ||
        isActive ||
        contract?.status == 'waiting_owner_signature' ||
        contract?.status == 'waiting_tenant_signature';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!canManagePdf)
          _buildInfoBox(
            "⚠️ Los flujos documentales se habilitarán cuando la propiedad sea aprobada, pagada y cuente con un inquilino seleccionado en las aplicaciones.",
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
              ),
            ),
        ],

        const Divider(height: 36, thickness: 0.8),

        if (contract?.ownerSignedPdfUrl != null)
          _buildPdfCardWithReject(
            context,
            contract!.ownerSignedPdfUrl!,
            "FIRMA_DEL_PROPIETARIO",
            const Color(0xFFE65100),
            property: property,
            onReject: isActive ? null : () => _rejectSignature(contract, true),
          )
        else if (contract != null &&
            !isActive &&
            contract.status != 'waiting_contract')
          _buildInfoBox(
            "Esperando firma electrónica del propietario",
            Colors.grey,
          ),

        const SizedBox(height: 12),

        if (contract?.tenantSignedPdfUrl != null)
          _buildPdfCardWithReject(
            context,
            contract!.tenantSignedPdfUrl!,
            "FIRMA_DEL_INQUILINO",
            Colors.green[700]!,
            property: property,
            onReject: isActive ? null : () => _rejectSignature(contract, false),
          )
        else if (contract != null &&
            !isActive &&
            contract.status != 'waiting_contract')
          _buildInfoBox(
            "Esperando firma electrónica del inquilino",
            Colors.grey,
          ),
      ],
    );
  }

  Widget _buildLocalPdfPreviewCard(PropertyModel property) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.orange.withOpacity(0.25), width: 1.2),
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
        leading: const Icon(Icons.picture_as_pdf_rounded, color: Colors.orange),
        title: CustomText(
          "Borrador Seleccionado",
          baseFontSize: ResponsiveUtils.getFontSize(context, 10),
          fontWeight: FontWeight.bold,
          color: Colors.orange[900],
        ),
        subtitle: CustomText(
          "Documento retenido listo para enviar",
          baseFontSize: ResponsiveUtils.getFontSize(context, 10),
          color: Colors.orange[800],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize
              .min, // Evita que el Row ocupe todo el ancho de la pantalla
          children: [
            // --- BOTÓN 1: VER VISTA PREVIA DEL PDF ---
            IconButton(
              icon: Icon(
                Icons.visibility_outlined,
                color: context.textSecondaryColor.withOpacity(0.5),
              ),
              onPressed: () {
                if (_selectedContractFile == null) return;

                // Abrimos la pantalla de previsualización del PDF pasándole el archivo local
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PdfViewScreen(
                      path: _selectedContractFile!.path,
                      title: "Previsualizar Contrato",
                    ),
                  ),
                );
              },
            ),

            // --- BOTÓN 2: ELIMINAR EL ARCHIVO SELECCIONADO ---
            IconButton(
              icon: Icon(
                Icons.delete_outline_rounded,
                color: context.textSecondaryColor.withOpacity(0.5),
              ),
              onPressed: () => setState(() => _selectedContractFile = null),
            ),
          ],
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
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => PdfViewScreen(path: url)),
            ),
            leading: Icon(Icons.picture_as_pdf_rounded, color: color, size: 24),
            title: CustomText(
              title.replaceAll('_', ' '),
              baseFontSize: 13,
              fontWeight: FontWeight.bold,
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
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
                          size: 22,
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
                          if (mounted) setState(() => _downloadingUrl = null);
                        },
                ),
                Icon(Icons.open_in_new_rounded, color: color, size: 18),
              ],
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
                    baseFontSize: ResponsiveUtils.getFontSize(context, 10),
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
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => PdfViewScreen(path: url)),
        ),
        leading: Icon(Icons.picture_as_pdf_rounded, color: color, size: 24),
        title: CustomText(
          title.replaceAll('_', ' '),
          baseFontSize: ResponsiveUtils.getFontSize(context, 10),
          fontWeight: FontWeight.bold,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onDelete != null)
              IconButton(
                icon: const Icon(
                  Icons.delete_sweep_outlined,
                  color: Colors.red,
                  size: 22,
                ),
                onPressed: onDelete,
              ),
            IconButton(
              icon: isThisDownloading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.blueGrey,
                      ),
                    )
                  : Icon(Icons.file_download_outlined, size: 22, color: color),
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
                      if (mounted) setState(() => _downloadingUrl = null);
                    },
            ),
            Icon(Icons.open_in_new_rounded, color: color, size: 18),
          ],
        ),
      ),
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
      );
    }

    if (status == 'paidPendingReview') {
      return _buildInfoBox(
        "⏳ Esperando la confirmación de la pasarela de pagos del propietario.",
        Colors.orange[800]!,
      );
    }

    if (status == 'approvedPendingPayment') {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => _propertyService.updateStatus(
                propertyId: widget.propertyId,
                newStatus: PropertyStatusEnum.approvedPendingPayment,
                paymentStatus: 'rejected',
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red, width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: const TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              child: const Text("RECHAZAR DEPÓSITO"),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: ElevatedButton(
              onPressed: () async {
                try {
                  _propertyService.updateStatus(
                    propertyId: widget.propertyId,
                    newStatus: PropertyStatusEnum.waitingSignature,
                    paymentStatus: 'approved',
                  );
                  await _contractService.updateContractStatus(
                    contract!.id!,
                    PropertyStatusEnum.waitingSignature.name,
                  );
                } catch (e) {
                  _showError("Error al convalidar pago: $e");
                }
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: Colors.green[700],
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: const TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              child: const Text("CONVALIDAR PAGO"),
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

    if (contract?.ownerSignedPdfUrl != null &&
        contract?.tenantSignedPdfUrl != null &&
        contract?.status != 'active') {
      return Column(
        children: [
          _buildInfoBox(
            "Ambas partes han completado el proceso de firma digital.",
            Colors.green,
          ),
          const SizedBox(height: 12),
          _actionButton(
            "APROBAR Y EMITIR ACTA DE ACTIVACIÓN",
            Colors.green[800]!,
            () => _handleFinalActivation(contract!),
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
        (contract?.baseContractPdfUrl != null) ||
        (_selectedContractFile != null);
    final bool canSend = hasPdf && winner != null;
    return Column(
      children: [
        _buildInfoBox(
          canSend
              ? "Expediente listo. Pulse para aperturar el flujo de firmas."
              : winner == null
              ? "Flujo suspendido: Esperando la selección de un arrendatario calificado."
              : "Acción requerida: Cargue el documento base en PDF para firmas.",
          canSend ? Colors.green : context.primaryColor,
        ),
        const SizedBox(height: 12),
        _actionButton(
          "NOTIFICAR USUARIOS PARA FIRMAS",
          canSend ? Colors.deepPurpleAccent : Colors.grey[400]!,
          canSend
              ? () => _confirmAndSendToSignature(property, contract, winner)
              : null,
        ),
      ],
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 2),
      child: CustomText.title(
        title,
        baseFontSize: 15,
        fontWeight: FontWeight.w800,
      ),
    );
  }

  Widget _buildPaymentReceiptWidget(BuildContext context, String? url) {
    if (url == null || url.isEmpty) {
      return _buildInfoBox("Soporte de pago ausente.", Colors.red);
    }
    return Row(
      children: [
        GestureDetector(
          onTap: () {
            showDialog(
              context: context,
              builder: (context) => Dialog(
                backgroundColor: Colors.black,
                child: InteractiveViewer(child: Image.network(url)),
              ),
            );
          },
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8),
              ],
            ),
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
            color: context.textSecondaryColor.withOpacity(0.7),
          ),
        ),
      ],
    );
  }

  Widget _actionButton(String label, Color color, VoidCallback? onTap) {
    final bool isButtonDisabled = _isProcessing || onTap == null;
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: isButtonDisabled ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          disabledBackgroundColor: context.textSecondaryColor.withOpacity(0.12),
          disabledForegroundColor: context.textSecondaryColor.withOpacity(0.4),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        child: _isProcessing
            ? const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Text(
                label,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  letterSpacing: 0.2,
                ),
              ),
      ),
    );
  }

  Widget _buildInfoBox(String msg, Color col) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: col.withOpacity(0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: col.withOpacity(0.2), width: 1.2),
      ),
      child: CustomText(
        msg,
        textAlign: TextAlign.center,
        baseFontSize: 12,
        fontWeight: FontWeight.w600,
        color: col,
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
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      setState(() => _isProcessing = false);
    }
  }

  Widget _buildStatusHeader(String status) {
    final Color color = StatusFormatter.getPropertyStatusColor(status);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Text(
        StatusFormatter.formatPropertyStatus(status).toUpperCase(),
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: 'Inter',
          color: color,
          fontWeight: FontWeight.w900,
          fontSize: 12,
          letterSpacing: 0.6,
        ),
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
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
            image: DecorationImage(
              image: NetworkImage(imageUrls[index]),
              fit: BoxFit.cover,
            ),
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
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.textColor.withOpacity(0.04)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1A365D).withOpacity(0.025),
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
              baseFontSize: ResponsiveUtils.getFontSize(context, 12),
              fontWeight: FontWeight.bold,
              color: color,
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 1),
              child: CustomText(
                subtitle,
                baseFontSize: ResponsiveUtils.getFontSize(context, 10),
                color: context.textSecondaryColor.withOpacity(0.6),
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
