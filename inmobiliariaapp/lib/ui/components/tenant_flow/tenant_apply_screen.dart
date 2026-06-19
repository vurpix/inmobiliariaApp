// ui/screens/tenant/tenant_apply_screen.dart
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:inmobiliariaapp/models/candidate_model.dart';
import 'package:inmobiliariaapp/models/config/price_scale.dart'; // Importación obligatoria del modelo PriceScale
import 'package:inmobiliariaapp/services/application_service.dart';
import 'package:inmobiliariaapp/services/user_service.dart';
import 'package:inmobiliariaapp/utils/format_extensions.dart';
import 'package:dio/dio.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inmobiliariaapp/bloc/subscriptionBloc/subscription_bloc.dart';
import 'package:inmobiliariaapp/bloc/subscriptionBloc/subscription_event.dart';
import 'package:inmobiliariaapp/bloc/subscriptionBloc/subscription_state.dart';
import 'package:inmobiliariaapp/ui/components/pdf/Pdf_view_screen.dart';
import 'package:inmobiliariaapp/ui/components/global/custom_text.dart';
import 'package:inmobiliariaapp/utils/themes.dart';

class TenantApplyScreen extends StatefulWidget {
  final String propertyId;
  final String propertyAddress;
  final int currentPropertyCanon;

  const TenantApplyScreen({
    super.key,
    required this.propertyId,
    required this.propertyAddress,
    required this.currentPropertyCanon,
  });

  @override
  State<TenantApplyScreen> createState() => _TenantApplyScreenState();
}

class _TenantApplyScreenState extends State<TenantApplyScreen> {
  final ImagePicker _imagePicker = ImagePicker();
  final UserService _userService = UserService();
  late Future<DocumentSnapshot> _paymentConfigFuture;
  final ApplicationService _applicationService = ApplicationService();
  bool _acceptedHabeasData = false;
  bool _isDownloading = false;
  bool _isUploadingPdf = false;
  bool _isUploadingImg = false;
  bool _isFinishing = false;

  String? _incomePdfUrl;
  String? _paymentImgUrl;
  String _pdfFileName = "No se ha seleccionado PDF";
  String _imgFileName = "No se ha seleccionado Imagen";

