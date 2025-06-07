// lib/screens/home_screen.dart (VERSI LENGKAP DAN STABIL)

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:markdown_widget/markdown_widget.dart'; // Pastikan package ini ada di pubspec.yaml

// Import untuk halaman lain yang kita perlukan
import '../pages/create_thread_page.dart';
import '../pages/comment_page.dart';
import 'login_screen.dart';
import 'account_screen.dart'; // Pastikan file ini ada di proyek Anda

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = ''; // Hanya untuk menyimpan query teks

  @override
  void initState() {
    super.initState();
    // Listener ini akan memanggil setState untuk memicu rebuild UI
    // saat pengguna mengetik di kolom pencarian.
    _searchController.addListener(() {
      if (mounted) {
        setState(() {
          _searchQuery = _searchController.text;
        });
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
  
  // Fungsi untuk menampilkan dialog konfirmasi penghapusan
  Future<void> _showDeleteConfirmationDialog(String threadId, String threadTitle) async {
    // Menggunakan BuildContext yang aman
    final navigator = Navigator.of(context);
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: const Text('Konfirmasi Hapus'),
          content: Text('Yakin ingin menghapus thread "$threadTitle"?\nTindakan ini tidak dapat dibatalkan.'),
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
        );
      },
    );
  }

  // Fungsi untuk menghapus thread beserta sub-koleksinya
  Future<void> _deleteThread(String threadId) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    try {
      WriteBatch batch = _firestore.batch();

      // Hapus sub-koleksi 'comments'
      QuerySnapshot comments = await _firestore.collection('threads').doc(threadId).collection('comments').get();
      for (var doc in comments.docs) { batch.delete(doc.reference); }

      // Hapus sub-koleksi 'votes'
      QuerySnapshot votes = await _firestore.collection('threads').doc(threadId).collection('votes').get();
      for (var doc in votes.docs) { batch.delete(doc.reference); }

      // Hapus dokumen thread utama
      batch.delete(_firestore.collection('threads').doc(threadId));
      
      await batch.commit();

      scaffoldMessenger.showSnackBar(const SnackBar(content: Text('Thread berhasil dihapus.')));
    } catch(e) {
      scaffoldMessenger.showSnackBar(SnackBar(content: Text('Gagal menghapus thread: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = _auth.currentUser;

    if (currentUser == null) {
      // Fallback jika user tidak login, seharusnya tidak terjadi jika alur aplikasi benar
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Forum Diskusi'),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle_outlined),
            tooltip: 'Pengaturan Akun',
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const AccountScreen()));
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () async {
              final navigator = Navigator.of(context);
              await _auth.signOut();
              navigator.pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const LoginScreen()),
                (_) => false,
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  labelText: 'Cari Judul Thread...',
                  hintText: 'Ketik untuk mencari...',
                  suffixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0)),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _firestore.collection('threads').orderBy('timestamp', descending: true).snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Terjadi kesalahan: ${snapshot.error}'));
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(child: Text('Belum ada thread.'));
                  }
                  
                  // Lakukan filtering di sini, langsung di dalam build method
                  final allThreads = snapshot.data!.docs;
                  final displayList = _searchQuery.isEmpty
                      ? allThreads
                      : allThreads.where((doc) {
                          final title = (doc.data() as Map<String, dynamic>)['title']?.toLowerCase() ?? '';
                          return title.contains(_searchQuery.toLowerCase());
                        }).toList();

                  if (displayList.isEmpty) {
                    return Center(child: Text(_searchQuery.isEmpty ? 'Belum ada thread.' : 'Thread tidak ditemukan.'));
                  }
                  
                  return ListView.builder(
                    itemCount: displayList.length,
                    itemBuilder: (context, index) {
                      final doc = displayList[index];
                      final data = doc.data() as Map<String, dynamic>;
                      final threadId = doc.id;
                      final createdByUid = data['createdBy'] as String?;
                      final threadTitle = data['title'] as String? ?? 'Tanpa Judul';
                      final timestamp = data['timestamp'] as Timestamp?;
                      final String markdownContent = data['content'] as String? ?? '';
                      final bool isCreator = (currentUser.uid == createdByUid);
                      String formattedDate = timestamp != null ? DateFormat('dd MMM yy, HH:mm').format(timestamp.toDate()) : 'Tanggal tidak diketahui';

                      return Card(
                        elevation: 3,
                        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: Text(threadTitle, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold))),
                                  if (isCreator)
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                      tooltip: 'Hapus Thread',
                                      onPressed: () => _showDeleteConfirmationDialog(threadId, threadTitle)
                                    ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              if (createdByUid != null)
                                FutureBuilder<DocumentSnapshot>(
                                  future: _firestore.collection('users').doc(createdByUid).get(),
                                  builder: (context, userSnapshot) {
                                    if (userSnapshot.connectionState == ConnectionState.waiting) {
                                      return const Text('Oleh: Memuat...', style: TextStyle(fontSize: 12, color: Colors.grey));
                                    }
                                    if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
                                      return Text('Oleh: Pengguna Tidak Dikenal • $formattedDate', style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.grey));
                                    }
                                    final userData = userSnapshot.data!.data() as Map<String, dynamic>;
                                    final displayName = userData['displayName'] as String? ?? 'Anonim';
                                    return Text('Oleh: $displayName • $formattedDate', style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.grey));
                                  },
                                ),
                              const SizedBox(height: 10),
                              MarkdownWidget(data: markdownContent.isEmpty ? '*Tidak ada konten*' : markdownContent, shrinkWrap: true, physics: const NeverScrollableScrollPhysics()),
                              const Divider(height: 20),
                              FutureBuilder<DocumentSnapshot>(
                                future: _firestore.collection('threads').doc(threadId).collection('votes').doc(currentUser.uid).get(),
                                builder: (context, voteSnapshot) {
                                  if (voteSnapshot.connectionState == ConnectionState.waiting) {
                                    return const Center(child: SizedBox(height: 24, child: CircularProgressIndicator(strokeWidth: 2)));
                                  }
                                  final userVote = (voteSnapshot.data?.data() as Map<String, dynamic>?)?['voteType'];
                                  return Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                                    children: [
                                      _VoteButton(
                                        icon: Icons.thumb_up_alt_outlined,
                                        filledIcon: Icons.thumb_up_alt,
                                        label: '${data['upvotes'] ?? 0}',
                                        isSelected: userVote == 'upvote',
                                        color: Colors.blue,
                                        onPressed: () async {
                                          if (userVote == 'upvote') {
                                            await _firestore.collection('threads').doc(threadId).collection('votes').doc(currentUser.uid).delete();
                                            await _firestore.collection('threads').doc(threadId).update({'upvotes': FieldValue.increment(-1)});
                                          } else {
                                            await _firestore.collection('threads').doc(threadId).collection('votes').doc(currentUser.uid).set({'voteType': 'upvote'});
                                            await _firestore.collection('threads').doc(threadId).update({
                                              'upvotes': FieldValue.increment(1),
                                              if (userVote == 'downvote') 'downvotes': FieldValue.increment(-1),
                                            });
                                          }
                                        },
                                      ),
                                      _VoteButton(
                                        icon: Icons.thumb_down_alt_outlined,
                                        filledIcon: Icons.thumb_down_alt,
                                        label: '${data['downvotes'] ?? 0}',
                                        isSelected: userVote == 'downvote',
                                        color: Colors.red,
                                        onPressed: () async {
                                          if (userVote == 'downvote') {
                                            await _firestore.collection('threads').doc(threadId).collection('votes').doc(currentUser.uid).delete();
                                            await _firestore.collection('threads').doc(threadId).update({'downvotes': FieldValue.increment(-1)});
                                          } else {
                                            await _firestore.collection('threads').doc(threadId).collection('votes').doc(currentUser.uid).set({'voteType': 'downvote'});
                                            await _firestore.collection('threads').doc(threadId).update({
                                              'downvotes': FieldValue.increment(1),
                                              if (userVote == 'upvote') 'upvotes': FieldValue.increment(-1),
                                            });
                                          }
                                        },
                                      ),
                                      TextButton.icon(
                                        icon: const Icon(Icons.comment_outlined, size: 20),
                                        label: const Text('Komentar'),
                                        onPressed: () {
                                          Navigator.push(context, MaterialPageRoute(builder: (_) => CommentPage(threadId: threadId)));
                                        },
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateThreadPage()));
        },
        label: const Text('Buat Thread'),
        icon: const Icon(Icons.add_comment_outlined),
      ),
    );
  }
}

// Widget helper _VoteButton (wajib ada untuk menghindari error)
class _VoteButton extends StatelessWidget {
  final IconData icon;
  final IconData filledIcon;
  final String label;
  final bool isSelected;
  final Color color;
  final VoidCallback onPressed;

  const _VoteButton({
    required this.icon,
    required this.filledIcon,
    required this.label,
    required this.isSelected,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      icon: Icon(isSelected ? filledIcon : icon, color: isSelected ? color : Colors.grey, size: 20),
      label: Text(label, style: TextStyle(color: isSelected ? color : Colors.grey)),
      style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
      onPressed: onPressed,
    );
  }
}