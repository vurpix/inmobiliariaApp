// ui/components/shared/step_media.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:inmobiliariaapp/ui/components/shared/video_preview_item.dart';
import 'package:inmobiliariaapp/ui/components/global/custom_text.dart'; // Componente unificado de texto
import 'package:inmobiliariaapp/utils/themes.dart';

class StepMedia extends StatelessWidget {
  final Map<String, dynamic> data;
  final Function(String, dynamic) onUpdate;

  const StepMedia({super.key, required this.data, required this.onUpdate});

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final List<XFile> pickedFiles = await picker.pickMultiImage(
      imageQuality: 80,
    );
    if (pickedFiles.isNotEmpty) {
      List<String> currentImages = List<String>.from(data['images'] ?? []);
      currentImages.addAll(pickedFiles.map((file) => file.path));
      onUpdate('images', currentImages);
    }
  }

  Future<void> _pickVideo() async {
    final picker = ImagePicker();
    final XFile? file = await picker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(minutes: 2),
    );
    if (file != null) {
      onUpdate('video', file.path);
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<String> images = List<String>.from(data['images'] ?? []);

    final String? localVideo = data['video'];
    final String? databaseVideo = data['videoUrl'];
    final String? activeVideoPath =
        (localVideo != null && localVideo.isNotEmpty)
        ? localVideo
        : databaseVideo;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- SECCIÓN: FOTOGRAFÍAS ---
          CustomText.title(
            "Fotos del Inmueble",
            baseFontSize: 18,
            fontWeight: FontWeight.w900,
            color: context.primaryColor,
          ),
          const SizedBox(height: 4),
          CustomText(
            "Adjunta imágenes nítidas en formato horizontal para capturar el interés de tus inquilinos.",
            baseFontSize: 13,
            color: context.textSecondaryColor.withOpacity(0.6),
          ),
          const SizedBox(height: 16),

          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: images.length + 1,
            itemBuilder: (context, index) {
              if (index == images.length) {
                return _buildAddButton(
                  context: context,
                  onTap: _pickImages,
                  icon: Icons.add_a_photo_outlined,
                  text: "Añadir",
                );
              }
              final path = images[index];
              return _buildMediaCard(
                context: context,
                child: path.startsWith('http')
                    ? Image.network(path, fit: BoxFit.cover)
                    : Image.file(File(path), fit: BoxFit.cover),
                onDelete: () {
                  List<String> newList = List<String>.from(images)
                    ..removeAt(index);
                  onUpdate('images', newList);
                },
              );
            },
          ),

          const SizedBox(height: 32),
          const Divider(height: 1, thickness: 0.6),
          const SizedBox(height: 24),

          // --- SECCIÓN: VIDEO EXCLUSIVO ---
          CustomText.title(
            "Video del Inmueble",
            baseFontSize: 18,
            fontWeight: FontWeight.w900,
            color: context.primaryColor,
          ),
          const SizedBox(height: 4),
          CustomText(
            "Previsualiza el material audiovisual del catálogo o carga un recorrido en video nuevo.",
            baseFontSize: 13,
            color: context.textSecondaryColor.withOpacity(0.6),
          ),
          const SizedBox(height: 16),

          if (activeVideoPath == null || activeVideoPath.isEmpty)
            _buildAddButton(
              context: context,
              onTap: _pickVideo,
              icon: Icons.video_library_outlined,
              text: "Seleccionar Video de la Galería",
              isWide: true,
            )
          else
            Column(
              children: [
                Container(
                  height: 200,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: VideoPreviewWidget(path: activeVideoPath),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 44,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            onUpdate('video', null);
                            onUpdate('videoUrl', null);
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.redAccent,
                            side: BorderSide(
                              color: Colors.redAccent.withOpacity(0.3),
                              width: 1.2,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            size: 18,
                          ),
                          label: const Text(
                            "Quitar Video",
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: SizedBox(
                        height: 44,
                        child: ElevatedButton.icon(
                          onPressed: _pickVideo,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: context.primaryColor,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.autorenew_rounded, size: 18),
                          label: const Text(
                            "Cambiar Video",
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildAddButton({
    required BuildContext context,
    required VoidCallback onTap,
    required IconData icon,
    required String text,
    bool isWide = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: isWide ? 110 : null,
        width: isWide ? double.infinity : null,
        decoration: BoxDecoration(
          color: context.primaryColor.withOpacity(0.015),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: context.primaryColor.withOpacity(0.12),
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: context.primaryColor.withOpacity(0.8), size: 26),
            const SizedBox(height: 6),
            CustomText(
              text,
              baseFontSize: 12,
              color: context.primaryColor,
              fontWeight: FontWeight.bold,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaCard({
    required BuildContext context,
    required Widget child,
    required VoidCallback onDelete,
  }) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: child,
            ),
          ),
        ),
        Positioned(
          top: -4,
          right: -4,
          child: GestureDetector(
            onTap: onDelete,
            child: CircleAvatar(
              radius: 11,
              backgroundColor: Colors.redAccent,
              child: Icon(
                Icons.close_rounded,
                size: 13,
                color: context.surfaceColor,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
