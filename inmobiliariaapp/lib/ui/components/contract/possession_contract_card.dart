// components/possession_contract_card.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:inmobiliariaapp/models/contract_model.dart';
import 'package:inmobiliariaapp/ui/components/auth_ux/user_review_dialog.dart';
import 'package:inmobiliariaapp/utils/themes.dart';
import 'package:inmobiliariaapp/ui/components/global/custom_text.dart'; // Componente de texto global
import '../../../enum/user_role.dart';

class PossessionContractCard extends StatefulWidget {
  final ContractModel contract;
  final String userId;
  final String userName;

  const PossessionContractCard({
    super.key,
    required this.contract,
    required this.userId,
    required this.userName,
  });

  @override
  State<PossessionContractCard> createState() => _PossessionContractCardState();
}

class _PossessionContractCardState extends State<PossessionContractCard> {
  // --- HELPER: CONSULTA SI EL INQUILINO YA CALIFICÓ AL PROPIETARIO EN ESTE CONTRATO ---
  Future<bool> _checkIfAlreadyReviewedOwner() async {
    try {
      final query = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.contract.ownerId)
          .collection('reviews')
          .where('contractId', isEqualTo: widget.contract.id)
          .where('fromUserId', isEqualTo: widget.userId)
          .limit(1)
          .get();

      return query.docs.isNotEmpty;
    } catch (e) {
      debugPrint("Error verificando reseña previa al propietario: $e");
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final DateTime startDate =
        widget.contract.updatedAt ?? widget.contract.createdAt;
    DateTime endDate = startDate;

    if (widget.contract.duration != null &&
        widget.contract.duration!.isNotEmpty) {
      try {
        final parts = widget.contract.duration!.split(' ');
        final int value = int.parse(parts[0]);
        final String unit = parts[1].toLowerCase();

        if (unit.contains('mes')) {
          endDate = DateTime(
            startDate.year,
            startDate.month + value,
            startDate.day,
          );
        } else if (unit.contains('año') || unit.contains('años')) {
          endDate = DateTime(
            startDate.year + value,
            startDate.month,
            startDate.day,
          );
        }
      } catch (e) {
        endDate = startDate.add(const Duration(days: 365));
      }
    } else {
      endDate = startDate.add(const Duration(days: 365));
    }

    final int totalDays = endDate.difference(startDate).inDays;
    final int daysLeft = 5; // Simulación para pruebas
    final double percent = (daysLeft / totalDays).clamp(0.0, 1.0);

    final Color statusColor = daysLeft <= 15
        ? Colors.redAccent
        : (daysLeft <= 30 ? Colors.orange : Colors.green);

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.textColor.withOpacity(0.04)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1A365D).withOpacity(0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: context.primaryColor.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.holiday_village_outlined,
                    size: 26,
                    color: context.primaryColor,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CustomText.title(
                        "Tu Inmueble Asignado",
                        baseFontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                      const SizedBox(height: 2),
                      CustomText(
                        "Contrato por: ${widget.contract.duration}",
                        baseFontSize: 12,
                        color: context.textSecondaryColor.withOpacity(0.6),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1, thickness: 0.6),
            ),
            const SizedBox(height: 8),

            // --- MEDIDOR DE TIEMPO DE POSESIÓN CIRCULAR ---
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 150,
                  height: 150,
                  child: CircularProgressIndicator(
                    value: percent,
                    strokeWidth: 10,
                    backgroundColor: context.textColor.withOpacity(0.04),
                    color: statusColor,
                    strokeCap:
                        StrokeCap.round, // Curvatura en los bordes del progreso
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CustomText.title(
                      daysLeft > 0 ? "$daysLeft" : "0",
                      baseFontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: statusColor,
                    ),
                    CustomText(
                      daysLeft == 1 ? "DÍA RESTANTE" : "DÍAS RESTANTES",
                      baseFontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: context.textSecondaryColor.withOpacity(0.5),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),

            CustomText(
              daysLeft > 0 ? "Arrendada con éxito" : "Contrato finalizado",
              baseFontSize: 14,
              fontWeight: FontWeight.bold,
              color: context.textColor.withOpacity(0.8),
            ),
            if (daysLeft > 0)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: CustomText(
                  "Vence el: ${endDate.day}/${endDate.month}/${endDate.year}",
                  baseFontSize: 12,
                  color: context.textSecondaryColor.withOpacity(0.5),
                ),
              ),

            // --- SECCIÓN: REPUTACIÓN DADA POR EL PROPIETARIO ---
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Divider(height: 1, thickness: 0.6),
            ),
            _buildMyReviewSection(),

