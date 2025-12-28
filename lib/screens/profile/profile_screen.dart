import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/incident_model.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final User? user = FirebaseAuth.instance.currentUser;
  
  // Bildirim Ayarları (Varsayılan hepsi açık)
  Map<String, bool> _notificationPreferences = {
    'saglik': true,
    'guvenlik': true,
    'teknik': true,
    'cevre': true,
    'diger': true,
  };

  @override
  Widget build(BuildContext context) {
    if (user == null) return Scaffold(body: Center(child: Text("Giriş yapılmamış")));

    return Scaffold(
      appBar: AppBar(
        title: Text("Profil ve Ayarlar"),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(user!.uid).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return Center(child: Text("Kullanıcı verisi bulunamadı."));
          }

          var userData = snapshot.data!.data() as Map<String, dynamic>;
          
          // Takip edilen ID listesi
          List<String> followedIds = List<String>.from(userData['followedIncidents'] ?? []);

          // Veritabanından bildirim tercihlerini çek 
          if (userData['notificationSettings'] != null) {
            _notificationPreferences = Map<String, bool>.from(userData['notificationSettings']);
          }

          return SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. BÖLÜM: PROFİL BİLGİLERİ (Ad, Rol, Birim)
                _buildProfileCard(userData),
                
                SizedBox(height: 20),
                Text("Bildirim Ayarları", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                SizedBox(height: 10),
                // 2. BÖLÜM: BİLDİRİM AYARLARI
                Card(
                  child: Column(
                    children: [
                      _buildSwitchTile("Sağlık Bildirimleri", "saglik"),
                      Divider(height: 1),
                      _buildSwitchTile("Güvenlik Bildirimleri", "guvenlik"),
                      Divider(height: 1),
                      _buildSwitchTile("Teknik Arızalar", "teknik"),
                      Divider(height: 1),
                      _buildSwitchTile("Çevre Sorunları", "cevre"),
                    ],
                  ),
                ),

                SizedBox(height: 20),
                Text("Takip Ettiğim Bildirimler", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                SizedBox(height: 10),

                // 3. BÖLÜM: TAKİP EDİLEN BİLDİRİMLER LİSTESİ
                followedIds.isEmpty
                    ? Center(child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Text("Henüz takip ettiğiniz bir bildirim yok.", style: TextStyle(color: Colors.grey)),
                      ))
                    : _buildFollowedIncidentsList(followedIds),

                SizedBox(height: 30),
                // 4. BÖLÜM: ÇIKIŞ YAP

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      padding: EdgeInsets.symmetric(vertical: 15),
                      foregroundColor: Colors.white,
                    ),
                    icon: Icon(Icons.exit_to_app),
                    label: Text("Güvenli Çıkış Yap", style: TextStyle(fontSize: 16)),
                    onPressed: _logout,
                  ),
                ),
                SizedBox(height: 30),
              ],
            ),
          );
        },
      ),
    );
  }

  // YARDIMCI BİLEŞENLER 

  // Profil Kartı Tasarımı
  Widget _buildProfileCard(Map<String, dynamic> data) {
    String role = data['role'] == 'admin' ? 'Yönetici' : 'Öğrenci / Personel';
    Color roleColor = data['role'] == 'admin' ? Colors.red : Colors.blue;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 35,
              backgroundColor: roleColor.withOpacity(0.2),
              child: Text(
                (data['name'] ?? 'U')[0].toUpperCase(),
                style: TextStyle(fontSize: 30, color: roleColor, fontWeight: FontWeight.bold),
              ),
            ),
            SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(data['name'] ?? 'İsimsiz', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  Text(user?.email ?? '', style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: roleColor, borderRadius: BorderRadius.circular(10)),
                        child: Text(role, style: TextStyle(color: Colors.white, fontSize: 12)),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          data['department'] ?? 'Birim Yok',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Bildirim Switch Tasarımı
  Widget _buildSwitchTile(String title, String key) {
    return SwitchListTile(
      title: Text(title),
      value: _notificationPreferences[key] ?? true,
      activeColor: Colors.blue,
      onChanged: (val) {
        setState(() {
          _notificationPreferences[key] = val;
        });
        // Ayarı Veritabanına Kaydet
        FirebaseFirestore.instance.collection('users').doc(user!.uid).update({
          'notificationSettings': _notificationPreferences
        });
      },
    );
  }

  // Takip Edilenler Listesi
  Widget _buildFollowedIncidentsList(List<String> ids) {
    
    if (ids.isEmpty) return SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('incidents').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return Center(child: CircularProgressIndicator());

        var myIncidents = snapshot.data!.docs.where((doc) => ids.contains(doc.id)).toList();

        if (myIncidents.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text("Takip ettiğiniz bildirimler silinmiş olabilir."),
          );
        }

        return ListView.builder(
          shrinkWrap: true, 
          physics: NeverScrollableScrollPhysics(),
          itemCount: myIncidents.length,
          itemBuilder: (context, index) {
            var data = myIncidents[index].data() as Map<String, dynamic>;
            var incident = Incident.fromMap(data, myIncidents[index].id);

            return Card(
              margin: EdgeInsets.symmetric(vertical: 5),
              child: ListTile(
                leading: Icon(Icons.bookmark, color: Colors.blueAccent),
                title: Text(incident.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(incident.status, style: TextStyle(
                  color: incident.status == 'Cozuldu' ? Colors.green : Colors.orange
                )),
                trailing: Icon(Icons.arrow_forward_ios, size: 14),
                onTap: () {
                  Navigator.pushNamed(context, '/detail', arguments: incident);
                },
              ),
            );
          },
        );
      },
    );
  }

  // Çıkış Fonksiyonu
  void _logout() async {
    await FirebaseAuth.instance.signOut();
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
  }
}