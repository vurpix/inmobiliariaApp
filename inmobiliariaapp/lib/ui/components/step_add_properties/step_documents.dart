// ui/components/shared/step_documents.dart
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:inmobiliariaapp/ui/components/global/custom_text.dart'; // Componente de marca unificado
import 'package:inmobiliariaapp/ui/components/pdf/Pdf_view_screen.dart';
import 'package:inmobiliariaapp/utils/themes.dart';

class StepDocuments extends StatelessWidget {
  final Map<String, dynamic> data;
  final Function(String, dynamic) onUpdate;

  const StepDocuments({super.key, required this.data, required this.onUpdate});

  // --- LÓGICA PARA SELECCIONAR PDF ---
  Future<void> _pickDocument() async {
    FilePickerResult? result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null && result.files.single.path != null) {
      List<String> currentDocs = List<String>.from(data['docs'] ?? []);
      currentDocs.add(result.files.single.path!);
      onUpdate('docs', currentDocs);
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<String> docs = List<String>.from(data['docs'] ?? []);
    final bool accepted = data['acceptTerms'] ?? false;

    // Obtener valores actuales de duración o poner por defecto
    final String selectedValue = (data['durationValue'] ?? "1").toString();
    final String selectedUnit = data['durationUnit'] ?? "Año";

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CustomText.title(
            "Configuración del Contrato",
            baseFontSize: 18,
            fontWeight: FontWeight.w900,
            color: context.primaryColor,
          ),
          const SizedBox(height: 20),

          // --- SECCIÓN: TIEMPO DE CONTRATO ---
          CustomText(
            "Vigencia del Contrato",
            baseFontSize: 13,
            fontWeight: FontWeight.w800,
            color: context.textSecondaryColor.withOpacity(0.7),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: context.surfaceColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: context.textColor.withOpacity(0.06),
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.history_toggle_off_rounded,
                  color: context.primaryColor.withOpacity(0.7),
                  size: 22,
                ),
                const SizedBox(width: 16),
                // Selector de número (1-12)
                Expanded(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedValue,
                      isExpanded: true,
                      dropdownColor: context.surfaceColor,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        color: context.textColor,
                        fontWeight: FontWeight.w600,
                      ),
                      items:
                          List.generate(12, (index) => (index + 1).toString())
                              .map(
                                (val) => DropdownMenuItem(
                                  value: val,
                                  child: Text(val),
                                ),
                              )
                              .toList(),
                      onChanged: (val) => onUpdate('durationValue', val),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Selector de Unidad (Mes/Año)
                Expanded(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedUnit,
                      isExpanded: true,
                      dropdownColor: context.surfaceColor,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        color: context.textColor,
                        fontWeight: FontWeight.w600,
                      ),
                      items: const ["Meses", "Año", "Años"]
                          .map(
                            (unit) => DropdownMenuItem(
                              value: unit,
                              child: Text(unit),
                            ),
                          )
                          .toList(),
                      onChanged: (val) => onUpdate('durationUnit', val),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          const Divider(height: 1, thickness: 0.6),
          const SizedBox(height: 20),

          CustomText(
            "Documentación Legal",
            baseFontSize: 13,
            fontWeight: FontWeight.w800,
            color: context.textSecondaryColor.withOpacity(0.7),
          ),
          const SizedBox(height: 12),

          // --- BOTÓN DE CARGA PREMIUM ---
          InkWell(
            onTap: _pickDocument,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 22),
              decoration: BoxDecoration(
                color: context.primaryColor.withOpacity(0.015),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: context.primaryColor.withOpacity(0.12),
                  width: 1.5,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.cloud_upload_outlined,
                    color: context.primaryColor,
                    size: 28,
                  ),
                  const SizedBox(height: 8),
                  CustomText(
                    "Subir nuevo soporte PDF",
                    baseFontSize: 13,
                    color: context.primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // --- LISTADO DINÁMICO DE DOCUMENTOS CON CONTROL DE DESBORDAMIENTO ---
          docs.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: _buildEmptyState(),
                )
              : ListView.builder(
                  shrinkWrap:
                      true, // Requisito para convivir dentro del flujo vertical
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final String path = docs[index];
                    final bool isNetwork = path.startsWith('http');
                    final String fileName = isNetwork
                        ? "Documento_Verificado_${index + 1}.pdf"
                        : path.split('/').last;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: context.surfaceColor,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: context.textColor.withOpacity(0.04),
                        ),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 2,
                        ),
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: (isNetwork ? Colors.green : Colors.red)
                                .withOpacity(0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.picture_as_pdf_rounded,
                            color: isNetwork
                                ? Colors.green[700]
                                : Colors.red[700],
                            size: 20,
                          ),
                        ),
                        title: CustomText(
                          fileName,
                          baseFontSize: 13,
                          fontWeight: FontWeight.bold,
                          overflow: TextOverflow.ellipsis,
                        ),
                        // --- MODIFICADO: Agrupación de acciones en fila ---
                        trailing: Row(
                          mainAxisSize: MainAxisSize
                              .min, // Evita que la fila se estire y rompa el ListTile
                          children: [
                            // BOTÓN: VISUALIZAR PDF
                            IconButton(
                              icon: Icon(
                                Icons.visibility_outlined,
                                color: context.textSecondaryColor.withOpacity(
                                  0.4,
                                ),
                                size: 20,
                              ),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => PdfViewScreen(
                                      path:
                                          path, // Pasa la ruta local o URL que se está iterando
                                      title: fileName,
                                    ),
                                  ),
                                );
                              },
                            ),
                            // BOTÓN: ELIMINAR
                            IconButton(
                              icon: Icon(
                                Icons.delete_sweep_outlined,
                                color: context.textSecondaryColor.withOpacity(
                                  0.4,
                                ),
                                size: 20,
                              ),
                              onPressed: () {
                                List<String> newList = List<String>.from(docs);
                                newList.removeAt(index);
                                onUpdate('docs', newList);
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),

          const SizedBox(height: 12),
          const Divider(height: 1, thickness: 0.6),
          const SizedBox(height: 8),

          // --- ACEPTACIÓN DE TÉRMINOS PREMIUM ---
          CheckboxListTile(
            value: accepted,
            onChanged: (val) => onUpdate('acceptTerms', val),
            title: CustomText(
              "Confirmo que la documentación cargada es verídica, vigente y autorizo explícitamente su revisión jurídica en el sistema.",
              baseFontSize: 11,
              fontWeight: FontWeight.w500,
              color: context.textColor.withOpacity(0.7),
            ),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            activeColor: context.primaryColor,
            checkColor: Colors.white,
            side: BorderSide(
              color: context.textColor.withOpacity(0.15),
              width: 1.5,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.article_outlined,
            size: 40,
            color: Colors.grey.withOpacity(0.4),
          ),
          const SizedBox(height: 8),
          const CustomText(
            "Sin documentos adjuntos en este registro",
            baseFontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ],
      ),
    );
  }
}
