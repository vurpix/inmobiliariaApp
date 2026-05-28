// lib/bloc/paymentBloc/payment_state.dart
import 'package:equatable/equatable.dart';

sealed class PaymentState extends Equatable {
  const PaymentState();
  
  @override
  List<Object?> get props => [];
}

final class PaymentInitial extends PaymentState {}

final class PaymentProcessing extends PaymentState {
  final String message;
  const PaymentProcessing(this.message);

  @override
  List<Object?> get props => [message];
}

final class PaymentSuccess extends PaymentState {
  final String transactionId;
  final String receiptUrl; // URL pública del comprobante en Firebase Storage
  final String propertyAddress; // Para personalizar el mensaje de WhatsApp

  const PaymentSuccess({
    required this.transactionId,
    required this.receiptUrl,
    required this.propertyAddress,
  });

  @override
  List<Object?> get props => [transactionId, receiptUrl, propertyAddress];
}

final class PaymentFailure extends PaymentState {
  final String error;
  const PaymentFailure(this.error);

  @override
  List<Object?> get props => [error];
}