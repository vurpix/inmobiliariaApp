import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:inmobiliariaapp/models/property_model.dart';

class PropertyRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // 1. Subir archivos (Imágenes o PDFs) y retornar URLs
  Future<List<String>> uploadFiles(
    List<String> localPaths,
    String folder,
  ) async {
    List<String> downloadUrls = [];
    for (String path in localPaths) {
      // IMPORTANTE: Si por error llega una URL de red aquí, la ignoramos
      // (aunque el Bloc ya debería filtrarlas)
      if (path.startsWith('http')) {
        downloadUrls.add(path);
        continue;
      }

      File file = File(path);
      String fileName =
          "${DateTime.now().millisecondsSinceEpoch}_${path.split('/').last}";
      Reference ref = _storage.ref().child(folder).child(fileName);

      UploadTask uploadTask = ref.putFile(file);
      TaskSnapshot snapshot = await uploadTask;
      String url = await snapshot.ref.getDownloadURL();
      downloadUrls.add(url);
    }
    return downloadUrls;
  }

  Future<bool> processPayment({
    required double amount,
    required String userId,
  }) async {
    try {
      await Future.delayed(const Duration(seconds: 2));
      return true;
    } catch (e) {
      return false;
    }
  }

  // 2. Guardar o Actualizar la propiedad en Firestore
  Future<void> saveProperty(PropertyModel property) async {
    try {
      if (property.id == null || property.id!.isEmpty) {
        // --- CASO NUEVA PROPIEDAD ---
        // Generamos un nuevo documento y obtenemos su ID automáticamente
        await _firestore.collection('properties').add(property.toMap());
      } else {
        // --- CASO EDICIÓN ---
        // Usamos .doc(id).set con merge: true para sobreescribir solo lo necesario
        await _firestore
            .collection('properties')
            .doc(property.id)
            .set(property.toMap(), SetOptions(merge: true));
      }
    } catch (e) {
      throw Exception("Error al persistir en Firestore: $e");
    }
  }
}
