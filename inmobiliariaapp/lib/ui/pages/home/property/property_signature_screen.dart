import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:inmobiliariaapp/models/property_model.dart';
import 'package:inmobiliariaapp/services/contract_service.dart';
import 'package:inmobiliariaapp/ui/components/pdf/Pdf_view_screen.dart';
import 'package:url_launcher/url_launcher.dart';

class PropertySignatureScreen extends StatefulWidget {
  final PropertyModel property;
  const PropertySignatureScreen({super.key, required this.property});

  @override
  State<PropertySignatureScreen> createState() =>
      _PropertySignatureScreenState();
}

class _PropertySignatureScreenState extends State<PropertySignatureScreen> {
  bool _isProcessing = false;
  String? _baseContractUrl;
  String? _contractDocId;
  final ContractService _contractService = ContractService();

  // Variable para guardar el archivo seleccionado localmente
  File? _selectedFile;

  @override
  void initState() {
    super.initState();
    _loadContractData();
  }

  Future<void> _loadContractData() async {
    try {
      // 2. Llamas al nuevo método del servicio
      final contract = await _contractService.getContractData(
        widget.property.id!,
      );

      if (contract != null) {
        setState(() {
          // 3. Extraes los datos directamente del objeto ContractModel
          _contractDocId = contract.id;
          _baseContractUrl = contract.baseContractPdfUrl;

          // Si necesitas cualquier dato extra dinámico, ya lo tienes aquí:
          // final meses = contract.extraData['meses_contrato'];
        });
        debugPrint("Datos del contrato cargados con éxito.");
      }
    } catch (e) {
      debugPrint("Error al cargar datos del contrato: $e");
    }
  }

  Future<void> _downloadPdf() async {
    if (_baseContractUrl == null) return;
    final uri = Uri.parse(_baseContractUrl!);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  // 1. PASO: SELECCIONAR EL ARCHIVO LOCALMENTE
  Future<void> _selectLocalFile() async {
    try {
      FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _selectedFile = File(result.files.single.path!);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error al seleccionar archivo: $e")),
      );
    }
  }

  // 2. PASO: SUBIR DEFINITIVAMENTE A FIREBASE
  Future<void> _uploadContractToFirebase() async {
    if (_contractDocId == null || _selectedFile == null) return;

    setState(() => _isProcessing = true);

    try {
      // Definimos la ruta en Storage
      String fileName =
          'contracts/signed/${widget.property.id}_signed_${DateTime.now().millisecondsSinceEpoch}.pdf';

      // 1. Subir el archivo físico a Firebase Storage
      TaskSnapshot uploadTask = await FirebaseStorage.instance
          .ref()
          .child(fileName)
          .putFile(_selectedFile!);

      String downloadUrl = await uploadTask.ref.getDownloadURL();

      // 2. Usar el Servicio para la actualización atómica de base de datos
      await _contractService.submitSignedContract(
        contractId: _contractDocId!,
        propertyId: widget.property.id!,
        downloadUrl: downloadUrl,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("✅ Contrato enviado con éxito")),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("❌ Error al subir: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Firma de Contrato")),
      body: _contractDocId == null
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Icon(
                    Icons.history_edu,
                    size: 80,
                    color: Colors.blueGrey,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "Proceso de Firma",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "Descargue el documento, fírmelo y luego súbalo para revisión.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                  const Spacer(),

                  // BOTÓN 1: DESCARGAR
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _downloadPdf,
                      icon: const Icon(Icons.download),
                      label: const Text("1. DESCARGAR CONTRATO BASE"),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 20),

                  // BOTÓN 2: SELECCIONAR ARCHIVO
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _isProcessing ? null : _selectLocalFile,
                      icon: const Icon(Icons.picture_as_pdf),
                      label: Text(
                        _selectedFile == null
                            ? "2. SELECCIONAR PDF FIRMADO"
                            : "CAMBIAR ARCHIVO SELECCIONADO",
                      ),
                    ),
                  ),

                  // VISOR DE ARCHIVO SELECCIONADO
                  if (_selectedFile != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.green.withOpacity(0.5),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle, color: Colors.green),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Archivo seleccionado listo:",
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  _selectedFile!.path.split('/').last,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          // BOTÓN PARA VER VISTA PREVIA
                          IconButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      PdfViewScreen(path: _selectedFile!.path),
                                ),
                              );
                            },
                            icon: const Icon(
                              Icons.remove_red_eye,
                              color: Colors.blue,
                            ),
                            tooltip: "Ver vista previa",
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),

                  // BOTÓN 3: SUBIR (Solo se activa si hay un archivo seleccionado)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: (_isProcessing || _selectedFile == null)
                          ? null
                          : _uploadContractToFirebase,
                      icon: _isProcessing
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.cloud_upload),
                      label: const Text("3. ENVIAR CONTRATO A REVISIÓN"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }
}
