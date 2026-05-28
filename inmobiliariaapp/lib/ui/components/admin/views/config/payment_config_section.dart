// ui/pages/admin/sections/payment_config_section.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:inmobiliariaapp/models/config/payment_Info.dart';
import 'package:inmobiliariaapp/services/config_service.dart';
import 'package:inmobiliariaapp/ui/components/admin/views/config/config_shared_widgets.dart';
import 'package:inmobiliariaapp/utils/themes.dart';
import 'package:inmobiliariaapp/ui/components/global/custom_text.dart';
import 'package:inmobiliariaapp/ui/components/global/custom_text_button.dart';

class PaymentConfigSection extends StatefulWidget {
  final Function(bool) onLoadingChanged;
  const PaymentConfigSection({super.key, required this.onLoadingChanged});

  @override
  State<PaymentConfigSection> createState() => _PaymentConfigSectionState();
}

class _PaymentConfigSectionState extends State<PaymentConfigSection> {
  final ConfigService _configService = ConfigService();

  Future<void> _uploadQRFile() async {
    FilePickerResult? result = await FilePicker.pickFiles(type: FileType.image);
    if (result == null) return;

    widget.onLoadingChanged(true);
    try {
      File file = File(result.files.single.path!);
      Reference ref = FirebaseStorage.instance.ref().child(
        "config/qr_pago.png",
      );
      UploadTask uploadTask = ref.putFile(file);
      TaskSnapshot snapshot = await uploadTask;
      String downloadUrl = await snapshot.ref.getDownloadURL();

      await _configService.updatePaymentInfo({"qrImageUrl": downloadUrl});
      if (mounted)
        ConfigSharedWidgets.showSuccessSnack(context, "Código QR actualizado");
    } catch (e) {
      if (mounted) ConfigSharedWidgets.showErrorSnack(context, e.toString());
    } finally {
      widget.onLoadingChanged(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PaymentInfo>(
      stream: _configService.watchPaymentInfo(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const LinearProgressIndicator();
        final payment = snapshot.data!;

        return ConfigSharedWidgets.cardWrapper(
          context: context,
          child: Column(
            children: [
              ConfigSharedWidgets.buildListTile(
                context: context,
                icon: Icons.phone_android_rounded,
                title: "Número Nequi Autorizado",
                subtitle: payment.nequiPhone,
                onTap: () => _showEditDialog("nequiPhone", payment.nequiPhone),
              ),
              const Divider(height: 1),
              ConfigSharedWidgets.buildListTile(
                context: context,
                icon: Icons.vpn_key_outlined,
                title: "Llave Digital Pública",
                subtitle: payment.digitalKey,
                onTap: () => _showEditDialog("digitalKey", payment.digitalKey),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const CustomText(
                      "Código QR de Transferencia",
                      fontWeight: FontWeight.bold,
                      baseFontSize: 14,
                    ),
                    const SizedBox(height: 2),
                    CustomText(
                      "Soporte visual escaneable",
                      baseFontSize: 12,
                      color: context.textSecondaryColor.withOpacity(0.5),
                    ),
                    CustomTextButton.primary(
                      "SUBIR NUEVO",
                      onPressed: _uploadQRFile,
                    ),
                  ],
                ),
              ),
              if (payment.qrImageUrl.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: GestureDetector(
                    onTap: () => ConfigSharedWidgets.showImageDialog(
                      context,
                      payment.qrImageUrl,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        payment.qrImageUrl,
                        height: 130,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _showEditDialog(String field, String current) {
    final controller = TextEditingController(text: current);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: CustomText.title(
          "Editar Pasarela",
          baseFontSize: 16,
          fontWeight: FontWeight.bold,
        ),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: field,
            contentPadding: const EdgeInsets.all(14),
          ),
        ),
        actions: [
          CustomTextButton.muted(
            "CANCELAR",
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            onPressed: () async {
              await _configService.updatePaymentInfo({field: controller.text});
              if (context.mounted) Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: context.primaryColor,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            child: const Text("GUARDAR"),
          ),
        ],
      ),
    );
  }
}
