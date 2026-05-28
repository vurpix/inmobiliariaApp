import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:inmobiliariaapp/bloc/scheduleBloc/schedule_event.dart';
import 'package:inmobiliariaapp/bloc/scheduleBloc/schedule_state.dart';

class ScheduleBloc extends Bloc<ScheduleEvent, ScheduleState> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  ScheduleBloc() : super(ScheduleInitial()) {
    // EVENTO: CREAR SLOT (ADMIN)
    on<CreateTimeSlotRequested>((event, emit) async {
      emit(ScheduleLoading());
      try {
        await _firestore.collection('available_slots').add({
          'propertyId': event.propertyId,
          'address': event.address,
          'dateTime': Timestamp.fromDate(event.dateTime),
          'maxCapacity': event.maxCapacity,
          'currentAttendees': 0,
          'attendeesUids': [],
          'createdAt': FieldValue.serverTimestamp(),
        });
        emit(ScheduleSuccess("Horario publicado exitosamente"));
      } catch (e) {
        emit(ScheduleFailure("Error al crear el horario: $e"));
      }
    });
    on<CancelBookingRequested>((event, emit) async {
      emit(ScheduleLoading());

      final slotRef = _firestore
          .collection('available_slots')
          .doc(event.slotId);

      try {
        await _firestore.runTransaction((transaction) async {
          // 1. Obtener el slot actual
          DocumentSnapshot slotSnapshot = await transaction.get(slotRef);
          if (!slotSnapshot.exists) throw "El horario ya no existe.";

          int current = slotSnapshot.get('currentAttendees') ?? 0;
          List attendees = List.from(slotSnapshot.get('attendeesUids') ?? []);

          if (!attendees.contains(event.userId))
            throw "No estás registrado en este horario.";

          // 2. Buscar la cita en 'appointments' para eliminarla
          final appointmentQuery = await _firestore
              .collection('appointments')
              .where('tenantId', isEqualTo: event.userId)
              // Usamos el ID del slot como referencia si lo guardaste,
              // si no, por fecha y propertyId (es mejor tener el slotId en la cita)
              .where('appointmentDate', isEqualTo: slotSnapshot.get('dateTime'))
              .limit(1)
              .get();

          // 3. Actualizar el slot (quitar usuario y restar contador)
          transaction.update(slotRef, {
            'currentAttendees': current > 0 ? current - 1 : 0,
            'attendeesUids': FieldValue.arrayRemove([event.userId]),
          });

          // 4. Eliminar el documento de la cita individual
          if (appointmentQuery.docs.isNotEmpty) {
            transaction.delete(appointmentQuery.docs.first.reference);
          }
        });

        emit(
          ScheduleSuccess(
            "Cita cancelada exitosamente. El cupo ha sido liberado.",
          ),
        );
      } catch (e) {
        emit(ScheduleFailure("Error al cancelar: $e"));
      }
    });
    // EVENTO: RESERVAR CUPO (INQUILINO) - CON TRANSACCIÓN
    on<BookSlotRequested>((event, emit) async {
      emit(ScheduleLoading());
      final slotRef = _firestore
          .collection('available_slots')
          .doc(event.slotId);

      try {
        await _firestore.runTransaction((transaction) async {
          DocumentSnapshot slotSnapshot = await transaction.get(slotRef);

          if (!slotSnapshot.exists) throw "El horario ya no está disponible.";

          int current = slotSnapshot.get('currentAttendees') ?? 0;
          int max = slotSnapshot.get('maxCapacity') ?? 0;
          List attendees = List.from(slotSnapshot.get('attendeesUids') ?? []);

          if (current >= max) throw "Lo sentimos, no hay más cupos.";
          if (attendees.contains(event.userId))
            throw "Ya estás inscrito en este horario.";

          // 1. Actualizar el slot de cupos
          transaction.update(slotRef, {
            'currentAttendees': current + 1,
            'attendeesUids': FieldValue.arrayUnion([event.userId]),
          });

          // 2. Crear la cita individual
          final appointmentRef = _firestore.collection('appointments').doc();
          transaction.set(appointmentRef, {
            'propertyId': event.propertyId,
            'propertyAddress': event.address,
            'tenantId': event.userId,
            'tenantName': event.userName,
            'appointmentDate': Timestamp.fromDate(event.dateTime),
            'status': 'scheduled',
            'createdAt': FieldValue.serverTimestamp(),
          });
        });
        emit(ScheduleSuccess("¡Cita agendada con éxito!"));
      } catch (e) {
        emit(ScheduleFailure(e.toString()));
      }
    });

    on<DeleteSlotRequested>((event, emit) async {
      try {
        await _firestore
            .collection('available_slots')
            .doc(event.slotId)
            .delete();
        emit(ScheduleSuccess("Horario eliminado"));
      } catch (e) {
        emit(ScheduleFailure("Error al eliminar: $e"));
      }
    });
  }
}