  @override
  void initState() {
    super.initState();
    _paymentConfigFuture = FirebaseFirestore.instance
        .collection('config')
        .doc('payment_info')
        .get();

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      context.read<SubscriptionBloc>().add(
        CalculateStudyCost(user.metadata.creationTime ?? DateTime.now()),
      );
    }
  }

  Future<void> _pickAndUploadPdf() async {
    FilePickerResult? result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result == null || result.files.single.path == null) {
      debugPrint("PDF cancelado o archivo inválido");
      return;
    }

    setState(() {
      _isUploadingPdf = true;
      _pdfFileName = result.files.single.name;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        debugPrint("Error PDF: No hay usuario autenticado");
        return;
      }

      debugPrint("UID actual: ${user.uid}");
      debugPrint("Email actual: ${user.email}");

      final file = result.files.single;
      final pdfFile = File(file.path!);

      final storageRef = FirebaseStorage.instance
          .ref()
          .child('tenant_extracts_pdf')
          .child(user.uid)
          .child('${DateTime.now().millisecondsSinceEpoch}_${file.name}');

      debugPrint("Subiendo PDF a: ${storageRef.fullPath}");

      final uploadTask = await storageRef.putFile(
        pdfFile,
        SettableMetadata(contentType: 'application/pdf'),
      );

      final url = await uploadTask.ref.getDownloadURL();

      debugPrint("PDF subido correctamente: $url");

      setState(() {
        _incomePdfUrl = url;
      });
    } on FirebaseException catch (e) {
      debugPrint("Firebase Storage Error");
      debugPrint("code: ${e.code}");
      debugPrint("message: ${e.message}");
      debugPrint("plugin: ${e.plugin}");
    } catch (e, stack) {
      debugPrint("Error PDF general: $e");
      debugPrint("Stack: $stack");
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingPdf = false;
        });
      }
    }
  }

  Future<void> _pickAndUploadImage() async {
    final XFile? image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );
    if (image == null) return;

    setState(() {
      _isUploadingImg = true;
      _imgFileName = "comprobante_pago.jpg";
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('payments_study_imgs')
          .child('${user!.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg');

      await storageRef.putFile(File(image.path));
      final url = await storageRef.getDownloadURL();
      setState(() => _paymentImgUrl = url);
    } catch (e) {
      debugPrint("Error Imagen: $e");
    } finally {
      setState(() => _isUploadingImg = false);
    }
  }

  Future<void> _processSubmit(bool isFree) async {
    setState(() => _isFinishing = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await _userService.updateIncomeAndApplication(
        uid: user.uid,
        incomePdfUrl: _incomePdfUrl!,
        propertyId: widget.propertyId,
      );

      final nuevoCandidato = CandidateModel(
        uid: user.uid,
        nombre: user.displayName ?? "Usuario",
        email: user.email ?? '',
        extractPdfUrl: _incomePdfUrl,
        paymentImgUrl: isFree ? null : _paymentImgUrl,
        status: 'pending_review',
        uploadedAt: DateTime.now(),
        isFreePromotion: isFree,
      );

      await _applicationService.applyToProperty(
        propertyId: widget.propertyId,
        propertyAddress: widget.propertyAddress,
        candidate: nuevoCandidato,
      );

      if (!isFree) {
        final config = await _paymentConfigFuture;
        final adminPhone = config.get('nequiPhone') ?? "3162868796";

        final String message =
            "¡Hola! He aplicado a una propiedad.\n"
            "🏠 *Inmueble:* ${widget.propertyAddress}\n"
            "👤 *Aspirante:* ${user.displayName}\n"
            "📊 *Extracto:* $_incomePdfUrl\n"
            "📸 *Pago:* $_paymentImgUrl";

        final whatsappUrl = Uri.parse(
          "https://wa.me/57$adminPhone?text=${Uri.encodeComponent(message)}",
        );

        if (await canLaunchUrl(whatsappUrl)) {
          await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: CustomText(
                "✅ Postulación enviada exitosamente (Promoción activa)",
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: CustomText(
              "Error al enviar postulación: $e",
              color: Colors.white,
            ),
            backgroundColor: context.errorColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isFinishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.surfaceColor.withOpacity(0.96),
      appBar: AppBar(
        title: CustomText(
          "Postulación",
          baseFontSize: 16,
          fontWeight: FontWeight.bold,
          color: context.textColor,
        ),
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: context.surfaceColor,
        iconTheme: IconThemeData(color: context.textColor),
      ),
      body: BlocBuilder<SubscriptionBloc, SubscriptionState>(
        builder: (context, subState) {
          if (subState is SubscriptionLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          bool isFree = false;
          if (subState is SubscriptionLoaded) {
            // CORRECCIÓN CENTRAL: Si freePeriodUntil es nulo o igual a la fecha de creación (días = 0), isFree es estrictamente falso
            isFree = subState.isFreePeriod;
          }

          final bool canSubmit =
              _incomePdfUrl != null &&
              _acceptedHabeasData &&
              (isFree || _paymentImgUrl != null);

          return FutureBuilder<DocumentSnapshot>(
            future: _paymentConfigFuture,
            builder: (context, snapshot) {
              final pData =
                  snapshot.data?.data() as Map<String, dynamic>? ?? {};

              return SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 20,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildPriceHeader(subState),
                    const SizedBox(height: 24),
                    _buildSectionTitle("1. Documentación de Ingresos"),
                    _buildUploadCard(
                      title: _incomePdfUrl != null
                          ? "Extracto PDF Cargado"
                          : "Seleccionar Extracto (PDF)",
                      subtitle: _pdfFileName,
                      icon: Icons.picture_as_pdf_rounded,
                      isDone: _incomePdfUrl != null,
                      isLoading: _isUploadingPdf,
                      onTap: _pickAndUploadPdf,
                      color: Colors.redAccent,
                      previewWidget: _incomePdfUrl != null
                          ? TextButton.icon(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      PdfViewScreen(path: _incomePdfUrl!),
                                ),
                              ),
                              style: TextButton.styleFrom(
                                foregroundColor: context.primaryColor,
                              ),
                              icon: const Icon(
                                Icons.visibility_outlined,
                                size: 16,
                              ),
                              label: const Text(
                                "Ver PDF",
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            )
                          : null,
                    ),
                    if (!isFree) ...[
                      const SizedBox(height: 24),
                      _buildSectionTitle("2. Pago del Estudio de Seguridad"),
                      _buildModernPaymentKeys(
                        pData['nequiPhone'] ?? '',
                        pData['digitalKey'] ?? '',
                        pData['qrImageUrl'] ?? '',
                      ),
                      const SizedBox(height: 16),
                      _buildUploadCard(
                        title: _paymentImgUrl != null
                            ? "Comprobante Cargado"
                            : "Subir Foto del Pago",
                        subtitle: _imgFileName,
                        icon: Icons.camera_alt_outlined,
                        isDone: _paymentImgUrl != null,
                        isLoading: _isUploadingImg,
                        onTap: _pickAndUploadImage,
                        color: Colors.blueAccent,
                        previewWidget: _paymentImgUrl != null
                            ? Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: context.textColor.withOpacity(0.06),
                                  ),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.network(
                                    _paymentImgUrl!,
                                    height: 100,
                                    width: 100,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              )
                            : null,
                      ),
                    ],
                    const SizedBox(height: 24),
                    _buildHabeasData(),
                    const SizedBox(height: 32),
                    _buildSubmitButton(canSubmit, isFree),
                    const SizedBox(height: 24),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  // --- COMPONENTE CONTROLADOR DE FLUJOS CORREGIDO ---
  Widget _buildPriceHeader(SubscriptionState state) {
    bool free = false;
    List<PriceScale> scales = [];

    if (state is SubscriptionLoaded) {
      free = state.isFreePeriod;
      scales = state.priceScales;
    }

    // 1. Caso Promoción de Gracia Activa (freeDays > 0)
    if (free) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.green[700],
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const CustomText(
                    "Estudio de Seguridad",
                    fontWeight: FontWeight.bold,
                    baseFontSize: 14,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 2),
                  CustomText(
                    "¡Promoción activa! Tienes días de gracia gratis.",
                    baseFontSize: 11,
                    color: Colors.white.withOpacity(0.7),
                  ),
                ],
              ),
            ),
            const CustomText(
              "GRATIS",
              fontWeight: FontWeight.w900,
              baseFontSize: 20,
              color: Colors.white,
            ),
          ],
        ),
      );
    }

    // 2. ALGORITMO DE CÁLCULO DIRECTO EN CALIENTE
    int calculatedCost = 0;
    if (scales.isNotEmpty) {
      bool rangeFound = false;
      for (var scale in scales) {
        if (widget.currentPropertyCanon >= scale.min &&
            widget.currentPropertyCanon <= scale.max) {
          calculatedCost = scale.price;
          rangeFound = true;
          break;
        }
      }
      // Salvaguarda por si supera el tope máximo configurable
      if (!rangeFound && widget.currentPropertyCanon > scales.last.max) {
        calculatedCost = scales.last.price;
      }
    }

    // 3. TARJETA ESTÁTICA PREMIUM COMPACTA (SIN LISTA DESPLEGABLE)
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.textColor.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.01),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: context.primaryColor.withOpacity(0.06),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.receipt_long_rounded,
              color: context.primaryColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CustomText(
                  "Valor del Estudio de Seguridad",
                  fontWeight: FontWeight.bold,
                  baseFontSize: 13,
                ),
                const SizedBox(height: 2),
                CustomText(
                  "Para un canon de arrendamiento de ${widget.currentPropertyCanon.toCOP()}",
                  baseFontSize: 11,
                  color: context.textSecondaryColor,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          CustomText(
            calculatedCost.toCOP(),
            fontWeight: FontWeight.w900,
            baseFontSize: 16,
            color: context.primaryColor,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 12, left: 2),
    child: CustomText(
      text,
      fontWeight: FontWeight.w900,
      baseFontSize: 14,
      color: context.primaryColor,
    ),
  );

  Widget _buildUploadCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isDone,
    required bool isLoading,
    required VoidCallback onTap,
    required Color color,
    Widget? previewWidget,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDone
              ? Colors.green.withOpacity(0.3)
              : context.textColor.withOpacity(0.04),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.015),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 4,
            ),
            onTap: isLoading ? null : onTap,
            leading: isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  )
                : Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: (isDone ? Colors.green : color).withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isDone ? Icons.check_circle_rounded : icon,
                      color: isDone ? Colors.green[700] : color,
                      size: 24,
                    ),
                  ),
            title: CustomText(
              title,
              fontWeight: FontWeight.bold,
              baseFontSize: 14,
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: CustomText(
                subtitle,
                baseFontSize: 11,
                color: context.textSecondaryColor.withOpacity(0.5),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            trailing: Icon(
              Icons.chevron_right_rounded,
              color: context.textSecondaryColor.withOpacity(0.3),
            ),
          ),
          if (previewWidget != null) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Divider(
                color: context.textColor.withOpacity(0.04),
                height: 1,
              ),
            ),
            Padding(padding: const EdgeInsets.all(14), child: previewWidget),
          ],
        ],
      ),
    );
  }

  Widget _buildModernPaymentKeys(String phone, String key, String qrUrl) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.textColor.withOpacity(0.02),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.textColor.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          _keyRow(Icons.phone_android_rounded, "CUENTA NEQUI", phone),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Divider(
              color: context.textColor.withOpacity(0.04),
              height: 1,
            ),
          ),
          _keyRow(Icons.vpn_key_outlined, "LLAVE DIGITAL", key),
          if (qrUrl.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(qrUrl, height: 130, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(height: 2),
            TextButton.icon(
              onPressed: () => _downloadQR(qrUrl),
              style: TextButton.styleFrom(
                foregroundColor: context.primaryColor,
              ),
              icon: Icon(
                _isDownloading
                    ? Icons.hourglass_empty_rounded
                    : Icons.cloud_download_outlined,
                size: 16,
              ),
              label: CustomText(
                _isDownloading ? "DESCARGANDO..." : "GUARDAR QR",
                baseFontSize: 12,
                fontWeight: FontWeight.bold,
                color: context.primaryColor,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _keyRow(IconData icon, String label, String value) => Row(
    children: [
      Icon(icon, color: context.primaryColor, size: 18),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CustomText(
              label,
              baseFontSize: 10,
              fontWeight: FontWeight.bold,
              color: context.textSecondaryColor.withOpacity(0.5),
            ),
            CustomText(value, baseFontSize: 14, fontWeight: FontWeight.bold),
          ],
        ),
      ),
      IconButton(
        icon: Icon(
          Icons.copy_all_rounded,
          color: context.textSecondaryColor.withOpacity(0.3),
          size: 18,
        ),
        onPressed: () {
          Clipboard.setData(ClipboardData(text: value));
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const CustomText(
                "Copiado al portapapeles",
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
              duration: const Duration(seconds: 1),
              backgroundColor: context.primaryColor,
              behavior: SnackBarBehavior.floating,
              width: 220,
            ),
          );
        },
      ),
    ],
  );

  Widget _buildHabeasData() => Container(
    decoration: BoxDecoration(
      color: context.surfaceColor,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: context.textColor.withOpacity(0.04)),
    ),
    child: CheckboxListTile(
      title: CustomText(
        "Autorizo el tratamiento de mis datos personales de acuerdo a las políticas de Habeas Data.",
        baseFontSize: 11,
        fontWeight: FontWeight.w500,
        color: context.textColor.withOpacity(0.7),
      ),
      value: _acceptedHabeasData,
      onChanged: (v) => setState(() => _acceptedHabeasData = v ?? false),
      controlAffinity: ListTileControlAffinity.leading,
      activeColor: context.primaryColor,
      checkColor: Colors.white,
      side: BorderSide(color: context.textColor.withOpacity(0.15), width: 1.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    ),
  );

  Widget _buildSubmitButton(bool canSubmit, bool isFree) => _isFinishing
      ? const Center(child: CircularProgressIndicator())
      : SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: canSubmit
                  ? context.primaryColor
                  : context.textColor.withOpacity(0.06),
              foregroundColor: Colors.white,
              elevation: 0,
              disabledBackgroundColor: context.textColor.withOpacity(0.06),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: canSubmit ? () => _processSubmit(isFree) : null,
            child: Text(
              "ENVIAR POSTULACIÓN",
              style: TextStyle(
                fontFamily: 'Inter',
                color: canSubmit
                    ? Colors.white
                    : context.textSecondaryColor.withOpacity(0.4),
                fontWeight: FontWeight.bold,
                fontSize: 14,
                letterSpacing: 0.2,
              ),
            ),
          ),
        );

  Future<void> _downloadQR(String url) async {
    if (_isDownloading) return;
    setState(() => _isDownloading = true);
    try {
      final tempDir = await getTemporaryDirectory();
      final path = "${tempDir.path}/qr_pago.png";
      await Dio().download(url, path);
      await Gal.putImage(path);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const CustomText(
              "✅ Código QR guardado en tu galería",
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const CustomText(
              "❌ Error al guardar el QR",
              color: Colors.white,
            ),
            backgroundColor: context.errorColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }
}
