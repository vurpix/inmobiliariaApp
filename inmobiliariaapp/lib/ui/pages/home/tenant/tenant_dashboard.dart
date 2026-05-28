import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:inmobiliariaapp/services/contract_service.dart';
import 'package:inmobiliariaapp/utils/format_extensions.dart';
import 'package:dio/dio.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

class TenantDashboard extends StatefulWidget {
  final dynamic property; // Pasamos la propiedad para obtener el ID

  const TenantDashboard({super.key, required this.property});

  @override
  State<TenantDashboard> createState() => _TenantDashboardState();
}

class _TenantDashboardState extends State<TenantDashboard> {
  final ImagePicker _picker = ImagePicker();
  final ContractService _contractService = ContractService();

  // Estados de carga y URLs
  bool _isDownloading = false;
  bool _isUploadingDoc = false;
  bool _isUploadingPay = false;
  bool _isFinishing = false;

  String? _idDocumentUrl;
  String? _paymentReceiptUrl;
  String? _contractDocId; // ID que recuperamos del servicio

  final double _costoEstudio = 60000;

  @override
  void initState() {
    super.initState();
    _loadContractData(); // Cargamos el ID del contrato al iniciar
  }

  // --- LÓGICA DE DATOS ---

  Future<void> _loadContractData() async {
    try {
      final contract = await _contractService.getContractData(
        widget.property.id,
      );
      if (contract != null) {
        setState(() {
          _contractDocId = contract.id;
          // Si ya existen documentos previos, podrías cargarlos aquí si quisieras
        });
      }
    } catch (e) {
      debugPrint("Error al cargar datos del contrato: $e");
    }
  }

  // 1. Lógica de WhatsApp
  Future<void> _sendWhatsAppAuto(String receiptUrl) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('config')
          .doc('payment_info')
          .get();

      final adminPhone = doc.data()?['nequiPhone'] ?? "3162868796";

      final String message =
          "¡Hola! He realizado el pago de mi estudio de seguridad y adjunto los documentos.\n\n"
          "🏠 *Propiedad:* ${widget.property.title}\n"
          "📄 *Comprobante de Pago:* $receiptUrl\n"
          "🆔 *Documento Identidad:* $_idDocumentUrl\n\n"
          "Quedo atento a la verificación jurídica. Gracias.";

      final whatsappUrl = Uri.parse(
        "https://wa.me/57$adminPhone?text=${Uri.encodeComponent(message)}",
      );

