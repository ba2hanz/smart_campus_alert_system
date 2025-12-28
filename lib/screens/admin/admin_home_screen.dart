import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:googleapis_auth/auth_io.dart'; // google api yetkilendirme için 
import 'package:smart_campus_alert_system/models/incident_model.dart'; 

class AdminHomeScreen extends StatefulWidget {
  @override
  _AdminHomeScreenState createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  String _filter = "Tümü";  // hangi duruma göre filtreleme yapılacak

  //BİLDİRİM GÖNDERME 
  // topic parametresi varsayılan olarak 'all' (herkes) alır.
  // Ama durum güncellemesi yaparken buraya 'incident_ID' göndereceğiz.
  Future<void> _sendPushNotification(String title, String body, {String topic = 'all'}) async {
    try {
      // Service Account dosyasını assets klasöründen oku
      final jsonString = await rootBundle.loadString('assets/service_account.json');
      final serviceAccount = ServiceAccountCredentials.fromJson(jsonDecode(jsonString));

      // Google'dan yetki iste
      final scopes = ['https://www.googleapis.com/auth/firebase.messaging'];
      final client = await clientViaServiceAccount(serviceAccount, scopes);

      final projectId = 'smartcampusalertsystem';

      // HTTP v1 API'ye İstek At
      final response = await client.post(
        Uri.parse('https://fcm.googleapis.com/v1/projects/$projectId/messages:send'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'message': {
            'topic': topic, 
            'notification': {
              'title': title,
              'body': body,
            },
            'data': {
              'click_action': 'FLUTTER_NOTIFICATION_CLICK',
              'status': 'urgent' 
            }
          }
        }),
      );

      if (response.statusCode == 200) {
        // Sadece admin manuel gönderdiyse ekranda bilgi ver, otomatikse sessiz kalabilir
        if (topic == 'all') {
           ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Duyuru başarıyla gönderildi!")));
        }
      } else {
        print("Hata Detayı: ${response.body}");
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Gönderilemedi. Hata: ${response.statusCode}")));
      }
      
      client.close();

    } catch (e) {
      print("Bildirim Hatası: $e");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Hata: JSON dosyası okunamadı.")));
    }
  }

  // ACİL DURUM DUYURUSU admin sağ üstteki megafon ikonuna bastığında açılan pencer
  void _showNotificationDialog() {
    TextEditingController titleController = TextEditingController();
    TextEditingController bodyController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [Icon(Icons.campaign, color: Colors.red), SizedBox(width: 10), Text("Acil Duyuru")],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Bu mesaj tüm kampüse gönderilecektir."),
            SizedBox(height: 10),
            TextField(controller: titleController, decoration: InputDecoration(hintText: "Başlık", border: OutlineInputBorder())),
            SizedBox(height: 10),
            TextField(controller: bodyController, decoration: InputDecoration(hintText: "Mesaj", border: OutlineInputBorder()), maxLines: 2),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text("İptal")),
          ElevatedButton( // butona basıldığında _sendPushNotification çağrılır ve topic 'all' olarak kalır herkese bildirim gider
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () {
              if (titleController.text.isNotEmpty && bodyController.text.isNotEmpty) {
                // varsayılan olarak 'all' (herkes) gidecek
                _sendPushNotification(titleController.text, bodyController.text);
                Navigator.pop(context);
              }
            },
            child: Text("GÖNDER"),
          )
        ],
      ),
    );
  }
  
  // OTOMATİK BİLDİRİM (Durum Değişince)
  // incidentTitle parametresi eklendi ki mesajda olay adı yazsın
  // admin olayın durumunu güncellemek istediğinde bu metot çağrılır
  void _updateStatus(String docId, String currentStatus, String incidentTitle) {
    showDialog(
      context: context,
      builder: (context) {
        String selectedStatus = currentStatus;
        return AlertDialog(
          title: Text("Durumu Güncelle"),
          content: DropdownButtonFormField<String>( //açılır menü oluşturma açık,inceleniyor çözüldü
            value: ["Açık", "İnceleniyor", "Çözüldü"].contains(currentStatus) ? currentStatus : "İnceleniyor",
            items: ["İnceleniyor", "Açık", "Çözüldü"].map((status) {
              return DropdownMenuItem(value: status, child: Text(status));
            }).toList(),
            onChanged: (val) {
              selectedStatus = val!;
            },
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text("İptal")),
            ElevatedButton(
              onPressed: () async {
                // Veritabanını Güncelle
                await FirebaseFirestore.instance.collection('incidents').doc(docId).update({ //
                  'status': selectedStatus
                });

                // OTOMATİK BİLDİRİM TETİKLE
                // Sadece bu olayın ID'sine abone olanlara gider
                await _sendPushNotification(   // burda herkese gitmiyo sadece bu olayın takipçilerine gidiyo
                  "Durum Güncellemesi", 
                  "'$incidentTitle' olayının durumu '$selectedStatus' olarak değiştirildi.",
                  topic: "incident_$docId" 
                );

                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Durum güncellendi ve takipçilere bildirildi!")));
              },
              child: Text("Kaydet"),
            )
          ],
        );
      },
    );
  }
