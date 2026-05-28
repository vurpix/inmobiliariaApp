import 'package:flutter/material.dart';
import 'package:inmobiliariaapp/ui/components/shared/direct_download_button.dart';
import 'package:inmobiliariaapp/ui/components/pdf/Pdf_view_screen.dart';

class PdfActionButtons extends StatefulWidget {
  final String url;
  final String title;
  final String propertyAddress;
  final Color color;

  // --- PROPIEDADES PARA PERSONALIZAR ICONOS Y COLORES ---
  final IconData downloadIcon;
  final IconData viewIcon;
  final Color? iconColor;

  // --- NUEVAS PROPIEDADES PARA EL TAMAÑO DE LOS ICONOS ---
  final double downloadIconSize;
  final double viewIconSize;

  const PdfActionButtons({
    super.key,
    required this.url,
    required this.title,
    required this.propertyAddress,
    this.color = Colors.blueGrey,
    this.downloadIcon = Icons.file_download_outlined,
    this.viewIcon = Icons.open_in_new,
    this.iconColor,
    this.downloadIconSize = 20.0, // Tamaño por defecto para descarga
    this.viewIconSize = 18.0, // Tamaño por defecto para visualización
  });

  @override
  State<PdfActionButtons> createState() => _PdfActionButtonsState();
}

class _PdfActionButtonsState extends State<PdfActionButtons> {
  bool _isDownloading = false;

  // Sanea el nombre eliminando caracteres extraños y reemplazando espacios
  String _sanitizeFileName(String address, String suffix) {
    final cleanAddress = address
        .replaceAll(RegExp(r'[^\w\s\-]'), '')
        .replaceAll(' ', '_');
    return "${cleanAddress}_$suffix.pdf";
  }

  @override
  Widget build(BuildContext context) {
    // Si no se define un iconColor explícito, hereda el color estructural por defecto
    final Color activeIconColor = widget.iconColor ?? widget.color;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // --- CONTENEDOR BOTÓN DE DESCARGA DIRECTA ---
        GestureDetector(
          onTap: _isDownloading
              ? null
              : () async {
                  setState(() => _isDownloading = true);

                  final generatedName = _sanitizeFileName(
                    widget.propertyAddress,
                    widget.title,
                  );

                  await DirectDownloadButton.downloadSilently(
                    context: context,
                    url: widget.url,
                    fileName: generatedName,
                  );

                  if (mounted) {
                    setState(() => _isDownloading = false);
                  }
                },
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors
                  .transparent, // Permite que todo el recuadro sea cliqueable
              borderRadius: BorderRadius.circular(8),
            ),
            child: _isDownloading
                ? SizedBox(
                    width: widget
                        .downloadIconSize, // Se adapta al tamaño del icono
                    height: widget
                        .downloadIconSize, // Se adapta al tamaño del icono
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: activeIconColor,
                    ),
                  )
                : Icon(
                    widget.downloadIcon,
                    size: widget.downloadIconSize, // Tamaño dinámico asignado
                    color: activeIconColor,
                  ),
          ),
        ),

        // --- ESPACIO CONTROLADO EXACTO ---
        const SizedBox(width: 4),

        // --- CONTENEDOR BOTÓN DE VISUALIZACIÓN ---
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PdfViewScreen(path: widget.url),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(
              6,
            ), // Mismo padding para mantener simetría
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              widget.viewIcon,
              size: widget.viewIconSize, // Tamaño dinámico asignado
              color: activeIconColor,
            ),
          ),
        ),
      ],
    );
  }
}
