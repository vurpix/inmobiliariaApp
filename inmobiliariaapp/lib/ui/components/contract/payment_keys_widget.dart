import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:inmobiliariaapp/models/config/payment_Info.dart';

class PaymentKeysWidget extends StatelessWidget {
  final PaymentInfo info;

  const PaymentKeysWidget({super.key, required this.info});

  void _copyToClipboard(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Copiado al portapapeles")));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F26), // Color oscuro del diseño
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          const Icon(Icons.vpn_key_outlined, color: Colors.blue, size: 40),
          const SizedBox(height: 15),
          const Text(
            "LLAVES DE PAGO",
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            "Si prefieres, usa una de las siguientes llaves en tu app Nequi:",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(height: 25),

          // LLAVE TELEFÓNICA
          _buildKeyCard(
            context,
            icon: Icons.phone_android,
            label: "LLAVE TELEFÓNICA",
            value: info.nequiPhone,
          ),

          const SizedBox(height: 15),

          // LLAVE DIGITAL
          _buildKeyCard(
            context,
            icon: Icons.alternate_email,
            label: "LLAVE DIGITAL",
            value: info.digitalKey,
          ),

          const SizedBox(height: 25),

          // QR DINÁMICO DESDE FIREBASE
          const Text(
            "O ESCANEA EL CÓDIGO QR",
            style: TextStyle(
              color: Colors.grey,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 15),
          ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: Image.network(
              info.qrImageUrl,
              height: 180,
              width: 180,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return const SizedBox(
                  height: 180,
                  child: Center(child: CircularProgressIndicator()),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKeyCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF252B33),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: const Color(0xFF1A1F26),
            child: Icon(icon, color: Colors.blue, size: 20),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy, color: Colors.grey, size: 20),
            onPressed: () => _copyToClipboard(context, value),
          ),
        ],
      ),
    );
  }
}
