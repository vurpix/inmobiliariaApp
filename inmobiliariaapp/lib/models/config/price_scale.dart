class PriceScale {
  final int min;
  final int max;
  final int price;

  PriceScale({required this.min, required this.max, required this.price});

  factory PriceScale.fromMap(Map<String, dynamic> map) {
    return PriceScale(
      min: map['min'] ?? 0,
      max: map['max'] ?? 0,
      price: map['price'] ?? 0,
    );
  }
}

// Función para calcular el precio dinámicamente
int calculateStudyPrice(int canonAmount, List<PriceScale> scales) {
  for (var scale in scales) {
    if (canonAmount >= scale.min && canonAmount <= scale.max) {
      return scale.price;
    }
  }
  return 0; // O un valor por defecto
}