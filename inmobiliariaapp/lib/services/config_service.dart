import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:inmobiliariaapp/models/config/app_values_model.dart';
import 'package:inmobiliariaapp/models/config/legal_info_model.dart';
import 'package:inmobiliariaapp/models/config/payment_Info.dart';

class ConfigService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String _collection = 'config';

  // --- STREAMS (Para la UI que debe reaccionar a cambios) ---

  Stream<AppValuesModel> watchAppValues() {
    return _db
        .collection(_collection)
        .doc('app_values')
        .snapshots()
        .map((doc) => AppValuesModel.fromFirestore(doc));
  }

  Stream<PaymentInfo> watchPaymentInfo() {
    return _db
        .collection(_collection)
        .doc('payment_info')
        .snapshots()
        .map((doc) => PaymentInfo.fromFirestore(doc));
  }

  Stream<LegalInfoModel> watchLegalInfo() {
    return _db
        .collection(_collection)
        .doc('legal_info')
        .snapshots()
        .map((doc) => LegalInfoModel.fromFirestore(doc));
  }

  // --- GETTERS (Para lógica puntual que no necesita Stream) ---

  Future<AppValuesModel> getAppValues() async {
    final doc = await _db.collection(_collection).doc('app_values').get();
    return AppValuesModel.fromFirestore(doc);
  }

  // --- UPDATERS (Para el panel de administración) ---

  Future<void> updatePaymentInfo(Map<String, dynamic> newData) async {
    await _db.collection(_collection).doc('payment_info').update(newData);
  }

  Future<void> updateAppValues(Map<String, dynamic> newData) async {
    await _db.collection(_collection).doc('app_values').update(newData);
  }
}