            // --- EVALUACIÓN CONDICIONAL DINÁMICA CON FUTUREBUILDER ---
            if (daysLeft <= 15) ...[
              FutureBuilder<bool>(
                future: _checkIfAlreadyReviewedOwner(),
                builder: (context, reviewSnapshot) {
                  if (reviewSnapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.only(top: 16),
                      child: Center(child: LinearProgressIndicator()),
                    );
                  }

                  final bool alreadyReviewed = reviewSnapshot.data ?? false;

                  return Column(
                    children: [
                      const SizedBox(height: 16),
                      alreadyReviewed
                          ? Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: context.textColor.withOpacity(0.02),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: context.textColor.withOpacity(0.06),
                                ),
                              ),
                              child: CustomText(
                                "🔒 Ya calificaste al propietario por este período contractual.",
                                textAlign: TextAlign.center,
                                fontWeight: FontWeight.bold,
                                baseFontSize: 12,
                                color: context.textSecondaryColor.withOpacity(
                                  0.7,
                                ),
                              ),
                            )
                          : SizedBox(
                              width: double.infinity,
                              height: 46,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: context.primaryColor,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.rate_review_rounded,
                                  size: 18,
                                ),
                                label: const Text(
                                  "CALIFICAR PROPIETARIO",
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                                onPressed: () async {
                                  await UserReviewDialog.show(
                                    context: context,
                                    targetUserId: widget.contract.ownerId,
                                    targetUserName: 'Propietario',
                                    fromUserId: widget.userId,
                                    fromName: widget.userName,
                                    fromRole: UserRole.tenant.name,
                                    contractId: widget.contract.id!,
                                    defaultTags: const [
                                      "Atento a reparaciones",
                                      "Excelente trato",
                                      "Buena comunicación",
                                      "Transparente con cuentas",
                                      "Propiedad en buen estado",
                                    ],
                                  );

                                  if (mounted) setState(() {});
                                },
                              ),
                            ),
                    ],
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMyReviewSection() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('reviews')
          .where('contractId', isEqualTo: widget.contract.id)
          .where('fromRole', isEqualTo: 'landlord')
          .limit(1)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: LinearProgressIndicator());
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.textColor.withOpacity(0.015),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.textColor.withOpacity(0.04)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Expanded(
                  flex: 1,
                  child: Icon(
                    Icons.info_outline_rounded,
                    color: context.textSecondaryColor.withOpacity(0.6),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 9,
                  child: CustomText(
                    "El propietario aún no ha enviado tu calificación",
                    baseFontSize: ResponsiveUtils.getFontSize(context, 14),
                    fontWeight: FontWeight.w600,
                    color: context.textSecondaryColor.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          );
        }

        final reviewData = docs.first.data() as Map<String, dynamic>;
        final int score = (reviewData['rating'] ?? 0).toInt();
        final String msg = reviewData['comment'] ?? '';

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.amber.withOpacity(0.04),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.amber.withOpacity(0.18)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CustomText(
                    "⭐ Tu Calificación como Inquilino",
                    fontWeight: FontWeight.bold,
                    baseFontSize: ResponsiveUtils.getFontSize(context, 10),
                    color: context.primaryColor,
                  ),
                  Row(
                    children: [
                      const Icon(
                        Icons.star_rounded,
                        color: Colors.amber,
                        size: 18,
                      ),
                      const SizedBox(width: 4),
                      CustomText(
                        "$score.0",
                        fontWeight: FontWeight.w900,
                        baseFontSize: ResponsiveUtils.getFontSize(context, 10),
                      ),
                    ],
                  ),
                ],
              ),
              if (msg.isNotEmpty) ...[
                const SizedBox(height: 8),
                CustomText(
                  '"$msg"',
                  baseFontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: context.textColor.withOpacity(0.8),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
