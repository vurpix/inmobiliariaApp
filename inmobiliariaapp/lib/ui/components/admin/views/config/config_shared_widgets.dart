// ui/pages/admin/widgets/config_shared_widgets.dart
import 'package:flutter/material.dart';
import 'package:inmobiliariaapp/ui/components/global/custom_text.dart';
import 'package:inmobiliariaapp/utils/themes.dart';

class ConfigSharedWidgets {
  static Widget cardWrapper({
    required BuildContext context,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.textColor.withOpacity(0.04)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1A365D).withOpacity(0.02),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  static Widget buildListTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: context.primaryColor.withOpacity(0.06),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: context.primaryColor, size: 20),
      ),
      title: CustomText(title, fontWeight: FontWeight.bold, baseFontSize: 14),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 2),
        child: CustomText(
          subtitle,
          baseFontSize: 13,
          color: context.textSecondaryColor,
        ),
      ),
      trailing: Icon(
        Icons.arrow_forward_ios_rounded,
        size: 12,
        color: context.textSecondaryColor.withOpacity(0.4),
      ),
      onTap: onTap,
    );
  }

  static Widget buildInfoBox(String msg, Color col) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: col.withOpacity(0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: col.withOpacity(0.2)),
      ),
      child: CustomText(
        msg,
        textAlign: TextAlign.center,
        fontWeight: FontWeight.w600,
        color: col,
      ),
    );
  }

  static void showImageDialog(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        child: InteractiveViewer(child: Image.network(url)),
      ),
    );
  }

  static void showSuccessSnack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: CustomText(
          msg,
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  static void showErrorSnack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: CustomText("Error: $msg", color: Colors.white),
        backgroundColor: context.errorColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
