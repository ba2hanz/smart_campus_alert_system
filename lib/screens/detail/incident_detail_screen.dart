import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
//import '../../models/incident_model.dart';
import 'package:smart_campus_alert_system/models/incident_model.dart';

class IncidentDetailScreen extends StatefulWidget {
  @override
  _IncidentDetailScreenState createState() => _IncidentDetailScreenState();
}

class _IncidentDetailScreenState extends State<IncidentDetailScreen> {
  bool _isFollowing = false;
  late Incident incident;
  String? uid = FirebaseAuth.instance.currentUser?.uid;

  bool _incidentLoaded = false; //  args geldi mi kontrolü (late hatası olmasın diye)

  //  tarih formatlama fonksiyonu
  String _formatDateTime(DateTime dt) {
    if (dt.millisecondsSinceEpoch == 0) return "-";
    String two(int n) => n.toString().padLeft(2, '0');
    return "${two(dt.day)}.${two(dt.month)}.${dt.year} ${two(dt.hour)}:${two(dt.minute)}";
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Incident) {
      incident = args;
      _incidentLoaded = true; 
      if (uid != null) _checkFollowStatus();  // kullanıcının bu olayı takip edip etmediğini kontrol
    }
  }

  void _checkFollowStatus() async {
    var doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();  // kullanıcının veritabanındaki kaydını al
    if (doc.exists) {
      List followed = doc.get('followedIncidents') ?? [];  // takip edilen olaylar listesi
      if (mounted) {
        setState(() {
          _isFollowing = followed.contains(incident.id);
        });
      }
    }
  }

  // hem veritabanını günceller hem bildirim ayarlarını yapar
  void _toggleFollow() async {
    if (uid == null) return;
    final topic = 'incident_${incident.id}';
    final messaging = FirebaseMessaging.instance;

    if (_isFollowing) {
      // Takibi kaldır: veritabanındaki listeden çkar
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'followedIncidents': FieldValue.arrayRemove([incident.id])
      });  // bildirim kanalından çık
      await messaging.unsubscribeFromTopic(topic);
    } else {
      // Takip et: veritabanındaki listeye ekle
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'followedIncidents': FieldValue.arrayUnion([incident.id])
      });
      await messaging.subscribeToTopic(topic);
    }
    setState(() => _isFollowing = !_isFollowing); //butonun durumunu tersne çevir
  }

  @override
  Widget build(BuildContext context) {
    // Eğer veri gelmediyse boş dön
    if (uid == null) return Scaffold(body: Center(child: Text("Hata: Giriş yapılmadı")));

    if (!_incidentLoaded) {
      return Scaffold(
        appBar: AppBar(title: Text("Detaylar")), //ekranın üstündeki bardaki detaylar yazısı
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text("Detaylar")), //ekranın üstündeki bardaki detaylar yazısı
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (incident.imageUrl != null && incident.imageUrl!.isNotEmpty)
              Image.network(incident.imageUrl!, height: 200, width: double.infinity, fit: BoxFit.cover),
            SizedBox(height: 10),

            Text(incident.title, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            Text(incident.type, style: TextStyle(color: Colors.grey)),

            // olayın tarihi
            SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.schedule, size: 18, color: Colors.grey),
                SizedBox(width: 6),
                Text(
                  "Tarih: ${_formatDateTime(incident.createdAt)}",
                  style: TextStyle(color: Colors.grey[700]),
                ),
              ],
            ),

            SizedBox(height: 20),
            Text(incident.description, style: TextStyle(fontSize: 16)),
            Spacer(),

            SizedBox(  //metin gösterme işi özelliklrei vs
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                icon: Icon(_isFollowing ? Icons.check : Icons.star_border),
                label: Text(_isFollowing ? "TAKİP EDİLİYOR" : "TAKİP ET"),
                style: ElevatedButton.styleFrom(backgroundColor: _isFollowing ? Colors.green : Colors.blue),
                onPressed: _toggleFollow,
              ),
            )
          ],
        ),
      ),
    );
  }
}
