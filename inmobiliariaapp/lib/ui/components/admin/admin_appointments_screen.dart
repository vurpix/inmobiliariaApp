// ui/components/admin/views/admin_appointments_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:inmobiliariaapp/utils/format_extensions.dart'; // Tus extensiones cronológicas nativas
import 'package:inmobiliariaapp/utils/themes.dart';
import 'package:inmobiliariaapp/ui/components/global/custom_text.dart';
import 'package:inmobiliariaapp/ui/components/global/custom_text_button.dart';

class AdminAppointmentsScreen extends StatelessWidget {
  const AdminAppointmentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('appointments')
          .orderBy('appointmentDate', descending: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return _buildEmptyState();
        }

        // --- 1. NUEVA AGRUPACIÓN CRONOLÓGICA PREMIUM POR MESES Y PROPIEDADES ---
        // Estructura ordenada: { "MAYO 2026": { "Dirección": { Timestamp: [Docs] } } }
        Map<String, Map<String, Map<int, List<DocumentSnapshot>>>> groupedData =
            {};

        for (var doc in docs) {
          final data = doc.data() as Map<String, dynamic>;
          final Timestamp timestamp = data['appointmentDate'] as Timestamp;
          final DateTime date = timestamp.toDate();

          // Reutilizamos tu extensión global .toMonthYear()
          final String monthKey = date.toMonthYear();
          final String address =
              data['propertyAddress'] ?? 'Propiedad Desconocida';
          final int timeKey = timestamp.millisecondsSinceEpoch;

          groupedData.putIfAbsent(monthKey, () => {});
          groupedData[monthKey]!.putIfAbsent(address, () => {});
          groupedData[monthKey]![address]!.putIfAbsent(timeKey, () => []);
          groupedData[monthKey]![address]![timeKey]!.add(doc);
        }

        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: groupedData.entries.map((monthEntry) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- CABECERA DE MES ---
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 20, 4, 12),
                  child: CustomText.title(
                    monthEntry.key,
                    baseFontSize: 18,
                    color: context.primaryColor,
                    fontWeight: FontWeight.w900,
                  ),
                ),

                // Iteración de Propiedades dentro de ese mes
                ...monthEntry.value.entries.map((propertyEntry) {
                  final String address = propertyEntry.key;
                  final Map<int, List<DocumentSnapshot>> timeSlots =
                      propertyEntry.value;
                  final List<int> sortedTimes = timeSlots.keys.toList()..sort();

                  return _buildPropertySection(
                    context,
                    address,
                    sortedTimes,
                    timeSlots,
                  );
                }).toList(),
                const Divider(height: 30, thickness: 1),
              ],
            );
          }).toList(),
        );
      },
    );
  }

  // --- SECCIÓN POR PROPIEDAD (TARJETA MODULAR ESTILO LUXE) ---
  Widget _buildPropertySection(
    BuildContext context,
    String address,
    List<int> sortedTimes,
    Map<int, List<DocumentSnapshot>> timeSlots,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.textColor.withOpacity(0.04)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1A365D).withOpacity(0.03),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Encabezado Interno Superior de la Propiedad
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: context.primaryColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(18),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.holiday_village_outlined,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    address,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    "${sortedTimes.length} Bloques",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Lista Interna de bloques de horas
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: sortedTimes.map((time) {
                final groupDocs = timeSlots[time]!;
                return _buildTimeSlotRow(context, groupDocs);
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // --- FILA DE CADA HORARIO ESPECÍFICO ESTILIZADA ---
  Widget _buildTimeSlotRow(BuildContext context, List<DocumentSnapshot> docs) {
    final data = docs.first.data() as Map<String, dynamic>;
    final DateTime date = (data['appointmentDate'] as Timestamp).toDate();
    final int maxCapacity = data['maxCapacity'] ?? 5;
    final int currentCount = docs.length;
    final bool isFull = currentCount >= maxCapacity;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.textColor.withOpacity(0.015),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.textColor.withOpacity(0.04)),
      ),
      child: Row(
        children: [
          // Bloque Cronológico (Abreviaciones globales)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CustomText(
                date.toDayMonth().toUpperCase(),
                baseFontSize: 12,
                fontWeight: FontWeight.w800,
                color: context.primaryColor,
              ),
              const SizedBox(height: 2),
              CustomText(
                date.toTime(),
                baseFontSize: 11,
                color: context.textSecondaryColor.withOpacity(0.6),
              ),
            ],
          ),
          const SizedBox(width: 16),

          // Medidor e Indicador de Capacidad de la Agenda
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildMiniBadge(context, currentCount, maxCapacity),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: (currentCount / maxCapacity),
                    backgroundColor: context.textColor.withOpacity(0.06),
                    color: isFull ? Colors.redAccent : const Color(0xFF2E7D32),
                    minHeight: 5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Panel de Control / Acciones Administrativas
          IconButton(
            icon: Icon(
              Icons.people_alt_rounded,
              color: context.primaryColor,
              size: 20,
            ),
            onPressed: () => _showAttendeesDialog(context, docs),
            tooltip: "Ver asistentes",
          ),
          IconButton(
            icon: const Icon(
              Icons.delete_outline_rounded,
              color: Colors.redAccent,
              size: 22,
            ),
            onPressed: () => _deleteAppointmentGroup(context, docs),
            tooltip: "Cancelar horario",
          ),
        ],
      ),
    );
  }

  Widget _buildMiniBadge(BuildContext context, int current, int max) {
    final bool full = current >= max;
    final Color textColor = full ? Colors.red[800]! : const Color(0xFF2E7D32);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: textColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        "$current / $max AGENDADOS",
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 9,
          fontWeight: FontWeight.w900,
          color: textColor,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  // --- DIÁLOGOS DE CONTROL REFRACTORIZADOS ---

  Future<void> _deleteAppointmentGroup(
    BuildContext context,
    List<DocumentSnapshot> docs,
  ) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: CustomText.title(
          "¿Cancelar este bloque?",
          baseFontSize: 16,
          fontWeight: FontWeight.bold,
        ),
        content: CustomText(
          "Se eliminarán de forma permanente las ${docs.length} citas agendadas y los inquilinos serán notificados en el feed.",
          baseFontSize: 13,
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        actions: [
          CustomTextButton.muted(
            "VOLVER",
            onPressed: () => Navigator.pop(context, false),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              "SÍ, ELIMINAR",
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      WriteBatch batch = FirebaseFirestore.instance.batch();
      for (var doc in docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const CustomText(
              "Bloque de horarios cancelado exitosamente",
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
            backgroundColor: context.primaryColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showAttendeesDialog(BuildContext context, List<DocumentSnapshot> docs) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: CustomText.title(
          "Asistentes Confirmados",
          baseFontSize: 16,
          fontWeight: FontWeight.w800,
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: docs.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 20, thickness: 0.6),
            itemBuilder: (context, i) {
              final d = docs[i].data() as Map<String, dynamic>;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: context.primaryColor.withOpacity(0.08),
                  child: Icon(
                    Icons.person_outline_rounded,
                    color: context.primaryColor,
                  ),
                ),
                title: CustomText(
                  d['tenantName'] ?? 'Candidato',
                  baseFontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
                subtitle: const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: CustomText(
                    "Perfil verificado para visita",
                    baseFontSize: 11,
                    color: Colors.grey,
                  ),
                ),
              );
            },
          ),
        ),
        actions: [
          CustomTextButton.muted(
            "CERRAR",
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.calendar_today_outlined,
            size: 70,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          const CustomText(
            "No hay citas agendadas por el momento",
            baseFontSize: 13,
            color: Colors.grey,
          ),
        ],
      ),
    );
  }
}
