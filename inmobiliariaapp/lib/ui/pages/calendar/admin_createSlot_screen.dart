import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inmobiliariaapp/bloc/scheduleBloc/schedule_bloc.dart';
import 'package:inmobiliariaapp/bloc/scheduleBloc/schedule_event.dart';
import 'package:inmobiliariaapp/utils/format_extensions.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';

// Definimos una clase simple para manejar los bloques temporales
class TimeSlotDraft {
  final String time;
  final int capacity;
  TimeSlotDraft({required this.time, required this.capacity});
}

class AdminCreateSlotScreen extends StatefulWidget {
  final String propertyId;
  final String propertyAddress;

  const AdminCreateSlotScreen({
    super.key,
    required this.propertyId,
    required this.propertyAddress,
  });

  @override
  State<AdminCreateSlotScreen> createState() => _AdminCreateSlotScreenState();
}

class _AdminCreateSlotScreenState extends State<AdminCreateSlotScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  String? _selectedTime;
  int _maxCapacity = 5;

  // Lista para guardar los bloques antes de subirlos a Firebase
  List<TimeSlotDraft> _draftSlots = [];

  final List<String> _timeSlots = [
    "08:00 AM",
    "09:00 AM",
    "10:00 AM",
    "11:00 AM",
    "02:00 PM",
    "03:00 PM",
    "04:00 PM",
    "05:00 PM",
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Configurar Visitas"),
        backgroundColor: Colors.blue[900],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            TableCalendar(
              firstDay: DateTime.now(),
              lastDay: DateTime.now().add(const Duration(days: 60)),
              focusedDay: _focusedDay,
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                  _draftSlots
                      .clear(); // Limpiamos al cambiar de día si prefieres
                });
              },
            ),
            const Divider(),
            if (_selectedDay != null) ...[
              _buildSelectorDeBloques(),
              if (_draftSlots.isNotEmpty) _buildListaDeBorradores(),
            ],
            const SizedBox(height: 30),
            _buildBotonPublicarTodo(),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  // Widget para seleccionar hora y capacidad, y agregar a la lista
  Widget _buildSelectorDeBloques() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.grey[100],
      child: Column(
        children: [
          const Text(
            "1. Selecciona Hora y Capacidad",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          Wrap(
            spacing: 8,
            children: _timeSlots
                .map(
                  (time) => ChoiceChip(
                    label: Text(time),
                    selected: _selectedTime == time,
                    onSelected: (selected) =>
                        setState(() => _selectedTime = selected ? time : null),
                  ),
                )
                .toList(),
          ),
          Slider(
            value: _maxCapacity.toDouble(),
            min: 1,
            max: 15,
            divisions: 14,
            label: "$_maxCapacity per.",
            onChanged: (v) => setState(() => _maxCapacity = v.toInt()),
          ),
          ElevatedButton.icon(
            onPressed: _selectedTime == null ? null : _addSlotToDraft,
            icon: const Icon(Icons.add),
            label: const Text("Añadir este horario"),
          ),
        ],
      ),
    );
  }

  void _addSlotToDraft() {
    setState(() {
      _draftSlots.add(
        TimeSlotDraft(time: _selectedTime!, capacity: _maxCapacity),
      );
      _selectedTime = null; // Reset para el siguiente
    });
  }

  // Lista visual de lo que se va a publicar
  Widget _buildListaDeBorradores() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "2. Horarios a publicar para este día:",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          ..._draftSlots.map(
            (slot) => Card(
              child: ListTile(
                leading: const Icon(Icons.access_time, color: Colors.blue),
                title: Text(slot.time),
                subtitle: Text("Cupo: ${slot.capacity} personas"),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => setState(() => _draftSlots.remove(slot)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBotonPublicarTodo() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size.fromHeight(55),
          backgroundColor: Colors.blue[900],
        ),
        onPressed: _draftSlots.isEmpty ? null : _createAvailableSlots,
        child: Text(
          "PUBLICAR ${_draftSlots.length} HORARIOS",
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  void _createAvailableSlots() {
    // Por cada borrador en la lista, disparamos un evento al BLoC
    for (var draft in _draftSlots) {
      final String dateString =
          "${_selectedDay!.toTechnicalDate()} ${draft.time}";

      final DateTime finalDateTime = DateFormat(
        "yyyy-MM-dd hh:mm a",
      ).parse(dateString);
      context.read<ScheduleBloc>().add(
        CreateTimeSlotRequested(
          propertyId: widget.propertyId,
          address: widget.propertyAddress,
          dateTime: finalDateTime,
          maxCapacity: draft.capacity,
        ),
      );
    }

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Horarios publicados exitosamente")),
    );
  }
}
