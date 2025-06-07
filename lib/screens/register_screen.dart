// lib/screens/register_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'home_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final nameController = TextEditingController(); // Pastikan controller ini ada
  final auth = FirebaseAuth.instance;
  final firestore = FirebaseFirestore.instance;

  void register() async {
    // Simpan Navigator dan ScaffoldMessenger ke variabel lokal SEBELUM await
    if (!mounted) return;
    final navigator = Navigator.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      UserCredential userCredential = await auth.createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      if (userCredential.user != null) {
        // Operasi async kedua
        await firestore.collection('users').doc(userCredential.user!.uid).set({
          'displayName': nameController.text.trim(),
          'email': emailController.text.trim(),
          'uid': userCredential.user!.uid,
          'createdAt': Timestamp.now(),
        });
      }
      
      // Gunakan variabel lokal 'navigator'
      navigator.pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } on FirebaseAuthException catch (e) {
      String message = 'Registrasi gagal.';
      if (e.code == 'weak-password') {
        message = 'Password yang diberikan terlalu lemah.';
      } else if (e.code == 'email-already-in-use') {
        message = 'Akun sudah ada untuk email tersebut.';
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
    // ... (Isi build method Anda tetap sama seperti sebelumnya, pastikan ada TextField untuk nameController) ...
    return Scaffold(
      appBar: AppBar(title: const Text('Register')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Nama Lengkap')),
            TextField(controller: emailController, decoration: const InputDecoration(labelText: 'Email')),
            TextField(controller: passwordController, decoration: const InputDecoration(labelText: 'Password'), obscureText: true),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: register, child: const Text('Register')),
          ],
        ),
      ),
    );
  }
}