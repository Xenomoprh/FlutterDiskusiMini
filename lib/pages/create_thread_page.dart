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
    String markdownContent = _contentController.text.trim();

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
        'content': markdownContent,
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
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: theme.colorScheme.background,
        iconTheme: IconThemeData(color: theme.colorScheme.primary),
        title: Text(
          'Buat Thread Baru',
          style: theme.textTheme.titleLarge?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          _isUploading
              ? const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.blue)),
                )
              : IconButton(
                  icon: const Icon(Icons.check_circle_rounded),
                  tooltip: 'Posting Thread',
                  color: theme.colorScheme.primary,
                  onPressed: _uploadPost,
                ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
              child: Material(
                elevation: 2,
                borderRadius: BorderRadius.circular(18),
                color: theme.cardColor,
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _titleController,
                        decoration: InputDecoration(
                          labelText: 'Judul Diskusi',
                          hintText: 'Masukkan judul yang menarik...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: theme.colorScheme.surface.withOpacity(0.05),
                          prefixIcon: const Icon(Icons.title_rounded),
                        ),
                        style: theme.textTheme.bodyLarge,
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 24.0),
                      Text(
                        'Isi Diskusi',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 8.0),
                      Container(
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: TextField(
                          controller: _contentController,
                          maxLines: 10,
                          minLines: 6,
                          keyboardType: TextInputType.multiline,
                          decoration: InputDecoration(
                            hintText: 'Silahkan tulis isi diskusi Anda di sini...',
                            filled: true,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            alignLabelWithHint: true,
                            contentPadding: const EdgeInsets.all(16),
                          ),
                          style: theme.textTheme.bodyLarge,
                        ),
                      ),
                      const SizedBox(height: 32.0),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.send_rounded),
                        label: const Text('Posting Thread'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          textStyle: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: Colors.white,
                          elevation: 1,
                        ),
                        onPressed: _isUploading ? null : _uploadPost,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}