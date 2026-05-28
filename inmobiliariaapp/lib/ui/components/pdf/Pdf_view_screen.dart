import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:share_plus/share_plus.dart';
import 'package:dio/dio.dart';

class PdfViewScreen extends StatefulWidget {
  final String path;
  final String title;

  const PdfViewScreen({
    super.key,
    required this.path,
    this.title = "Visualización de Contrato",
  });

  @override
  State<PdfViewScreen> createState() => _PdfViewScreenState();
}

class _PdfViewScreenState extends State<PdfViewScreen> {
  bool _isSharing = false;

  // Método helper para estandarizar el nombre del archivo tal como lo guardan tus otros botones
  String _getSanitizedFileName() {
    final cleanTitle = widget.title
        .replaceAll(RegExp(r'[^\w\s\-]'), '')
        .replaceAll(' ', '_');
    return "$cleanTitle.pdf";
  }

  Future<void> _sharePdf() async {
    setState(() => _isSharing = true);

    try {
      // 1. Si la ruta es local (un archivo ya existente en el móvil)
      if (!widget.path.startsWith('http')) {
        final file = File(widget.path);
        if (await file.exists()) {
          final params = ShareParams(
            files: [XFile(widget.path, mimeType: 'application/pdf')],
            fileNameOverrides: [_getSanitizedFileName()],
          );
          await SharePlus.instance.share(params);
        }
        return;
      }

      // 2. ESCENARIO CRÍTICO (Tu caso): El PDF viene de la URL (Firebase) y no está en el móvil
      // Descargamos los bytes directamente en la memoria RAM de forma silenciosa
      final Dio dio = Dio();
      final response = await dio.get<List<int>>(
        widget.path,
        options: Options(responseType: ResponseType.bytes),
      );

      if (response.data != null) {
        // 3. Convertimos los bytes crudos a Uint8List para XFile.fromData
        final Uint8List pdfBytes = Uint8List.fromList(response.data!);

        // 4. Armamos los parámetros tal como lo muestra tu documentación
        final params = ShareParams(
          files: [XFile.fromData(pdfBytes, mimeType: 'application/pdf')],
          // Usamos fileNameOverrides porque la docu advierte que 'name' se ignora en la mayoría de plataformas
          fileNameOverrides: [_getSanitizedFileName()],
        );

        // 5. Despachamos la hoja para compartir nativa
        await SharePlus.instance.share(params);
      } else {
        throw Exception("No se recibieron datos binarios desde el servidor.");
      }
    } catch (e) {
      debugPrint("Error compartiendo con la nueva API: $e");

      // RESPALDO (Fallback): Si todo el proceso de bytes falla, enviamos el enlace como texto plano
      try {
        final textParams = ShareParams(
          uri: Uri.parse(
            widget.path,
          ), // Usamos la propiedad de la docu para URIs
        );
        await SharePlus.instance.share(textParams);
      } catch (shareError) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                "No se pudo compartir de ninguna forma: $shareError",
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isSharing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          _isSharing
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                  ),
                )
              : IconButton(icon: const Icon(Icons.share), onPressed: _sharePdf),
        ],
      ),
      body: widget.path.startsWith('http')
          ? SfPdfViewer.network(widget.path)
          : SfPdfViewer.file(File(widget.path)),
    );
  }
}
