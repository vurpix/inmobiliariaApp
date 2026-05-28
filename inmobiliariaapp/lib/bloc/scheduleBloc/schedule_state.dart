abstract class ScheduleState {}

class ScheduleInitial extends ScheduleState {}
class ScheduleLoading extends ScheduleState {}
class ScheduleSuccess extends ScheduleState {
  final String message;
  ScheduleSuccess(this.message);
}
class ScheduleFailure extends ScheduleState {
  final String error;
  ScheduleFailure(this.error);
}