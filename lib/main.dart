import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'screens/auth/forgot_password_screen.dart';

import 'firebase_options.dart'; 
import 'screens/profile/profile_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/detail/incident_detail_screen.dart';
import 'screens/admin/admin_home_screen.dart';
import 'screens/map/map_screen.dart';
import 'screens/create_incident_screen.dart';

// ARKA PLAN BİLDİRİM HANDLER'I
// Uygulama kapalıyken veya arka plandayken gelen bildirimleri işler
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print("Arka plan bildirimi: ${message.notification?.title}");
}

// GLOBAL NAVİGATOR KEY
// Herhangi bir sayfadan bildirim dialog'u açmak için kullanılır
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 1. Firebase'i Başlat
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Arka plan dinleyicisini kaydet
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  
  @override
  void initState() {
    super.initState();
    _setupPushNotifications(); // Bildirim sistemini başlat
  }

  // BİLDİRİM SİSTEMİ KURULUMU
  // Push notification izinleri ve dinleyicileri ayarlar
  void _setupPushNotifications() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;

    // 1. İZİN İSTE
    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('Bildirim izni verildi.');
      // Herkese gönderilen mesajlar için 'all' kanalına abone ol
      await messaging.subscribeToTopic('all');
    }

    // 2. UYGULAMA AÇIKKEN (FOREGROUND) MESAJ GELİRSE
    // Uygulama açıkken bildirim gelirse ekranda dialog göster
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Ön planda mesaj geldi: ${message.notification?.title}');
      
      if (message.notification != null) {
        // Context null kontrolü yap
        final context = navigatorKey.currentContext;
        if (context != null) {
          // Hangi sayfada olursan ol ekrana uyarı bas
          showDialog(
            context: context, 
            builder: (ctx) => AlertDialog(
              backgroundColor: Colors.red[50], 
              title: Row(
                children: [
                  Icon(Icons.notifications_active, color: Colors.red),
                  SizedBox(width: 10),
                  Expanded(child: Text(message.notification!.title ?? "Bildirim")),
                ],
              ),
              content: Text(message.notification!.body ?? ""),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text("TAMAM", style: TextStyle(color: Colors.red)),
                )
              ],
            ),
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Akıllı Kampüs',
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        appBarTheme: AppBarTheme(
          centerTitle: true,
          backgroundColor: Colors.blueAccent,
          foregroundColor: Colors.white,
        ),
      ),
      
      // ANA GİRİŞ KAPISI (AuthWrapper)
      // Uygulama açılınca kullanıcı kontrolü yapar.
      home: AuthWrapper(), 

      // ROTALAR
      // Sayfalar arası geçişlerde kullanılan yollar
      routes: {
        '/login': (context) => LoginScreen(),
        '/register': (context) => RegisterScreen(),
        '/home': (context) => HomeScreen(),
        '/detail': (context) => IncidentDetailScreen(),
        '/map': (context) => MapScreen(),
        '/createIncident': (context) => CreateIncidentScreen(),
        '/adminHome': (context) => AdminHomeScreen(),
        '/profile': (context) => ProfileScreen(),
        '/forgotPassword': (context) => ForgotPasswordScreen(),

      },
    );
  }
}

// OTURUM KONTROLCÜSÜ (AuthWrapper)
// Kullanıcıyı durumuna göre Login veya Home sayfasına atar.
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
          return RoleCheckWrapper(); 
        }
        // 3. Kullanıcı Yoksa -> Giriş Ekranına Gönder
        return LoginScreen();
      },
    );
  }
}

// ROL KONTROLCÜSÜ (RoleCheckWrapper)
// Kullanıcının rolünü kontrol edip Admin veya Öğrenci sayfasına yönlendirir.
class RoleCheckWrapper extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return LoginScreen();

    // Firestore'a git ve bu kullanıcının "role" bilgisini oku
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(user.uid).get(),
      builder: (context, snapshot) {
        
        // Veri okunurken dönen tekerlek göster
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        // Veri geldiyse kontrol et
        if (snapshot.hasData && snapshot.data!.exists) {
          var userData = snapshot.data!.data() as Map<String, dynamic>;
          // Varsayılan rol 'user' olsun, eğer veritabanında 'admin' yazıyorsa onu al
          String role = userData['role'] ?? 'user';

          if (role == 'admin') {
            return AdminHomeScreen(); // ADMİN İSE BURAYA
          } else {
            return HomeScreen();      // ÖĞRENCİ İSE BURAYA
          }
        }

        // Veri okunamazsa veya hata olursa güvenli olarak ana sayfaya at
        return HomeScreen();
      },
    );
  }
}