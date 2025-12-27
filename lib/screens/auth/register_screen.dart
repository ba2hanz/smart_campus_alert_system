import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RegisterScreen extends StatefulWidget {
  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();  // form doğrulama anahtarı e posta şifre vs geçerli mi diye
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _deptController = TextEditingController();   // controllerlar kullanıcının email passowrd name gibi girişlerini kontrol etmek için
  bool _isLoading = false;

  Future<void> _register() async {  // önce girilen bilgilerin doğruluğunu kontrol et sıkıntı yoksa firebase e kaydet
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      // auth ile kullanıcı oluştur
      UserCredential userCred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // firestore'a detayları yaz (Kritik Nokta: role = 'user')
      await FirebaseFirestore.instance.collection('users').doc(userCred.user!.uid).set({
        'uid': userCred.user!.uid,
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'department': _deptController.text.trim(),
        'role': 'user', // tüm yeni kayıtlar normal kullanıcı olarak başlar
        'followedIncidents': [], // kullanıcının takip ettiği olaylar için boş liste
        'createdAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Kayıt Başarılı!")));
      Navigator.pop(context); // Giriş ekranına geri dön

    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Hata: ${e.message}"), backgroundColor: Colors.red));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Kayıt Ol")),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [                                                                                                                   //validator gerekli kılıyor değerleri
              TextFormField(controller: _nameController, decoration: InputDecoration(labelText: "Ad Soyad", border: OutlineInputBorder()), validator: (v) => v!.isEmpty ? "Gerekli" : null),
              SizedBox(height: 10),
              TextFormField(controller: _deptController, decoration: InputDecoration(labelText: "Birim / Bölüm", border: OutlineInputBorder()), validator: (v) => v!.isEmpty ? "Gerekli" : null),
              SizedBox(height: 10),
              TextFormField(controller: _emailController, decoration: InputDecoration(labelText: "E-posta", border: OutlineInputBorder()), validator: (v) => v!.contains("@") ? null : "Geçersiz mail"),
              SizedBox(height: 10),
              TextFormField(controller: _passwordController, obscureText: true, decoration: InputDecoration(labelText: "Şifre", border: OutlineInputBorder()), validator: (v) => v!.length < 6 ? "En az 6 karakter" : null),
              SizedBox(height: 20),
              _isLoading ? CircularProgressIndicator() : ElevatedButton(
                onPressed: _register,
                child: Padding(padding: EdgeInsets.all(12.0), child: Text("KAYIT OL")),
              )
            ],
          ),
        ),
      ),
    );
  }
}