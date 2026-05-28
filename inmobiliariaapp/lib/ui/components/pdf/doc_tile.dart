import 'package:flutter/material.dart';
import 'package:inmobiliariaapp/ui/components/pdf/Pdf_view_screen.dart';

class DocTile extends StatelessWidget {
  final String title;
  final String? path;
  final String? subtitle;
  final Color color;
  final IconData icon;

  const DocTile({
    super.key, // Añade super.key para seguir buenas prácticas
    required this.title, 
    this.path, 
    this.subtitle, 
    required this.color, 
    required this.icon
  });

  @override
  Widget build(BuildContext context) {
    final bool hasFile = path != null;
    return Card(
      child: ListTile(
        leading: Icon(icon, color: hasFile ? color : Colors.grey),
        title: Text(
          title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          subtitle ?? (hasFile ? "Listo para revisión" : "Pendiente de carga"),
          style: TextStyle(
            fontSize: 11,
            color: hasFile ? Colors.green : Colors.orange,
          ),
        ),
        trailing: hasFile
            ? IconButton(
                icon: const Icon(Icons.visibility, color: Colors.blue),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => PdfViewScreen(path: path!)),
                ),
              )
            : const Icon(Icons.hourglass_empty, size: 20, color: Colors.grey),
      ),
    );
  }
}
