// ui/components/auth_ux/components/review_tile.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:inmobiliariaapp/utils/format_extensions.dart';

class ReviewTile extends StatelessWidget {
  final Map<String, dynamic> reviewData;

  const ReviewTile({super.key, required this.reviewData});

  @override
  Widget build(BuildContext context) {
    final int rating = (reviewData['rating'] ?? 0).toInt();
    final String fromName = reviewData['fromName'] ?? 'Usuario Anónimo';
    final String comment = reviewData['comment'] ?? '';
    final List<dynamic> tags = reviewData['predefinedAnswers'] ?? [];

    // Formateo seguro de la fecha de Firestore
    String formattedDate = '';
    if (reviewData['createdAt'] is Timestamp) {
      final DateTime date = (reviewData['createdAt'] as Timestamp).toDate();
      formattedDate = date.toFullDateTime();
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    fromName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                Row(
                  children: [
                    const Icon(
                      Icons.star_rounded,
                      color: Colors.amber,
                      size: 18,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      "$rating.0",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (formattedDate.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  formattedDate,
                  style: TextStyle(color: Colors.grey[500], fontSize: 11),
                ),
              ),
            if (comment.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                '"$comment"',
                style: const TextStyle(
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                  color: Colors.black87,
                ),
              ),
            ],
            if (tags.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: tags.map((tag) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A237E).withOpacity(0.05),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      tag.toString(),
                      style: const TextStyle(
                        color: Color(0xFF1A237E),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
