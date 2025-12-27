import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// giriş ekranı, giren kullanıcının rolüne göre yönlendirme yapılır
class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;  // yükleniyor animasyomu

  Future<void> _login() async {
    setState(() => _isLoading = true);
    try {
      // giriş yyapma kısmı
      UserCredential userCred = await FirebaseAuth.instance.signInWithEmailAndPassword(  //firebasede kullanıcı var mı kontrolü
        email: _emailController.text.trim(),  //trim i deerste söyledi boşluk vs sorunları için 
        password: _passwordController.text.trim(),
      );

      // rol kontrolü
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')   //firestoredaki users tablosuna gidip admin mi user mi kontrolü
          .doc(userCred.user!.uid)
          .get();

      if (userDoc.exists) {
        String role = userDoc.get('role');

        if (!mounted) return;

        if (role == 'admin') {
          // Admin paneli rotası (İbo yapınca aktif edeceğim)  
          Navigator.pushReplacementNamed(context, '/adminHome');
        } else {
          // Normal User -> Ana Sayfaya
          Navigator.pushReplacementNamed(context, '/home');
        }
      }
    } on FirebaseAuthException catch (e) { // şifre yanlışsa vs hata mesajı gösterme
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Hata: ${e.message}"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if(mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Akıllı Kampüs Giriş")),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(controller: _emailController, decoration: InputDecoration(labelText: "E-posta", prefixIcon: Icon(Icons.email))),
            SizedBox(height: 10),
            TextField(controller: _passwordController, obscureText: true, decoration: InputDecoration(labelText: "Şifre", prefixIcon: Icon(Icons.lock))),
            SizedBox(height: 20),                        //burdaki obscureText şifreyi gizler *** gibi gözüktürür
            _isLoading ? CircularProgressIndicator() : ElevatedButton(  // giriş yapılıyorsa yükleniyor animasyonu
              onPressed: _login,
              child: Text("Giriş Yap"),
              style: ElevatedButton.styleFrom(minimumSize: Size(double.infinity, 50)),
            ),
            TextButton( //kayıt ol butonu
              onPressed: () => Navigator.pushNamed(context, '/register'),
              child: Text("Hesabın yok mu? Kayıt Ol"),
            )
          ],
        ),
      ),
    );
  }
}