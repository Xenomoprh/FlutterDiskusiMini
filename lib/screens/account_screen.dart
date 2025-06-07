// lib/screens/account_screen.dart (REVISI)

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../pages/edit_thread_page.dart'; // Import halaman edit yang baru dibuat

// Import intl.dart dihapus karena tidak digunakan di versi ini

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  User? _currentUser;

  final TextEditingController _displayNameController = TextEditingController();
  String _currentDisplayName = '';
  bool _isNameSaving = false;

  Stream<QuerySnapshot>? _userThreadsStream;

  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser;
    if (_currentUser != null) {
      _loadCurrentDisplayName();
      _userThreadsStream = _firestore
          .collection('threads')
          .where('createdBy', isEqualTo: _currentUser!.uid)
          .orderBy('timestamp', descending: true)
          .snapshots();
    }
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentDisplayName() async {
    if (_currentUser == null) return;
    try {
      final DocumentSnapshot userDoc = await _firestore.collection('users').doc(_currentUser!.uid).get();
      final data = userDoc.data();
      if (mounted && data is Map<String, dynamic>) {
        setState(() {
          _currentDisplayName = data['displayName'] as String? ?? '';
          _displayNameController.text = _currentDisplayName;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal memuat nama: ${e.toString()}')));
      }
    }
  }

  Future<void> _updateDisplayName() async {
    if (_currentUser == null || _displayNameController.text.trim().isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() { _isNameSaving = true; });
    String newName = _displayNameController.text.trim();
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    try {
      await _firestore.collection('users').doc(_currentUser!.uid).update({'displayName': newName});
      await _currentUser!.updateDisplayName(newName);
      setState(() { _currentDisplayName = newName; });
      scaffoldMessenger.showSnackBar(const SnackBar(content: Text('Nama berhasil diperbarui.')));
    } catch (e) {
      scaffoldMessenger.showSnackBar(SnackBar(content: Text('Gagal: ${e.toString()}')));
    } finally {
      if (mounted) { setState(() { _isNameSaving = false; }); }
    }
  }

  Future<void> _showDeleteConfirmationDialog(String threadId, String threadTitle) async {
    final navigator = Navigator.of(context);
    return showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Konfirmasi Hapus'),
        content: Text('Yakin ingin menghapus thread "$threadTitle"?'),
        actions: [
          TextButton(onPressed: () => navigator.pop(), child: const Text('Batal')),
          TextButton(
            onPressed: () {
              navigator.pop();
              _deleteThread(threadId);
            },
            child: const Text('Hapus', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteThread(String threadId) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    try {
      WriteBatch batch = _firestore.batch();
      QuerySnapshot comments = await _firestore.collection('threads').doc(threadId).collection('comments').get();
      for (var doc in comments.docs) { batch.delete(doc.reference); }
      QuerySnapshot votes = await _firestore.collection('threads').doc(threadId).collection('votes').get();
      for (var doc in votes.docs) { batch.delete(doc.reference); }
      batch.delete(_firestore.collection('threads').doc(threadId));
      await batch.commit();
      scaffoldMessenger.showSnackBar(const SnackBar(content: Text('Thread berhasil dihapus.')));
    } catch(e) {
      scaffoldMessenger.showSnackBar(SnackBar(content: Text('Gagal menghapus: $e')));
    }
  }

  void _navigateToEditPage(String threadId, String title, String content) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditThreadPage(
          threadId: threadId,
          currentTitle: title,
          currentContent: content,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUser == null) {
      return const Scaffold(body: Center(child: Text("Pengguna tidak ditemukan.")));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan Akun')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ganti Nama Tampilan', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            TextField(
              controller: _displayNameController,
              decoration: InputDecoration(
                labelText: 'Nama Tampilan Baru',
                hintText: _currentDisplayName.isNotEmpty ? _currentDisplayName : 'Masukkan nama',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            _isNameSaving
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton.icon(
                    icon: const Icon(Icons.save),
                    label: const Text('Simpan Nama'),
                    onPressed: _updateDisplayName,
                    style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 44)),
                  ),
            const Divider(height: 40, thickness: 1),
            Text('Thread Saya', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            StreamBuilder<QuerySnapshot>(
              stream: _userThreadsStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) return Text('Error: ${snapshot.error}');
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 24.0), child: Text('Anda belum membuat thread.')));
                
                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    final threadDoc = snapshot.data!.docs[index];
                    final threadData = threadDoc.data() as Map<String, dynamic>;
                    final String threadTitle = threadData['title'] ?? 'Tanpa Judul';
                    final String threadContent = threadData['content'] ?? '';
                    
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 6.0),
                      child: ListTile(
                        title: Text(threadTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, color: Colors.blueAccent),
                              tooltip: 'Edit Thread',
                              onPressed: () => _navigateToEditPage(threadDoc.id, threadTitle, threadContent),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                              tooltip: 'Hapus Thread',
                              onPressed: () => _showDeleteConfirmationDialog(threadDoc.id, threadTitle),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}