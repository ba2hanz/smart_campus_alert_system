import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/incident_model.dart';
import 'map/location_picker_screen.dart';

class CreateIncidentScreen extends StatefulWidget {
  const CreateIncidentScreen({super.key});

  @override
  _CreateIncidentScreenState createState() => _CreateIncidentScreenState();
}

class _CreateIncidentScreenState extends State<CreateIncidentScreen> {
  final _formKey = GlobalKey<FormState>();

  final TitleController = TextEditingController();
  final DescriptionController = TextEditingController();
  String? selectedType = 'Genel';

  LatLng? _selectedLocation;
  File? _imageFile;
  bool _isLoading = false;

  final List<String> _incidentTypes = ['Genel', 'Guvenlik', 'Saglik', 'Teknik', 'Cevre', 'Kayip-Buluntu'];

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedImage = await picker.pickImage(source: ImageSource.camera);

    if (pickedImage != null) {
      setState(() {
        _imageFile = File(pickedImage.path);
      });
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLoading = true);

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
      Position position = await Geolocator.getCurrentPosition();
      setState(() {
        _selectedLocation = LatLng(position.latitude, position.longitude);
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Konum bilgisi alındı')));
    } else {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Konum bilgisi alınamadı')));
    }
  }

  void _pickLocationOnMap() async {
    final LatLng? pickedLocation = await Navigator.of(context).push<LatLng>(
      MaterialPageRoute(
        builder: (ctx) => LocationPickerScreen(),
      ),
    );

    if (pickedLocation != null) {
      setState(() {
        _selectedLocation = pickedLocation;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Konum haritadan alındı!")),
      );
    }
  }

  Future<void> _submitIncident() async {
      if (!_formKey.currentState!.validate()) return;
      if (_selectedLocation == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lütfen bir konum seçiniz')));
        return;
      }
      setState(() => _isLoading = true);
      try {
        String? imageUrl;
        if (_imageFile != null) {
          String fileName = DateTime.now().millisecondsSinceEpoch.toString();
          Reference storageRef = FirebaseStorage.instance.ref().child('incident_images/$fileName.jpg');
          // Storage kuralları yalnızca görsel kabul ediyor (storage.rules)
          UploadTask uploadTask = storageRef.putFile(_imageFile!, SettableMetadata(contentType: 'image/jpeg'));
          TaskSnapshot taskSnapshot = await uploadTask;
          imageUrl = await taskSnapshot.ref.getDownloadURL();
        }

        final user = FirebaseAuth.instance.currentUser;
        if (user == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Lütfen giriş yaptıktan sonra tekrar deneyin')),
          );
          return;
        }

        Incident newIncident = Incident(
          id: '',
          title: TitleController.text,
          description: DescriptionController.text,
          type: selectedType!,
          status: 'İnceleniyor', // Yeni bildirimler önce incelenmeyi bekler
          latitude: _selectedLocation!.latitude,
          longitude: _selectedLocation!.longitude,
          imageUrl: imageUrl,
          createdAt: DateTime.now(),
          userId: user.uid,
        );
        final data = newIncident.toMap();
        // Server saati ile yaz kronolojik sıra için
        data['createdAt'] = FieldValue.serverTimestamp();

        await FirebaseFirestore.instance.collection('incidents').add(data);
        @override
        void dispose() {
        TitleController.dispose();
        DescriptionController.dispose();
        super.dispose();
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Bildirim başarıyla kaydedildi')));
        Navigator.pop(context);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Bildirim kaydedilirken bir hata oluştu: $e')));
      } finally {
        setState(() => _isLoading = false);
      }
    }
    
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Bildirim Oluştur'),
      ),
      body: _isLoading ? Center(child: CircularProgressIndicator()) : SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<String>(
                initialValue: selectedType,
                decoration: InputDecoration(labelText: 'Bildirim Türü', border: OutlineInputBorder()),
                items: _incidentTypes.map((type) {
                  return DropdownMenuItem(value: type, child: Text(type));
                }).toList(),
                onChanged: (value) => setState(() => selectedType = value!),
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: TitleController,
                decoration: InputDecoration(labelText: 'Başlık', border: OutlineInputBorder()),
                validator: (value) => value!.isEmpty ? 'Başlık gereklidir' : null,
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: DescriptionController,
                decoration: InputDecoration(labelText: 'Açıklama', border: OutlineInputBorder()),
                maxLines: 3,
                validator: (value) => value!.isEmpty ? 'Açıklama gereklidir' : null,
              ),
              SizedBox(height: 16),

              Text('Konum Seç', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: Icon(Icons.my_location),
                      label: Text('Konum Seç'), 
                      onPressed: _getCurrentLocation)
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: Icon(Icons.map),
                      label: Text('Haritadan Seç'),
                      onPressed: _pickLocationOnMap)
                  ),
                ],
              ),
              
              if (_selectedLocation != null)
                Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'Seçilen Konum: ${_selectedLocation!.latitude}, ${_selectedLocation!.longitude}', 
                  style: TextStyle(color: Colors.green),
                  ),
                ),
                SizedBox(height: 16),

                GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    height: 150,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: _imageFile == null 
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.camera_alt, size: 50, color: Colors.grey),
                            Text("Fotoğraf Ekle(Opsiyonel)"),
                          ],
                        )
                        : Image.file(_imageFile!, fit: BoxFit.cover),
                  ),
                ),
                SizedBox(height: 24),

                ElevatedButton(
                  onPressed: _submitIncident,
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.blueAccent,
                  ),
                  child: Text('Bildirimi Gönder', style: TextStyle(fontSize: 18, color: Colors.white)),
                ),
              ],
            ),
          ),
        ),
      
    );

  }
}
                  
  