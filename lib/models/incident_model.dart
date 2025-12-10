import 'package:cloud_firestore/cloud_firestore.dart';

class Incident {
  final String id;
  final String title;
  final String description;
  final String type;
  String status;
  final double latitude;
  final double longitude;
  final String? imageUrl;
  final DateTime createdAt;
  final String userId;

  Incident({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    this.status = 'Acik',
    required this.latitude,
    required this.longitude,
    this.imageUrl,
    required this.createdAt,
    required this.userId,
  });

  factory Incident.fromMap(Map<String, dynamic> map, String docId) {
    return Incident(
      id: docId,
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      type: map['type'] ?? 'Genel',
      status: map['status'] ?? 'Acik',
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
      imageUrl: map['imageUrl'],
      // Firestore Timestamp'ini DateTime'a çevirme:
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      userId: map['userId'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'type': type,
      'status': status,
      'latitude': latitude,
      'longitude': longitude,
      'imageUrl': imageUrl,
      'createdAt': Timestamp.fromDate(createdAt),
      'userId': userId,
    };
  }
}