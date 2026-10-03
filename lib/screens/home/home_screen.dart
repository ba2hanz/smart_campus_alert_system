import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/incident_model.dart';
//hem userr(öğrenci) hem admin için ana ekran

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _filter = "Tümü";  //hangi olayların gösterileceği filtresi
  String _searchQuery = "";  //arama çubuğuna yazılan metin
  List<String> _followedIds = []; // kullanıcının takip ettiği olay ID'leri
  bool _isAdmin = false; // Admin mi kontrolü için

  @override
  void initState() {
    super.initState();
    _getFollowedIncidents(); // Takip edilen olayları yükle veritabanından
    _checkIfAdmin(); // Rol kontrolü
  }

  // KULLANICI ROLÜ KONTROLÜ
  // Kullanıcı Admin mi diye bakar
  void _checkIfAdmin() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      var doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists && doc.data() != null) {
        if (doc.data()!['role'] == 'admin') {
          if (mounted) {
            setState(() {
              _isAdmin = true;
            });
          }
        }
      }
    }
  }

  // TAKİP EDİLEN OLAYLARI YÜKLE
  // Kullanıcının takip ettiği olay ID'lerini Firestore'dan çeker
  void _getFollowedIncidents() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      var doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>?;
        setState(() {
          _followedIds = List<String>.from(data?['followedIncidents'] ?? []);
        });
      }
    }
  }

  // ana ekran yapısındaki butonlar arama filtreleme listeleme gibi işlemler
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Kampüs Bildirimleri"),
        actions: [
          // HARİTA BUTONU
          IconButton(
            icon: Icon(Icons.map),
            tooltip: "Haritada Gör",
            onPressed: () {
              Navigator.pushNamed(context, '/map');
            },
          ),
          // PROFİL BUTONU
          IconButton(
            icon: Icon(Icons.person),
            tooltip: "Profil ve Ayarlar",
            onPressed: () {
              Navigator.pushNamed(context, '/profile');
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // ARAMA
          Padding(
            padding: EdgeInsets.all(8.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: "Bildirim arama...",
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                contentPadding: EdgeInsets.symmetric(vertical: 0, horizontal: 10),
              ),
              onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
            ),
          ),

          // FİLTRELER
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: ["Tümü", "Acik", "Takip"].map((f) => Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: ChoiceChip(
                label: Text(f == "Acik" ? "Sadece Açık" : (f == "Takip" ? "Takip Ettiklerim" : "Tümü")),
                selected: _filter == f,
                selectedColor: Colors.blueAccent.withOpacity(0.2),
                onSelected: (val) => setState(() => _filter = f),
              ),
            )).toList(),
          ),

          // LİSTE
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance  //kronolojik olarak bildirileri çeker
                  .collection('incidents')
                  // İnceleniyor olanlar sunucuda süzülür; kurallar onları zaten vermez
                  .where('status', whereIn: publicIncidentStatuses)
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text("Hata: ${snapshot.error}"));
                }
                if (!snapshot.hasData) {
                  return Center(child: Text("Veri yok"));
                }

                var docs = snapshot.data!.docs.where((doc) {
                  var data = doc.data() as Map<String, dynamic>;
                  String status = data['status'] ?? '';

                  // Arama metni ile eşleşiyor mu
                  bool matchesSearch = data['title'].toString().toLowerCase().contains(_searchQuery);

                  // Filtreye göre eşleşiyor mu
                  bool matchesFilter = true;
                  if (_filter == "Acik") matchesFilter = status == "Acik" || status == "Açık";
                  if (_filter == "Takip") matchesFilter = _followedIds.contains(doc.id);

                  return matchesSearch && matchesFilter;
                }).toList();

                if (docs.isEmpty) return Center(child: Text("Bildirim bulunamadı."));

                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    var data = docs[index].data() as Map<String, dynamic>;
                    var incident = Incident.fromMap(data, docs[index].id);

                    return Card(
                      margin: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: incident.status == 'Çözüldü' || incident.status == 'Cozuldu'
                              ? Colors.green
                              : Colors.red,
                          child: Icon(Icons.info_outline, color: Colors.white),
                        ),
                        title: Text(incident.title, style: TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text("${incident.type} - ${incident.status}"),
                        trailing: Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () {
                          // Detay sayfasına gidip gelince takip listesini güncelle
                          Navigator.pushNamed(context, '/detail', arguments: incident)
                              .then((_) => _getFollowedIncidents());
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

      // DİNAMİK BUTON
      floatingActionButton: _isAdmin
          ? Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                //ADMİNE DÖN Sadece Adminler görür :)        
                Padding(
                  padding: const EdgeInsets.only(left: 30.0),
                  child: FloatingActionButton.extended(
                    heroTag: "btnAdminReturn", // Çakışmayı önlemek için özel etiket
                    onPressed: () {
                      Navigator.pop(context); // Admin paneline geri dön
                    },
                    backgroundColor: Colors.redAccent,
                    icon: Icon(Icons.admin_panel_settings, color: Colors.white),
                    label: Text("ADMİNE DÖN", style: TextStyle(color: Colors.white)),
                  ),
                ),

                SizedBox(width: 10),

                FloatingActionButton(
                  heroTag: "btnAddIncident", // Çakışmayı önlemek için özel etiket
                  child: Icon(Icons.add),
                  tooltip: "Yeni Bildirim Oluştur",
                  onPressed: () {
                    Navigator.pushNamed(context, '/createIncident');
                  },
                ),
              ],
            )
          : FloatingActionButton(
              // normal kullanıcı için tek buton
              heroTag: "btnStudentAdd",
              child: Icon(Icons.add),
              tooltip: "Yeni Bildirim Oluştur",
              onPressed: () {
                Navigator.pushNamed(context, '/createIncident');
              },
            ),
    );
  }
}
