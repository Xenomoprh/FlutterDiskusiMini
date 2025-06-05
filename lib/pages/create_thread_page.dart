// lib/pages/create_thread_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CreateThreadPage extends StatefulWidget {
  const CreateThreadPage({Key? key}) : super(key: key);

  @override
  State<CreateThreadPage> createState() => _CreateThreadPageState();
}

class _CreateThreadPageState extends State<CreateThreadPage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController(); // Controller untuk konten Markdown

  bool _isUploading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _uploadPost() async {
    if (_isUploading) return;

    setState(() {
      _isUploading = true;
    });

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Anda harus login untuk membuat thread.')),
        );
      }
      setState(() {
        _isUploading = false;
      });
      return;
    }

    String title = _titleController.text.trim();
    String markdownContent = _contentController.text.trim(); // Ambil dari TextField biasa

    if (title.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Judul thread tidak boleh kosong.')),
        );
      }
      setState(() {
        _isUploading = false;
      });
      return;
    }

    if (markdownContent.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Isi diskusi tidak boleh kosong.')),
        );
      }
      setState(() {
        _isUploading = false;
      });
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('threads').add({
        'title': title,
        'content': markdownContent, // Simpan string Markdown mentah
        'createdBy': user.uid,
        'timestamp': FieldValue.serverTimestamp(),
        'upvotes': 0,
        'downvotes': 0,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Thread berhasil diposting!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memposting thread: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Buat Thread Baru (Markdown Input)'),
        actions: [
          _isUploading
              ? const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white)),
                )
              : IconButton(
                  icon: const Icon(Icons.check_circle_outline),
                  tooltip: 'Posting Thread',
                  onPressed: _uploadPost,
                ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Judul Diskusi',
                hintText: 'Masukkan judul yang menarik...',
                border: OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16.0),
            // Tidak ada toolbar Markdown khusus, pengguna mengetik manual
            const Text(
              'Isi Diskusi (Gunakan sintaks Markdown):',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8.0),
            Expanded(
              child: TextField( // Menggunakan TextField biasa
                controller: _contentController,
                maxLines: null, // Agar bisa banyak baris dan scroll
                keyboardType: TextInputType.multiline,
                decoration: const InputDecoration(
                  hintText: 'Contoh: **tebal**, *miring*, # Judul, - item list',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true, // Agar label sejajar dengan hint saat multiline
                ),
                style: const TextStyle(fontSize: 16),
              ),
            ),
            const SizedBox(height: 16.0),
          ],
        ),
      ),
    );
  }
}