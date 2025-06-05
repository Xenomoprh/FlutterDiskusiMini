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
  final TextEditingController _contentController = TextEditingController();

  Future<void> _uploadPost() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    String title = _titleController.text.trim();
    String content = _contentController.text.trim();

    if (title.isEmpty || content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Judul dan isi harus diisi.')),
      );
      return;
    }

    await FirebaseFirestore.instance.collection('threads').add({
      'title': title,
      'content': content,
      'createdBy': user.uid,
      'timestamp': FieldValue.serverTimestamp(),
      'upvotes': 0,
      'downvotes': 0,
    });

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Buat Thread'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Judul Diskusi'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _contentController,
              maxLines: 5,
              decoration: const InputDecoration(labelText: 'Isi Diskusi'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _uploadPost,
              child: const Text('Posting'),
            ),
          ],
        ),
      ),
    );
  }
}