//olay silme 
  void _deleteIncident(String docId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Silmek İstediğine Emin misin?"),
        content: Text("Bu işlem geri alınamaz."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text("İptal")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              await FirebaseFirestore.instance.collection('incidents').doc(docId).delete();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Kayıt Silindi.")));
            },
            child: Text("SİL"),
          )
        ],
      ),
    );
  }
// uı kısmı
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(  // üst bar
        title: Text("Yönetici Paneli"),
        backgroundColor: Colors.redAccent,
        leading: IconButton(
          icon: Icon(Icons.campaign), 
          tooltip: "Duyuru Yap",
          onPressed: _showNotificationDialog, // ACİL DURUM DUYURUSU
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.remove_red_eye),  // normal kullanıcı (öğrenci) görünümüne geçme butonu
            tooltip: "Öğrenci Görünümüne Geç",
            onPressed: () {
              Navigator.pushNamed(context, '/home'); 
            },
          ),
          IconButton(
            icon: Icon(Icons.map), // harita butonu
            tooltip: "Haritaya Git", 
            onPressed: () => Navigator.pushNamed(context, '/map')
          ),
          IconButton(
            icon: Icon(Icons.person), // profil butonu
            tooltip: "Profil",
            onPressed: () => Navigator.pushNamed(context, '/profile'),
          ),
        ],
      ),
      body: Column(
        children: [
          // FİLTRE MENÜSÜ
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.all(10),
            child: Row(
              children: ["Tümü", "İnceleniyor", "Açık", "Çözüldü"].map((status) {  //burası filtre seçeneklerinin listesi
                return Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: Text(
                      status == "İnceleniyor" ? "Onay Bekleyenler" : status,
                      style: TextStyle(
                        color: _filter == status ? Colors.white : Colors.black,
                        fontWeight: FontWeight.bold
                      ),
                    ),
                    selected: _filter == status,
                    selectedColor: Colors.redAccent,
                    onSelected: (val) {
                      setState(() {
                        _filter = status;
                      });
                    },
                  ),
                );
              }).toList(),
            ),
          ),
        
          Expanded(  // olayların listelendiği kısım
            child: StreamBuilder<QuerySnapshot>(  //StreamBuilder kullanarak Firestore'dan gerçek zamanlı veri çekme
              stream: FirebaseFirestore.instance.collection('incidents').orderBy('createdAt', descending: true).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return Center(child: CircularProgressIndicator());
                
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                   return Center(child: Text("Hiç bildirim yok."));
                }

                var docs = snapshot.data!.docs.where((doc) {  //veritabanından gelen tüm veriler, kullanıcının seçtiği filtreye göre elenir.
                  var data = doc.data() as Map<String, dynamic>;
                  if (_filter == "Tümü") return true;
                  return data['status'] == _filter;
                }).toList();

                if (docs.isEmpty) return Center(child: Text("Bu kategoride bildirim yok."));

                return ListView.builder(  // olayları listeleme
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    var data = docs[index].data() as Map<String, dynamic>;
                    var incident = Incident.fromMap(data, docs[index].id);

                    Color statusColor = Colors.grey;   //bıton durumuna göre renk belirleme
                    if (incident.status == 'İnceleniyor') statusColor = Colors.orange;
                    if (incident.status == 'Açık') statusColor = Colors.red;
                    if (incident.status == 'Çözüldü') statusColor = Colors.green;

                    return Card(   //icon ve butonların gösterildiği kısım
                      elevation: 3,
                      margin: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: statusColor,
                          child: Icon(
                            incident.status == 'Çözüldü' ? Icons.check : Icons.warning_amber_rounded,
                            color: Colors.white
                          ),
                        ),
                        title: Text(incident.title, style: TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Tür: ${incident.type}"),
                            Text("Durum: ${incident.status}", style: TextStyle(color: statusColor, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(Icons.edit, color: Colors.blue),
                              // updateStatus'a başlığı da gönderiyoruz
                              onPressed: () => _updateStatus(incident.id, incident.status, incident.title),
                            ),
                            IconButton(
                              icon: Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deleteIncident(incident.id),
                            ),
                          ],
                        ),
                        onTap: () {
                           Navigator.pushNamed(context, '/detail', arguments: incident);
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}