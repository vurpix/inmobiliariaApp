// ui/components/global/custom_text.dart
import 'package:flutter/material.dart';
import 'package:inmobiliariaapp/utils/themes.dart'; // Importamos tus utilidades adaptativas

class CustomText extends StatelessWidget {
  final String text;
  final double baseFontSize;
  final FontWeight fontWeight;
  final Color?
  color; // Permitimos que sea nulo para usar el del tema por defecto
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  const CustomText(
    this.text, { // El texto es posicional (obligatorio), los demás son opcionales con nombre
    super.key,
    this.baseFontSize = 14.0, // Valor estándar por defecto
    this.fontWeight = FontWeight.normal,
    this.color,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });

  // --- FÁBRICA CONSTRUCTORA PARA TÍTULOS (ESTILO COMPONENTES UI COMPACTOS) ---
  factory CustomText.title(
    String text, {
    double baseFontSize = 24.0,
    FontWeight fontWeight = FontWeight.w800,
    Color? color,
    TextAlign? textAlign,
  }) {
    return CustomText(
      text,
      baseFontSize: baseFontSize,
      fontWeight: fontWeight,
      color: color,
      textAlign: textAlign,
    );
  }

  // --- FÁBRICA CONSTRUCTORA PARA SUBTÍTULOS ---
  factory CustomText.subtitle(
    String text, {
    double baseFontSize = 16.0,
    FontWeight fontWeight = FontWeight.w600,
    Color? color,
    TextAlign? textAlign,
  }) {
    return CustomText(
      text,
      baseFontSize: baseFontSize,
      fontWeight: fontWeight,
      color: color,
      textAlign: textAlign,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
      style: TextStyle(
        fontFamily: 'Inter', // Forzamos tu fuente Inter global
        fontWeight: fontWeight,
        // Si no se le pasa color, toma automáticamente el textColor dinámico (Claro/Oscuro)
        color: color ?? context.textColor,
        // Aplicamos tu utilidad de escalado responsivo
        fontSize: ResponsiveUtils.getFontSize(context, baseFontSize),
      ),
    );
  }
}
