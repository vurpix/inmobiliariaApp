abstract class ScheduleEvent {}

// Cargar los bloques horarios disponibles creados por el admin
class LoadAvailableSlotsRequested extends ScheduleEvent {
  final String propertyId;
  LoadAvailableSlotsRequested(this.propertyId);
}

// Crear un nuevo bloque horario (Acción del Admin)
class CreateTimeSlotRequested extends ScheduleEvent {
  final String propertyId;
  final String address;
  final DateTime dateTime;
  final int maxCapacity;

  CreateTimeSlotRequested({
    required this.propertyId,
    required this.address,
    required this.dateTime,
    required this.maxCapacity,
  });
}

// Reservar un cupo (Acción del Inquilino)
class BookSlotRequested extends ScheduleEvent {
  final String slotId;
  final String userId;
  final String userName;
  final String propertyId;
  final String address;
  final DateTime dateTime;

  BookSlotRequested({
    required this.slotId,
    required this.userId,
    required this.userName,
    required this.propertyId,
    required this.address,
    required this.dateTime,
  });
}

// Eliminar un slot o cita
class DeleteSlotRequested extends ScheduleEvent {
  final String slotId;
  DeleteSlotRequested(this.slotId);
}

class CancelBookingRequested extends ScheduleEvent {
  final String slotId;
  final String userId;

  CancelBookingRequested({
    required this.slotId,
    required this.userId,
  });
}