// ui/components/tenant_flow/property_payment_screen.dart
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gal/gal.dart';
import 'package:image_picker/image_picker.dart';
import 'package:inmobiliariaapp/models/config/app_values_model.dart';
import 'package:inmobiliariaapp/models/config/payment_Info.dart';
import 'package:inmobiliariaapp/models/config/price_scale.dart';
import 'package:inmobiliariaapp/utils/format_extensions.dart';
import 'package:path_provider/path_provider.dart';

import 'package:inmobiliariaapp/bloc/paymentBloc/payment_bloc.dart';
import 'package:inmobiliariaapp/bloc/paymentBloc/payment_event.dart';
import 'package:inmobiliariaapp/bloc/paymentBloc/payment_state.dart';
import 'package:inmobiliariaapp/models/property_model.dart';
import 'package:inmobiliariaapp/services/config_service.dart';
import 'package:inmobiliariaapp/utils/themes.dart';
import 'package:inmobiliariaapp/ui/components/global/custom_text.dart';

class PropertyPaymentScreen extends StatefulWidget {
  final PropertyModel property;

  const PropertyPaymentScreen({super.key, required this.property});

  @override
  State<PropertyPaymentScreen> createState() => _PropertyPaymentScreenState();
}

class _PropertyPaymentScreenState extends State<PropertyPaymentScreen> {
  final ImagePicker _picker = ImagePicker();
  final ConfigService _configService = ConfigService();

  String? _localScreenshotPath;
  bool _isDownloading = false;

  double _calculateGestionValue(double canon, List<PriceScale> scales) {
    if (scales.isEmpty) return 200000;
    for (var scale in scales) {
      if (canon >= scale.min && canon <= scale.max) {
        return scale.price.toDouble();
      }
    }
    return scales.last.price.toDouble();
  }

  void _sendPaymentToBloc() {
    if (_localScreenshotPath == null) return;
    context.read<PaymentBloc>().add(
      UpdatePropertyPaymentOnly(
        propertyId: widget.property.id!,
        screenshotPath: _localScreenshotPath!,
      ),
    );
  }

