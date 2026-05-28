// utils/format_extensions.dart
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

// --- INSTANCIAS DE CONFIGURACIÓN ÚNICAS (OPTIMIZACIÓN DE MEMORIA) ---
final _dotThousandsFormatter = NumberFormat('#,###', 'es_CO');

// =========================================================================
// 1. UTILIDADES Y EXTENSIONES PARA MONEDA Y NÚMEROS (COP)
// =========================================================================
extension COPFormatter on num {
  /// Convierte un número puro a Pesos Colombianos con signo estrictamente a la IZQUIERDA.
  /// Ej: 1250000 -> $1.250.000
  String toCOP() {
    // Reutilizamos el formateador de miles y forzamos el símbolo al inicio del String
    return '\$${this.toDots()}';
  }

  /// Convierte un número puro a formato de miles con puntos sin signo de moneda.
  /// Ej: 1250000 -> 1.250.000
  String toDots() => _dotThousandsFormatter.format(this).replaceAll(',', '.');
}

class FormatUtils {
  /// Parsea cualquier objeto dynamic de forma segura y lo devuelve en formato Pesos Colombianos.
  static String formatCurrency(dynamic value) {
    final num numericValue = num.tryParse(value?.toString() ?? '0') ?? 0;
    return numericValue.toCOP();
  }

  /// Parsea cualquier objeto dynamic de forma segura y lo devuelve con puntos de miles sin signo.
  static String formatInitialNumber(dynamic value) {
    if (value == null) return '0';
    final num numericValue = num.tryParse(value.toString()) ?? 0;
    return numericValue.toDots();
  }
}

// =========================================================================
// 2. FORMATEADOR DE INPUTS EN TIEMPO REAL (TEXTFIELDS)
// =========================================================================
class ThousandsFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) return newValue;

    // Removemos los puntos existentes para evitar duplicaciones
    final String cleanText = newValue.text.replaceAll('.', '');
    final int? numValue = int.tryParse(cleanText);

    if (numValue == null) return oldValue;

    // Aplicamos el formato con la instancia optimizada
    final String formatted = _dotThousandsFormatter
        .format(numValue)
        .replaceAll(',', '.');

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

// =========================================================================
// 3. EXTENSIONES GLOBALES SOBRE DATETIME (MANEJO DE FECHAS CRONOLÓGICAS)
// =========================================================================
extension AppDateFormatter on DateTime {
  /// 1. Formato Corto Estándar (Contratos, recibos)
  /// Ej: 26/05/2026
  String toShortDate() {
    return DateFormat('dd/MM/yyyy').format(this);
  }

  /// 2. Formato Mes y Año (Cabeceras cronológicas)
  /// Corresponde a: DateFormat('MMMM yyyy', 'es')
  /// Ej: MAYO 2026
  String toMonthYear() {
    return DateFormat('MMMM yyyy', 'es_CO').format(this).toUpperCase();
  }

  /// 3. Formato de Semana Numérica (Agrupar actividades)
  /// Ej: SEMANA 4
  String toWeekFormat() {
    int weekOfMonth = ((day - 1) / 7).floor() + 1;
    return "SEMANA $weekOfMonth";
  }

  /// 4. Formato Largo Textual (Firmas o estados formales)
  /// Ej: Martes, 26 de Mayo de 2026
  String toLongDate() {
    return DateFormat("EEEE, d 'de' MMMM 'de' yyyy", 'es_CO').format(this);
  }

  /// 5. Día y Mes abreviado en mayúsculas (Feeds de notificaciones)
  /// Ej: 26 MAY
  String toDayMonth() {
    return DateFormat("dd MMM", "es_CO").format(this).toUpperCase();
  }

  /// 6. Hora en formato de 12 horas con meridiano
  /// Ej: 09:35 AM
  String toTime() {
    return DateFormat("hh:mm a", "es_CO").format(this);
  }

  /// 7. Marca de tiempo completa combinada (24 horas)
  /// Ej: 26 May 2026, 09:35 AM
  String toFullDateTime() {
    return DateFormat('dd MMM yyyy, hh:mm a', 'es_CO').format(this);
  }

  /// 8. Nombre del día seguido de fecha corta
  /// Ej: Martes, 26/05/2026
  String toDayAndShortDate() {
    final String formatted = DateFormat(
      'EEEE, dd/MM/yyyy',
      'es_CO',
    ).format(this);
    return formatted.substring(0, 1).toUpperCase() + formatted.substring(1);
  }

  /// 9. Fecha y hora compacta guionada (12 horas)
  /// Ej: 26/05/2026 - 09:35 AM
  String toCompactDateTime() =>
      DateFormat('dd/MM/yyyy - hh:mm a', 'es_CO').format(this);

  /// 10. NUEVO: Fecha con hora estándar de un solo dígito (H) en español
  /// Corresponde a: DateFormat('dd MMM yyyy, h:mm a', 'es')
  /// Ej: 26 may 2026, 9:35 AM
  String toSpanishFullDateTime() {
    return DateFormat('dd MMM yyyy, h:mm a', 'es_CO').format(this);
  }

  /// 11. NUEVO: Día de la semana abreviado con día numérico (Historiales o listas compactas)
  /// Corresponde a: DateFormat("EEE, d MMM")
  /// Ej: mar., 26 may.
  String toShortDayAndDate() {
    return DateFormat("EEE, d MMM", 'es_CO').format(this);
  }

  /// 12. NUEVO: Sello cronológico técnico guionado con hora (Logs de auditoría estricta)
  /// Corresponde a: DateFormat("yyyy-MM-dd hh:mm a")
  /// Ej: 2026-05-26 09:35 AM
  String toTechnicalDateTime() {
    return DateFormat("yyyy-MM-dd hh:mm a", 'es_CO').format(this);
  }

  /// 13. NUEVO: Sello de fecha técnico ISO estandarizado (Consultas de base de datos)
  /// Corresponde a: DateFormat("yyyy-MM-dd")
  /// Ej: 2026-05-26
  String toTechnicalDate() {
    return DateFormat("yyyy-MM-dd").format(this);
  }
}
