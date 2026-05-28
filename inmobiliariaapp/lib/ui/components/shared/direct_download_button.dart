// ui/components/shared/direct_download_button.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart'; // Garantiza compatibilidad sin permisos invasivos en Android 11+ e iOS
import 'package:inmobiliariaapp/ui/components/global/custom_text.dart'; // Componente de marca unificado
import 'package:inmobiliariaapp/utils/themes.dart';

class DirectDownloadButton extends StatefulWidget {
  final String pdfUrl;
  final String fileName;

  const DirectDownloadButton({
    super.key,
    required this.pdfUrl,
    required this.fileName,
  });

  // --- MÉTODO ESTÁTICO COMPARTIDO: COMPATIBLE CON FIREBASE STORAGE WEB ---
  static Future<void> downloadSilently({
    required BuildContext context,
    required String url,
    required String fileName,
  }) async {
    try {
      // 1. Obtener la ruta del directorio temporal seguro de la App
      final Directory tempDir = await getTemporaryDirectory();

      // 2. Sanitizar el nombre del archivo para asegurar que termine en .pdf
      String cleanName = fileName.replaceAll(' ', '_');
      if (!cleanName.toLowerCase().endsWith('.pdf')) {
        cleanName = "$cleanName.pdf";
      }

      // Definimos la ruta de escritura aislando el nombre limpio de los tokens de Firebase de la URL
      final String savePath = "${tempDir.path}/$cleanName";
      final Dio dio = Dio();

      // 3. Descarga de flujo binario puro compatible con redirecciones de Google APIs
      await dio.download(
        url.trim(),
        savePath,
        options: Options(
          responseType: ResponseType
              .bytes, // Evita archivos corruptos de 0 KB forzando bytes puros
          followRedirects: true,
          validateStatus: (status) =>
              status != null &&
              status < 500, // Permite códigos de redirección 3xx
          headers: {
            'Accept':
                'application/pdf', // Header explícito para el storage web de Firebase
          },
        ),
      );

      final File downloadedFile = File(savePath);

      // 4. Validar existencia y peso real del documento en el disco temporal
      if (await downloadedFile.exists() && await downloadedFile.length() > 0) {
        // 5. Delegación al gestor nativo del sistema operativo (Android / iOS)
        // Esto abre la interfaz oficial para que el usuario elija "Guardar en Descargas", "Guardar en Archivos" o compartirlo
        final XFile xFile = XFile(
          savePath,
          mimeType: 'application/pdf',
          name: cleanName,
        );

        await Share.shareXFiles([xFile], subject: 'Guardar documento PDF');

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const CustomText(
                "Proceso completado con éxito",
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
              backgroundColor: Colors.green[700],
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
      } else {
        throw Exception(
          "El archivo descargado está vacío o el enlace de Firebase expiró.",
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: CustomText(
              "Error en la descarga web: ${e.toString().replaceAll('Exception:', '')}",
              color: Colors.white,
            ),
            backgroundColor: context.errorColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  @override
  State<DirectDownloadButton> createState() => _DirectDownloadButtonState();
}

class _DirectDownloadButtonState extends State<DirectDownloadButton> {
  bool _isDownloading = false;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: context.primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        onPressed: _isDownloading
            ? null
            : () async {
                setState(() => _isDownloading = true);

                // Llamamos al método estático interno compartiendo el contexto de este botón
                await DirectDownloadButton.downloadSilently(
                  context: context,
                  url: widget.pdfUrl,
                  fileName: widget.fileName,
                );

                if (mounted) setState(() => _isDownloading = false);
              },
        icon: _isDownloading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              )
            : const Icon(Icons.cloud_download_outlined, size: 20),
        label: Text(
          _isDownloading ? "PROCESANDO DESCARGA..." : "DESCARGAR DOCUMENTO PDF",
          style: const TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.bold,
            fontSize: 13,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }
}
