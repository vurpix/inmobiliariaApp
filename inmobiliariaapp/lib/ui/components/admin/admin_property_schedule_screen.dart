import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inmobiliariaapp/bloc/scheduleBloc/schedule_bloc.dart';
import 'package:inmobiliariaapp/bloc/scheduleBloc/schedule_state.dart';
import 'package:inmobiliariaapp/ui/pages/calendar/admin_createSlot_screen.dart';
import 'package:inmobiliariaapp/utils/format_extensions.dart';

class AdminPropertyScheduleScreen extends StatelessWidget {
  final String propertyId;
  final String address;

  const AdminPropertyScheduleScreen({
    super.key,
    required this.propertyId,
    required this.address,
  });

  @override
  Widget build(BuildContext context) {
    return BlocListener<ScheduleBloc, ScheduleState>(
      listener: (context, state) {
        if (state is ScheduleSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message), backgroundColor: Colors.green),
          );
        }
      },
      child: DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            title: const Text("Gestión de Agenda"),
            backgroundColor: Colors.blue[900],
            foregroundColor: Colors.white,
            bottom: const TabBar(
              indicatorColor: Colors.white,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              tabs: [
                Tab(icon: Icon(Icons.calendar_month), text: "Cupos Abiertos"),
                Tab(icon: Icon(Icons.people), text: "Citas Confirmadas"),
              ],
            ),
          ),
          body: TabBarView(
            children: [
              _buildAvailableSlotsList(), 
              _buildConfirmedAppointmentsList(),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _showAddTimeSlotDialog(context),
            label: const Text("Nuevo Horario"),
            icon: const Icon(Icons.add_task),
            backgroundColor: Colors.blue[900],
          ),
        ),
      ),
    );
  }

  // --- LISTA DE CUPOS ABIERTOS (Basado en tu captura 'available_slots') ---
  Widget _buildAvailableSlotsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('available_slots')
          .where('propertyId', isEqualTo: propertyId)
          // Quitamos el orderBy temporalmente para evitar errores de índice si no existen
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        
        final slots = snapshot.data!.docs;

        if (slots.isEmpty) return const Center(child: Text("No has creado horarios para esta casa."));

        return ListView.builder(
          itemCount: slots.length,
          padding: const EdgeInsets.all(16),
          itemBuilder: (context, index) {
            final doc = slots[index];
            final data = doc.data() as Map<String, dynamic>;
            
            // Conversión segura de Timestamp
            final DateTime date = (data['dateTime'] as Timestamp).toDate();
            final int max = data['maxCapacity'] ?? 0;
            final int current = data['currentAttendees'] ?? 0;

            return Card(
              child: ListTile(
                leading: const Icon(Icons.event_available, color: Colors.green),
                title: Text(date.toDayAndShortDate()),
                subtitle: Text(
                  "Hora: ${date.toTime()}\nCupos: $current / $max",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_sweep, color: Colors.red),
                  onPressed: () => _confirmDelete(context, doc.reference, "este cupo"),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // --- LISTA DE CITAS (Cruce con 'appointments' o 'applications') ---
  Widget _buildConfirmedAppointmentsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('appointments')
          .where('propertyId', isEqualTo: propertyId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final appointments = snapshot.data!.docs;

        if (appointments.isEmpty) return const Center(child: Text("Nadie ha reservado aún."));

        return ListView.builder(
          itemCount: appointments.length,
          padding: const EdgeInsets.all(16),
          itemBuilder: (context, index) {
            final appo = appointments[index].data() as Map<String, dynamic>;
            final DateTime date = (appo['appointmentDate'] as Timestamp).toDate();

            return Card(
              color: Colors.blue[50],
              child: ListTile(
                leading: const Icon(Icons.person, color: Colors.blue),
                title: Text(appo['tenantName'] ?? 'Candidato'),
                subtitle: Text(date.toCompactDateTime()),
                trailing: IconButton(
                  icon: const Icon(Icons.cancel, color: Colors.red),
                  onPressed: () => _confirmDelete(context, appointments[index].reference, "la cita"),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _confirmDelete(BuildContext context, DocumentReference ref, String mensaje) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("¿Eliminar?"),
        content: Text("¿Deseas quitar $mensaje?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCELAR")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              ref.delete();
              Navigator.pop(context);
            },
            child: const Text("ELIMINAR", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showAddTimeSlotDialog(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AdminCreateSlotScreen(
          propertyId: propertyId,
          propertyAddress: address,
        ),
      ),
    );
  }
}