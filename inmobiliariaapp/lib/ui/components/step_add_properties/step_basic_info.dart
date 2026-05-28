// ui/pages/form/step_basic_info.dart
import 'dart:convert'; // Necesario para jsonDecode
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Necesario para rootBundle
import 'package:inmobiliariaapp/ui/components/shared/local_search_provider.dart';
import 'package:inmobiliariaapp/utils/currency_input_formatter.dart';
import 'package:inmobiliariaapp/utils/themes.dart';

class StepBasicInfo extends StatefulWidget {
  final Map<String, dynamic> data;
  final Function(String, dynamic) onUpdate;

  const StepBasicInfo({super.key, required this.data, required this.onUpdate});

  @override
  State<StepBasicInfo> createState() => _StepBasicInfoState();
}

class _StepBasicInfoState extends State<StepBasicInfo> {
  late TextEditingController _canonController;
  late TextEditingController _areaController;
  late TextEditingController _adminController;
  late TextEditingController _descController;

  // --- CONTROLADORES INDEPENDIENTES PARA EL DISEÑO DE DIRECCIÓN ---
  late TextEditingController _streetController;
  late TextEditingController _additionalController;
  late TextEditingController _zipController; // Código Postal opcional

  // Estructura de datos para el JSON dinámico
  Map<String, List<String>> _colombiaLocationData = {};
  String? _selectedDepartment;
  String? _selectedCity;
  List<String> _availableCities = [];
  bool _isJsonLoading = true;

  @override
  void initState() {
    super.initState();
    _canonController = TextEditingController(
      text: widget.data['canon']?.toString() ?? "",
    );
    _areaController = TextEditingController(
      text: widget.data['area']?.toString() ?? "",
    );
    _adminController = TextEditingController(
      text: widget.data['adminPrice']?.toString() ?? "",
    );
    _descController = TextEditingController(
      text: widget.data['description'] ?? "",
    );

    // Separación sutil si se está editando una propiedad previa
    final String fullAddress = widget.data['address'] ?? "";
    String street = "";
    String additional = "";

    if (fullAddress.isNotEmpty) {
      final parts = fullAddress.split(',');
      if (parts.length >= 1) street = parts[0].trim();
      if (parts.length >= 2) additional = parts[1].trim();
    }

    _streetController = TextEditingController(text: street);
    _additionalController = TextEditingController(text: additional);
    _zipController = TextEditingController(text: widget.data['zipCode'] ?? "");

    _loadColombiaData();
  }

  // --- CONCATENACIÓN AUTOMÁTICA DE LA DIRECCIÓN PREMIUM ---
  void _buildAndSaveAddress() {
    final String street = _streetController.text.trim();
    final String additional = _additionalController.text.trim();

    List<String> components = [];
    if (street.isNotEmpty) components.add(street);
    if (additional.isNotEmpty) components.add(additional);

    final String finalAddress = components.join(', ');
    widget.onUpdate('address', finalAddress);
  }

  Future<void> _loadColombiaData() async {
    try {
      final String response = await rootBundle.loadString(
        'assets/json/colombia_municipios.json',
      );
      final Map<String, dynamic> decodedJson = jsonDecode(response);

      setState(() {
        _colombiaLocationData = decodedJson.map(
          (key, value) => MapEntry(key, List<String>.from(value)),
        );

        _selectedDepartment = widget.data['state'];
        if (_selectedDepartment != null) {
          _availableCities = _colombiaLocationData[_selectedDepartment] ?? [];
          _selectedCity = widget.data['city'];
        }
        _isJsonLoading = false;
      });
    } catch (e) {
      debugPrint("Error cargando el archivo de municipios JSON: $e");
      setState(() => _isJsonLoading = false);
    }
  }

