// ui/pages/admin/sections/subscriptions_config_section.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:inmobiliariaapp/models/config/price_scale.dart'; // Importación de tu modelo
import 'package:inmobiliariaapp/ui/components/admin/views/config/config_shared_widgets.dart';
import 'package:inmobiliariaapp/utils/format_extensions.dart';
import 'package:inmobiliariaapp/utils/themes.dart';
import 'package:inmobiliariaapp/ui/components/global/custom_text.dart';
import 'package:inmobiliariaapp/ui/components/global/custom_text_button.dart';

class SubscriptionsConfigSection extends StatefulWidget {
  const SubscriptionsConfigSection({super.key});

  @override
  State<SubscriptionsConfigSection> createState() =>
      _SubscriptionsConfigSectionState();
}

class _SubscriptionsConfigSectionState
    extends State<SubscriptionsConfigSection> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _firestore.collection('subscriptions').doc('config').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LinearProgressIndicator();
        }
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return ConfigSharedWidgets.buildInfoBox(
            "No se encontró el documento de suscripciones.",
            Colors.orange,
          );
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;

        // 1. Parámetros globales de suscripción
        final int creditStudyCost =
            (data['creditStudyCost'] as num?)?.toInt() ?? 0;
        final int freeDays = (data['freeDays'] as num?)?.toInt() ?? 0;

        // 2. Mapeo seguro de la lista interna de escalas
        final List<dynamic> rawScales =
            data['priceScales'] as List<dynamic>? ?? [];
        final List<PriceScale> scales = rawScales
            .map((item) => PriceScale.fromMap(item as Map<String, dynamic>))
            .toList();

        return ConfigSharedWidgets.cardWrapper(
          context: context,
          child: Column(
            children: [
              // --- ENCABEZADO MINIMALISTA DE PARÁMETROS GLOBALES ---
              ConfigSharedWidgets.buildListTile(
                context: context,
                icon: Icons.monetization_on_outlined,
                title: "Precio del Estudio de Crédito",
                subtitle: creditStudyCost.toCOP(),
                onTap: () => _showSubscriptionEditDialog(
                  field: "creditStudyCost",
                  title: "Precio Estudio Crédito",
                  currentValue: creditStudyCost,
                  isPrice: true,
                ),
              ),
              const Divider(height: 1),
              ConfigSharedWidgets.buildListTile(
                context: context,
                icon: Icons.calendar_today_outlined,
                title: "Días de Tiempo Gratis (Free Trial)",
                subtitle: "$freeDays días asignados",
                onTap: () => _showSubscriptionEditDialog(
                  field: "freeDays",
                  title: "Días Gratis de Suscripción",
                  currentValue: freeDays,
                  isPrice: false,
                ),
              ),
              const Divider(height: 1),
              const SizedBox(height: 16),

              // --- SECCIÓN COMPACTA: ESCALAS DE PRECIOS ---
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  children: [
                    Icon(Icons.layers_outlined, size: 16),
                    SizedBox(width: 6),
                    CustomText(
                      "Rangos de Precios Configurables",
                      fontWeight: FontWeight.bold,
                      baseFontSize: 13,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: scales.length,
                onReorder: (oldIndex, newIndex) =>
                    _onReorderScales(scales, oldIndex, newIndex),
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
                            Expanded(
                              child: IconButton(
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
                            ),
                            Expanded(
                              child: IconButton(
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

  // --- DIÁLOGOS DE EDICIÓN DE VALORES GENERALES ---
  void _showSubscriptionEditDialog({
    required String field,
    required String title,
    required int currentValue,
    required bool isPrice,
  }) {
    final controller = TextEditingController(
      text: isPrice ? currentValue.toDots() : currentValue.toString(),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: CustomText.title(
          "Modificar parámetro",
          baseFontSize: 16,
          fontWeight: FontWeight.bold,
        ),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            if (isPrice) ThousandsFormatter(),
          ],
          decoration: InputDecoration(
            labelText: title,
            prefixText: isPrice ? "\$ " : null,
            contentPadding: const EdgeInsets.all(14),
          ),
        ),
        actions: [
          CustomTextButton.muted(
            "CANCELAR",
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            onPressed: () async {
              final String cleanText = controller.text.replaceAll('.', '');
              final int parsedValue = int.tryParse(cleanText) ?? 0;

              await _firestore.collection('subscriptions').doc('config').update(
                {field: parsedValue, 'updatedAt': FieldValue.serverTimestamp()},
              );
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

  // --- DIÁLOGO EXTENDIDO: EDICIÓN DE CADA ESCALA INDIVIDUAL ---
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
                // 1. Clonar la lista a mapas dinámicos mutables
                List<Map<String, dynamic>> list = currentScales
                    .map((s) => {'min': s.min, 'max': s.max, 'price': s.price})
                    .toList();

                final int cleanMax =
                    int.tryParse(maxController.text.replaceAll('.', '')) ?? 0;
                final int cleanPrice =
                    int.tryParse(priceController.text.replaceAll('.', '')) ?? 0;

                list[index]['max'] = cleanMax;
                list[index]['price'] = cleanPrice;

                // 2. Ejecución de la cascada de mínimos
                for (int i = 0; i < list.length; i++) {
                  list[i]['min'] = i == 0 ? 0 : list[i - 1]['max'] + 1;
                }

                // 3. Ordenamiento ascendente de control
                list.sort(
                  (a, b) => (a['max'] as int).compareTo(b['max'] as int),
                );

                // 4. Re-asentamiento final de límites post-sort
                for (int i = 0; i < list.length; i++) {
                  list[i]['min'] = i == 0 ? 0 : list[i - 1]['max'] + 1;
                }

                await _firestore
                    .collection('subscriptions')
                    .doc('config')
                    .update({'priceScales': list});
                if (context.mounted) Navigator.pop(context);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: CustomText(
                        "Error al reorganizar la lista: $e",
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

  // --- DIÁLOGO DE CONFIRMACIÓN DE BORRADO ---
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
              await _firestore.collection('subscriptions').doc('config').update(
                {'priceScales': list},
              );
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text("ELIMINAR"),
          ),
        ],
      ),
    );
  }

  // --- OPERACIONES COMPARTIDAS DE ARRASTRE Y REORDENACIÓN ---
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
    await _firestore.collection('subscriptions').doc('config').update({
      'priceScales': list,
    });
  }

  void _addNewScale(List<PriceScale> currentScales) async {
    // CORRECCIÓN: Forzamos explícitamente el tipado a Map<String, dynamic>
    List<Map<String, dynamic>> list = currentScales
        .map<Map<String, dynamic>>(
          (s) => {'min': s.min, 'max': s.max, 'price': s.price},
        )
        .toList();

    // CORRECCIÓN: Aseguramos el mismo tipo dinámico al agregar el nuevo rango base
    list.add(<String, dynamic>{
      'min': list.isEmpty ? 0 : (list.last['max'] as int) + 1,
      'max': 0,
      'price': 0,
    });

    try {
      await _firestore.collection('subscriptions').doc('config').update({
        'priceScales': list,
      });
    } catch (e) {
      debugPrint("Error al guardar nueva escala en Firestore: $e");
    }
  }
}
