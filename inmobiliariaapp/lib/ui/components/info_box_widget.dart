import 'package:flutter/material.dart';
import 'package:inmobiliariaapp/ui/components/global/custom_text.dart';

Widget buildInfoBox(String msg, Color col) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(
      color: col.withOpacity(0.05),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: col.withOpacity(0.2), width: 1.2),
    ),
    child: CustomText(
      msg,
      textAlign: TextAlign.center,
      baseFontSize: 12,
      fontWeight: FontWeight.w600,
      color: col,
    ),
  );
}
