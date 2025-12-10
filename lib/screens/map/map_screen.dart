import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/incident_model.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final CameraPosition _initialCameraPosition = const CameraPosition(
    target: LatLng(39.89942065166383, 41.243193915599775),
    zoom: 15.0,
  );

  Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    _loadIncidentMarkers();
  }

  Future<void> _loadIncidentMarkers() async {

    var snapshot = await FirebaseFirestore.instance.collection('incidents').get();

    Set<Marker> newMarkers = {};

    for (var doc in snapshot.docs) {

      Incident incident = Incident.fromMap(doc.data(), doc.id);

      double markerHue;

      if (incident.type == 'Saglik') {
        markerHue = BitmapDescriptor.hueRed;
      } else if (incident.type == 'Guvenlik') markerHue = BitmapDescriptor.hueBlue;
      else if (incident.type == 'Teknik') markerHue = BitmapDescriptor.hueOrange;
      else if (incident.type == 'Cevre') markerHue = BitmapDescriptor.hueGreen;
      else if (incident.type == 'Kayip-Buluntu') markerHue = BitmapDescriptor.hueYellow;
      else markerHue = BitmapDescriptor.hueViolet;

      newMarkers.add(Marker(
        markerId: MarkerId(incident.id),
        position: LatLng(incident.latitude, incident.longitude),
        icon: BitmapDescriptor.defaultMarkerWithHue(markerHue),
        infoWindow: InfoWindow(
          title: incident.title,
          snippet: "${_getTimeAgo(incident.createdAt)} - Detayları Görüntüle",
          onTap: () {
            Navigator.pushNamed(context, '/detail', arguments: incident);
          },
        ),
      ));
    }
    if (mounted) {
      setState(() {
        _markers = newMarkers;
      });
    }
  }

  String _getTimeAgo(DateTime createdAt) {
    Duration difference = DateTime.now().difference(createdAt);
    if (difference.inMinutes < 60) {
      return "${difference.inMinutes} dakika önce";
    } else if (difference.inHours < 24) return "${difference.inHours} saat önce";
    else if (difference.inDays < 30) return "${difference.inDays} gün önce";
    else if (difference.inDays >= 30 && difference.inDays < 365) return "${(difference.inDays / 30).floor()} ay önce";
    else return "${(difference.inDays / 365).floor()} yıl önce";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Kampüs Haritası'),
        actions: [
          IconButton(
            icon: Icon(Icons.add),
            onPressed: _loadIncidentMarkers,
          )
        ]
          
        
      ),
      body: GoogleMap(
        initialCameraPosition: _initialCameraPosition,
        markers: _markers,
        myLocationEnabled: true,
        myLocationButtonEnabled: true,
        zoomGesturesEnabled: true,

      ),
    );
  }
}