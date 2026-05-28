// ui/components/admin/views/admin_applications_view.dart
import 'package:flutter/material.dart';
import 'package:inmobiliariaapp/models/application_model.dart';
import 'package:inmobiliariaapp/services/application_service.dart';
import 'package:inmobiliariaapp/ui/components/admin/candidate_detail_screen.dart';
import 'package:inmobiliariaapp/utils/status_formatter.dart';
import 'package:inmobiliariaapp/utils/themes.dart';
import 'package:inmobiliariaapp/utils/format_extensions.dart'; // Extensión global de fechas integrada
import 'package:inmobiliariaapp/ui/components/global/custom_text.dart'; // Tus componentes de texto

class AdminApplicationsView extends StatelessWidget {
  final ApplicationService applicationService;
  final Widget Function(IconData, String) emptyStateBuilder;

  const AdminApplicationsView({
    super.key,
    required this.applicationService,
    required this.emptyStateBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ApplicationModel>>(
      stream: applicationService.watchAllApplications(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final applications = snapshot.data ?? [];

        if (applications.isEmpty) {
          return emptyStateBuilder(
            Icons.folder_open_rounded,
            "No hay aplicaciones activas",
          );
        }

        // --- ORDENACIÓN Y AGRUPACIÓN CRONOLÓGICA PREMIUM ---
        // Ordenamos primero de la más reciente a la más antigua
        applications.sort((a, b) => b.lastUpdate.compareTo(a.lastUpdate));

        Map<String, Map<String, List<ApplicationModel>>> groupedData = {};

        for (var app in applications) {
          String monthKey = app.lastUpdate.toMonthYear(); // Ej: "MAYO 2026"
          String weekKey = app.lastUpdate
              .toWeekFormat()
              .toUpperCase(); // Ej: "SEMANA 4"

          groupedData.putIfAbsent(monthKey, () => {});
          groupedData[monthKey]!.putIfAbsent(weekKey, () => []);
          groupedData[monthKey]![weekKey]!.add(app);
        }

        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: groupedData.entries.map((monthEntry) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- CABECERA MENSUAL ---
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 20, 4, 12),
                  child: CustomText.title(
                    monthEntry.key,
                    baseFontSize: 18,
                    color: context.primaryColor,
                    fontWeight: FontWeight.w900,
                  ),
                ),

                ...monthEntry.value.entries.map((weekEntry) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // --- BADGE SEMANAL ---
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        margin: const EdgeInsets.only(bottom: 14, left: 4),
                        decoration: BoxDecoration(
                          color: context.primaryColor.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: CustomText(
                          weekEntry.key,
                          baseFontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: context.primaryColor,
                        ),
                      ),

                      // --- LISTADO DE TARJETAS EXPANSIVOS ---
                      ...weekEntry.value
                          .map((app) => _buildApplicationCard(context, app))
                          .toList(),
                      const SizedBox(height: 8),
                    ],
                  );
                }).toList(),
                const Divider(height: 30, thickness: 1),
              ],
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildApplicationCard(BuildContext context, ApplicationModel app) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1A365D).withOpacity(0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Theme(
          data: Theme.of(context).copyWith(
            dividerColor: Colors.transparent,
            splashColor: context.primaryColor.withOpacity(0.02),
          ),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 6,
            ),
            iconColor: context.primaryColor,
            collapsedIconColor: context.textSecondaryColor.withOpacity(0.6),
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: context.primaryColor.withOpacity(0.06),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                Icons.holiday_village_outlined,
                color: context.primaryColor,
                size: 22,
              ),
            ),
            title: CustomText.title(
              app.address,
              baseFontSize: 15,
              color: context.textColor,
              fontWeight: FontWeight.w700,
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: CustomText(
                "${app.candidates.length} postulantes • Actividad: ${app.lastUpdate.toShortDate()}",
                baseFontSize: 12,
                color: context.textSecondaryColor.withOpacity(0.7),
              ),
            ),
            children: [
              const Divider(height: 1, indent: 16, endIndent: 16),
              ...app.candidates.map((candidate) {
                final bool isApproved =
                    candidate.status.toLowerCase().contains('approve') ||
                    candidate.status.toLowerCase().contains('paid');

                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 4,
                  ),
                  leading: CircleAvatar(
                    radius: 16,
                    backgroundColor: context.primaryColor.withOpacity(0.08),
                    child: Icon(
                      Icons.person_outline_rounded,
                      size: 16,
                      color: context.primaryColor,
                    ),
                  ),
                  title: CustomText(
                    candidate.nombre,
                    baseFontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isApproved ? Colors.green : Colors.amber,
                          ),
                        ),
                        const SizedBox(width: 6),
                        CustomText(
                          StatusFormatter.formatApplicationStatus(
                            candidate.status,
                          ),
                          baseFontSize: 12,
                          color: isApproved
                              ? Colors.green[700]
                              : context.textSecondaryColor,
                        ),
                      ],
                    ),
                  ),
                  trailing: Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: context.textSecondaryColor.withOpacity(0.4),
                  ),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CandidateDetailScreen(
                        candidate: candidate,
                        propertyId: app.propertyId,
                      ),
                    ),
                  ),
                );
              }).toList(),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
