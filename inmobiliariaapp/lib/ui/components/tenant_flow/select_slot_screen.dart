import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inmobiliariaapp/bloc/scheduleBloc/schedule_bloc.dart';
import 'package:inmobiliariaapp/bloc/scheduleBloc/schedule_event.dart';
import 'package:inmobiliariaapp/bloc/scheduleBloc/schedule_state.dart';
import 'package:inmobiliariaapp/utils/format_extensions.dart';
import 'package:add_2_calendar/add_2_calendar.dart';
import 'package:inmobiliariaapp/utils/themes.dart';

class SelectSlotScreen extends StatelessWidget {
  final String propertyId;
  final String propertyAddress;
  final String userId;
  final String userName;

  const SelectSlotScreen({
    super.key,
    required this.propertyId,
    required this.propertyAddress,
    required this.userId,
    required this.userName,
  });

  // --- LÓGICA: ¿EL HORARIO YA PASÓ? ---
  bool _isExpired(DateTime appointmentDate) {
    return appointmentDate.isBefore(DateTime.now());
  }

  // --- LÓGICA: CANCELACIÓN CON 24 HORAS DE ANTICIPACIÓN ---
  bool _canCancel(DateTime appointmentDate) {
    if (_isExpired(appointmentDate))
      return false; // Si ya pasó, no se puede cancelar
    final now = DateTime.now();
    final difference = appointmentDate.difference(now);
    return difference.inHours >= 24;
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ScheduleBloc, ScheduleState>(
      listener: (context, state) {
        if (state is ScheduleSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        }
        if (state is ScheduleFailure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.error), backgroundColor: Colors.red),
          );
        }
      },
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          title: const Text(
            "Seleccionar Horario",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          backgroundColor: context.primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('available_slots')
                    .where('propertyId', isEqualTo: propertyId)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError)
                    return const Center(
                      child: Text("Error al cargar horarios"),
                    );
                  if (!snapshot.hasData)
                    return const Center(child: CircularProgressIndicator());

                  final slots = snapshot.data!.docs;
                  if (slots.isEmpty) return _buildEmptyState();

                  // Opcional: Ordenar por fecha para que los vencidos queden abajo o arriba
                  final sortedDocs = slots.toList()
                    ..sort(
                      (a, b) => (a['dateTime'] as Timestamp).compareTo(
                        b['dateTime'] as Timestamp,
                      ),
                    );

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: sortedDocs.length,
                    itemBuilder: (context, index) {
                      final doc = sortedDocs[index];
                      final data = doc.data() as Map<String, dynamic>;
                      final DateTime date = (data['dateTime'] as Timestamp)
                          .toDate();
                      final int capacity = data['maxCapacity'] ?? 0;
                      final int current = data['currentAttendees'] ?? 0;
                      final dynamic attendees = data['attendeesUids'];

                      bool iAmIn = false;
                      if (attendees is List) {
                        iAmIn = attendees.contains(userId);
                      } else if (attendees is Map) {
                        iAmIn = attendees.containsKey(userId);
                      }

                      return _buildSlotCard(
                        context,
                        doc.id,
                        data,
                        date,
                        capacity,
                        current,
                        iAmIn,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.primaryColor,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Propiedad en gestión:",
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 5),
          Text(
            propertyAddress,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            "Selecciona un horario disponible. Recuerda que no se permiten cancelaciones con menos de 24h de aviso.",
            style: TextStyle(color: Colors.white60, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildSlotCard(
    BuildContext context,
    String slotId,
    Map<String, dynamic> data,
    DateTime date,
    int capacity,
    int current,
    bool iAmIn,
  ) {
    final bool isExpired = _isExpired(date);
    final bool isFull = current >= capacity;
    final double progress = capacity > 0 ? (current / capacity) : 0;
    final bool canCancel = _canCancel(date);

    return Opacity(
      opacity: isExpired
          ? 0.6
          : 1.0, // Efecto visual de deshabilitado si ya pasó
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: isExpired ? Colors.grey[200] : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            if (!isExpired)
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
          ],
          border: Border.all(
            color: iAmIn
                ? context.successColor
                : (isExpired ? Colors.grey.shade300 : Colors.transparent),
            width: 2,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: iAmIn
                          ? context.successColor.withOpacity(0.1)
                          : (isExpired ? Colors.grey[300] : Colors.blue[50]),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isExpired ? Icons.history : Icons.calendar_month,
                      color: iAmIn
                          ? context.successColor
                          : (isExpired
                                ? Colors.grey[600]
                                : context.primaryColor),
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          date.toLongDate().toUpperCase(),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: isExpired ? Colors.grey[700] : Colors.black,
                          ),
                        ),
                        Text(
                          "Hora: ${date.toTime()}",
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (iAmIn)
                    _badge("MI CITA", context.successColor)
                  else if (isExpired)
                    _badge("EXPIRADO", Colors.grey[600]!),
                ],
              ),
              const SizedBox(height: 15),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 8,
                            backgroundColor: Colors.grey[200],
                            color: isExpired
                                ? Colors.grey
                                : (isFull
                                      ? Colors.red
                                      : (iAmIn
                                            ? Colors.green
                                            : context.primaryColor)),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          isExpired
                              ? "Este horario ya no está disponible"
                              : (iAmIn
                                    ? "Ya tienes un lugar reservado"
                                    : "Cupos: ${capacity - current} de $capacity"),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 15),
                  _buildActionButton(
                    context,
                    slotId,
                    date,
                    iAmIn,
                    isFull,
                    canCancel,
                    isExpired,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context,
    String slotId,
    DateTime date,
    bool iAmIn,
    bool isFull,
    bool canCancel,
    bool isExpired,
  ) {
    if (isExpired) {
      return ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.grey[300],
          foregroundColor: Colors.grey[600],
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: null,
        child: const Text("Cerrado"),
      );
    }

    if (iAmIn) {
      return ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: canCancel ? Colors.red[50] : Colors.grey[200],
          foregroundColor: canCancel ? Colors.red : Colors.grey[500],
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: canCancel ? () => _showCancelDialog(context, slotId) : null,
        child: Text(canCancel ? "Cancelar" : "Inamovible"),
      );
    }

    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: isFull ? Colors.grey[300] : Color(0xFF1A237E),
        foregroundColor: isFull ? Colors.grey[600] : Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: isFull ? null : () => _confirmBooking(context, slotId, date),
      child: Text(isFull ? "Lleno" : "Reservar"),
    );
  }

  void _confirmBooking(BuildContext context, String slotId, DateTime date) {
    context.read<ScheduleBloc>().add(
      BookSlotRequested(
        slotId: slotId,
        userId: userId,
        userName: userName,
        propertyId: propertyId,
        address: propertyAddress,
        dateTime: date,
      ),
    );
    _addToNativeCalendar(date);
  }

  void _showCancelDialog(BuildContext context, String slotId) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("¿Cancelar Visita?"),
        content: const Text(
          "Si cancelas, liberarás tu cupo y otro interesado podrá tomarlo.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("MANTENER CITA"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () {
              Navigator.pop(dialogContext);
              context.read<ScheduleBloc>().add(
                CancelBookingRequested(slotId: slotId, userId: userId),
              );
            },
            child: const Text("CANCELAR CITA"),
          ),
        ],
      ),
    );
  }

  void _addToNativeCalendar(DateTime date) {
    final Event event = Event(
      title: 'Visita Inmueble: $propertyAddress',
      description: 'Cita agendada desde Inmobiliaria App.',
      location: propertyAddress,
      startDate: date,
      endDate: date.add(const Duration(hours: 1)),
    );
    Add2Calendar.addEvent2Cal(event);
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
          const Text(
            "No hay horarios publicados.",
            style: TextStyle(
              color: Colors.grey,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Text(
            "Vuelve a consultar más tarde.",
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
