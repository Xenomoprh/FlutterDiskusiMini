// lib/screens/login_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'register_screen.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final auth = FirebaseAuth.instance;

  void login() async {
    // Simpan Navigator dan ScaffoldMessenger ke variabel lokal SEBELUM await
    if (!mounted) return; // Cek mounted di awal
    final navigator = Navigator.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      await auth.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );
      
      // Gunakan variabel lokal 'navigator'
      navigator.pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } on FirebaseAuthException catch (e) {
      String message = 'Login gagal.';
      if (e.code == 'user-not-found' || e.code == 'wrong-password' || e.code == 'invalid-credential') {
        message = 'Email atau password salah.';
      } else if (e.code == 'invalid-email') {
        message = 'Format email tidak valid.';
      }
      // Gunakan variabel lokal 'scaffoldMessenger'
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (e) {
      // Gunakan variabel lokal 'scaffoldMessenger'
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Terjadi kesalahan: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // ... (Isi build method Anda tetap sama seperti sebelumnya) ...
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(controller: emailController, decoration: const InputDecoration(labelText: 'Email')),
            TextField(controller: passwordController, decoration: const InputDecoration(labelText: 'Password'), obscureText: true),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: login, child: const Text('Login')),
            TextButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen())),
              child: const Text('Belum punya akun? Register'),
            ),
          ],
        ),
      ),
    );
  }
}