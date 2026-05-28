import 'package:equatable/equatable.dart';
import 'package:inmobiliariaapp/enum/application_status.dart';

class ContractState extends Equatable {
  final ApplicationStatus status;
  final String? pdfPath;           // PDF del Contrato (Abogado)
  final String? propertyDocsPath;   // PDF Inmueble (Propietario) - NUEVO
  final String? tenantDocsPath;     // PDF Identidad/Laboral (Inquilino) - NUEVO
  final List<int>? signatureBytes; // Firma Inquilino
  final double canonAmount;
  final bool isStudyPaid;           // ¿Pagó los $60.000? - NUEVO
  final String? rejectionReason;
  final bool isLoading;

  const ContractState({
    this.status = ApplicationStatus.paymentPending,
    this.pdfPath,
    this.propertyDocsPath,
    this.tenantDocsPath,
    this.signatureBytes,
    this.canonAmount = 0,
    this.isStudyPaid = false,
    this.rejectionReason,
    this.isLoading = false,
  });

  ContractState copyWith({
    ApplicationStatus? status,
    String? pdfPath,
    String? propertyDocsPath,
    String? tenantDocsPath,
    List<int>? signatureBytes,
    double? canonAmount,
    bool? isStudyPaid,
    String? rejectionReason,
    bool? isLoading,
  }) {
    return ContractState(
      status: status ?? this.status,
      pdfPath: pdfPath ?? this.pdfPath,
      propertyDocsPath: propertyDocsPath ?? this.propertyDocsPath,
      tenantDocsPath: tenantDocsPath ?? this.tenantDocsPath,
      signatureBytes: signatureBytes ?? this.signatureBytes,
      canonAmount: canonAmount ?? this.canonAmount,
      isStudyPaid: isStudyPaid ?? this.isStudyPaid,
      isLoading: isLoading ?? this.isLoading,
      // Mantenemos la lógica de limpieza de errores
      rejectionReason: (status != null && status != ApplicationStatus.rejected)
          ? null
          : (rejectionReason ?? this.rejectionReason),
    );
  }

  @override
  List<Object?> get props => [
        status,
        pdfPath,
        propertyDocsPath,
        tenantDocsPath,
        signatureBytes,
        canonAmount,
        isStudyPaid,
        rejectionReason,
        isLoading,
      ];
}