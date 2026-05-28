import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:inmobiliariaapp/utils/format_extensions.dart';
import 'package:dio/dio.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';

class StepSummaryAndPay extends StatefulWidget {
  final Map<String, dynamic> data;
  final Function(String, dynamic) onUpdate;

  const StepSummaryAndPay({
    super.key,
    required this.data,
    required this.onUpdate,
  });

  @override
  State<StepSummaryAndPay> createState() => _StepSummaryAndPayState();
}

class _StepSummaryAndPayState extends State<StepSummaryAndPay> {
  final ImagePicker _picker = ImagePicker();
  bool _isDownloading = false;

  double get _gestionValue {
    double canon = widget.data['canon'] ?? 0.0;
    if (canon > 20000000) return 1000000;
    if (canon > 5000000) return 500000;
    if (canon > 3000000) return 350000;
    return 200000;
  }

  Future<void> _downloadQR(String url) async {
    setState(() => _isDownloading = true);
    try {
      final tempDir = await getTemporaryDirectory();
      final path = "${tempDir.path}/qr_pago.png";
      await Dio().download(url, path);
      await Gal.putImage(path);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("✅ QR guardado en tu galería")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("❌ Error al descargar: $e")));
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  Future<void> _pickScreenshot() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (image != null) {
      widget.onUpdate('paymentScreenshot', image.path);
    }
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Copiado al portapapeles"),
        duration: Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
 

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('config')
          .doc('payment_info')
          .get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 300,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final paymentData =
            snapshot.data?.data() as Map<String, dynamic>? ?? {};
        final String nequiPhone = paymentData['nequiPhone'] ?? '3102198939';
        final String digitalKey = paymentData['digitalKey'] ?? '@EAMA7209';
        final String qrUrl = paymentData['qrImageUrl'] ?? '';

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              _buildSummaryCard(),
              const SizedBox(height: 25),
              _buildModernPaymentKeys(nequiPhone, digitalKey, qrUrl),
              const SizedBox(height: 25),
              _buildScreenshotUploader(),
              const SizedBox(height: 20),
              _buildWarningNote(),
              const SizedBox(height: 30),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          _priceRow(
            "Canon Mensual",
            FormatUtils.formatCurrency(widget.data['canon'] ?? 0),
          ),
          const SizedBox(height: 8),
          _priceRow("Gestión Inicial", FormatUtils.formatCurrency(_gestionValue)),
          const Divider(height: 30),
          _priceRow(
            "TOTAL A PAGAR",
            FormatUtils.formatCurrency((widget.data['canon'] ?? 0) + _gestionValue),
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
        color: const Color(0xFF1A1F26),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          const Icon(Icons.vpn_key_outlined, color: Colors.blue, size: 35),
          const SizedBox(height: 12),
          const Text(
            "LLAVES DE PAGO",
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 20),
          _keyCard(Icons.phone_android, "LLAVE TELEFÓNICA", phone),
          const SizedBox(height: 12),
          _keyCard(Icons.alternate_email, "LLAVE DIGITAL", key),
          const SizedBox(height: 25),
          const Text(
            "CÓDIGO QR DE PAGO",
            style: TextStyle(
              color: Colors.grey,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 15),
          if (qrUrl.isNotEmpty)
            Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    qrUrl,
                    height: 160,
                    width: 160,
                    fit: BoxFit.cover,
                  ),
                ),
                TextButton.icon(
                  onPressed: _isDownloading ? null : () => _downloadQR(qrUrl),
                  icon: _isDownloading
                      ? const SizedBox(
                          width: 15,
                          height: 15,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.download, color: Colors.blue),
                  label: Text(
                    _isDownloading ? "DESCARGANDO..." : "DESCARGAR QR",
                    style: const TextStyle(color: Colors.blue),
                  ),
                ),
              ],
            )
          else
            const Icon(Icons.qr_code_2, size: 100, color: Colors.white24),
        ],
      ),
    );
  }

  Widget _keyCard(IconData icon, String title, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF252B33),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: const Color(0xFF1A1F26),
            radius: 18,
            child: Icon(icon, color: Colors.blue, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy, color: Colors.white38, size: 18),
            onPressed: () => _copyToClipboard(value),
          ),
        ],
      ),
    );
  }

  Widget _buildScreenshotUploader() {
    final String? screenshotPath = widget.data['paymentScreenshot'];
    return Column(
      children: [
        if (screenshotPath == null)
          ElevatedButton.icon(
            onPressed: _pickScreenshot,
            icon: const Icon(Icons.upload_file),
            label: const Text("SUBIR COMPROBANTE DE PAGO"),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
              backgroundColor: Colors.blue[900],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          )
        else
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.green, width: 2),
              borderRadius: BorderRadius.circular(12),
              color: Colors.green.withOpacity(0.05),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    File(screenshotPath),
                    height: 50,
                    width: 50,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 15),
                const Expanded(
                  child: Text(
                    "✅ Comprobante cargado",
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.green),
                  onPressed: _pickScreenshot,
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildWarningNote() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              "Debes subir el comprobante para habilitar el envío del registro.",
              style: TextStyle(
                fontSize: 11,
                color: Colors.brown,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _priceRow(String label, String value, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isTotal ? 16 : 14,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isTotal ? 16 : 14,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            color: isTotal ? Colors.blue[900] : Colors.black,
          ),
        ),
      ],
    );
  }
}
