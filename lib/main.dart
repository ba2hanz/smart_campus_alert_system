import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart'; // FlutterFire configure ile gelen dosya

// Senin oluşturduğun ekranlar
import 'screens/map/map_screen.dart';
import 'screens/create_incident_screen.dart';
import 'screens/map/location_picker_screen.dart';

import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/detail/incident_detail_screen.dart';
// import 'screens/detail/incident_detail_screen.dart'; // Eğer bu dosyan varsa yorum satırını kaldır

void main() async {
  // 1. Flutter motorunu başlat
  WidgetsFlutterBinding.ensureInitialized();
  
  // 2. Firebase'i başlat (Platforma uygun ayarlarla)
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Akıllı Kampüs',
      debugShowCheckedModeBanner: false, // Sağ üstteki "Debug" bandını kaldırır
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      
      // NORMALDE BURASI: home: LoginScreen() OLACAKTI.
      // AMA ŞU AN TEST İÇİN GEÇİCİ MENÜ AÇIYORUZ:
      home: TestMenuScreen(), 

      // Sayfa Rotaları (Navigasyon İsimleri)
      routes: {
        '/map': (context) => MapScreen(),
        '/createIncident': (context) => CreateIncidentScreen(),
        '/locationPicker' : (context) => LocationPickerScreen(),
        // '/detail': (context) => IncidentDetailScreen(), // Dosyan varsa aç
      },
    );
  }
}

// ---------------------------------------------------------
// GEÇİCİ TEST MENÜSÜ (Giriş Ekranı yapılana kadar bunu kullan)
// ---------------------------------------------------------
class TestMenuScreen extends StatelessWidget {
  const TestMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Test Menüsü (Role 2)")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("Harita ve Medya Modülü Testi", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 20),
            
            // 1. Harita Ekranına Git
            ElevatedButton.icon(
              icon: Icon(Icons.map),
              label: Text("Harita Ekranına Git"),
              style: ElevatedButton.styleFrom(padding: EdgeInsets.all(20)),
              onPressed: () {
                Navigator.pushNamed(context, '/map');
              },
            ),
            
            SizedBox(height: 10),

            // 2. Yeni Bildirim Oluştur Ekranına Git
            ElevatedButton.icon(
              icon: Icon(Icons.add_a_photo),
              label: Text("Yeni Bildirim Oluştur"),
              style: ElevatedButton.styleFrom(padding: EdgeInsets.all(20), backgroundColor: Colors.orange[100]),
              onPressed: () {
                Navigator.pushNamed(context, '/createIncident');
              },
            ),
          ],
        ),
      ),
    );
  }
}