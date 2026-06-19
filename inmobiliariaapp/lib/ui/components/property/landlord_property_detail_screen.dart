// ui/screens/landlord/landlord_property_detail_screen.dart

import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inmobiliariaapp/bloc/signatureBloc/signature_bloc_bloc.dart';
import 'package:inmobiliariaapp/bloc/signatureBloc/signature_bloc_event.dart';
import 'package:inmobiliariaapp/bloc/signatureBloc/signature_bloc_state.dart';
import 'package:inmobiliariaapp/enum/contract_status.dart';
import 'package:inmobiliariaapp/enum/user_role.dart';
import 'package:inmobiliariaapp/models/config/app_values_model.dart';
import 'package:inmobiliariaapp/models/contract_model.dart';
import 'package:inmobiliariaapp/models/property_model.dart';
import 'package:inmobiliariaapp/services/config_service.dart';
import 'package:inmobiliariaapp/services/contract_service.dart';
import 'package:inmobiliariaapp/ui/components/info_box_widget.dart';
import 'package:inmobiliariaapp/ui/components/pdf/Pdf_view_screen.dart';
import 'package:inmobiliariaapp/ui/components/pdf/pdf_action_buttons.dart';
import 'package:inmobiliariaapp/utils/themes.dart';
import 'package:inmobiliariaapp/ui/components/global/custom_text.dart';
import 'package:inmobiliariaapp/ui/components/auth_ux/user_review_dialog.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';


class LandlordPropertyDetailScreen extends StatefulWidget {
  final ContractModel contract;
  final PropertyModel property;

  const LandlordPropertyDetailScreen({
    super.key,
    required this.property,
    required this.contract,
  });

  @override
  State<LandlordPropertyDetailScreen> createState() =>
      _LandlordPropertyDetailScreenState();
}

