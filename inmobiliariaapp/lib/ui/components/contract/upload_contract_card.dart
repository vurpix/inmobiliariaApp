import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inmobiliariaapp/bloc/contractBloc/contract_bloc.dart';
import 'package:inmobiliariaapp/bloc/contractBloc/contract_event.dart';

class UploadContractCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final ContractEvent eventToDispatch; 
  // Añadimos el callback como opcional para que no de error donde no se usa
  final Function(String path)? onFileSelected; 

  const UploadContractCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.eventToDispatch,
    this.onFileSelected, // Opcional
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.upload_file, size: 60, color: Colors.blue),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.search),
              label: const Text("Seleccionar PDF"),
              onPressed: () => _pickAndUpload(context),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndUpload(BuildContext context) async {
    try {
      FilePickerResult? result = await FilePicker.pickFiles( // Usamos platform para versiones actuales
        allowMultiple: false,
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result != null && result.files.single.path != null) {
        final String filePath = result.files.single.path!;

        if (context.mounted) {
          // 1. Ejecutamos el callback si existe (para actualizar la UI local)
          if (onFileSelected != null) {
            onFileSelected!(filePath);
          }

          // 2. Mapeamos el evento según el rol
          if (eventToDispatch is UploadDraftEvent) {
            context.read<ContractBloc>().add(UploadDraftEvent(filePath));
          } else if (eventToDispatch is UploadPropertyDocsEvent) {
            context.read<ContractBloc>().add(UploadPropertyDocsEvent(filePath));
          } else if (eventToDispatch is UploadTenantDocsEvent) {
            // NUEVO: Evento para los documentos del estudio del inquilino
            context.read<ContractBloc>().add(UploadTenantDocsEvent(filePath));
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Archivo cargado: ${result.files.single.name}")),
          );
        }
      }
    } catch (e) {
      debugPrint("Error: $e");
    }
  }
}