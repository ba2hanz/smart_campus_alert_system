import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    FocusScope.of(context).unfocus(); // klavyeyi kapat
    setState(() => _isLoading = true);

    try {
      final email = _emailController.text.trim();
      final pass = _passwordController.text.trim();

      final userCred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: pass,
      );

      // rol kontrolü
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userCred.user!.uid)
          .get();

      if (!mounted) return;

      if (!userDoc.exists) {
        // Kullanıcı Firestore'da yoksa varsayılan user gibi davran
        Navigator.pushReplacementNamed(context, '/home');
        return;
      }

      final data = userDoc.data() as Map<String, dynamic>;
      final role = (data['role'] ?? 'user').toString();

      if (role == 'admin') {
        Navigator.pushReplacementNamed(context, '/adminHome');
      } else {
        Navigator.pushReplacementNamed(context, '/home');
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      String msg = "Bir hata oluştu.";
      if (e.code == 'user-not-found') msg = "Kullanıcı bulunamadı.";
      if (e.code == 'wrong-password') msg = "Yanlış şifre.";
      if (e.code == 'invalid-email') msg = "Geçersiz e-posta formatı.";
      if (e.code == 'user-disabled') msg = "Kullanıcı engellenmiş.";
      if (e.code == 'too-many-requests') msg = "Çok fazla deneme. Lütfen sonra tekrar deneyin.";

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Hata: $e"), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
    );

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: const [
            Icon(Icons.login_rounded),
            SizedBox(width: 8),
            Text("Akıllı Kampüs Giriş"),
          ],
        ),
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: "E-posta",
                prefixIcon: Icon(Icons.alternate_email_rounded),
                border: border,
                enabledBorder: border,
                focusedBorder: border,
              ),
            ),
            SizedBox(height: 10),
            TextField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                labelText: "Şifre",
                prefixIcon: Icon(Icons.password_rounded),
                border: border,
                enabledBorder: border,
                focusedBorder: border,
                suffixIcon: IconButton(
                  tooltip: _obscurePassword ? "Şifreyi göster" : "Şifreyi gizle",
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_rounded
                        : Icons.visibility_off_rounded,
                  ),
                  onPressed: () {
                    setState(() => _obscurePassword = !_obscurePassword);
                  },
                ),
              ),
            ),

            // Şifremi Unuttum
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => Navigator.pushNamed(context, '/forgotPassword'),
                icon: const Icon(Icons.help_outline_rounded),
                label: const Text("Şifremi unuttum"),
              ),
            ),

            SizedBox(height: 10),

            _isLoading
                ? CircularProgressIndicator()
                : ElevatedButton.icon(
                    onPressed: _login,
                    icon: const Icon(Icons.arrow_forward_rounded),
                    label: Text("Giriş Yap"),
                    style: ElevatedButton.styleFrom(
                      minimumSize: Size(double.infinity, 50),
                    ),
                  ),

            TextButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/register'),
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: const Text("Hesabın yok mu? Kayıt Ol"),
            ),
          ],
        ),
      ),
    );
  }
}
