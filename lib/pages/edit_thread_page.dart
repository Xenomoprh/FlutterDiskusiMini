import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EditThreadPage extends StatefulWidget {
  final String threadId;
  final String currentTitle;
  final String currentContent;

  const EditThreadPage({
    super.key,
    required this.threadId,
    required this.currentTitle,
    required this.currentContent,
  });

  @override
  State<EditThreadPage> createState() => _EditThreadPageState();
}

class _EditThreadPageState extends State<EditThreadPage> {
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    // Isi controller dengan data thread yang ada
    _titleController = TextEditingController(text: widget.currentTitle);
    _contentController = TextEditingController(text: widget.currentContent);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _updatePost() async {
    if (_titleController.text.trim().isEmpty || _contentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Judul dan isi tidak boleh kosong.')),
      );
      return;
    }

    setState(() { _isUpdating = true; });

    final navigator = Navigator.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      await FirebaseFirestore.instance
          .collection('threads')
          .doc(widget.threadId)
          .update({
        'title': _titleController.text.trim(),
        'content': _contentController.text.trim(), // Konten Markdown
        'lastUpdatedAt': FieldValue.serverTimestamp(), // Opsional: tandai waktu update
      });

      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('Thread berhasil diperbarui!')),
      );
      navigator.pop(); // Kembali ke halaman akun
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Gagal memperbarui thread: $e')),
      );
    } finally {
      if (mounted) { setState(() { _isUpdating = false; }); }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Thread'),
        actions: [
          _isUpdating
              ? const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                )
              : IconButton(
                  icon: const Icon(Icons.save_as_outlined),
                  tooltip: 'Simpan Perubahan',
                  onPressed: _updatePost,
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
                border: OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16.0),
            Expanded(
              child: TextField(
                controller: _contentController,
                maxLines: null,
                keyboardType: TextInputType.multiline,
                decoration: const InputDecoration(
                  labelText: 'Isi Diskusi (Markdown)',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}