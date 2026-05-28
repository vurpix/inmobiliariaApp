// ui/pages/admin/admin_config_screen.dart
import 'package:flutter/material.dart';
import 'package:inmobiliariaapp/ui/components/admin/views/config/admin_stories_screen.dart';
import 'package:inmobiliariaapp/ui/components/admin/views/config/legal_config_section.dart';
import 'package:inmobiliariaapp/ui/components/admin/views/config/payment_config_section.dart';
import 'package:inmobiliariaapp/ui/components/admin/views/config/price_scales_config_section.dart';
import 'package:inmobiliariaapp/ui/components/admin/views/config/subscriptions_config_section.dart';
import 'package:inmobiliariaapp/utils/themes.dart';
import 'package:inmobiliariaapp/ui/components/global/custom_text.dart';

class AdminConfigScreen extends StatefulWidget {
  const AdminConfigScreen({super.key});

  @override
  State<AdminConfigScreen> createState() => _AdminConfigScreenState();
}

class _AdminConfigScreenState extends State<AdminConfigScreen> {
  int _selectedMenuIndex = 0;
  bool _isUploadingGlobal = false;

  void _setGlobalLoading(bool value) {
    setState(() => _isUploadingGlobal = value);
  }

  @override
  Widget build(BuildContext context) {
    // Listado desacoplado y envuelto en contenedores de scroll reutilizables
    final List<Widget> subViews = [
      _viewWrapper(
        title: "Configuración de Suscripciones",
        child: const SubscriptionsConfigSection(),
      ),
      _viewWrapper(
        title: "Pasarela de Pagos Automática",
        child: PaymentConfigSection(onLoadingChanged: _setGlobalLoading),
      ),
      _viewWrapper(
        title: "Honorarios de Precios de Estudio",
        child: const PriceScalesConfigSection(),
      ),
      _viewWrapper(
        title: "Documentación y Modelos Legales",
        child: LegalConfigSection(onLoadingChanged: _setGlobalLoading),
      ),
      _viewWrapper(
        title: "Multimedia y Contenido de Historias",
        child: const AdminStoriesScreen(),
      ),
    ];

    return Scaffold(
      backgroundColor: context.surfaceColor.withOpacity(0.96),
      body: Stack(
        children: [
          subViews[_selectedMenuIndex],
          if (_isUploadingGlobal)
            Container(
              color: Colors.black38,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1A365D).withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedMenuIndex,
          onTap: (index) => setState(() => _selectedMenuIndex = index),
          backgroundColor: context.surfaceColor,
          selectedItemColor: context.primaryColor,
          unselectedItemColor: context.textSecondaryColor.withOpacity(0.4),
          showUnselectedLabels: true,
          type: BottomNavigationBarType.fixed,
          selectedLabelStyle: const TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
            fontSize: 11,
          ),
          unselectedLabelStyle: const TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w500,
            fontSize: 11,
          ),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.card_membership_rounded),
              label: "Suscripción",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.account_balance_wallet_rounded),
              label: "Pasarela",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.bar_chart_rounded),
              label: "Honorarios",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.gavel_rounded),
              label: "Legales",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.video_library_rounded),
              label: "Multimedia",
            ),
          ],
        ),
      ),
    );
  }

  Widget _viewWrapper({required String title, required Widget child}) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      children: [
        CustomText.title(
          title,
          baseFontSize: 18,
          color: context.primaryColor,
          fontWeight: FontWeight.w900,
        ),
        const SizedBox(height: 16),
        child,
      ],
    );
  }
}
