// Widget de soporte aislado para evitar fugas de memoria en los TextFields dinámicos
import 'package:flutter/material.dart';
import 'package:inmobiliariaapp/utils/themes.dart';

class LocalSearchProvider extends StatefulWidget {
  final List<String> items;
  final List<String> filteredItems;
  final String? currentSelection;
  final String title;
  final ValueChanged<String?> onChanged;
  final BuildContext modalContext;
  final StateSetter setModalState;

  const LocalSearchProvider({
    super.key,
    required this.items,
    required this.filteredItems,
    required this.currentSelection,
    required this.title,
    required this.onChanged,
    required this.modalContext,
    required this.setModalState,
  });

  @override
  State<LocalSearchProvider> createState() => _LocalSearchProviderState();
}

class _LocalSearchProviderState extends State<LocalSearchProvider> {
  late TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController
        .dispose(); // Se destruye limpiamente AQUÍ cuando el modal se cierra físicamente
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: 16,
        left: 16,
        right: 16,
        bottom: MediaQuery.of(widget.modalContext).viewInsets.bottom + 16,
      ),
      height: MediaQuery.of(widget.modalContext).size.height * 0.6,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4.5,
              decoration: BoxDecoration(
                color: context.textSecondaryColor.withOpacity(0.3),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            "Seleccionar ${widget.title}",
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: context.textColor,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _searchController,
            style: TextStyle(
              color: context.textColor,
              fontFamily: 'Inter',
              fontSize: 14,
            ),
            decoration: InputDecoration(
              hintText: "Buscar...",
              prefixIcon: Icon(
                Icons.search_rounded,
                color: context.primaryColor,
                size: 20,
              ),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        widget.setModalState(() {
                          widget.filteredItems.clear();
                          widget.filteredItems.addAll(widget.items);
                        });
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
            onChanged: (text) {
              widget.setModalState(() {
                widget.filteredItems.clear();
                widget.filteredItems.addAll(
                  widget.items
                      .where(
                        (item) =>
                            item.toLowerCase().contains(text.toLowerCase()),
                      )
                      .toList(),
                );
              });
            },
          ),
          const SizedBox(height: 12),
          Expanded(
            child: widget.filteredItems.isEmpty
                ? Center(
                    child: Text(
                      "No se encontraron resultados",
                      style: TextStyle(
                        color: context.textSecondaryColor,
                        fontFamily: 'Inter',
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: widget.filteredItems.length,
                    physics: const BouncingScrollPhysics(),
                    itemBuilder: (context, index) {
                      final item = widget.filteredItems[index];
                      final isSelected = item == widget.currentSelection;

                      return ListTile(
                        title: Text(
                          item,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: isSelected
                                ? context.primaryColor
                                : context.textColor,
                          ),
                        ),
                        trailing: isSelected
                            ? Icon(
                                Icons.check_circle_rounded,
                                color: context.primaryColor,
                                size: 20,
                              )
                            : null,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                        ),
                        onTap: () {
                          widget.onChanged(item);
                          Navigator.of(
                            widget.modalContext,
                          ).pop(); // Cierre seguro usando la ruta aislada
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