      if (await canLaunchUrl(whatsappUrl)) {
        await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint("Error al abrir WhatsApp: $e");
    }
  }

  // 2. Lógica para descargar el QR
  Future<void> _downloadQR(String url) async {
    setState(() => _isDownloading = true);
    try {
      final tempDir = await getTemporaryDirectory();
      final path = "${tempDir.path}/qr_pago_estudio.png";
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

  // 3. Lógica para seleccionar y subir archivos
  Future<void> _handleFileUpload(bool isDocument) async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );

    if (image == null) return;

    setState(() {
      if (isDocument)
        _isUploadingDoc = true;
      else
        _isUploadingPay = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw "Usuario no autenticado";

      final folder = isDocument ? 'tenant_ids' : 'payments_study';
      final storageRef = FirebaseStorage.instance
          .ref()
          .child(folder)
          .child('${user.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg');

      await storageRef.putFile(File(image.path));
      final downloadUrl = await storageRef.getDownloadURL();

      setState(() {
        if (isDocument)
          _idDocumentUrl = downloadUrl;
        else
          _paymentReceiptUrl = downloadUrl;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("❌ Error al subir: $e")));
      }
    } finally {
      if (mounted) {
        setState(() {
          if (isDocument)
            _isUploadingDoc = false;
          else
            _isUploadingPay = false;
        });
      }
    }
  }

  // 4. Finalizar: Actualizar Firestore y abrir WhatsApp
  Future<void> _finishAndNotify() async {
    if (_contractDocId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("❌ Error: No se encontró el contrato de la propiedad."),
        ),
      );
      return;
    }

    setState(() => _isFinishing = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || _idDocumentUrl == null || _paymentReceiptUrl == null)
        return;

      // Usamos el Service consolidado
      await _contractService.finalizeContractDocuments(
        contractId: _contractDocId!,
        idDocumentUrl: _idDocumentUrl!,
        paymentReceiptUrl: _paymentReceiptUrl!,
      );

      // Notificar por WhatsApp
      await _sendWhatsAppAuto(_paymentReceiptUrl!);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("✅ Documentos enviados a revisión")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("❌ Error al finalizar: $e")));
      }
    } finally {
      if (mounted) setState(() => _isFinishing = false);
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

  // --- COMPONENTES DE UI ---

  @override
  Widget build(BuildContext context) {
    final bool canFinish = _idDocumentUrl != null && _paymentReceiptUrl != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Estudio de Seguridad"),
        centerTitle: true,
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('config')
            .doc('payment_info')
            .get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final paymentData =
              snapshot.data?.data() as Map<String, dynamic>? ?? {};
          final String nequiPhone = paymentData['nequiPhone'] ?? '3162868796';
          final String digitalKey = paymentData['digitalKey'] ?? '@EAMA7209';
          final String qrUrl = paymentData['qrImageUrl'] ?? '';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _buildValueCard(),
                const SizedBox(height: 25),

                _buildUploadTile(
                  title: "1. Documento de Identidad",
                  subtitle: "Carga tu cédula (PDF o Imagen)",
                  isDone: _idDocumentUrl != null,
                  isLoading: _isUploadingDoc,
                  onTap: () => _handleFileUpload(true),
                ),

                const SizedBox(height: 20),
                _buildModernPaymentKeys(nequiPhone, digitalKey, qrUrl),
                const SizedBox(height: 20),

                _buildUploadTile(
                  title: "2. Comprobante de Pago",
                  subtitle: "Sube la captura de los \$60.000",
                  isDone: _paymentReceiptUrl != null,
                  isLoading: _isUploadingPay,
                  onTap: () => _handleFileUpload(false),
                ),

                const SizedBox(height: 30),

                if (_isFinishing)
                  const CircularProgressIndicator()
                else
                  ElevatedButton(
                    onPressed: canFinish ? _finishAndNotify : null,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 60),
                      backgroundColor: canFinish
                          ? Colors.green[800]
                          : Colors.grey,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      canFinish ? "REVISAR Y ENVIAR" : "FALTAN DOCUMENTOS",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                const SizedBox(height: 20),
                _buildWarningNote(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildUploadTile({
    required String title,
    required String subtitle,
    required bool isDone,
    required bool isLoading,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDone ? Colors.green.withOpacity(0.05) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDone ? Colors.green : Colors.grey[300]!),
      ),
      child: ListTile(
        onTap: isLoading ? null : onTap,
        leading: isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(
                isDone ? Icons.check_circle : Icons.upload_file,
                color: isDone ? Colors.green : Colors.blue,
              ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.chevron_right, size: 20),
      ),
    );
  }

  Widget _buildValueCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.blue.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
        ],
      ),
      child: Column(
        children: [
          const Text(
            "VALOR ESTUDIO JURÍDICO",
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            FormatUtils.formatCurrency(_costoEstudio),
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.blue[900],
            ),
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
          const Text(
            "MÉTODOS DE PAGO",
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 15),
          _keyRow(Icons.phone_android, "NEQUI", phone),
          const SizedBox(height: 10),
          _keyRow(Icons.vpn_key, "LLAVE", key),
          if (qrUrl.isNotEmpty) ...[
            const SizedBox(height: 20),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(qrUrl, height: 140, width: 140),
            ),
            TextButton.icon(
              onPressed: _isDownloading ? null : () => _downloadQR(qrUrl),
              icon: Icon(Icons.download, size: 18, color: Colors.blue[300]),
              label: Text(
                "DESCARGAR QR",
                style: TextStyle(color: Colors.blue[300], fontSize: 12),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _keyRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: Colors.blue[300], size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            "$label: $value",
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.copy, color: Colors.white54, size: 16),
          onPressed: () => _copyToClipboard(value),
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
          Icon(Icons.security, color: Colors.amber, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              "El estudio jurídico inicia una vez se confirme el pago y los documentos.",
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
}
