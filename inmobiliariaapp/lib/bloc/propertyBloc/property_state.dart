enum PropertyStatus { initial, loading, success, failure }

class PropertyState {
  final Map<String, dynamic> formData;
  final PropertyStatus status;
  final String? errorMessage;
  // --- NUEVA PROPIEDAD ---
  final bool isEditing; 

  PropertyState({
    required this.formData,
    this.status = PropertyStatus.initial,
    this.errorMessage,
    this.isEditing = false, // Por defecto es falso (creación)
  });

  PropertyState copyWith({
    Map<String, dynamic>? formData,
    PropertyStatus? status,
    String? errorMessage,
    bool? isEditing,
  }) {
    return PropertyState(
      formData: formData ?? this.formData,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      isEditing: isEditing ?? this.isEditing,
    );
  }
}