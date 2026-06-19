// lib/models/contract_model.dart

class SignaturePartyModel {
  final String uid;
  final String role;
  final String email;
  final String name;       
  final String key;        //  (ej: 'firmante_1')
  final String status;     // 'PENDING', 'SIGNED', 'REJECTED'
  final String? signLink;  //  (La URL larga de Viafirma)
  final String? signToken; //  (El JWT de Viafirma)

  SignaturePartyModel({
    required this.uid,
    required this.role,
    required this.email,
    required this.name,
    required this.key,
    required this.status,
    this.signLink,
    this.signToken,
  });

  factory SignaturePartyModel.fromMap(Map<String, dynamic> map) {
    return SignaturePartyModel(
      uid: map['uid']?.toString() ?? '',
      role: map['role']?.toString() ?? '',
      email: map['email']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      key: map['key']?.toString() ?? '',
      status: map['status']?.toString() ?? 'PENDING',
      signLink: map['signLink']?.toString(),
      signToken: map['signToken']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'role': role,
      'email': email,
      'name': name,
      'key': key,
      'status': status,
      'signLink': signLink,
      'signToken': signToken,
    };
  }
}