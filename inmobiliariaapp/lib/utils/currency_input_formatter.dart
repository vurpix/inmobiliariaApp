import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class CurrencyInputFormatter extends TextInputFormatter {
@override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    
    // 1. Si el usuario borra todo, permitimos el campo vacío
    if (newValue.text.isEmpty) {
      return newValue.copyWith(text: '');
    }

    // 2. Extraemos solo los dígitos (quitamos puntos, símbolos, letras)
    String cleanText = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');

    if (cleanText.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }

    // 3. Formateamos el número con puntos de miles (estilo CO/ES)
    // Usamos un NumberFormat que no tenga símbolos de moneda
    final formatter = NumberFormat("#,###", "es_CO");
    
    double value = double.parse(cleanText);
    String formattedText = formatter.format(value).replaceAll(',', '.'); 
    // Nota: es_CO a veces usa coma para miles según la versión, 
    // forzamos el punto para que sea 1.000.000

    return TextEditingValue(
      text: formattedText,
      selection: TextSelection.collapsed(offset: formattedText.length),
    );
  }
}