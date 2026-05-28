import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:inmobiliariaapp/enum/contract_status.dart';
import 'package:inmobiliariaapp/models/contract_model.dart';
import 'package:inmobiliariaapp/services/contract_service.dart';
import 'package:inmobiliariaapp/ui/components/pdf/Pdf_view_screen.dart';
import 'package:inmobiliariaapp/ui/components/shared/direct_download_button.dart';

class TenantContractDetailsScreen extends StatefulWidget {
  final ContractModel contract;
  const TenantContractDetailsScreen({super.key, required this.contract});

  @override
  State<TenantContractDetailsScreen> createState() =>
      _TenantContractDetailsScreenState();
}

class _TenantContractDetailsScreenState
    extends State<TenantContractDetailsScreen> {
  final ContractService _contractService = ContractService();
  String? _downloadingUrl;
  bool _isUploading = false;
  File? _selectedFile; // Archivo en memoria local

  // --- 1. SELECCIONAR ARCHIVO ---
  Future<void> _pickContract() async {
    FilePickerResult? result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        _selectedFile = File(result.files.single.path!);
      });
    }
  }

  // --- 2. SUBIDA DEFINITIVA ---
  Future<void> _uploadAndFinalize() async {
    if (_selectedFile == null) return;

    setState(() => _isUploading = true);
    try {
      String fileName =
          'contracts/final/TENANT_${widget.contract.id}_${DateTime.now().millisecondsSinceEpoch}.pdf';

      TaskSnapshot uploadTask = await FirebaseStorage.instance
          .ref()
          .child(fileName)
          .putFile(_selectedFile!);

      String downloadUrl = await uploadTask.ref.getDownloadURL();

      // 1. Determinamos el nuevo estado por defecto
      String nuevoEstado = ContractStatus.waitingOwnerSignature.name;

      // 2. EVALUACIÓN DE CONTROL: Si el estado ya estaba rechazado, decidimos qué hacer
      if (widget.contract.status == ContractStatus.signatureRejected.name) {
        // Opción A: Mantenerlo como 'signatureRejected' para que el administrador sepa que re-subió el archivo
        nuevoEstado = ContractStatus.signatureRejected.name;

        // Opción B: Si prefieres que al re-subir vuelva a revisión, usa:
        // nuevoEstado = ContractStatus.signedPendingReview.name;
      }

      // 3. Ejecutamos la actualización con el estado controlado
      await _contractService.updateFields(widget.contract.id!, {
        'tenantSignedPdfUrl': downloadUrl,
        'status': nuevoEstado,
        'updatedAt': DateTime.now(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("✅ ¡Felicidades! Inmueble arrendado legalmente."),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error al legalizar: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Finalizar Contrato"),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Revisión y Firma Final",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              "Primero revisa el contrato firmado por el Propietario, luego sube tu firma y verifica que el archivo sea el correcto antes de enviar.",
              style: TextStyle(fontSize: 15, color: Colors.black54),
            ),
            const SizedBox(height: 30),

            _sectionTitle("1. Revisar documento del Propietario"),
            _buildDocTile(
              "Contrato Firmado (Propietario)",
              widget.contract.ownerSignedPdfUrl ?? '',
              Icons.assignment_turned_in,
              const Color(0xFF1A237E),
              isRemote: true,
            ),

            const SizedBox(height: 30),
            _sectionTitle("2. Tu Firma"),

            if (_selectedFile == null)
              _buildUploadPlaceholder()
            else
              _buildLocalPreviewCard(),

            const SizedBox(height: 40),

            if (_isUploading)
              const Center(child: CircularProgressIndicator())
            else if (_selectedFile != null)
              _buildSubmitButton(),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.blueGrey,
        ),
      ),
    );
  }

  // Tarjeta para cuando no hay archivo seleccionado
  Widget _buildUploadPlaceholder() {
    return InkWell(
      onTap: _pickContract,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 40),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.grey[300]!,
            style: BorderStyle.solid,
          ),
        ),
        child: const Column(
          children: [
            Icon(Icons.cloud_upload_outlined, size: 40, color: Colors.grey),
            SizedBox(height: 10),
            Text(
              "Toca para seleccionar tu PDF firmado",
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  // Tarjeta de previsualización del archivo local
  Widget _buildLocalPreviewCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green[200]!),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.picture_as_pdf, color: Colors.green),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _selectedFile!.path.split('/').last,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: () => setState(() => _selectedFile = null),
              ),
            ],
          ),
          const Divider(),
          TextButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PdfViewScreen(path: _selectedFile!.path),
              ),
            ),
            icon: const Icon(Icons.visibility),
            label: const Text("VER MI DOCUMENTO CARGADO"),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton(
        onPressed: _uploadAndFinalize,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green[700],
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: const Text(
          "CONFIRMAR Y FINALIZAR ARRENDAMIENTO",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        ),
      ),
    );
  }

  Widget _buildDocTile(
    String title,
    String url,
    IconData icon,
    Color color, {
    bool isRemote = true,
  }) {
    final bool isThisDownloading = _downloadingUrl == url;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      tileColor: color.withOpacity(0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withOpacity(0.2)),
      ),
      leading: Icon(icon, color: color),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: isThisDownloading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.blueGrey,
                    ),
                  )
                : const Icon(Icons.file_download_outlined, size: 20),
            color: color,
            onPressed: isThisDownloading
                ? null
                : () async {
                    setState(() => _downloadingUrl = url);

                    final generatedName = _sanitizeFileName(
                      widget.contract.address,
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
          Icon(Icons.open_in_new, color: color, size: 18),
        ],
      ),
    );
  }

  // --- NUEVO HELPER: COMPONE UN NOMBRE SEGURO USANDO LA DIRECCIÓN ---
  String _sanitizeFileName(String address, String suffix) {
    final cleanAddress = address
        .replaceAll(RegExp(r'[^\w\s\-]'), '')
        .replaceAll(' ', '_');
    return "${cleanAddress}_$suffix.pdf";
  }
}
