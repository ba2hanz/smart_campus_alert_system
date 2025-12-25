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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Incident) {
      incident = args;
      if (uid != null) _checkFollowStatus();
    }
  }

  void _checkFollowStatus() async {
    var doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    if (doc.exists) {
      List followed = doc.get('followedIncidents') ?? [];
      if (mounted) {
        setState(() {
          _isFollowing = followed.contains(incident.id);
        });
      }
    }
  }

  void _toggleFollow() async {
    if (uid == null) return;
    final topic = 'incident_${incident.id}';
    final messaging = FirebaseMessaging.instance;
    
    if (_isFollowing) {
      // Takibi kaldır: Firestore'dan çıkar ve FCM topic'inden unsubscribe ol
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'followedIncidents': FieldValue.arrayRemove([incident.id])
      });
      await messaging.unsubscribeFromTopic(topic);
    } else {
      // Takip et: Firestore'a ekle ve FCM topic'ine subscribe ol
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'followedIncidents': FieldValue.arrayUnion([incident.id])
      });
      await messaging.subscribeToTopic(topic);
    }
    setState(() => _isFollowing = !_isFollowing);
  }

  @override
  Widget build(BuildContext context) {
    // Eğer veri gelmediyse boş dön
    if (uid == null) return Scaffold(body: Center(child: Text("Hata: Giriş yapılmadı")));

    return Scaffold(
      appBar: AppBar(title: Text("Detaylar")),
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
            SizedBox(height: 20),
            Text(incident.description, style: TextStyle(fontSize: 16)),
            Spacer(),
            
            SizedBox(
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