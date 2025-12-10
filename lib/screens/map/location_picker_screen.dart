import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class LocationPickerScreen extends StatefulWidget {
  const LocationPickerScreen({super.key});

  @override
  _LocationPickerScreenState createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  LatLng? _pickedLocation; 


  static const LatLng _defaultLocation = LatLng(39.89942065166383, 41.243193915599775); 

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

          if (_pickedLocation != null)
            IconButton(
              icon: Icon(Icons.check),
              onPressed: () {

                Navigator.of(context).pop(_pickedLocation);
              },
            )
        ],
      ),
      body: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: _defaultLocation,
          zoom: 15,
        ),

        onTap: _selectLocation,
        

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