class _LandlordPropertyDetailScreenState
    extends State<LandlordPropertyDetailScreen> {
  final ContractService _contractService = ContractService();
  final ConfigService _configService = ConfigService();

  late final Stream<ContractModel?> _contractStream;
  late final String _contractId;

  bool _isUploading = false;
  File? _selectedFile;

  @override
  void initState() {
    super.initState();

    _contractStream = _contractService.watchContractByProperty(
      widget.property.id!,
    );

    _contractId = widget.contract.id ?? widget.property.id!;
  }

  int _getGestionPrice(AppValuesModel config, double canonAmount) {
    for (var scale in config.priceScales) {
      if (canonAmount >= scale.min && canonAmount <= scale.max) {
        return scale.price;
      }
    }
    return 0;
  }

  Future<void> _pickContractFile() async {
    try {
      FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _selectedFile = File(result.files.single.path!);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const CustomText(
              "Archivo seleccionado. Por favor verifíquelo antes de enviar.",
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
            backgroundColor: context.primaryColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint("Error seleccionando archivo: $e");
    }
  }

  Future<bool> _checkIfAlreadyReviewed(ContractModel currentContract) async {
    if (currentContract.tenant == null) return false;

    try {
      final query = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentContract.tenant!.uid)
          .collection('reviews')
          .where('contractId', isEqualTo: currentContract.id)
          .where('fromUserId', isEqualTo: currentContract.ownerId)
          .limit(1)
          .get();

      return query.docs.isNotEmpty;
    } catch (e) {
      debugPrint("Error verifying previous review: $e");
      return false;
    }
  }

  Future<void> _uploadAndSubmit(ContractModel currentContract) async {
    if (_selectedFile == null) return;

    setState(() => _isUploading = true);

    try {
      String fileName =
          'contracts/signed/OWNER_${currentContract.id}_${DateTime.now().millisecondsSinceEpoch}.pdf';

      TaskSnapshot uploadTask = await FirebaseStorage.instance
          .ref()
          .child(fileName)
          .putFile(_selectedFile!);

      String downloadUrl = await uploadTask.ref.getDownloadURL();

      await _contractService.updateFields(currentContract.id!, {
        'ownerSignedPdfUrl': downloadUrl,
        'status': ContractStatus.signedPendingReview.name,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const CustomText(
              "✅ Contrato firmado enviado correctamente",
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
            backgroundColor: Colors.green[700],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: CustomText("❌ Error: $e", color: Colors.white),
            backgroundColor: context.errorColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _openOwnerWebView(
    BuildContext context,
    String link,
    String contractId,
  ) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MyWebViewPage(
          initialUrl: link,
        ),
      ),
    );

    if (!context.mounted) return;

    context.read<SignatureBloc>().add(
          RefreshSignatureStatusRequested(contractId),
        );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => SignatureBloc()
        ..add(
          WatchContractSignatureRequested(_contractId),
        ),
      child: Scaffold(
        backgroundColor: context.surfaceColor.withOpacity(0.96),
        appBar: AppBar(
          title: const CustomText(
            "Gestión de Contrato",
            baseFontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          backgroundColor: context.primaryColor,
          iconTheme: const IconThemeData(color: Colors.white),
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        body: StreamBuilder<ContractModel?>(
          stream: _contractStream,
          builder: (context, contractSnapshot) {
            final ContractModel currentContract =
                contractSnapshot.data ?? widget.contract;

            return StreamBuilder<AppValuesModel>(
              stream: _configService.watchAppValues(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData) {
                  return const Center(
                    child: CustomText(
                      "Error al cargar configuración",
                      baseFontSize: 14,
                    ),
                  );
                }

                final config = snapshot.data!;
                final int gestionPrice = _getGestionPrice(
                  config,
                  currentContract.canonAmount,
                );

                return BlocBuilder<SignatureBloc, SignatureState>(
                  builder: (context, signatureState) {
                    final bool isApproved =
                        currentContract.status == 'active';

                    final bool isRejected =
                        currentContract.status ==
                        ContractStatus.signatureRejected.name;

                    final bool isPendingReview =
                        currentContract.status ==
                        ContractStatus.signedPendingReview.name;

                    bool ownerHasSigned = false;
                    String? myOwnerSignLink;
                    String ownerSignatureStatus = 'WAITING';
                    String tenantSignatureStatus = 'PENDING';

                    final ownerUid = currentContract.ownerId;

                    if (signatureState.signature != null) {
                      final signature = signatureState.signature!;

                      ownerSignatureStatus = signature.statusForUser(ownerUid);
                      tenantSignatureStatus =
                          signature.tenantSignatureStatus;

                      myOwnerSignLink = signature.signLinkForUser(ownerUid);

                      ownerHasSigned = ownerSignatureStatus == 'SIGNED' ||
                          ownerSignatureStatus == 'COMPLETED';
                    } else {
                      if (currentContract.signaturesTracking != null) {
                        final tracking = currentContract.signaturesTracking!;

                        if (tracking.containsKey(ownerUid)) {
                          final ownerStatus = tracking[ownerUid]!.status;
                          ownerSignatureStatus = ownerStatus;
                          ownerHasSigned = ownerStatus == 'SIGNED' ||
                              ownerStatus == 'COMPLETED';

                          try {
                            final rawTrackingMap = (currentContract as dynamic)
                                .toMap()['signaturesTracking']?[ownerUid] as Map?;

                            if (rawTrackingMap != null &&
                                rawTrackingMap.containsKey('signLink')) {
                              myOwnerSignLink =
                                  rawTrackingMap['signLink']?.toString();
                            }
                          } catch (_) {
                            myOwnerSignLink = tracking[ownerUid]!.signLink;
                          }
                        }
                      }
                    }

                    final bool canUpload =
                        !ownerHasSigned && !isPendingReview && !isApproved;

                    return SingleChildScrollView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildPropertyHeader(),
                          const SizedBox(height: 20),

                          _sectionTitle("Resumen de Activación"),
                          const SizedBox(height: 10),
                          _buildFinancialCard(
                            gestionPrice,
                            currentContract.canonAmount,
                          ),
                          const SizedBox(height: 8),

                          Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: CustomText(
                              "* Este cobro de gestión es único para activar la propiedad.",
                              baseFontSize: 12,
                              color: context.textSecondaryColor.withOpacity(0.5),
                            ),
                          ),

                          const SizedBox(height: 20),
                          const Divider(height: 1),
                          const SizedBox(height: 16),

                          _sectionTitle("Documentos del Proceso"),
                          const SizedBox(height: 12),

                          ...widget.property.docUrls.map(
                            (url) => _buildDocTile(
                              title: "Soporte Legal Propiedad",
                              url: url,
                              color: Colors.orange[800]!,
                              icon: Icons.account_balance_outlined,
                            ),
                          ),

                          if (currentContract.baseContractPdfUrl != null)
                            _buildDocTile(
                              title: "Borrador de Contrato PDF",
                              url: currentContract.baseContractPdfUrl!,
                              color: Colors.redAccent,
                              icon: Icons.gavel_rounded,
                              subtitle: "Documento base para firmar",
                            ),

                          if (ownerHasSigned &&
                              currentContract.ownerSignedPdfUrl != null)
                            _buildDocTile(
                              title: "📄 CONTRATO LEGALIZADO (CON TU FIRMA)",
                              url: currentContract.ownerSignedPdfUrl!,
                              color: Colors.blue[800]!,
                              icon: Icons.verified_user_rounded,
                              subtitle: "Documento firmado oficialmente",
                            )
                          else if (currentContract.ownerSignedPdfUrl != null)
                            _buildDocTile(
                              title: "Mi Contrato Firmado",
                              url: currentContract.ownerSignedPdfUrl!,
                              color: Colors.green[700]!,
                              icon: Icons.draw_rounded,
                              subtitle: isApproved
                                  ? "Documento aprobado por administración"
                                  : "Documento en revisión",
                            ),

                          const SizedBox(height: 20),
                          const Divider(height: 1),
                          const SizedBox(height: 16),

                          _sectionTitle("Estado del Proceso"),
                          const SizedBox(height: 12),

                          if (signatureState.status == SignatureStatus.loading ||
                              signatureState.status == SignatureStatus.initial)
                            buildInfoBox(
                              "⏳ Consultando estado de firma digital...",
                              Colors.blueGrey,
                            ),

                          if (signatureState.errorMessage != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: buildInfoBox(
                                "⚠️ ${signatureState.errorMessage}",
                                Colors.redAccent,
                              ),
                            ),

                          _buildSignatureStatusBox(
                            ownerStatus: ownerSignatureStatus,
                            tenantStatus: tenantSignatureStatus,
                          ),

                          const SizedBox(height: 12),

                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              icon: signatureState.isRefreshing
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.sync),
                              label: const Text("Actualizar estado de firma"),
                              onPressed: signatureState.isRefreshing
                                  ? null
                                  : () {
                                      context.read<SignatureBloc>().add(
                                            RefreshSignatureStatusRequested(
                                              _contractId,
                                            ),
                                          );
                                    },
                            ),
                          ),

                          const SizedBox(height: 16),

                          if (isApproved)
                            buildInfoBox(
                              "✅ ¡PROCESO COMPLETADO! El contrato con su firma digital ha sido verificado con éxito. Su propiedad ya está activa en el catálogo público.",
                              Colors.green[700]!,
                            )
                          else if (ownerHasSigned && isPendingReview)
                            buildInfoBox(
                              "🎉 ¡Firma completada! El contrato fue firmado exitosamente por Usted. Se encuentra en validación jurídica final por el Administrador.",
                              Colors.teal[700]!,
                            )
                          else if (isPendingReview)
                            buildInfoBox(
                              "⏳ Su contrato firmado ha sido enviado y está en revisión por el administrador. Le notificaremos pronto.",
                              context.primaryColor,
                            )
                          else if (canUpload) ...[
                            if (isRejected) _buildRejectAlert(),

                            if (myOwnerSignLink != null &&
                                myOwnerSignLink.isNotEmpty) ...[
                              Container(
                                width: double.infinity,
                                margin: const EdgeInsets.only(bottom: 14),
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFE65100),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 1,
                                  ),
                                  icon: const Icon(
                                    Icons.assignment_turned_in_rounded,
                                    size: 20,
                                  ),
                                  label: const Text(
                                    "IR A FIRMAR CONTRATO DIGITAL (IN-APP)",
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                  onPressed: () async {
                                    await _openOwnerWebView(
                                      context,
                                      myOwnerSignLink!,
                                      _contractId,
                                    );
                                  },
                                ),
                              ),
                            ],

                            _buildStep(
                              1,
                              "Descargue el borrador PDF arriba o use el acceso digital de Viafirma.",
                            ),
                            _buildStep(
                              2,
                              "Firme el documento física o digitalmente.",
                            ),
                            _buildStep(
                              3,
                              "Suba el PDF firmado aquí abajo si optó por firma externa manual.",
                            ),
                            const SizedBox(height: 16),

                            _selectedFile == null
                                ? _buildInitialUploadButton()
                                : _buildPreviewAndSubmitActions(
                                    currentContract,
                                  ),
                          ],

                          if (isApproved && currentContract.tenant != null) ...[
                            FutureBuilder<bool>(
                              future: _checkIfAlreadyReviewed(currentContract),
                              builder: (context, reviewSnapshot) {
                                if (reviewSnapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return const Padding(
                                    padding: EdgeInsets.only(top: 20),
                                    child: Center(
                                      child: LinearProgressIndicator(),
                                    ),
                                  );
                                }

                                final bool alreadyReviewed =
                                    reviewSnapshot.data ?? false;

                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 20),
                                    const Divider(height: 1),
                                    const SizedBox(height: 16),
                                    _sectionTitle("Cierre del Período Legal"),
                                    const SizedBox(height: 12),

                                    alreadyReviewed
                                        ? buildInfoBox(
                                            "🔒 Ya se calificó al inquilino por este período contractual de arriendo.",
                                            Colors.blueGrey[600]!,
                                          )
                                        : SizedBox(
                                            width: double.infinity,
                                            height: 48,
                                            child: ElevatedButton.icon(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    context.primaryColor,
                                                foregroundColor: Colors.white,
                                                elevation: 0,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                              ),
                                              icon: const Icon(
                                                Icons.star_rate_rounded,
                                                size: 20,
                                              ),
                                              label: Text(
                                                "CALIFICAR A: ${currentContract.tenant!.nombre.toUpperCase()}",
                                                style: const TextStyle(
                                                  fontFamily: 'Inter',
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12,
                                                  letterSpacing: 0.2,
                                                ),
                                              ),
                                              onPressed: () async {
                                                await UserReviewDialog.show(
                                                  context: context,
                                                  targetUserId:
                                                      currentContract.tenant!.uid,
                                                  targetUserName:
                                                      currentContract
                                                          .tenant!.nombre,
                                                  fromUserId:
                                                      currentContract.ownerId,
                                                  fromName: "Propietario",
                                                  fromRole:
                                                      UserRole.landlord.name,
                                                  contractId:
                                                      currentContract.id!,
                                                  defaultTags: const [
                                                    "Excelente comunicación",
                                                    "Puntual con el canon",
                                                    "Muy ordenado",
                                                    "Cuidó las instalaciones",
                                                    "Altamente recomendado",
                                                  ],
                                                );

                                                if (mounted) setState(() {});
                                              },
                                            ),
                                          ),
                                  ],
                                );
                              },
                            ),
                          ],

                          const SizedBox(height: 24),
                        ],
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildSignatureStatusBox({
    required String ownerStatus,
    required String tenantStatus,
  }) {
    String label(String status) {
      switch (status) {
        case 'PENDING':
          return 'Pendiente por firmar';
        case 'WAITING':
          return 'Esperando turno';
        case 'SIGNED':
        case 'COMPLETED':
          return 'Firmado';
        case 'REJECTED':
          return 'Rechazado';
        case 'RECEIVED':
          return 'Recibido por Viafirma';
        case 'FINISHED':
          return 'Finalizado';
        case 'ERROR':
          return 'Error';
        default:
          return status;
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFE65100).withOpacity(0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFE65100).withOpacity(0.16),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CustomText(
            "Estado de firmas digitales",
            baseFontSize: 13,
            fontWeight: FontWeight.bold,
            color: Color(0xFFE65100),
          ),
          const SizedBox(height: 8),
          CustomText(
            "Inquilino: ${label(tenantStatus)}",
            baseFontSize: 12,
          ),
          const SizedBox(height: 4),
          CustomText(
            "Mi firma como propietario: ${label(ownerStatus)}",
            baseFontSize: 12,
          ),
        ],
      ),
    );
  }

  Widget _buildInitialUploadButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: context.primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: _pickContractFile,
        icon: const Icon(Icons.upload_file_rounded, size: 20),
        label: const Text(
          "SUBIR CONTRATO FIRMADO",
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildPreviewAndSubmitActions(ContractModel currentContract) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.04),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.green.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.check_circle_rounded,
                color: Colors.green,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: CustomText(
                  "Nuevo: ${_selectedFile!.path.split('/').last}",
                  baseFontSize: 13,
                  fontWeight: FontWeight.bold,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: Colors.redAccent,
                  size: 20,
                ),
                onPressed: () => setState(() => _selectedFile = null),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 46,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: context.primaryColor,
                    side: BorderSide(
                      color: context.primaryColor.withOpacity(0.4),
                      width: 1.5,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PdfViewScreen(path: _selectedFile!.path),
                    ),
                  ),
                  icon: const Icon(Icons.visibility_outlined, size: 18),
                  label: const Text(
                    "VER PDF",
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 46,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[700],
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _isUploading
                      ? null
                      : () => _uploadAndSubmit(currentContract),
                  icon: _isUploading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.send_rounded, size: 16),
                  label: Text(
                    _isUploading ? "ENVIANDO..." : "ENVIAR FIRMA",
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRejectAlert() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.red.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.error_outline_rounded,
                color: Colors.red[700],
                size: 20,
              ),
              const SizedBox(width: 8),
              const CustomText(
                "FIRMA RECHAZADA",
                baseFontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ],
          ),
          const SizedBox(height: 6),
          CustomText(
            "El administrador ha rechazado el documento cargado. Por favor, revise las correcciones solicitadas y suba el archivo nuevamente.",
            baseFontSize: 12,
            color: context.textColor.withOpacity(0.8),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) => Padding(
        padding: const EdgeInsets.only(left: 2),
        child: CustomText(
          title,
          fontWeight: FontWeight.w900,
          baseFontSize: 14,
          color: context.primaryColor,
        ),
      );

  Widget _buildPropertyHeader() {
    return Row(
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.network(
              widget.property.imageUrls.isNotEmpty
                  ? widget.property.imageUrls.first
                  : 'https://via.placeholder.com/100',
              width: 80,
              height: 80,
              fit: BoxFit.cover,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CustomText.title(
                widget.property.address,
                baseFontSize: 16,
                fontWeight: FontWeight.w800,
              ),
              const SizedBox(height: 6),
              if (widget.contract.id != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: context.primaryColor.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: CustomText(
                    "ID: #${widget.contract.id!.substring(0, 8).toUpperCase()}",
                    baseFontSize: 10,
                    color: context.primaryColor,
                    fontWeight: FontWeight.w900,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFinancialCard(int gestion, double canonAmount) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.textColor.withOpacity(0.04)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1A365D).withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _infoRow("Canon de Arriendo:", canonAmount.toInt().toCOPMoney()),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(height: 1, thickness: 0.5),
          ),
          _infoRow(
            "Costo Gestión Inmobiliaria:",
            gestion.toCOPMoney(),
            isBold: true,
            color: context.primaryColor,
          ),
        ],
      ),
    );
  }

  Widget _buildDocTile({
    required String title,
    required String url,
    required Color color,
    required IconData icon,
    String? subtitle,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.textColor.withOpacity(0.04)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => PdfViewScreen(path: url)),
        ),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        title: CustomText(title, baseFontSize: 13, fontWeight: FontWeight.bold),
        subtitle: subtitle != null
            ? CustomText(
                subtitle,
                baseFontSize: 11,
                color: context.textSecondaryColor.withOpacity(0.6),
              )
            : null,
        trailing: PdfActionButtons(
          url: url,
          title: widget.property.address,
          propertyAddress: widget.property.address,
          color: color,
          downloadIcon: Icons.download_outlined,
          viewIcon: Icons.visibility_outlined,
          downloadIconSize: 16,
          viewIconSize: 16,
        ),
      ),
    );
  }

  Widget _infoRow(
    String label,
    String value, {
    bool isBold = false,
    Color? color,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        CustomText(
          label,
          baseFontSize: 13,
          color: context.textSecondaryColor.withOpacity(0.7),
        ),
        CustomText(
          value,
          baseFontSize: 13,
          fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
          color: color,
        ),
      ],
    );
  }

  Widget _buildStep(int num, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
      child: Row(
        children: [
          CircleAvatar(
            radius: 9,
            backgroundColor: context.primaryColor,
            child: Text(
              num.toString(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: CustomText(
              text,
              baseFontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

extension on int {
  String toCOPMoney() {
    return "\$${toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}";
  }
}

// =========================================================================
// 🟢 INTEGRACIÓN DE LA CLASE DE NAVEGACIÓN Y ESCUCHA DE CAMBIOS
// =========================================================================

class CustomInAppWebController extends ChangeNotifier {
  InAppWebViewController? _webViewController;
  String _currentUrl = "";
  bool _isLoading = false;
  double _progress = 0.0;

  String get currentUrl => _currentUrl;
  bool get isLoading => _isLoading;
  double get progress => _progress;
  InAppWebViewController? get controller => _webViewController;

  void setController(InAppWebViewController controller) {
    _webViewController = controller;
  }

  void updateUrl(WebUri? url) {
    if (url != null) {
      _currentUrl = url.toString();
      notifyListeners();
    }
  }

  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void updateProgress(int progress) {
    _progress = progress / 100;
    notifyListeners();
  }

  Future<void> goBack() async {
    if (await _webViewController?.canGoBack() ?? false) {
      await _webViewController?.goBack();
    }
  }

  Future<void> reload() async {
    await _webViewController?.reload();
  }
}

class MyWebViewPage extends StatefulWidget {
  final String initialUrl;

  const MyWebViewPage({
    Key? key,
    required this.initialUrl,
  }) : super(key: key);

  @override
  State<MyWebViewPage> createState() => _MyWebViewPageState();
}

class _MyWebViewPageState extends State<MyWebViewPage> {
  late CustomInAppWebController _webController;

  @override
  void initState() {
    super.initState();
    _webController = CustomInAppWebController();
  }

  @override
  void dispose() {
    _webController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Firma de Contrato Digital",
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFFE65100),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _webController.reload(),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: _webController,
        builder: (context, child) {
          return Column(
            children: [
              if (_webController.isLoading)
                LinearProgressIndicator(
                  value: _webController.progress,
                  color: const Color(0xFFE65100),
                ),
              Expanded(
                child: InAppWebView(
                  initialUrlRequest: URLRequest(url: WebUri(widget.initialUrl)),
                  initialSettings: InAppWebViewSettings(
                    useShouldOverrideUrlLoading: true,
                    mediaPlaybackRequiresUserGesture: false,
                    javaScriptEnabled: true,
                    domStorageEnabled: true,
                    databaseEnabled: true,
                    thirdPartyCookiesEnabled: true,
                    userAgent:
                        "Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36",
                  ),
                  onWebViewCreated: (controller) {
                    _webController.setController(controller);
                  },
                  onLoadStart: (controller, url) {
                    _webController.setLoading(true);
                    _webController.updateUrl(url);
                  },
                  onLoadStop: (controller, url) {
                    _webController.setLoading(false);
                    _webController.updateUrl(url);
                  },
                  onProgressChanged: (controller, progress) {
                    _webController.updateProgress(progress);
                  },
                  shouldOverrideUrlLoading:
                      (controller, navigationAction) async {
                    var uri = navigationAction.request.url;

                    if (uri != null &&
                        (uri.toString().contains("success") ||
                            uri.toString().contains("complete"))) {
                      debugPrint(
                        "🎯 ¡Contrato firmado detectado en la URL!: $uri",
                      );

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            "¡Proceso completado en el portal de firma!",
                          ),
                        ),
                      );

                      Navigator.pop(context);
                      return NavigationActionPolicy.CANCEL;
                    }

                    return NavigationActionPolicy.ALLOW;
                  },
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: ListenableBuilder(
        listenable: _webController,
        builder: (context, child) {
          return Container(
            color: Colors.white,
            height: 50,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => _webController.goBack(),
                ),
                const Text(
                  "Navegación Segura",
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}