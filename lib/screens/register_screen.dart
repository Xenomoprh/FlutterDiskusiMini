import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // <-- Tambahkan import ini
import 'home_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final nameController = TextEditingController(); // <-- Controller untuk nama
  final auth = FirebaseAuth.instance;
  final firestore = FirebaseFirestore.instance; // <-- Instance Firestore

  void register() async {
    // Tampilkan loading indicator jika diperlukan
    // misalnya dengan setState dan variabel _isLoading

    if (nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nama tidak boleh kosong.')),
      );
      return;
    }
    if (emailController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email tidak boleh kosong.')),
      );
      return;
    }
    if (passwordController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password tidak boleh kosong.')),
      );
      return;
    }

    try {
      UserCredential userCredential = await auth.createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      // Setelah pengguna berhasil dibuat, simpan data tambahan ke Firestore
      if (userCredential.user != null) {
        await firestore.collection('users').doc(userCredential.user!.uid).set({
          'displayName': nameController.text.trim(),
          'email': emailController.text.trim(),
          'uid': userCredential.user!.uid,
          'createdAt': Timestamp.now(),
        });

        if (mounted) {
          // Tampilkan notifikasi berhasil
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Akun berhasil dibuat!')),
          );
          // Tunggu sebentar agar user melihat notifikasi
          await Future.delayed(const Duration(seconds: 1));
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const HomeScreen()),
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      String message = 'Registrasi gagal.';
      if (e.code == 'weak-password') {
        message = 'Password yang diberikan terlalu lemah.';
      } else if (e.code == 'email-already-in-use') {
        message = 'Akun sudah ada untuk email tersebut.';
      } else if (e.code == 'invalid-email') {
        message = 'Format email tidak valid.';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Terjadi kesalahan: ${e.toString()}')),
      );
    } finally {
      // Sembunyikan loading indicator jika ada
      // setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    nameController.dispose(); // <-- Jangan lupa dispose controller nama
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Register')),
      body: SingleChildScrollView( // <-- Tambahkan SingleChildScrollView
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 20),
            Text(
              'Buat Akun Baru',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 30),
            TextField(
              controller: nameController, // <-- TextField untuk nama
              decoration: const InputDecoration(
                labelText: 'Nama Lengkap',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
              keyboardType: TextInputType.name,
            ),
            const SizedBox(height: 20),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 20),
            TextField(
              controller: passwordController,
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock),
                // Tambahkan suffixIcon untuk show/hide password jika diinginkan
              ),
              obscureText: true,
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: register,
              child: const Text('Register'),
            ),
            TextButton(
              onPressed: () {
                // Jika pengguna sudah punya akun, arahkan ke halaman login
                Navigator.of(context).pop(); // Kembali ke halaman sebelumnya (login)
              },
              child: const Text('Sudah punya akun? Login'),
            ),
          ],
        ),
      ),
    );
  }
}