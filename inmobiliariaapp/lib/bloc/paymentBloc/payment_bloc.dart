import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inmobiliariaapp/bloc/paymentBloc/payment_event.dart';
import 'package:inmobiliariaapp/bloc/paymentBloc/payment_state.dart';
import 'package:inmobiliariaapp/models/property_model.dart';
import 'package:inmobiliariaapp/services/property_repository.dart';
import '../../enum/payment_status.dart';
import '../../enum/property_status.dart';

class PaymentBloc extends Bloc<PaymentEvent, PaymentState> {
  final PropertyRepository _propertyRepo;

  PaymentBloc(this._propertyRepo) : super(PaymentInitial()) {
    on<ProcessRegistrationPayment>((event, emit) async {
      try {
        // 1. INICIO DEL PROCESO
        emit(const PaymentProcessing("Iniciando registro seguro..."));

        // 2. SUBIDA DE ARCHIVOS (Simultánea para ahorrar tiempo)
        emit(
          const PaymentProcessing(
            "Subiendo fotos, documentos y comprobante...",
          ),
        );

        final results = await Future.wait([
          _propertyRepo.uploadFiles(
            List<String>.from(event.propertyData['images'] ?? []),
            'properties/images',
          ),
          _propertyRepo.uploadFiles(
            List<String>.from(event.propertyData['docs'] ?? []),
            'properties/docs',
          ),
          // Subida del comprobante (screenshot)
          _propertyRepo.uploadFiles([
            event.propertyData['paymentScreenshot'],
          ], 'payments/receipts'),
        ]);

        // Extraemos las URLs resultantes de la subida
        final imageUrls = results[0];
        final docUrls = results[1];
        final receiptUrl =
            results[2].first; // URL pública del comprobante de pago

        // 3. CREACIÓN DEL MODELO FINAL
        emit(const PaymentProcessing("Guardando información del inmueble..."));

        final data = event.propertyData;
        final newProperty = PropertyModel(
          ownerId: event.userId,
          address: data['address'] ?? '',

          // --- NUEVOS CAMPOS EXTRAÍDOS DEL MAPA DE DATOS ---
          state: data['state'] ?? '', // Fallback seguro si no viene en el mapa
          city: data['city'] ?? '', // Fallback seguro si no viene en el mapa

          description: data['description'] ?? '',
          canon: (data['canon'] as num?)?.toDouble() ?? 0.0,
          area: data['area'] ?? '',
          hasAdmin: data['hasAdmin'] ?? false,
          adminPrice: (data['adminPrice'] as num?)?.toDouble() ?? 0.0,
          amenities: List<String>.from(data['amenities'] ?? []),
          imageUrls: imageUrls,
          docUrls: docUrls,
          paymentReceiptUrl:
              receiptUrl, // Guardamos la URL del pago en el modelo
          status: PropertyStatusEnum.paidPendingReview,
          paymentStatus: PaymentStatusEnum.pendingVerify,
          createdAt: DateTime.now(),
        );
        // 4. GUARDADO EN FIRESTORE
        await _propertyRepo.saveProperty(newProperty);

        // 5. EMISIÓN DE ÉXITO CON DATOS PARA WHATSAPP
        emit(
          PaymentSuccess(
            transactionId: "REF_${DateTime.now().millisecondsSinceEpoch}",
            receiptUrl: receiptUrl, // Pasamos la URL al estado para el Listener
            propertyAddress: data['address'] ?? 'Sin dirección',
          ),
        );
      } catch (e) {
        emit(PaymentFailure("Error en el registro: ${e.toString()}"));
      }
    });

    on<UpdatePropertyPaymentOnly>((event, emit) async {
      try {
        emit(const PaymentProcessing("Subiendo comprobante de pago..."));

        // 1. Subir SOLO el archivo del comprobante
        final results = await _propertyRepo.uploadFiles([
          event.screenshotPath,
        ], 'payments/receipts');
        final String receiptUrl = results.first;

        emit(const PaymentProcessing("Actualizando estado del inmueble..."));

        // 2. Actualizar SOLO los campos necesarios en Firestore
        // Accedemos directamente a la colección de propiedades por el ID
        await FirebaseFirestore.instance
            .collection('properties')
            .doc(event.propertyId)
            .update({
              'paymentReceiptUrl': receiptUrl,
              'status': PropertyStatusEnum
                  .paidPendingReview
                  .name, // O .value según tu extensión
              'paymentStatus': PaymentStatusEnum.pendingVerify.name,
            });

        emit(
          PaymentSuccess(
            transactionId: "UP_REF_${DateTime.now().millisecondsSinceEpoch}",
            receiptUrl: receiptUrl,
            propertyAddress: "Actualización de pago",
          ),
        );
      } catch (e) {
        emit(PaymentFailure("Error al actualizar pago: ${e.toString()}"));
      }
    });
  }
}
