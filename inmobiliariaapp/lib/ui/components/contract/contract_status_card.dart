import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inmobiliariaapp/bloc/contractBloc/contract_bloc.dart';
import 'package:inmobiliariaapp/bloc/contractBloc/contract_event.dart';
import 'package:inmobiliariaapp/bloc/contractBloc/contract_state.dart';
import 'package:inmobiliariaapp/enum/application_status.dart';
import 'package:inmobiliariaapp/ui/components/pdf/Pdf_view_screen.dart';

class ContractStatusCard extends StatelessWidget {
  final ContractState state;

  const ContractStatusCard({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Card(
            elevation: 4,
            child: ListTile(
              leading: const Icon(
                Icons.picture_as_pdf,
                color: Colors.red,
                size: 40,
              ),
              title: Text(state.pdfPath?.split('/').last ?? "Contrato.pdf"),
              subtitle: Text("Estado: ${state.status.name}"),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Ver PDF
                  IconButton(
                    icon: const Icon(Icons.remove_red_eye, color: Colors.blue),
                    onPressed: () => _viewPdf(context, state.pdfPath),
                  ),
                  // Reemplazar/Editar PDF
                  IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () => _reUpload(context),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Si el inquilino ya firmó, aparece el botón para finalizar
          if (state.status == ApplicationStatus.finalReview)
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(50),
              ),
              icon: const Icon(Icons.check_circle),
              onPressed: () =>
                  context.read<ContractBloc>().add(FinalizeContractEvent()),
              label: const Text("FINALIZAR Y CERRAR CONTRATO"),
            ),
        ],
      ),
    );
  }

  void _viewPdf(BuildContext context, String? path) {
    if (path == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => PdfViewScreen(path: path)),
    );
  }

  Future<void> _reUpload(BuildContext context) async {
    // Reutilizamos la lógica de picking
    FilePickerResult? result = await FilePicker.pickFiles(
      allowMultiple: false,
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null && context.mounted) {
      context.read<ContractBloc>().add(
        UploadDraftEvent(result.files.single.path!),
      );
    }
  }
}
