class CandidateModel {
  final String uid;
  final String nombre;
  final String email;
  final String? extractPdfUrl;
  final String? paymentImgUrl;
  final String? note;
  final String status;
  final DateTime uploadedAt;
  final bool isFreePromotion;

  CandidateModel({
    required this.uid,
    required this.nombre,
    required this.email,
    this.extractPdfUrl,
    this.paymentImgUrl,
    this.note,
    required this.status,
    required this.uploadedAt,
    required this.isFreePromotion,
  });

  // Convertir de Objeto a Map (para guardar en Firestore)
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'nombre': nombre,
      'email': email,
      'extractPdfUrl': extractPdfUrl,
      'paymentImgUrl': paymentImgUrl,
      'status': status,
      'note': note,
      'uploadedAt': uploadedAt.toIso8601String(),
      'isFreePromotion': isFreePromotion,
    };
  }

  // Crear objeto desde un Map (para leer de Firestore)
  factory CandidateModel.fromMap(Map<String, dynamic> map) {
    return CandidateModel(
      uid: map['uid'] ?? '',
      nombre: map['nombre'] ?? 'Usuario',
      email: map['email'] ?? '',
      extractPdfUrl: map['extractPdfUrl'],
      paymentImgUrl: map['paymentImgUrl'],
      note: map['note'],
      status: map['status'] ?? 'pending_review',
      uploadedAt: map['uploadedAt'] != null
          ? DateTime.parse(map['uploadedAt'])
          : DateTime.now(),
      isFreePromotion: map['isFreePromotion'] ?? false,
    );
  }

  // Método opcional para copiar el objeto con modificaciones
  CandidateModel copyWith({
    String? status,
    String? extractPdfUrl,
    String? paymentImgUrl,
    String? note,
  }) {
    return CandidateModel(
      uid: uid,
      nombre: nombre,
      email: email,
      extractPdfUrl: extractPdfUrl ?? this.extractPdfUrl,
      paymentImgUrl: paymentImgUrl ?? this.paymentImgUrl,
      note: note ?? this.note,
      status: status ?? this.status,
      uploadedAt: uploadedAt,
      isFreePromotion: isFreePromotion,
    );
  }
}
