import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/incident_model.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _filter = "Tümü";
  String _searchQuery = "";
  List<String> _followedIds = [];

  @override
  void initState() {
    super.initState();
    _getFollowedIncidents();
  }

  void _getFollowedIncidents() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      var doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists) {
        setState(() {
          _followedIds = List<String>.from(doc.get('followedIncidents') ?? []);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Kampüs Bildirimleri"),
        actions: [
          IconButton(
            icon: Icon(Icons.map), 
            tooltip: "Haritada Gör",
            onPressed: () {
              Navigator.pushNamed(context, '/map'); 
            },
          ),
          IconButton(
            icon: Icon(Icons.exit_to_app), 
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              Navigator.pushReplacementNamed(context, '/login');
            }
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(8.0),
            child: TextField(
              decoration: InputDecoration(hintText: "Ara...", prefixIcon: Icon(Icons.search), border: OutlineInputBorder()),
              onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: ["Tümü", "Acik", "Takip"].map((f) => Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: ChoiceChip(
                label: Text(f == "Acik" ? "Sadece Açık" : (f == "Takip" ? "Takip Ettiklerim" : "Tümü")),
                selected: _filter == f,
                onSelected: (val) => setState(() => _filter = f),
              ),
            )).toList(),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('incidents').orderBy('createdAt', descending: true).snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return Center(child: CircularProgressIndicator());
                
                var docs = snapshot.data!.docs.where((doc) {
                  var data = doc.data() as Map<String, dynamic>;

                  if (data['status'] == 'İnceleniyor') return false;

                  bool matchesSearch = data['title'].toString().toLowerCase().contains(_searchQuery);
                  bool matchesFilter = true;
                  
                  if (_filter == "Acik") matchesFilter = data['status'] == "Acik";
                  if (_filter == "Takip") matchesFilter = _followedIds.contains(doc.id);

                  return matchesSearch && matchesFilter;
                }).toList();

                if (docs.isEmpty) return Center(child: Text("Bildirim bulunamadı."));

                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    var incident = Incident.fromMap(docs[index].data() as Map<String, dynamic>, docs[index].id);
                    return Card(
                      margin: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      child: ListTile(
                        leading: Icon(Icons.info, color: Colors.blue),
                        title: Text(incident.title, style: TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text("${incident.type} - ${incident.status}"),
                        trailing: Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () {
                          Navigator.pushNamed(context, '/detail', arguments: incident).then((_) => _getFollowedIncidents()); 
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
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.add),
        tooltip: "Yeni Bildirim Oluştur",
        onPressed: () {
          Navigator.pushNamed(context, '/createIncident');
        },
      ),
    );
  }
}