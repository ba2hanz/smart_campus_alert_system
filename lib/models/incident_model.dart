import 'package:cloud_firestore/cloud_firestore.dart';

// Herkesin görebileceği durumlar. 'İnceleniyor' (onay bekleyen) bildirimleri
// yalnızca adminler ve bildirimi yapan görebilir — bunu Firestore kuralları
// sağlıyor (firestore.rules). Kurallar filtre olmadığı için admin olmayanların
// sorguları durumu bu listeyle süzmek ZORUNDA, yoksa sorgunun tamamı reddedilir.
// firestore.rules → publicStatuses() ile aynı kalmalı. 'Acik' / 'Cozuldu' eski kayıtlardaki yazımlar.
const List<String> publicIncidentStatuses = ['Açık', 'Acik', 'Çözüldü', 'Cozuldu'];

// olayın modeli
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
  // olayın hangi bilgilerini tutacağını tanımlıyoruz
  //required zorunlu alanlar demke
  Incident({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    this.status = 'İnceleniyor',  // durum belirtilmemişse varsayılan değer
    required this.latitude,
    required this.longitude,
    this.imageUrl,
    required this.createdAt,
    required this.userId,
  });
  // firestore dan gelen veriyi modele çeviriyoruz

  factory Incident.fromMap(Map<String, dynamic> map, String docId) {
    DateTime created;

    final rawCreatedAt = map['createdAt'];
    if (rawCreatedAt is Timestamp) {
      created = rawCreatedAt.toDate();
    } else if (rawCreatedAt is DateTime) {
      created = rawCreatedAt;
    } else {
      // createdAt yoksa çökmemek için çok eski bir tarih ver
      created = DateTime.fromMillisecondsSinceEpoch(0);
    }

    return Incident(
      id: docId,
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      type: map['type'] ?? 'Genel',
      status: map['status'] ?? 'İnceleniyor',
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
      imageUrl: map['imageUrl'],
      // Firestore Timestamp'ini DateTime'a çevirme:
      createdAt: created,
      userId: map['userId'] ?? '',
    );
  }
  // veritabanına yeni bir kayıt eklerken veya güncellerken bu metodu çağıracağız
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'type': type,
      'status': status,
      'latitude': latitude,
      'longitude': longitude,
      'imageUrl': imageUrl,
      // Burayı CreateIncident'de serverTimestamp ile override ediyoruz
      'createdAt': Timestamp.fromDate(createdAt),
      'userId': userId,
    };
  }
}
