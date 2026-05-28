// ui/components/global/custom_text_button.dart
import 'package:flutter/material.dart';
import 'package:inmobiliariaapp/utils/themes.dart'; // Tus utilidades adaptativas

class CustomTextButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed; // Función de navegación o acción
  final double baseFontSize;
  final FontWeight fontWeight;
  final Color? color; // Color del texto
  final AlignmentGeometry alignment;
  final EdgeInsetsGeometry? padding;

  const CustomTextButton(
    this.text, {
    super.key,
    required this.onPressed,
    this.baseFontSize = 14.0, // Tamaño estándar por defecto
    this.fontWeight = FontWeight.w600, // Los botones suelen ser semibold
    this.color,
    this.alignment = Alignment.center,
    this.padding,
  });

  // --- FÁBRICA CONSTRUCTORA PARA BOTONES DE NAVEGACIÓN PRINCIPAL (PRIMARY) ---
  // Ej: "Ver todos", "Continuar"
  factory CustomTextButton.primary(
    String text, {
    required VoidCallback onPressed,
    double baseFontSize = 14.0,
    AlignmentGeometry alignment = Alignment.center,
    EdgeInsetsGeometry? padding,
  }) {
    return CustomTextButton(
      text,
      onPressed: onPressed,
      baseFontSize: baseFontSize,
      fontWeight: FontWeight.w700, // Más grueso para denotar acción principal
      color:
          null, // Tomará context.primaryColor de forma automática en el build
      alignment: alignment,
      padding: padding,
    );
  }

  // --- FÁBRICA CONSTRUCTORA PARA BOTONES MENOS LLAMATIVOS (MUTED) ---
  // Ej: "Cancelar", "Atrás", "Saltar"
  factory CustomTextButton.muted(
    String text, {
    required VoidCallback onPressed,
    double baseFontSize = 13.0,
    AlignmentGeometry alignment = Alignment.center,
    EdgeInsetsGeometry? padding,
  }) {
    return CustomTextButton(
      text,
      onPressed: onPressed,
      baseFontSize: baseFontSize,
      fontWeight: FontWeight.w500, // Más delgado para jerarquía secundaria
      color: Colors.grey[600], // Tono neutro apagado
      alignment: alignment,
      padding: padding,
    );
  }

  // --- FÁBRICA CONSTRUCTORA PARA ACCIONES DE PELIGRO ---
  // Ej: "Eliminar propiedad", "Cerrar sesión"
  factory CustomTextButton.danger(
    String text, {
    required VoidCallback onPressed,
    double baseFontSize = 14.0,
    AlignmentGeometry alignment = Alignment.center,
    EdgeInsetsGeometry? padding,
  }) {
    return CustomTextButton(
      text,
      onPressed: onPressed,
      baseFontSize: baseFontSize,
      fontWeight: FontWeight.w600,
      color: Colors.redAccent, // Color de advertencia
      alignment: alignment,
      padding: padding,
    );
  }

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        alignment: alignment,
        padding:
            padding ?? const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        // Quita el efecto splash gigante si buscas un acabado minimalista, u opcionalmente configúralo:
        foregroundColor: color ?? context.primaryColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'Inter', // Forzamos tu tipografía corporativa
          fontWeight: fontWeight,
          // Escalado responsivo idéntico a tu CustomText
          fontSize: ResponsiveUtils.getFontSize(context, baseFontSize),
        ),
      ),
    );
  }
}
