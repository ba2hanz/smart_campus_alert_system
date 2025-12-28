import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/incident_model.dart'; 

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  // BAŞLANGIÇ KONUMU (Kampüs Koordinatları)
  final CameraPosition _initialCameraPosition = const CameraPosition(
    target: LatLng(39.89942065166383, 41.243193915599775),
    zoom: 15.0,
  );

  Set<Marker> _markers = {};
  
  // Verileri hafızada tutacağız ki mod değiştirince tekrar internetten çekmesin
  List<QueryDocumentSnapshot> _currentDocs = [];
  
  bool _isAdmin = false; 
  bool _colorByStatus = false; // FALSE: Türe göre renk, TRUE: Duruma göre renk

  @override
  void initState() {
    super.initState();
    _checkUserRole(); // Kullanıcı rolünü kontrol et
  }

  // KULLANICI ROLÜ KONTROLÜ
  // Admin mi öğrenci mi diye bakar, ona göre harita özellikleri değişir
  void _checkUserRole() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      var doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists && doc.data() != null) {
        if (mounted) {
          setState(() {
            _isAdmin = doc.get('role') == 'admin';
          });
          // Admin yetkisi geç yüklenirse haritayı yeniden yüklensin.
          _updateMarkers(); 
        }
      }
    }
    _listenToIncidents(); // Olayları dinlemeye başla
  }

  // OLAYLARI DİNLE (REALTIME)
  // Firestore'dan gelen her güncellemede markerları yeniden çizer
  void _listenToIncidents() {
    FirebaseFirestore.instance.collection('incidents').snapshots().listen((snapshot) {
      // Gelen veriyi hafızaya al
      _currentDocs = snapshot.docs;
      // Markerları oluştur
      _updateMarkers();
    });
  }

  // Markerları o anki moda göre oluşturan fonksiyon
  void _updateMarkers() {
    Set<Marker> newMarkers = {};
    
    for (var doc in _currentDocs) {
      var data = doc.data() as Map<String, dynamic>;
      
      if (data['latitude'] == null || data['longitude'] == null) continue;

      var incident = Incident.fromMap(data, doc.id);

      // --- GÜVENLİK FİLTRESİ ---
      if (!_isAdmin) {
        if (incident.status == 'İnceleniyor' || 
            incident.status == 'Inceleniyor' || 
            incident.status == 'Beklemede') {
          continue;
        }
      }

      // --- RENK SEÇİMİ (MODA GÖRE) ---
      double markerHue;
      
      if (_isAdmin && _colorByStatus) {
        // MOD 1: DURUMA GÖRE RENKLENDİRME (Sadece Admin Görebilir)
        if (incident.status == 'İnceleniyor') markerHue = BitmapDescriptor.hueOrange; 
        else if (incident.status == 'Çözüldü') markerHue = BitmapDescriptor.hueGreen;
        else markerHue = BitmapDescriptor.hueRed; // Açık
      } else {
        // MOD 2: TÜRE GÖRE RENKLENDİRME (Varsayılan)
        if (incident.type == 'Saglik') markerHue = BitmapDescriptor.hueRed;

        else if (incident.type == 'Guvenlik') markerHue = BitmapDescriptor.hueBlue;

        else if (incident.type == 'Teknik') markerHue = BitmapDescriptor.hueOrange;

        else if (incident.type == 'Cevre') markerHue = BitmapDescriptor.hueGreen;

        else if (incident.type == 'Kayip-Buluntu') markerHue = BitmapDescriptor.hueYellow;

        else markerHue = BitmapDescriptor.hueViolet;
      }

      newMarkers.add(
        Marker(
          markerId: MarkerId(incident.id),
          position: LatLng(incident.latitude, incident.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(markerHue),
          onTap: () => _showIncidentPanel(incident),
        ),
      );
    }

    if (mounted) {
      setState(() {
        _markers = newMarkers;
      });
    }
  }

  // OLAY DETAY PANELİ (Marker'a Tıklanınca)
  // Haritadaki bir marker'a tıklanınca alt panel açılır
  void _showIncidentPanel(Incident incident) {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Container(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: Text(incident.title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(incident.status),
                      borderRadius: BorderRadius.circular(12)
                    ),
                    child: Text(incident.status, style: TextStyle(color: Colors.white, fontSize: 12)),
                  ),
                ],
              ),
              SizedBox(height: 10),
              Text(incident.description),
              Divider(),
              
              // Butonlar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    icon: Icon(Icons.info_outline),
                    label: Text("Detay"),
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/detail', arguments: incident);
                    },
                  ),
                  if (_isAdmin) ...[
                    IconButton(
                      icon: Icon(Icons.edit, color: Colors.blue),
                      onPressed: () {
                        Navigator.pop(context);
                        _showStatusUpdateDialog(incident);
                      },
                    ),
                    IconButton(
                      icon: Icon(Icons.delete, color: Colors.red),
                      onPressed: () {
                        Navigator.pop(context);
                        _deleteIncident(incident.id);
                      },
                    ),
                  ]
                ],
              )
            ],
          ),
        );
      },
    );
  }

  // DURUM RENGİ BELİRLEME
  // Her durum için farklı renk döndürür (panel'de gösterim için)
  Color _getStatusColor(String status) {
    if (status == 'İnceleniyor') return Colors.orange;
    if (status == 'Çözüldü') return Colors.green;
    return Colors.red;
  }

  // DURUM GÜNCELLEME DİALOGU (Sadece Admin)
  // Admin bir olayın durumunu değiştirebilir
  void _showStatusUpdateDialog(Incident incident) {
    String selectedStatus = incident.status;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Durumu Güncelle"),
        content: DropdownButtonFormField<String>(
           value: ["Açık", "İnceleniyor", "Çözüldü"].contains(selectedStatus) ? selectedStatus : "İnceleniyor",
           items: ["İnceleniyor", "Açık", "Çözüldü"].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
           onChanged: (val) => selectedStatus = val!,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text("İptal")),
          ElevatedButton(
            onPressed: () async {
              await FirebaseFirestore.instance.collection('incidents').doc(incident.id).update({'status': selectedStatus});
              Navigator.pop(ctx);
            }, 
            child: Text("Kaydet")
          )
        ],
      )
    );
  }

  // OLAY SİLME (Sadece Admin)
  // Seçilen olayı veritabanından siler
  void _deleteIncident(String id) async {
    await FirebaseFirestore.instance.collection('incidents').doc(id).delete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isAdmin ? 'Yönetici Haritası' : 'Kampüs Haritası'),
      ),
      body: Stack(
        children: [
          // HARİTA WİDGET'I
          GoogleMap(
            initialCameraPosition: _initialCameraPosition,
            markers: _markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: true, // Sağ üstteki konum butonu
            zoomGesturesEnabled: true,
            padding: EdgeInsets.only(top: 60), 
          ),

          // --- ADMIN İÇİN RENK MODU DEĞİŞTİRME BUTONU ---
          // Admin haritada renklendirme modunu değiştirebilir (Tür/Durum)
          if (_isAdmin)
            Positioned(
              top: 10,
              right: 10,
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _colorByStatus = !_colorByStatus; // Modu tersine çevir
                      _updateMarkers(); // Harita pinlerini güncelle
                    });
                  },
                  borderRadius: BorderRadius.circular(30),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _colorByStatus ? Icons.assignment_turned_in : Icons.category,
                          color: Colors.blueAccent,
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Text(
                          _colorByStatus ? "Renklendirme: DURUM" : "Renklendirme: TÜR",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}