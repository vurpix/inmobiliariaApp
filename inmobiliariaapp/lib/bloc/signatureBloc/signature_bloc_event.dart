import 'package:inmobiliariaapp/models/signature/signature_status_model.dart';

abstract class SignatureEvent {}

class WatchContractSignatureRequested extends SignatureEvent {
  final String contractId;

  WatchContractSignatureRequested(this.contractId);
}

class SignatureSnapshotReceived extends SignatureEvent {
  final SignatureStatusModel? signature;

  SignatureSnapshotReceived(this.signature);
}

class RefreshSignatureStatusRequested extends SignatureEvent {
  final String contractId;

  RefreshSignatureStatusRequested(this.contractId);
}

class RefreshCurrentSignatureStatusRequested extends SignatureEvent {
   RefreshCurrentSignatureStatusRequested();
}

class StopWatchingSignatureRequested extends SignatureEvent {}