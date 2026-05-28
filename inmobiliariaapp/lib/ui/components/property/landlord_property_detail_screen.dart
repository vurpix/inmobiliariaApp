// ui/screens/landlord/landlord_property_detail_screen.dart
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:inmobiliariaapp/enum/contract_status.dart';
import 'package:inmobiliariaapp/enum/user_role.dart';
import 'package:inmobiliariaapp/models/config/app_values_model.dart';
import 'package:inmobiliariaapp/models/contract_model.dart';
import 'package:inmobiliariaapp/models/property_model.dart';
import 'package:inmobiliariaapp/services/config_service.dart';
import 'package:inmobiliariaapp/services/contract_service.dart';
import 'package:inmobiliariaapp/ui/components/pdf/Pdf_view_screen.dart';
import 'package:inmobiliariaapp/ui/components/pdf/pdf_action_buttons.dart';
import 'package:inmobiliariaapp/utils/format_extensions.dart'; // Extensión global única para .toCOP()
import 'package:inmobiliariaapp/utils/themes.dart';
import 'package:inmobiliariaapp/ui/components/global/custom_text.dart';
import 'package:inmobiliariaapp/ui/components/auth_ux/user_review_dialog.dart';

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

  bool _isUploading = false;
  File? _selectedFile;

  int _getGestionPrice(AppValuesModel config) {
    final canon = widget.contract.canonAmount;
    for (var scale in config.priceScales) {
      if (canon >= scale.min && canon <= scale.max) {
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

  Future<bool> _checkIfAlreadyReviewed() async {
    if (widget.contract.tenant == null) return false;
    try {
      final query = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.contract.tenant!.uid)
          .collection('reviews')
          .where('contractId', isEqualTo: widget.contract.id)
          .where('fromUserId', isEqualTo: widget.contract.ownerId)
          .limit(1)
          .get();

      return query.docs.isNotEmpty;
    } catch (e) {
      debugPrint("Error verifying previous review: $e");
      return false;
    }
  }

  Future<void> _uploadAndSubmit() async {
    if (_selectedFile == null) return;

    setState(() => _isUploading = true);
    try {
      String fileName =
          'contracts/signed/OWNER_${widget.contract.id}_${DateTime.now().millisecondsSinceEpoch}.pdf';

      TaskSnapshot uploadTask = await FirebaseStorage.instance
          .ref()
          .child(fileName)
          .putFile(_selectedFile!);

      String downloadUrl = await uploadTask.ref.getDownloadURL();

      await _contractService.updateFields(widget.contract.id!, {
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

  @override
  Widget build(BuildContext context) {
    final DateTime startDate =
        widget.contract.updatedAt ?? widget.contract.createdAt;
    DateTime endDate = startDate;

    if (widget.contract.duration != null &&
        widget.contract.duration!.isNotEmpty) {
      try {
        final parts = widget.contract.duration!.split(' ');
        final int value = int.parse(parts[0]);
        final String unit = parts[1].toLowerCase();

        if (unit.contains('mes')) {
          endDate = DateTime(
            startDate.year,
            startDate.month + value,
            startDate.day,
          );
        } else if (unit.contains('año') || unit.contains('años')) {
          endDate = DateTime(
            startDate.year + value,
            startDate.month,
            startDate.day,
          );
        }
      } catch (e) {
        endDate = startDate.add(const Duration(days: 365));
      }
    } else {
      endDate = startDate.add(const Duration(days: 365));
    }

    final int daysLeft = 5; // Simulación activa para pruebas

    return Scaffold(
      backgroundColor: context.surfaceColor.withOpacity(0.96),
      appBar: AppBar(
        title: CustomText(
          "Gestión de Contrato",
          baseFontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        backgroundColor: context.primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        scrolledUnderElevation:
            0, // --- SOLUCIÓN DE COLOR TENUE AL HACER SCROLL ---
      ),
      body: StreamBuilder<AppValuesModel>(
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
          final int gestionPrice = _getGestionPrice(config);

          final bool isApproved = widget.contract.status == 'active';
          final bool isRejected = widget.contract.status == 'signatureRejected';
          final bool isPendingReview =
              widget.contract.status == ContractStatus.signedPendingReview.name;
          final bool canUpload =
              widget.contract.tenantSignedPdfUrl != null || isRejected;

          return SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPropertyHeader(),
                const SizedBox(height: 20),

                _sectionTitle("Resumen de Activación"),
                const SizedBox(height: 10),
                _buildFinancialCard(gestionPrice),
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
                if (widget.contract.baseContractPdfUrl != null)
                  _buildDocTile(
                    title: "Borrador de Contrato PDF",
                    url: widget.contract.baseContractPdfUrl!,
                    color: Colors.redAccent,
                    icon: Icons.gavel_rounded,
                    subtitle: "Documento base para firmar",
                  ),
                if (widget.contract.ownerSignedPdfUrl != null)
                  _buildDocTile(
                    title: "Mi Contrato Firmado",
                    url: widget.contract.ownerSignedPdfUrl!,
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

                if (isApproved)
                  _buildInfoBox(
                    "✅ El inmueble y el contrato han sido aprobados exitosamente. Su propiedad ya se encuentra activa en el catálogo.",
                    Colors.green[700]!,
                  )
                else if (isPendingReview)
                  _buildInfoBox(
                    "⏳ Su contrato firmado ha sido enviado y está en revisión por el administrador. Le notificaremos pronto.",
                    context.primaryColor,
                  )
                else if (canUpload) ...[
                  if (isRejected) _buildRejectAlert(),

                  _buildStep(1, "Descargue el borrador PDF arriba."),
                  _buildStep(2, "Firme el documento física o digitalmente."),
                  _buildStep(3, "Suba el PDF firmado aquí abajo."),
                  const SizedBox(height: 16),

                  _selectedFile == null
                      ? _buildInitialUploadButton()
                      : _buildPreviewAndSubmitActions(),
                ],

                // --- CALIFICACIÓN INTELIGENTE DEL INQUILINO ---
                if (isApproved &&
                    daysLeft <= 15 &&
                    widget.contract.tenant != null) ...[
                  FutureBuilder<bool>(
                    future: _checkIfAlreadyReviewed(),
                    builder: (context, reviewSnapshot) {
                      if (reviewSnapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.only(top: 20),
                          child: Center(child: LinearProgressIndicator()),
                        );
                      }

                      final bool alreadyReviewed = reviewSnapshot.data ?? false;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 20),
                          const Divider(height: 1),
                          const SizedBox(height: 16),
                          _sectionTitle("Cierre del Período Legal"),
                          const SizedBox(height: 12),
                          alreadyReviewed
                              ? _buildInfoBox(
                                  "🔒 Ya se calificó al inquilino por este período contractual de arriendo.",
                                  Colors.blueGrey[600]!,
                                )
                              : SizedBox(
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
                                    icon: const Icon(
                                      Icons.star_rate_rounded,
                                      size: 20,
                                    ),
                                    label: Text(
                                      "CALIFICAR A: ${widget.contract.tenant!.nombre.toUpperCase()}",
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
                                            widget.contract.tenant!.uid,
                                        targetUserName:
                                            widget.contract.tenant!.nombre,
                                        fromUserId: widget.contract.ownerId,
                                        fromName: "Propietario",
                                        fromRole: UserRole.landlord.name,
                                        contractId: widget.contract.id!,
                                        defaultTags: const [
                                          "Excelente comunicación",
                                          "Puntual con el canon",
                                          "Muy ordenado",
                                          "Cuidó las instalaciones",
                                          "Altamente recomendado",
                                        ],
                                      );
                                      Future.delayed(
                                        const Duration(milliseconds: 600),
                                        () {
                                          if (mounted) setState(() {});
                                        },
                                      );
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

  Widget _buildPreviewAndSubmitActions() {
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
                  onPressed: _isUploading ? null : _uploadAndSubmit,
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

  Widget _buildFinancialCard(int gestion) {
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
          _infoRow(
            "Canon de Arriendo:",
            (widget.contract.canonAmount).toInt().toCOPMoney(),
          ),
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

  Widget _buildInfoBox(String msg, Color col) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: col.withOpacity(0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: col.withOpacity(0.2)),
      ),
      child: CustomText(
        msg,
        textAlign: TextAlign.center,
        fontWeight: FontWeight.bold,
        baseFontSize: 12,
        color: col,
      ),
    );
  }
}

// --- EXTENSION DE SEGURIDAD INTERNA REUTILIZABLE PARA GARANTIZAR COMPILACIÓN SIN INTERRUPCIONES ---
extension on int {
  String toCOPMoney() {
    return "\$${this.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}";
  }
}
