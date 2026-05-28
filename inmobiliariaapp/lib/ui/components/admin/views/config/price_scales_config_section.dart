// ui/pages/admin/sections/price_scales_config_section.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:inmobiliariaapp/models/config/app_values_model.dart';
import 'package:inmobiliariaapp/models/config/price_scale.dart';
import 'package:inmobiliariaapp/services/config_service.dart';
import 'package:inmobiliariaapp/ui/components/admin/views/config/config_shared_widgets.dart';
import 'package:inmobiliariaapp/utils/themes.dart';
import 'package:inmobiliariaapp/utils/format_extensions.dart';
import 'package:inmobiliariaapp/ui/components/global/custom_text.dart';
import 'package:inmobiliariaapp/ui/components/global/custom_text_button.dart';

class PriceScalesConfigSection extends StatefulWidget {
  const PriceScalesConfigSection({super.key});

  @override
  State<PriceScalesConfigSection> createState() =>
      _PriceScalesConfigSectionState();
}

class _PriceScalesConfigSectionState extends State<PriceScalesConfigSection> {
  final ConfigService _configService = ConfigService();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppValuesModel>(
      stream: _configService.watchAppValues(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const LinearProgressIndicator();
        final appValues = snapshot.data!;
        final List<PriceScale> scales = appValues.priceScales;

        return ConfigSharedWidgets.cardWrapper(
          context: context,
          child: Column(
            children: [
              // --- ENCABEZADO MINIMALISTA DE COSTO BASE ---
              InkWell(
                onTap: () => _showCostoBaseDialog(appValues.creditStudyCost),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.analytics_outlined,
                        size: 18,
                        color: context.primaryColor,
                      ),
                      const SizedBox(width: 8),
                      const CustomText(
                        "Costo Base Directo:",
                        fontWeight: FontWeight.w600,
                        baseFontSize: 13,
                      ),
                      const SizedBox(width: 6),
                      CustomText(
                        appValues.creditStudyCost.toCOP(),
                        fontWeight: FontWeight.bold,
                        baseFontSize: 13,
                        color: context.primaryColor,
                      ),
                      const Spacer(),
                      Icon(
                        Icons.edit_note_rounded,
                        size: 18,
                        color: context.textSecondaryColor.withOpacity(0.5),
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(height: 1),
              const SizedBox(height: 8),

              // --- LISTADO DE ESCALAS OPTIMIZADO (SIN PRICETENANT) ---
              ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: scales.length,
                onReorder: (old, current) =>
                    _onReorderScales(scales, old, current),
                itemBuilder: (context, index) {
                  final scale = scales[index];

                  return Container(
                    key: ValueKey('scale_${index}_${scale.max}'),
                    margin: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: context.textColor.withOpacity(0.01),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: context.textColor.withOpacity(0.03),
                      ),
                    ),
                    child: ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      leading: ReorderableDragStartListener(
                        index: index,
                        child: Icon(
                          Icons.drag_indicator_rounded,
                          size: 18,
                          color: context.textSecondaryColor.withOpacity(0.3),
                        ),
                      ),
                      title: CustomText(
                        "Hasta ${scale.max.toCOP()}",
                        fontWeight: FontWeight.w900,
                        baseFontSize: 13,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.real_estate_agent_outlined,
                              size: 12,
                              color: context.primaryColor.withOpacity(0.7),
                            ),
                            const SizedBox(width: 4),
                            CustomText(
                              "Costo Estudio: ${scale.price.toCOP()}",
                              baseFontSize: 11,
                              color: context.textSecondaryColor,
                            ),
                          ],
                        ),
                      ),
                      trailing: SizedBox(
                        width: 54,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            IconButton(
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              icon: const Icon(
                                Icons.edit_note_rounded,
                                color: Colors.blue,
                                size: 20,
                              ),
                              onPressed: () =>
                                  _showScaleEditDialog(scales, index),
                            ),
                            const Spacer(),
                            IconButton(
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              icon: const Icon(
                                Icons.delete_outline_rounded,
                                color: Colors.redAccent,
                                size: 18,
                              ),
                              onPressed: () =>
                                  _showDeleteConfirmDialog(scales, index),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),
              CustomTextButton.primary(
                "AGREGAR NUEVO RANGO",
                onPressed: () => _addNewScale(scales),
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  void _showCostoBaseDialog(int current) {
    final controller = TextEditingController(text: current.toDots());
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: CustomText.title(
          "Editar Costo Base",
          baseFontSize: 16,
          fontWeight: FontWeight.bold,
        ),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            ThousandsFormatter(),
          ],
          decoration: const InputDecoration(
            labelText: "Costo Base Directo",
            prefixText: "\$ ",
            contentPadding: EdgeInsets.all(14),
          ),
        ),
        actions: [
          CustomTextButton.muted(
            "CANCELAR",
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            onPressed: () async {
              final int val =
                  int.tryParse(controller.text.replaceAll('.', '')) ?? 0;
              await _configService.updateAppValues({"creditStudyCost": val});
              if (context.mounted) Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: context.primaryColor,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            child: const Text("GUARDAR"),
          ),
        ],
      ),
    );
  }

  void _showScaleEditDialog(List<PriceScale> currentScales, int index) {
    final scale = currentScales[index];
    final maxController = TextEditingController(
      text: scale.max.toInt().toDots(),
    );
    final priceController = TextEditingController(
      text: scale.price.toInt().toDots(),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: CustomText.title(
          "Editar Rango Escala",
          baseFontSize: 16,
          fontWeight: FontWeight.bold,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: maxController,
              decoration: const InputDecoration(
                labelText: "Máximo Canon (COP)",
                prefixText: "\$ ",
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                ThousandsFormatter(),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: priceController,
              decoration: const InputDecoration(
                labelText: "Precio del Estudio (COP)",
                prefixText: "\$ ",
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                ThousandsFormatter(),
              ],
            ),
          ],
        ),
        actions: [
          CustomTextButton.muted(
            "CANCELAR",
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                List<Map<String, dynamic>> list = currentScales
                    .map((s) => {'min': s.min, 'max': s.max, 'price': s.price})
                    .toList();

                final int cleanMax =
                    int.tryParse(maxController.text.replaceAll('.', '')) ?? 0;
                final int cleanPrice =
                    int.tryParse(priceController.text.replaceAll('.', '')) ?? 0;

                list[index]['max'] = cleanMax;
                list[index]['price'] = cleanPrice;

                // Algoritmo en cascada para recalcular mínimos sin descalces
                for (int i = 0; i < list.length; i++) {
                  list[i]['min'] = i == 0 ? 0 : list[i - 1]['max'] + 1;
                }

                // Auto-ordenar ascendente por seguridad de negocio
                list.sort(
                  (a, b) => (a['max'] as int).compareTo(b['max'] as int),
                );

                // Re-confirmar mínimos tras el ordenamiento lineal
                for (int i = 0; i < list.length; i++) {
                  list[i]['min'] = i == 0 ? 0 : list[i - 1]['max'] + 1;
                }

                await _configService.updateAppValues({'priceScales': list});
                if (context.mounted) Navigator.pop(context);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: CustomText(
                        "Error al guardar la lista: $e",
                        color: Colors.white,
                      ),
                      backgroundColor: context.errorColor,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: context.primaryColor,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            child: const Text("GUARDAR"),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmDialog(List<PriceScale> currentScales, int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text("¿Eliminar rango?"),
          ],
        ),
        content: const CustomText(
          "¿Está seguro de que desea eliminar este rango de escala? Esto recalculará automáticamente los límites del sistema.",
        ),
        actions: [
          CustomTextButton.muted(
            "CANCELAR",
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            onPressed: () async {
              List<Map<String, dynamic>> list = currentScales
                  .map((s) => {'min': s.min, 'max': s.max, 'price': s.price})
                  .toList();
              list.removeAt(index);

              for (int i = 0; i < list.length; i++) {
                list[i]['min'] = i == 0 ? 0 : list[i - 1]['max'] + 1;
              }
              await _configService.updateAppValues({'priceScales': list});
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text("ELIMINAR"),
          ),
        ],
      ),
    );
  }

  Future<void> _onReorderScales(
    List<PriceScale> currentScales,
    int oldIndex,
    int newIndex,
  ) async {
    if (newIndex > oldIndex) newIndex -= 1;
    List<Map<String, dynamic>> list = currentScales
        .map((s) => {'min': s.min, 'max': s.max, 'price': s.price})
        .toList();
    final Map<String, dynamic> movedItem = list.removeAt(oldIndex);
    list.insert(newIndex, movedItem);

    for (int i = 0; i < list.length; i++) {
      list[i]['min'] = i == 0 ? 0 : list[i - 1]['max'] + 1;
    }
    await _configService.updateAppValues({'priceScales': list});
  }

  void _addNewScale(List<PriceScale> currentScales) async {
    List<Map<String, dynamic>> list = currentScales
        .map((s) => {'min': s.min, 'max': s.max, 'price': s.price})
        .toList();
    list.add({
      'min': list.isEmpty ? 0 : list.last['max'] + 1,
      'max': 0,
      'price': 0,
    });
    await _configService.updateAppValues({'priceScales': list});
  }
}