  @override
  void dispose() {
    _canonController.dispose();
    _areaController.dispose();
    _adminController.dispose();
    _descController.dispose();
    _streetController.dispose();
    _additionalController.dispose();
    _zipController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<String> amenitiesOptions = [
      "Parqueadero",
      "Ascensor",
      "Piscina",
      "Gimnasio",
      "Zonas Verdes",
      "Portería 24/7",
      "Balcón",
      "Juegos Infantiles",
    ];

    List<String> selectedAmenities = List<String>.from(
      widget.data['amenities'] ?? [],
    );
    bool hasAdmin = widget.data['hasAdmin'] ?? false;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Detalles de la Propiedad",
            style: TextStyle(
              fontSize: ResponsiveUtils.getFontSize(context, 22),
              fontWeight: FontWeight.w800, // Estilo Bold Premium
              color: context.textColor,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 25),

          // --- ROW: CANON Y ÁREA ---
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: _buildCustomInput(
                  label: "Canon mensual",
                  prefix: "\$ ",
                  controller: _canonController,
                  keyboard: TextInputType.number,
                  formatters: [CurrencyInputFormatter()],
                  onChanged: (v) {
                    String cleanValue = v.replaceAll(RegExp(r'[^0-9]'), '');
                    widget.onUpdate(
                      'canon',
                      double.tryParse(cleanValue) ?? 0.0,
                    );
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 1,
                child: _buildCustomInput(
                  label: "Área m²",
                  suffix: " m²",
                  controller: _areaController,
                  keyboard: TextInputType.number,
                  onChanged: (v) => widget.onUpdate('area', v),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // --- INTERRUPTOR DE ADMINISTRACIÓN ---
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: context.surfaceColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.black.withOpacity(0.04)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "¿Tiene administración?",
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: context.textColor,
                    fontSize: 14,
                  ),
                ),
                Switch(
                  value: hasAdmin,
                  onChanged: (v) => widget.onUpdate('hasAdmin', v),
                  activeColor: context.primaryColor,
                ),
              ],
            ),
          ),

          if (hasAdmin) ...[
            const SizedBox(height: 16),
            _buildCustomInput(
              label: "Valor de administración",
              prefix: "\$ ",
              controller: _adminController,
              keyboard: TextInputType.number,
              formatters: [CurrencyInputFormatter()],
              onChanged: (v) {
                String cleanValue = v.replaceAll(RegExp(r'[^0-9]'), '');
                widget.onUpdate(
                  'adminPrice',
                  double.tryParse(cleanValue) ?? 0.0,
                );
              },
            ),
          ],

          const SizedBox(height: 30),

          // =========================================================================
          // --- NUEVA SECCIÓN DE DIRECCIÓN INTERNACIONAl/NACIONAL (DISEÑO IMAGEN) ---
          // =========================================================================
          Text(
            "¿Cuál es la dirección de la propiedad?",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: context.textColor,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 16),

          // 1. Street Address Input
          _buildCustomInput(
            label: "Dirección / Calle principal",
            controller: _streetController,
            onChanged: (_) => _buildAndSaveAddress(),
          ),
          const SizedBox(height: 14),

          // 2. Apt, Suite, etc. Input
          _buildCustomInput(
            label: "Apto, Casa, Torre (Opcional)",
            controller: _additionalController,
            onChanged: (_) => _buildAndSaveAddress(),
          ),
          const SizedBox(height: 14),

          // 3. City Input (Usa tu BottomSheet dinámico de la app)
          _isJsonLoading
              ? const LinearProgressIndicator()
              : _buildDropdownSelector(
                  label: "Departamento",
                  hint: "Seleccione",
                  value: _selectedDepartment,
                  items: _colombiaLocationData.keys.toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedDepartment = value;
                      _availableCities = _colombiaLocationData[value] ?? [];
                      _selectedCity = null;
                    });
                    widget.onUpdate('state', value);
                    widget.onUpdate('city', null);
                  },
                ),
          const SizedBox(height: 14),

          // 4. Row de Estado/Dpto y Código Postal (Exacto como la parte inferior de la imagen)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Dropdown de Departamento
              Expanded(
                flex: 4,
                child: _isJsonLoading
                    ? const SizedBox()
                    : _buildDropdownSelector(
                        label: "Ciudad / Municipio",
                        hint: _selectedDepartment == null
                            ? "Seleccione primero dpto."
                            : "Seleccionar ciudad",
                        value: _selectedCity,
                        items: _availableCities,
                        onChanged: _selectedDepartment == null
                            ? null
                            : (value) {
                                setState(() {
                                  _selectedCity = value;
                                });
                                widget.onUpdate('city', value);
                              },
                      ),
              ),
              const SizedBox(width: 14),
              // Input de Código Postal / Zip Code
              Expanded(
                flex: 3,
                child: _buildCustomInput(
                  label: "Cód. Postal",
                  controller: _zipController,
                  keyboard: TextInputType.number,
                  onChanged: (v) => widget.onUpdate('zipCode', v),
                ),
              ),
            ],
          ),

          // =========================================================================
          const SizedBox(height: 30),

          // --- SECCIÓN: AMENIDADES ---
          Text(
            "Características y Zonas comunes",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: context.textColor,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: amenitiesOptions.map((amenity) {
              final isSelected = selectedAmenities.contains(amenity);
              return FilterChip(
                label: Text(amenity),
                selected: isSelected,
                selectedColor: context.primaryColor.withOpacity(0.12),
                checkmarkColor: context.primaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                labelStyle: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  color: isSelected ? context.primaryColor : context.textColor,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
                ),
                onSelected: (bool selected) {
                  setState(() {
                    selected
                        ? selectedAmenities.add(amenity)
                        : selectedAmenities.remove(amenity);
                  });
                  widget.onUpdate('amenities', selectedAmenities);
                },
              );
            }).toList(),
          ),

          const SizedBox(height: 30),

          // --- CAMPO: DESCRIPCIÓN ADICIONAL ---
          Text(
            "Descripción interna",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: context.textColor,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            onChanged: (v) => widget.onUpdate('description', v),
            controller: _descController,
            maxLines: 4,
            maxLength: 400,
            style: TextStyle(
              fontFamily: 'Inter',
              color: context.textColor,
              fontSize: 14,
            ),
            decoration: InputDecoration(
              hintText:
                  "Cuéntanos sobre los acabados, iluminación, remodelaciones...",
              hintStyle: TextStyle(
                color: context.textSecondaryColor.withOpacity(0.4),
              ),
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  // =========================================================================
  // --- COMPONENTES ATÓMICOS PREMIUM REUTILIZABLES (ESTILO LUXE) ---
  // =========================================================================

  // Input de Texto Moderno con etiquetas flotantes e internas integradas
  Widget _buildCustomInput({
    required String label,
    required TextEditingController controller,
    required Function(String) onChanged,
    String? prefix,
    String? suffix,
    TextInputType? keyboard,
    List<TextInputFormatter>? formatters,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.015),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        onChanged: onChanged,
        keyboardType: keyboard,
        inputFormatters: formatters,
        controller: controller,
        style: TextStyle(
          fontFamily: 'Inter',
          color: context.textColor,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            color: context.textSecondaryColor.withOpacity(0.6),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
          prefixText: prefix,
          suffixText: suffix,
          alignLabelWithHint: true,
          floatingLabelBehavior: FloatingLabelBehavior.auto,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
              color: context.textColor.withOpacity(0.08),
              width: 1.5,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: context.primaryColor, width: 2),
          ),
        ),
      ),
    );
  }

  // Selector Dropdown Premium Estilo "InkWell Field" que despliega tu BottomSheet modal
  Widget _buildDropdownSelector({
    required String label,
    required String hint,
    required String? value,
    required List<String> items,
    required ValueChanged<String?>? onChanged,
  }) {
    final bool isEnabled = onChanged != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: !isEnabled
              ? null
              : () => _showLocationBottomSheet(
                  label,
                  hint,
                  items,
                  value,
                  onChanged,
                ),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
            decoration: BoxDecoration(
              color: isEnabled
                  ? context.surfaceColor
                  : context.surfaceColor.withOpacity(0.4),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: value != null
                    ? context.primaryColor.withOpacity(0.3)
                    : context.textColor.withOpacity(0.08),
                width: value != null ? 2 : 1.5,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          color: context.textSecondaryColor.withOpacity(0.5),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        value ?? hint,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          fontWeight: value != null
                              ? FontWeight.w600
                              : FontWeight.normal,
                          color: value != null
                              ? context.textColor
                              : context.textSecondaryColor.withOpacity(0.5),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.expand_more_rounded,
                  color: isEnabled
                      ? context.primaryColor
                      : context.textSecondaryColor.withOpacity(0.2),
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showLocationBottomSheet(
    String title,
    String searchHint,
    List<String> items,
    String? currentSelection,
    ValueChanged<String?> onChanged,
  ) {
    List<String> filteredItems = List.from(items);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (modalContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return LocalSearchProvider(
              items: items,
              filteredItems: filteredItems,
              currentSelection: currentSelection,
              title: title,
              onChanged: onChanged,
              modalContext: modalContext,
              setModalState: setModalState,
            );
          },
        );
      },
    );
  }
}
