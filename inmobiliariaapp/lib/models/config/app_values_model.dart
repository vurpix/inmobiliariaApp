import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:inmobiliariaapp/models/config/price_scale.dart';

class AppValuesModel {
  final int creditStudyCost;
  final List<PriceScale> priceScales;

  AppValuesModel({required this.creditStudyCost, required this.priceScales});

  factory AppValuesModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return AppValuesModel(
      creditStudyCost: int.tryParse(data['creditStudyCost'].toString()) ?? 0,
      priceScales: (data['priceScales'] as List? ?? [])
          .map((item) => PriceScale.fromMap(item))
          .toList(),
    );
  }
}
