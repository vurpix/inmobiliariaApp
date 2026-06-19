class SignatureStatusModel {
  final String contractId;
  final String signatureStatus;
  final String tenantSignatureStatus;
  final String ownerSignatureStatus;
  final String? viafirmaSetCode;
  final String? viafirmaMessageCode;
  final String? viafirmaSignatureDocId;
  final String? tenantSignLink;
  final String? ownerSignLink;
  final Map<String, dynamic> signaturesTracking;

  SignatureStatusModel({
    required this.contractId,
    required this.signatureStatus,
    required this.tenantSignatureStatus,
    required this.ownerSignatureStatus,
    required this.signaturesTracking,
    this.viafirmaSetCode,
    this.viafirmaMessageCode,
    this.viafirmaSignatureDocId,
    this.tenantSignLink,
    this.ownerSignLink,
  });

  factory SignatureStatusModel.fromMap({
    required String contractId,
    required Map<String, dynamic> data,
  }) {
    return SignatureStatusModel(
      contractId: contractId,
      signatureStatus: data['signatureStatus']?.toString() ?? 'unknown',
      tenantSignatureStatus:
          data['tenantSignatureStatus']?.toString() ?? 'PENDING',
      ownerSignatureStatus:
          data['ownerSignatureStatus']?.toString() ?? 'WAITING',
      viafirmaSetCode: data['viafirmaSetCode']?.toString(),
      viafirmaMessageCode: data['viafirmaMessageCode']?.toString(),
      viafirmaSignatureDocId: data['viafirmaSignatureDocId']?.toString(),
      tenantSignLink: data['tenantSignLink']?.toString(),
      ownerSignLink: data['ownerSignLink']?.toString(),
      signaturesTracking: Map<String, dynamic>.from(
        data['signaturesTracking'] ?? {},
      ),
    );
  }

  Map<String, dynamic>? trackingForUser(String uid) {
    final value = signaturesTracking[uid];

    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    return null;
  }

  String? signLinkForUser(String uid) {
    final tracking = trackingForUser(uid);
    return tracking?['signLink']?.toString();
  }

  String statusForUser(String uid) {
    final tracking = trackingForUser(uid);
    return tracking?['status']?.toString() ?? 'unknown';
  }
}