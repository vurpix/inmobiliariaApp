// models/story_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class StoryModel {
  final String id;
  final String videoUrl;
  final String title;
  final String
  thumbnailUrl; // <--- NUEVO: Soporte para miniatura estática opcional
  final DateTime createdAt;

  StoryModel({
    required this.id,
    required this.videoUrl,
    required this.title,
    required this.thumbnailUrl, // <--- NUEVO
    required this.createdAt,
  });

  factory StoryModel.fromMap(String id, Map<String, dynamic> map) {
    return StoryModel(
      id: id,
      videoUrl: map['videoUrl'] ?? '',
      title: map['title'] ?? '',
      thumbnailUrl: map['thumbnailUrl'] ?? '', // <--- NUEVO
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'videoUrl': videoUrl,
      'title': title,
      'thumbnailUrl': thumbnailUrl, // <--- NUEVO
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
