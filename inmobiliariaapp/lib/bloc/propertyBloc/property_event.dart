import 'package:inmobiliariaapp/models/property_model.dart';

abstract class PropertyEvent {}

// Cargar datos desde el Cache al iniciar
class LoadPropertyCacheRequested extends PropertyEvent {}

// Actualizar un campo específico (ej: canon, dirección)
class UpdatePropertyData extends PropertyEvent {
  final String key;
  final dynamic value;
  UpdatePropertyData(this.key, this.value);
}

// El evento "Boss": Sube todo a Firebase
class SubmitPropertyRequested extends PropertyEvent {
  final String userId;
  SubmitPropertyRequested(this.userId);
}
class EditPropertyStarted extends PropertyEvent {
  final PropertyModel property;
  EditPropertyStarted(this.property);
}
class ClearPropertyCacheRequested extends PropertyEvent {}