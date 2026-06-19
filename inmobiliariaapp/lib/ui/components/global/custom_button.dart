// lib/ui/components/global/custom_button.dart
import 'package:flutter/material.dart';
import 'package:inmobiliariaapp/utils/themes.dart';

class CustomButton extends StatelessWidget {
  final Widget childText;
  final VoidCallback? onPressed;
  final bool isLoading;
  final double height;
  final Color? backgroundColor;
  final double borderRadius;

  // Agregamos estas propiedades planas para que personalices sin romper nada
  final BorderSide? borderSide;
  final List<BoxShadow>? boxShadow;

  const CustomButton({
    super.key,
    required this.childText,
    required this.onPressed,
    this.isLoading = false,
    this.height = 50.0,
    this.backgroundColor,
    this.borderRadius = 8.0,
    this.borderSide,
    this.boxShadow,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDisabled = onPressed == null || isLoading;

    // Resolvemos el color base de forma segura sin funciones de opacidad conflictivas
    final Color buttonColor = backgroundColor ?? context.primaryColor;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 150),
      // Si está deshabilitado o cargando, opacamos el botón COMPLETO de forma externa y segura
      opacity: isDisabled ? 0.6 : 1.0,
      child: Container(
        width: double.infinity,
        height: height,
        // Aquí puedes meter sombras personalizadas con total libertad
        decoration: boxShadow != null && !isDisabled
            ? BoxDecoration(
                borderRadius: BorderRadius.circular(borderRadius),
                boxShadow: boxShadow,
              )
            : null,
        child: ElevatedButton(
          // Bloqueamos el clic nativo si está cargando
          onPressed: isLoading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: buttonColor,
            // Evitamos usar .withOpacity aquí adentro para no corromper el Inspector de VS Code
            disabledBackgroundColor: buttonColor,
            elevation: 0,
            padding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(borderRadius),
              // Si pasas un borde personalizado (como para el botón de rechazar), se dibuja aquí
              side: borderSide ?? BorderSide.none,
            ),
          ),
          child: isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : childText,
        ),
      ),
    );
  }
}
