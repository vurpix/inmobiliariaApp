// ui/pages/admin/admin_stories_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:inmobiliariaapp/models/story_model.dart';
import 'package:inmobiliariaapp/ui/components/global/custom_text.dart';
import 'package:inmobiliariaapp/ui/components/tenant_flow/stories_viewer_page.dart';
import 'package:inmobiliariaapp/utils/themes.dart';
import 'package:video_compress/video_compress.dart';

class AdminStoriesScreen extends StatefulWidget {
  const AdminStoriesScreen({super.key});

  @override
  State<AdminStoriesScreen> createState() => _AdminStoriesScreenState();
}

class _AdminStoriesScreenState extends State<AdminStoriesScreen> {
  final TextEditingController _titleController = TextEditingController();
  File? _selectedVideo;
  bool _isUploading = false;
  double _uploadProgress = 0.0;

  List<StoryModel> _uploadedStories = [];

  Future<void> _pickVideo() async {
    FilePickerResult? result = await FilePicker.pickFiles(type: FileType.video);

    if (result != null && result.files.single.path != null) {
      setState(() {
        _selectedVideo = File(result.files.single.path!);
      });
    }
  }

  Future<void> _uploadStory() async {
    if (_selectedVideo == null) return;

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
    });

    try {
      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      String thumbnailUrl = '';

      // 1. EXTRAER EL PRIMER FRAME REAL DEL VIDEO (Rápido, Nativo y con Tipo File)
      try {
        // Obtenemos directamente el archivo físico (.jpg) generado en la caché
        final File thumbFile = await VideoCompress.getFileThumbnail(
          _selectedVideo!.path,
          quality:
              60, // Peso pluma y excelente velocidad de descarga para el cliente
          position: 0, // Extrae justo el primer milisegundo
        );

        final String thumbFileName = '$timestamp.jpg';
        final Reference thumbStorageRef = FirebaseStorage.instance.ref().child(
          'stories_thumbnails/$thumbFileName',
        );

        // Subimos el archivo de la miniatura a Firebase Storage
        final TaskSnapshot thumbSnapshot = await thumbStorageRef.putFile(
          thumbFile,
        );
        thumbnailUrl = await thumbSnapshot.ref.getDownloadURL();
      } catch (thumbError, stackTrace) {
        debugPrint("🚨 Error exacto extrayendo miniatura real: $thumbError");
        debugPrint("📌 Rastro del fallo: $stackTrace");
        thumbnailUrl = '';
      }

      // 2. SUBIR EL VIDEO PRINCIPAL A FIREBASE STORAGE
      final String videoFileName = '$timestamp.mp4';
      final Reference videoStorageRef = FirebaseStorage.instance.ref().child(
        'stories/$videoFileName',
      );
      final UploadTask videoUploadTask = videoStorageRef.putFile(
        _selectedVideo!,
      );

      videoUploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        setState(() {
          _uploadProgress = snapshot.bytesTransferred / snapshot.totalBytes;
        });
      });

      final TaskSnapshot videoSnapshot = await videoUploadTask;
      final String videoUrl = await videoSnapshot.ref.getDownloadURL();

      // 3. GUARDAR AMBAS URLS EN FIRESTORE
      await FirebaseFirestore.instance.collection('stories').add({
        'videoUrl': videoUrl,
        'title': _titleController.text.trim(),
        'thumbnailUrl':
            thumbnailUrl, // Guarda la URL de la imagen o vacío si falló el procesamiento
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Limpieza de estados e interfaz de usuario
      _titleController.clear();
      setState(() => _selectedVideo = null);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("¡Historia publicada con éxito con su miniatura!"),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error general en el proceso: $e"),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      setState(() => _isUploading = false);
    }
  }

  // --- ALGORITMO INTEGRADO DE ELIMINACIÓN DE HISTORIAS ---
  Future<void> _deleteStory(StoryModel story) async {
    showDialog(
      context: context,
      builder: (context) => _buildDeleteDialog(
        story,
      ), // Separado en un método para limpiar el build
    );
  }

  Widget _buildDeleteDialog(StoryModel story) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.red),
          SizedBox(width: 8),
          Text("¿Eliminar video?"),
        ],
      ),
      content: const CustomText(
        "Esta acción eliminará el video informativo de la base de datos de forma permanente.",
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("CANCELAR"),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            elevation: 0,
          ),
          onPressed: () async {
            // Guardamos el contexto antes de hacer operaciones 'await' asíncronas
            final scaffoldMessenger = ScaffoldMessenger.of(context);
            Navigator.pop(context);

            try {
              // 1. PRIMERO STORAGE: Intentar remover el archivo pesado de Firebase Storage de forma aislada
              if (story.videoUrl.isNotEmpty &&
                  story.videoUrl.contains('firebase')) {
                try {
                  await FirebaseStorage.instance
                      .refFromURL(story.videoUrl)
                      .delete();
                } catch (storageError) {
                  // Si el archivo ya no existía en Storage, imprimimos el aviso pero no bloqueamos
                  // la eliminación del registro de la base de datos.
                  debugPrint(
                    "Aviso Storage (puede que el archivo ya no exista): $storageError",
                  );
                }
              }

              // 2. SEGUNDO FIRESTORE: Ahora que el Storage terminó, borramos el documento de texto
              await FirebaseFirestore.instance
                  .collection('stories')
                  .doc(story.id)
                  .delete();

              scaffoldMessenger.showSnackBar(
                const SnackBar(
                  content: Text("Video eliminado del sistema"),
                  backgroundColor: Colors.black,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            } catch (e) {
              scaffoldMessenger.showSnackBar(
                SnackBar(
                  content: Text("Error al eliminar de la base de datos: $e"),
                  backgroundColor: Colors.red,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          },
          child: const Text("ELIMINAR"),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // OYENTE EN SEGUNDO PLANO EN TIEMPO REAL
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('stories')
              .orderBy('createdAt', descending: false)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              _uploadedStories = snapshot.data!.docs.map((doc) {
                return StoryModel.fromMap(
                  doc.id,
                  doc.data() as Map<String, dynamic>,
                );
              }).toList();
            }
            return const SizedBox.shrink();
          },
        ),

        SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // --- INTEGRACIÓN: VISTA PREVIA ADMINISTRATIVA EN VIVO ---
                const CustomText(
                  "Videos Activos en la App",
                  fontWeight: FontWeight.bold,
                  baseFontSize: 14,
                ),
                const SizedBox(height: 8),
                _buildStoriesSection(),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 16),

                const CustomText(
                  "Subir Video Informativo",
                  fontWeight: FontWeight.bold,
                  baseFontSize: 16,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: "Título de la Historia (Opcional)",
                    hintText: "Ej: ¿Cómo aplicar a un estudio?",
                  ),
                ),
                const SizedBox(height: 20),

                InkWell(
                  onTap: _isUploading ? null : _pickVideo,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: double.infinity,
                    height: 180,
                    decoration: BoxDecoration(
                      color: context.textColor.withOpacity(0.02),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _selectedVideo == null
                            ? context.textColor.withOpacity(0.1)
                            : Colors.green.withOpacity(0.4),
                        style: BorderStyle.solid,
                      ),
                    ),
                    child: _selectedVideo == null
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.video_library_rounded,
                                size: 40,
                                color: context.primaryColor,
                              ),
                              const SizedBox(height: 8),
                              const CustomText(
                                "Seleccionar Video desde Galería",
                                baseFontSize: 12,
                              ),
                            ],
                          )
                        : Stack(
                            alignment: Alignment.center,
                            children: [
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.check_circle_rounded,
                                    size: 36,
                                    color: Colors.green,
                                  ),
                                  const SizedBox(height: 6),
                                  CustomText(
                                    "Video listo en memoria",
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green[700],
                                    baseFontSize: 13,
                                  ),
                                  CustomText(
                                    "Mira la secuencia completa antes de publicar",
                                    baseFontSize: 10,
                                    color: context.textSecondaryColor
                                        .withOpacity(0.5),
                                  ),
                                ],
                              ),
                              Positioned(
                                child: CircleAvatar(
                                  radius: 26,
                                  backgroundColor: context.primaryColor
                                      .withOpacity(0.9),
                                  child: IconButton(
                                    icon: const Icon(
                                      Icons.play_arrow_rounded,
                                      color: Colors.white,
                                      size: 28,
                                    ),
                                    onPressed: () {
                                      final List<StoryModel>
                                      previewCarouselList = List.from(
                                        _uploadedStories,
                                      );

                                      final mockNewStory = StoryModel(
                                        id: 'temp_local_preview',
                                        title:
                                            _titleController.text
                                                .trim()
                                                .isNotEmpty
                                            ? '${_titleController.text.trim()} (Nuevo)'
                                            : 'Nuevo Video Informativo',
                                        videoUrl: _selectedVideo!.path,
                                        thumbnailUrl: '',
                                        createdAt: DateTime.now(),
                                      );

                                      previewCarouselList.add(mockNewStory);
                                      final int targetIndex =
                                          previewCarouselList.length - 1;

                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => StoriesViewerPage(
                                            stories: previewCarouselList,
                                            initialIndex: targetIndex,
                                            isSingleMode: false,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 10,
                                right: 10,
                                child: IconButton(
                                  icon: const Icon(
                                    Icons.cancel_rounded,
                                    color: Colors.redAccent,
                                    size: 22,
                                  ),
                                  onPressed: () {
                                    setState(() => _selectedVideo = null);
                                  },
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 24),
                if (_isUploading) ...[
                  LinearProgressIndicator(
                    value: _uploadProgress,
                    backgroundColor: Colors.grey[200],
                    color: context.primaryColor,
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: CustomText(
                      "Subiendo: ${(_uploadProgress * 100).toStringAsFixed(0)}%",
                      baseFontSize: 12,
                    ),
                  ),
                ] else
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _selectedVideo != null ? _uploadStory : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: context.primaryColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: const Text("PUBLICAR HISTORIA"),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // --- LISTA COMPACTA DE GESTIÓN DE HISTORIAS CON BOTÓN DE BORRADO ---
  Widget _buildStoriesSection() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('stories')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const CustomText(
            "No hay videos informativos publicados.",
            baseFontSize: 12,
            color: Colors.grey,
          );
        }

        final List<StoryModel> storiesList = snapshot.data!.docs.map((doc) {
          return StoryModel.fromMap(doc.id, doc.data() as Map<String, dynamic>);
        }).toList();

        return Container(
          height: 110,
          width: double.infinity,
          margin: const EdgeInsets.only(top: 4),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: storiesList.length,
            itemBuilder: (context, index) {
              final story = storiesList[index];
              final String? thumbnailUrl = story.thumbnailUrl.isNotEmpty
                  ? story.thumbnailUrl
                  : null;

              return Padding(
                padding: const EdgeInsets.only(right: 16.0),
                child: Column(
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // Burbuja de reproducción interactiva
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => StoriesViewerPage(
                                  stories: [story],
                                  initialIndex: 0,
                                  isSingleMode: true,
                                ),
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.all(2.5),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: context.primaryColor.withOpacity(0.4),
                                width: 2,
                              ),
                            ),
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: context.surfaceColor,
                                shape: BoxShape.circle,
                              ),
                              child: CircleAvatar(
                                radius: 26,
                                backgroundColor: context.primaryColor
                                    .withOpacity(0.08),
                                backgroundImage: thumbnailUrl != null
                                    ? NetworkImage(thumbnailUrl)
                                    : null,
                                child: Icon(
                                  thumbnailUrl != null
                                      ? Icons.play_arrow_rounded
                                      : Icons.play_circle_fill_rounded,
                                  color: thumbnailUrl != null
                                      ? Colors.white
                                      : context.primaryColor,
                                  size: 26,
                                ),
                              ),
                            ),
                          ),
                        ),
                        // --- BOTÓN BADGE INCORPORADO PARA BORRAR LA HISTORIA DE FIRESTORE ---
                        Positioned(
                          top: -2,
                          right: -2,
                          child: GestureDetector(
                            onTap: () => _deleteStory(story),
                            child: const CircleAvatar(
                              radius: 10,
                              backgroundColor: Colors.red,
                              child: Icon(
                                Icons.close_rounded,
                                color: Colors.white,
                                size: 12,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      width: 64,
                      child: CustomText(
                        story.title.isNotEmpty ? story.title : "Info",
                        baseFontSize: 10,
                        fontWeight: FontWeight.w600,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}