  Future<void> _pickScreenshot() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (image != null) setState(() => _localScreenshotPath = image.path);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return BlocListener<PaymentBloc, PaymentState>(
      listener: (context, state) {
        if (state is PaymentSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const CustomText(
                "✅ Comprobante enviado a revisión jurídica",
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
          Navigator.pop(context);
        } else if (state is PaymentFailure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: CustomText("❌ ${state.error}", color: Colors.white),
              backgroundColor: context.errorColor,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
      },
      child: Scaffold(
        backgroundColor: context.surfaceColor.withOpacity(0.96),
        appBar: AppBar(
          title: CustomText(
            "Finalizar Pago",
            baseFontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          backgroundColor: context.primaryColor,
          iconTheme: const IconThemeData(color: Colors.white),
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        body: StreamBuilder<PaymentInfo>(
          stream: _configService.watchPaymentInfo(),
          builder: (context, paymentSnapshot) {
            return StreamBuilder<AppValuesModel>(
              stream: _configService.watchAppValues(),
              builder: (context, appValuesSnapshot) {
                if (!paymentSnapshot.hasData || !appValuesSnapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final paymentData = paymentSnapshot.data!;
                final appValues = appValuesSnapshot.data!;

                final double gestionValue = _calculateGestionValue(
                  widget.property.canon,
                  appValues.priceScales,
                );

                return SingleChildScrollView(
                  padding: EdgeInsets.all(size.width * 0.05),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSummaryCard(gestionValue),
                      const SizedBox(height: 24),
                      _buildModernPaymentKeys(
                        paymentData.nequiPhone,
                        paymentData.digitalKey,
                        paymentData.qrImageUrl,
                      ),
                      const SizedBox(height: 24),
                      _buildScreenshotUploader(),
                      const SizedBox(height: 32),
                      if (_localScreenshotPath != null) _buildSubmitButton(),
                      const SizedBox(height: 24),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildSummaryCard(double gestionValue) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.textColor.withOpacity(0.04)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1A365D).withOpacity(0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _priceRow("Canon Mensual", (widget.property.canon).toInt().toCOP()),
          const SizedBox(height: 8),
          _priceRow("Gestión Inicial", (gestionValue).toInt().toCOP()),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1, thickness: 0.6),
          ),
          _priceRow(
            "TOTAL A DEPOSITAR",
            (widget.property.canon + gestionValue).toInt().toCOP(),
            isTotal: true,
          ),
        ],
      ),
    );
  }

  Widget _buildModernPaymentKeys(String phone, String key, String qrUrl) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.textColor.withOpacity(0.02),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.textColor.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          CustomText.title(
            "LLAVES DE TRANSFERENCIA",
            baseFontSize: 14,
            color: context.primaryColor,
            fontWeight: FontWeight.w900,
          ),
          const SizedBox(height: 16),
          _keyCard(Icons.phone_android_rounded, "CUENTA NEQUI", phone),
          const SizedBox(height: 12),
          _keyCard(Icons.qr_code_scanner_rounded, "LLAVE DIGITAL", key),
          if (qrUrl.isNotEmpty) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  qrUrl,
                  height: 150,
                  width: 150,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 4),
            TextButton.icon(
              onPressed: _isDownloading ? null : () => _downloadQR(qrUrl),
              icon: _isDownloading
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      Icons.cloud_download_outlined,
                      size: 16,
                      color: context.primaryColor,
                    ),
              label: CustomText(
                _isDownloading ? "DESCARGANDO..." : "GUARDAR QR EN GALERÍA",
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

  Widget _keyCard(IconData icon, String title, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.textColor.withOpacity(0.04)),
      ),
      child: Row(
        children: [
          Icon(icon, color: context.primaryColor, size: 20),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CustomText(
                  title,
                  baseFontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: context.textSecondaryColor.withOpacity(0.5),
                ),
                const SizedBox(height: 2),
                CustomText(
                  value,
                  baseFontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.copy_all_rounded,
              color: context.textSecondaryColor.withOpacity(0.4),
              size: 20,
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
      ),
    );
  }

  Widget _buildScreenshotUploader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 8),
          child: CustomText(
            "Comprobante de transferencia",
            baseFontSize: 13,
            fontWeight: FontWeight.w800,
            color: context.textColor.withOpacity(0.8),
          ),
        ),
        if (_localScreenshotPath == null)
          InkWell(
            onTap: _pickScreenshot,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: double.infinity,
              height: 130,
              decoration: BoxDecoration(
                color: context.primaryColor.withOpacity(0.02),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: context.primaryColor.withOpacity(0.15),
                  width: 1.5,
                  style: BorderStyle.solid,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_photo_alternate_outlined,
                    size: 36,
                    color: context.primaryColor,
                  ),
                  const SizedBox(height: 8),
                  CustomText(
                    "Adjuntar soporte de pago (Pantallazo)",
                    baseFontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: context.primaryColor,
                  ),
                ],
              ),
            ),
          )
        else
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.02),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.green.withOpacity(0.2)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.check_circle_rounded,
                          color: Colors.green,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        const CustomText(
                          "Soporte legal cargado",
                          baseFontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ],
                    ),
                    TextButton(
                      onPressed: _pickScreenshot,
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                      ),
                      child: CustomText(
                        "REEMPLAZAR",
                        baseFontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: context.primaryColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    File(_localScreenshotPath!),
                    height: 240,
                    width: double.infinity,
                    fit: BoxFit.contain,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return BlocBuilder<PaymentBloc, PaymentState>(
      builder: (context, state) {
        final bool isLoading = state is PaymentProcessing;
        return SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: isLoading ? null : _sendPaymentToBloc,
            style: ElevatedButton.styleFrom(
              backgroundColor: context.primaryColor,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Text(
                    "NOTIFICAR DEPOSITOS A REVISIÓN",
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      letterSpacing: 0.3,
                    ),
                  ),
          ),
        );
      },
    );
  }

  Widget _priceRow(String label, String value, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        CustomText(
          label,
          baseFontSize: isTotal ? 14 : 13,
          fontWeight: isTotal ? FontWeight.w900 : FontWeight.w500,
          color: isTotal
              ? context.textColor
              : context.textSecondaryColor.withOpacity(0.7),
        ),
        CustomText(
          value,
          baseFontSize: isTotal ? 15 : 13,
          fontWeight: isTotal ? FontWeight.w900 : FontWeight.bold,
          color: isTotal ? context.primaryColor : context.textColor,
        ),
      ],
    );
  }

  Future<void> _downloadQR(String url) async {
    setState(() => _isDownloading = true);
    try {
      final tempDir = await getTemporaryDirectory();
      final path = "${tempDir.path}/qr_pago_inmueble.png";
      await Dio().download(url, path);
      await Gal.putImage(path);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const CustomText(
              "✅ Código QR guardado con éxito en tu galería",
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
            content: Text("❌ Error al descargar: $e"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }
}
