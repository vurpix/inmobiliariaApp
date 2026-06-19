import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class ViafirmaTestScreen extends StatefulWidget {
  const ViafirmaTestScreen({super.key});

  @override
  State<ViafirmaTestScreen> createState() => _ViafirmaTestScreenState();
}

class _ViafirmaTestScreenState extends State<ViafirmaTestScreen> {
  final _formKey = GlobalKey<FormState>();

  final contractIdController = TextEditingController();
  final propertyIdController = TextEditingController();
  final propertyAddressController = TextEditingController();

  final tenantIdController = TextEditingController();
  final tenantNameController = TextEditingController();
  final tenantEmailController = TextEditingController();

  final ownerIdController = TextEditingController();
  final ownerNameController = TextEditingController();
  final ownerEmailController = TextEditingController();

  final pdfUrlController = TextEditingController();

  final signatureIdController = TextEditingController();

  bool isLoading = false;
  String resultText = '';

  /// Cambia esta URL por la URL real de tu Firebase Function.
  ///
  /// Ejemplo:
  /// https://us-central1-TU-PROYECTO.cloudfunctions.net/createViafirmaSignature
  final String createSignatureUrl =
      'https://us-central1-TU-PROYECTO.cloudfunctions.net/createViafirmaSignature';

  /// Ejemplo:
  /// https://us-central1-TU-PROYECTO.cloudfunctions.net/refreshViafirmaStatus
  final String refreshStatusUrl =
      'https://us-central1-TU-PROYECTO.cloudfunctions.net/refreshViafirmaStatus';

  @override
  void initState() {
    super.initState();

    contractIdController.text = 'contract_test_001';
    propertyIdController.text = 'property_test_001';
    propertyAddressController.text = 'Apartamento prueba';

    tenantIdController.text = 'uid_inquilino_test';
    tenantNameController.text = 'Inquilino Prueba';
    tenantEmailController.text = 'davidbarrera@humanbionics.com.co';

    ownerIdController.text = 'uid_propietario_test';
    ownerNameController.text = 'Propietario Prueba';
    ownerEmailController.text = 'sistemas@humanbionics.com.co';

    pdfUrlController.text =
        'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf';
  }

  @override
  void dispose() {
    contractIdController.dispose();
    propertyIdController.dispose();
    propertyAddressController.dispose();

    tenantIdController.dispose();
    tenantNameController.dispose();
    tenantEmailController.dispose();

    ownerIdController.dispose();
    ownerNameController.dispose();
    ownerEmailController.dispose();

    pdfUrlController.dispose();
    signatureIdController.dispose();

    super.dispose();
  }

  Future<void> createSignatureRequest() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      isLoading = true;
      resultText = 'Creando solicitud en Viafirma...';
    });

    try {
      final body = {
        'contractId': contractIdController.text.trim(),
        'propertyId': propertyIdController.text.trim(),
        'propertyAddress': propertyAddressController.text.trim(),
        'pdfUrl': pdfUrlController.text.trim(),
        'tenant': {
          'uid': tenantIdController.text.trim(),
          'name': tenantNameController.text.trim(),
          'email': tenantEmailController.text.trim(),
        },
        'owner': {
          'uid': ownerIdController.text.trim(),
          'name': ownerNameController.text.trim(),
          'email': ownerEmailController.text.trim(),
        },
      };

      final response = await http.post(
        Uri.parse(createSignatureUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(body),
      );

      final decoded = _tryDecode(response.body);

      setState(() {
        resultText = const JsonEncoder.withIndent('  ').convert({
          'statusCode': response.statusCode,
          'response': decoded,
        });

        final signatureId = decoded['signatureId'];
        if (signatureId != null) {
          signatureIdController.text = signatureId.toString();
        }
      });
    } catch (e) {
      setState(() {
        resultText = 'Error creando firma:\n$e';
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> refreshSignatureStatus() async {
    final signatureId = signatureIdController.text.trim();

    if (signatureId.isEmpty) {
      setState(() {
        resultText = 'Debes ingresar un signatureId para consultar estado.';
      });
      return;
    }

    setState(() {
      isLoading = true;
      resultText = 'Consultando estado...';
    });

    try {
      final uri = Uri.parse(refreshStatusUrl).replace(
        queryParameters: {
          'signatureId': signatureId,
        },
      );

      final response = await http.get(
        uri,
        headers: {
          'Accept': 'application/json',
        },
      );

      final decoded = _tryDecode(response.body);

      setState(() {
        resultText = const JsonEncoder.withIndent('  ').convert({
          'statusCode': response.statusCode,
          'response': decoded,
        });
      });
    } catch (e) {
      setState(() {
        resultText = 'Error consultando estado:\n$e';
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  dynamic _tryDecode(String body) {
    try {
      return jsonDecode(body);
    } catch (_) {
      return {
        'raw': body,
      };
    }
  }

  Widget _input({
    required String label,
    required TextEditingController controller,
    String? hint,
    TextInputType keyboardType = TextInputType.text,
    bool requiredField = true,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: const OutlineInputBorder(),
        ),
        validator: requiredField
            ? (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Campo obligatorio';
                }
                return null;
              }
            : null,
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 10),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _button({
    required String text,
    required VoidCallback? onPressed,
    Color? color,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
        ),
        onPressed: isLoading ? null : onPressed,
        child: Text(text),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Prueba Viafirma'),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionTitle('Datos del contrato'),
                    _input(
                      label: 'Contract ID',
                      controller: contractIdController,
                    ),
                    _input(
                      label: 'Property ID',
                      controller: propertyIdController,
                    ),
                    _input(
                      label: 'Dirección / inmueble',
                      controller: propertyAddressController,
                    ),
                    _input(
                      label: 'URL del PDF a firmar',
                      controller: pdfUrlController,
                      keyboardType: TextInputType.url,
                    ),

                    _sectionTitle('Datos del inquilino'),
                    _input(
                      label: 'UID inquilino',
                      controller: tenantIdController,
                    ),
                    _input(
                      label: 'Nombre inquilino',
                      controller: tenantNameController,
                    ),
                    _input(
                      label: 'Email inquilino',
                      controller: tenantEmailController,
                      keyboardType: TextInputType.emailAddress,
                    ),

                    _sectionTitle('Datos del propietario'),
                    _input(
                      label: 'UID propietario',
                      controller: ownerIdController,
                    ),
                    _input(
                      label: 'Nombre propietario',
                      controller: ownerNameController,
                    ),
                    _input(
                      label: 'Email propietario',
                      controller: ownerEmailController,
                      keyboardType: TextInputType.emailAddress,
                    ),

                    const SizedBox(height: 12),

                    _button(
                      text: 'Crear solicitud de firma',
                      color: Colors.blue,
                      onPressed: createSignatureRequest,
                    ),

                    const SizedBox(height: 24),

                    _sectionTitle('Consultar estado'),
                    _input(
                      label: 'Signature ID',
                      controller: signatureIdController,
                      requiredField: false,
                    ),

                    _button(
                      text: 'Consultar estado de firma',
                      color: Colors.green,
                      onPressed: refreshSignatureStatus,
                    ),

                    const SizedBox(height: 24),

                    _sectionTitle('Resultado'),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: SelectableText(
                        resultText.isEmpty
                            ? 'Aquí aparecerá la respuesta del backend.'
                            : resultText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontFamily: 'monospace',
                          fontSize: 13,
                        ),
                      ),
                    ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),

            if (isLoading)
              Container(
                color: Colors.black.withOpacity(0.2),
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}