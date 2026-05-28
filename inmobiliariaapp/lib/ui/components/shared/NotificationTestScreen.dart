import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:inmobiliariaapp/services/contract_service.dart';

class NotificationTestScreen extends StatelessWidget {
  const NotificationTestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? "";

    return Scaffold(
      appBar: AppBar(title: const Text("Panel de Pruebas - Notificaciones")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            "Al presionar estos botones, se actualizará Firestore y el Backend debería enviarte una notificación.",
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 20),

          // PRUEBA 1: CONTRATO FIRMADO
          _testCard(
            title: "Simular Firma de Contrato",
            subtitle: "Cambia el estado de un contrato a 'signedPendingReview'",
            icon: Icons.assignment_turned_in,
            color: Colors.blue,
            onTap: () => _simulateContractSignature(currentUserId, context),
          ),

          // PRUEBA 2: PAGO RECIBIDO
          _testCard(
            title: "Simular Pago Nuevo",
            subtitle: "Crea un registro en la colección 'payments'",
            icon: Icons.monetization_on,
            color: Colors.green,
            onTap: () => _simulateNewPayment(currentUserId, context),
          ),

          const Divider(),
          ListTile(
            title: const Text("Tu ID actual:"),
            subtitle: Text(currentUserId),
            leading: const Icon(Icons.person),
          ),
        ],
      ),
    );
  }

  // --- LÓGICA DE PRUEBAS ---

  Future<void> _simulateContractSignature(
    String userId,
    BuildContext context,
  ) async {
    try {
      // Buscamos un contrato donde tú seas el Propietario para recibir la notificación
      await ContractService().simulateSignature(userId);

      _showSuccess(context, "Firestore actualizado: Contrato firmado.");
    } catch (e) {
      _showError(context, e.toString());
    }
  }

  Future<void> _simulateNewPayment(String userId, BuildContext context) async {
    try {
      await FirebaseFirestore.instance.collection('payments').add({
        'tenantId': userId, // Te lo mandas a ti mismo
        'amount': 1500,
        'status': 'completed',
        'createdAt': FieldValue.serverTimestamp(),
      });
      _showSuccess(context, "Firestore actualizado: Pago creado.");
    } catch (e) {
      _showError(context, e.toString());
    }
  }

  // --- COMPONENTES UI ---

  Widget _testCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 16),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color,
          child: Icon(icon, color: Colors.white),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        onTap: onTap,
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      ),
    );
  }

  void _showSuccess(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }
}
