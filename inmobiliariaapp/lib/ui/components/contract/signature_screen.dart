import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:syncfusion_flutter_signaturepad/signaturepad.dart';
import 'dart:ui' as ui;
import 'package:inmobiliariaapp/bloc/contractBloc/contract_bloc.dart';
import 'package:inmobiliariaapp/bloc/contractBloc/contract_event.dart';

class SignatureScreen extends StatefulWidget {
  final String pdfPath; // Recibimos el path del PDF para referencia visual si fuera necesario

  const SignatureScreen({super.key, required this.pdfPath});

  @override
  State<SignatureScreen> createState() => _SignatureScreenState();
}

class _SignatureScreenState extends State<SignatureScreen> {
  final GlobalKey<SfSignaturePadState> _signaturePadKey = GlobalKey();
  bool _isProcessing = false;

  Future<void> _handleConfirmSignature() async {
    setState(() => _isProcessing = true);

    try {
      // 1. Convertir la firma a bytes (PNG)
      final image = await _signaturePadKey.currentState!.toImage(pixelRatio: 3.0);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      
      if (data != null) {
        final Uint8List bytes = data.buffer.asUint8List();

        // 2. Despachar el evento al Bloc para procesar la firma físicamente en el PDF
        if (mounted) {
          context.read<ContractBloc>().add(SignContractEvent(bytes));
          
          // 3. Volver a la Home (donde el BlocBuilder detectará el cambio de estado)
          Navigator.pop(context);
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error al procesar la firma")),
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Firma Digital")),
      body: _isProcessing 
        ? const Center(child: CircularProgressIndicator())
        : Column(
            children: [
              const Padding(
                padding: EdgeInsets.all(20.0),
                child: Text(
                  "Al firmar, usted acepta los términos del contrato cargado por el abogado.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ),
              const Spacer(),
              const Text("FIRME AQUÍ", style: TextStyle(letterSpacing: 2, fontWeight: FontWeight.bold)),
              Container(
                height: 250,
                margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  border: Border.all(color: Colors.blueAccent, width: 2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SfSignaturePad(
                  key: _signaturePadKey,
                  backgroundColor: Colors.transparent,
                  strokeColor: Colors.black,
                  minimumStrokeWidth: 3.0,
                ),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => _signaturePadKey.currentState!.clear(),
                        child: const Text("LIMPIAR"),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 15)
                        ),
                        onPressed: _handleConfirmSignature,
                        child: const Text("CONFIRMAR FIRMA"),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
    );
  }
}