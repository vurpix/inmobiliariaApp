import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:inmobiliariaapp/models/application_model.dart';
import 'package:inmobiliariaapp/services/application_service.dart';
import 'package:inmobiliariaapp/ui/components/tenant_flow/select_slot_screen.dart';
import 'package:inmobiliariaapp/utils/format_extensions.dart';

class ApplicationStatusButton extends StatefulWidget {
  final String propertyId;
  final String propertyAddress;
  final String userId;
  final VoidCallback onApply;

  const ApplicationStatusButton({
    super.key,
    required this.propertyId,
    required this.propertyAddress,
    required this.userId,
    required this.onApply,
  });

  @override
  State<ApplicationStatusButton> createState() =>
      _ApplicationStatusButtonState();
}

final ApplicationService _applicationService = ApplicationService();

class _ApplicationStatusButtonState extends State<ApplicationStatusButton> {
  @override
  Widget build(BuildContext context) {
    // 1. PRIMERO: Buscamos si el usuario ya tiene una cita (independientemente de su estatus de candidato)
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('appointments')
          .where('propertyId', isEqualTo: widget.propertyId)
          .where('tenantId', isEqualTo: widget.userId)
          .limit(1)
          .snapshots(),
      builder: (context, appointSnapshot) {
        if (appointSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        }

        // CASO A: SI YA TIENE UNA CITA AGENDADA
        if (appointSnapshot.hasData && appointSnapshot.data!.docs.isNotEmpty) {
          final appointData =
              appointSnapshot.data!.docs.first.data() as Map<String, dynamic>;
          final DateTime date = (appointData['appointmentDate'] as Timestamp)
              .toDate();
          return _buildAppointmentInfoCard(context, date, "Candidato");
        }

        // CASO B: NO TIENE CITA. Ahora verificamos su estatus de postulación
        return StreamBuilder<ApplicationModel?>(
          // Usamos el servicio para escuchar la aplicación de la propiedad
          stream: _applicationService.watchApplicationByProperty(
            widget.propertyId,
          ),
          builder: (context, snapshot) {
            // 1. Si no hay datos o la aplicación no existe (nadie se ha postulado)
            if (!snapshot.hasData) {
              return _buildNoAppointmentAction(context);
            }

            final application = snapshot.data!;

            // 2. Buscamos si el usuario actual es un candidato usando el helper del servicio
            final userCandidate = _applicationService.getUserCandidate(
              application,
              widget.userId,
            );

            // 3. Si el usuario no se ha postulado aún
            if (userCandidate == null) {
              return _buildNoAppointmentAction(context);
            }

            // 4. Lógica de estados basada en el modelo CandidateModel
            final String status = userCandidate.status;

            if (status == 'approved') {
              // Si está aprobado pero llegó aquí es porque no tiene cita aún, permitimos agendar
              return _buildNoAppointmentAction(context);
            } else {
              // Si está en 'pending_review', 'rejected' o cualquier otro, mostramos el indicador
              return _buildStatusIndicator(status);
            }
          },
        );
      },
    );
  }

  // --- MODIFICADO: EL BOTÓN DE "SIN CITA" AHORA NAVEGA AL CALENDARIO ---
  Widget _buildNoAppointmentAction(BuildContext context) {
    return InkWell(
      // Ahora al tocar "SIN CITA" o el icono, te lleva a seleccionar el horario
      onTap: () => _navigateToBooking(context, "Interesado"),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.blue.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.blue.shade300, width: 1.5),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.calendar_month, color: Colors.blue, size: 20),
            SizedBox(width: 8),
            Text(
              "AGENDAR CITA",
              style: TextStyle(
                color: Colors.blue,
                fontWeight: FontWeight.bold,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppointmentInfoCard(
    BuildContext context,
    DateTime date,
    String currentUserName,
  ) {
    final dateStr = date.toShortDayAndDate();
    final timeStr = date.toTime();

    return GestureDetector(
      onTap: () => _navigateToBooking(context, currentUserName),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.blue[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.blue[900]!, width: 1.5),
        ),
        child: Row(
          children: [
            Icon(Icons.event_available, color: Colors.blue[900], size: 18),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "CITA LISTA",
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  Text(
                    "$dateStr - $timeStr",
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[900],
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIndicator(String status) {
    Color color = status == 'rejected' ? Colors.red : Colors.orange[800]!;
    String text = status == 'rejected' ? "RECHAZADO" : "EN REVISIÓN";

    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 10,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  void _navigateToBooking(BuildContext context, String name) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SelectSlotScreen(
          propertyId: widget.propertyId,
          propertyAddress: widget.propertyAddress,
          userId: widget.userId,
          userName: name,
        ),
      ),
    );
  }
}
