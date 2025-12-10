import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart'; // FlutterFire configure ile gelen dosya

// --- YENİ EKLENEN EKRANLAR ---
// Dosya yollarının (klasör isimlerinin) senin projenle aynı olduğundan emin ol
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/detail/incident_detail_screen.dart';

// Harita ve yeni bildirim ekranları
import 'screens/map/map_screen.dart';
import 'screens/create_incident_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Firebase'i başlat
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Akıllı Kampüs',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        // Görsel güzellik için genel tema ayarları
        appBarTheme: AppBarTheme(
          centerTitle: true,
          backgroundColor: Colors.blueAccent,
          foregroundColor: Colors.white,
        ),
      ),
      
      // --- ANA GİRİŞ KAPISI (AuthWrapper) ---
      // Uygulama açılınca "Kullanıcı içeride mi?" kontrolü yapar.
      home: AuthWrapper(), 

      // --- ROTALAR ---
      // Sayfalar arası geçişlerde kullanılan isimler
      routes: {
        '/login': (context) => LoginScreen(),
        '/register': (context) => RegisterScreen(),
        '/home': (context) => HomeScreen(),
        '/detail': (context) => IncidentDetailScreen(),
        '/map': (context) => MapScreen(),
        '/createIncident': (context) => CreateIncidentScreen(),
      },
    );
  }
}

// -----------------------------------------------------------
// OTURUM KONTROLCÜSÜ (AuthWrapper)
// Kullanıcıyı durumuna göre Login veya Home sayfasına atar.
// -----------------------------------------------------------
class AuthWrapper extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      // Firebase'in oturum durumunu canlı dinle
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        
        // 1. Bağlantı bekleniyorsa (Yükleniyor...)
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        // 2. Kullanıcı Giriş Yapmışsa -> Ana Sayfaya Gönder
        if (snapshot.hasData) {
          return HomeScreen(); 
        }

        // 3. Kullanıcı Yoksa -> Giriş Ekranına Gönder
        return LoginScreen();
      },
    );
  }
}