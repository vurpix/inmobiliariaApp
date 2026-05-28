// ui/pages/admin/sections/legal_config_section.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:inmobiliariaapp/models/config/legal_info_model.dart';
import 'package:inmobiliariaapp/services/config_service.dart';
import 'package:inmobiliariaapp/ui/components/admin/views/config/config_shared_widgets.dart';
import 'package:inmobiliariaapp/ui/components/pdf/Pdf_view_screen.dart';
import 'package:inmobiliariaapp/utils/themes.dart';
import 'package:inmobiliariaapp/ui/components/global/custom_text.dart';

class LegalConfigSection extends StatefulWidget {
  final Function(bool) onLoadingChanged;
  const LegalConfigSection({super.key, required this.onLoadingChanged});

  @override
  State<LegalConfigSection> createState() => _LegalConfigSectionState();
}

class _LegalConfigSectionState extends State<LegalConfigSection> {
  final ConfigService _configService = ConfigService();

  Future<void> _uploadPdfFile(String field) async {
    FilePickerResult? result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result == null) return;

    widget.onLoadingChanged(true);
    try {
      File file = File(result.files.single.path!);
      Reference ref = FirebaseStorage.instance.ref().child("legal/$field.pdf");
      UploadTask uploadTask = ref.putFile(file);
      TaskSnapshot snapshot = await uploadTask;
      String downloadUrl = await snapshot.ref.getDownloadURL();

      await FirebaseFirestore.instance
          .collection('config')
          .doc('legal_info')
          .update({field: downloadUrl});
      if (mounted)
        ConfigSharedWidgets.showSuccessSnack(
          context,
          "Documento legal actualizado",
        );
    } catch (e) {
      if (mounted) ConfigSharedWidgets.showErrorSnack(context, e.toString());
    } finally {
      widget.onLoadingChanged(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<LegalInfoModel>(
      stream: _configService.watchLegalInfo(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const LinearProgressIndicator();
        final legal = snapshot.data!;

        return ConfigSharedWidgets.cardWrapper(
          context: context,
          child: Column(
            children: [
              _legalItem(
                "Política de Privacidad",
                "privacyPolicyUrl",
                legal.privacyPolicyUrl,
              ),
              const Divider(height: 1),
              _legalItem(
                "Términos y Condiciones",
                "termsConditionsUrl",
                legal.termsConditionsUrl,
              ),
              const Divider(height: 1),
              _legalItem(
                "Modelo de Contrato Base",
                "contractModelUrl",
                legal.contractModelUrl,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _legalItem(String title, String field, String url) {
    final bool hasUrl = url.isNotEmpty;

    return ListTile(
      title: CustomText(title, fontWeight: FontWeight.bold),
      subtitle: CustomText(
        hasUrl ? "Documento PDF cargado" : "Falta documento",
        baseFontSize: 12,
        color: hasUrl ? Colors.green[700]! : context.errorColor,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasUrl)
            IconButton(
              icon: Icon(
                Icons.visibility_outlined,
                color: context.primaryColor,
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PdfViewScreen(path: url, title: title),
                  ),
                );
              },
            ),
          IconButton(
            icon: Icon(
              Icons.upload_file_rounded,
              color: context.textSecondaryColor.withOpacity(0.6),
            ),
            onPressed: () => _uploadPdfFile(field),
          ),
        ],
      ),
    );
  }
}
