import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class LocationPickerScreen extends StatefulWidget {
  const LocationPickerScreen({super.key});

  @override
  _LocationPickerScreenState createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  LatLng? _pickedLocation; // kullanıcının seçtiği konum

  // BAŞLANGIÇ KONUMU (Kampüs Koordinatları)
  static const LatLng _defaultLocation = LatLng(39.89942065166383, 41.243193915599775); 

  // KONUM SEÇİMİ (Haritaya Tıklanınca)
  // Kullanıcı haritaya tıkladığında seçilen konumu kaydeder
  void _selectLocation(LatLng position) {
    setState(() {
      _pickedLocation = position;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Konumu İşaretle"),
        actions: [
          // ONAY BUTONU (Konum seçildiyse görünür)
          if (_pickedLocation != null)
            IconButton(
              icon: Icon(Icons.check),
              onPressed: () {
                // Seçilen konumu geri döndür
                Navigator.of(context).pop(_pickedLocation);
              },
            )
        ],
      ),
      body: GoogleMap(
        // BAŞLANGIÇ KAMERA POZİSYONU
        initialCameraPosition: CameraPosition(
          target: _defaultLocation,
          zoom: 15,
        ),

        // HARİTAYA TIKLAMA
        onTap: _selectLocation,
        
        // MARKER GÖSTERİMİ (Konum seçildiyse marker göster)
        markers: _pickedLocation == null
            ? {}
            : {
                Marker(
                  markerId: MarkerId('m1'),
                  position: _pickedLocation!,
                ),
              },
      ),
    );
  }
}