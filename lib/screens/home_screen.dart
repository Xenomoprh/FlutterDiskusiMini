import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:markdown_widget/markdown_widget.dart';

import '../pages/create_thread_page.dart';
import '../pages/comment_page.dart';
import '../pages/edit_thread_page.dart';
import 'login_screen.dart';
import 'account_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
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

  @override
  Widget build(BuildContext context) {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        elevation: 1,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        title: const Text('Forum Diskusi', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () {
              setState(() {}); // Memicu rebuild dan refresh StreamBuilder
            },
          ),
          IconButton(
            icon: const Icon(Icons.account_circle_outlined),
            tooltip: 'Pengaturan Akun',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AccountScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () async {
              final navigator = Navigator.of(context);
              await _auth.signOut();
              navigator.pushAndRemoveUntil(MaterialPageRoute(builder: (context) => const LoginScreen()), (_) => false);
            },
          ),
        ],
      ),
      backgroundColor: Colors.grey[200],
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            color: Colors.white,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Cari sesuatu...',
                prefixIcon: const Icon(Icons.search, size: 24),
                contentPadding: const EdgeInsets.all(12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30.0),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey[200],
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                // Force rebuild, StreamBuilder akan otomatis update data terbaru
                setState(() {});
                // Jika ingin benar-benar reload dari Firestore, bisa tambahkan logika lain di sini
              },
              child: StreamBuilder<QuerySnapshot>(
                stream: _firestore.collection('threads').orderBy('timestamp', descending: true).snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                  if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
                  
                  final allThreads = snapshot.data!.docs;
                  final displayList = _searchQuery.isEmpty
                      ? allThreads
                      : allThreads.where((doc) {
                          final title = (doc.data() as Map<String, dynamic>)['title']?.toLowerCase() ?? '';
                          return title.contains(_searchQuery.toLowerCase());
                        }).toList();

                  if (displayList.isEmpty) return Center(child: Text(_searchQuery.isEmpty ? 'Belum ada thread.' : 'Thread tidak ditemukan.'));
                  
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: displayList.length,
                    itemBuilder: (context, index) {
                      final doc = displayList[index];
                      return ThreadCard(
                        threadId: doc.id,
                        data: doc.data() as Map<String, dynamic>,
                        currentUser: currentUser,
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateThreadPage())),
        child: const Icon(Icons.add),
        tooltip: 'Buat Thread Baru',
      ),
    );
  }
}

class ThreadCard extends StatelessWidget {
  final String threadId;
  final Map<String, dynamic> data;
  final User currentUser;

  const ThreadCard({
    super.key,
    required this.threadId,
    required this.data,
    required this.currentUser,
  });

  Future<void> _showDeleteConfirmationDialog(BuildContext context, String threadTitle) async {
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
              _deleteThread(context, threadId);
            },
            child: const Text('Hapus', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteThread(BuildContext context, String threadId) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final firestore = FirebaseFirestore.instance;
    try {
      WriteBatch batch = firestore.batch();
      QuerySnapshot comments = await firestore.collection('threads').doc(threadId).collection('comments').get();
      for (var doc in comments.docs) { batch.delete(doc.reference); }
      QuerySnapshot votes = await firestore.collection('threads').doc(threadId).collection('votes').get();
      for (var doc in votes.docs) { batch.delete(doc.reference); }
      batch.delete(firestore.collection('threads').doc(threadId));
      await batch.commit();
      scaffoldMessenger.showSnackBar(const SnackBar(content: Text('Thread berhasil dihapus.')));
    } catch(e) {
      scaffoldMessenger.showSnackBar(SnackBar(content: Text('Gagal menghapus: $e')));
    }
  }

  void _navigateToEditPage(BuildContext context, String title, String content) {
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
    final firestore = FirebaseFirestore.instance;
    final createdByUid = data['createdBy'] as String?;
    final threadTitle = data['title'] as String? ?? 'Tanpa Judul';
    final timestamp = data['timestamp'] as Timestamp?;
    final String markdownContent = data['content'] as String? ?? '';
    final bool isCreator = (currentUser.uid == createdByUid);

    String formattedDate = 'beberapa waktu lalu';
    if (timestamp != null) {
      final difference = DateTime.now().difference(timestamp.toDate());
      if (difference.inDays > 7) formattedDate = DateFormat('dd MMM yy').format(timestamp.toDate());
      else if (difference.inDays > 0) formattedDate = '${difference.inDays} hari yang lalu';
      else if (difference.inHours > 0) formattedDate = '${difference.inHours} jam yang lalu';
      else if (difference.inMinutes > 0) formattedDate = '${difference.inMinutes} menit yang lalu';
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
      elevation: 2.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FutureBuilder<DocumentSnapshot>(
              future: firestore.collection('users').doc(createdByUid).get(),
              builder: (context, userSnapshot) {
                if (!userSnapshot.hasData) return const Row(children: [SizedBox(height: 40)]);
                final displayName = (userSnapshot.data?.data() as Map<String, dynamic>?)?['displayName'] ?? 'Anonim';
                return Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.grey.shade300,
                      child: Text(displayName.isNotEmpty ? displayName[0].toUpperCase() : 'A', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(displayName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          Text(formattedDate, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                        ],
                      ),
                    ),
                    if (isCreator)
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_horiz, color: Colors.grey),
                        onSelected: (value) {
                          if (value == 'edit') {
                            _navigateToEditPage(context, threadTitle, markdownContent);
                          } else if (value == 'delete') {
                            _showDeleteConfirmationDialog(context, threadTitle);
                          }
                        },
                        itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                          const PopupMenuItem<String>(
                            value: 'edit',
                            child: Row(children: [Icon(Icons.edit_outlined, size: 20), SizedBox(width: 8), Text('Edit')]),
                          ),
                          const PopupMenuItem<String>(
                            value: 'delete',
                            child: Row(children: [Icon(Icons.delete_outline, size: 20, color: Colors.red), SizedBox(width: 8), Text('Hapus', style: TextStyle(color: Colors.red))]),
                          ),
                        ],
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            Text(threadTitle, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            MarkdownWidget(data: markdownContent, shrinkWrap: true, physics: const NeverScrollableScrollPhysics()),
            const SizedBox(height: 8),
            Row(
              children: [
                Text('${data['upvotes'] ?? 0} Suka', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                const SizedBox(width: 8), const Text('•', style: TextStyle(color: Colors.grey)), const SizedBox(width: 8),
                Text('${data['downvotes'] ?? 0} Tidak Suka', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                const SizedBox(width: 8), const Text('•', style: TextStyle(color: Colors.grey)), const SizedBox(width: 8),
                Text('${data['commentCount'] ?? 0} Komentar', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
              ],
            ),
            const Divider(height: 24),
            FutureBuilder<DocumentSnapshot>(
              future: firestore.collection('threads').doc(threadId).collection('votes').doc(currentUser.uid).get(),
              builder: (context, voteSnapshot) {
                if (!voteSnapshot.hasData) return const Center(child: SizedBox(height: 24, child: CircularProgressIndicator(strokeWidth: 2)));
                final userVote = (voteSnapshot.data?.data() as Map<String, dynamic>?)?['voteType'];
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _ActionButton(
                      icon: userVote == 'upvote' ? Icons.thumb_up_alt : Icons.thumb_up_alt_outlined,
                      label: 'Suka',
                      isSelected: userVote == 'upvote',
                      onPressed: () async {
                        // --- LOGIKA UPVOTE LENGKAP DIMASUKKAN KEMBALI ---
                        final docRef = firestore.collection('threads').doc(threadId).collection('votes').doc(currentUser.uid);
                        final threadRef = firestore.collection('threads').doc(threadId);
                        if (userVote == 'upvote') {
                          await docRef.delete();
                          await threadRef.update({'upvotes': FieldValue.increment(-1)});
                        } else {
                          await docRef.set({'voteType': 'upvote'});
                          await threadRef.update({
                            'upvotes': FieldValue.increment(1),
                            if (userVote == 'downvote') 'downvotes': FieldValue.increment(-1),
                          });
                        }
                      },
                    ),
                    _ActionButton(
                      icon: userVote == 'downvote' ? Icons.thumb_down_alt : Icons.thumb_down_alt_outlined,
                      label: 'Tidak Suka',
                      isSelected: userVote == 'downvote',
                      onPressed: () async {
                        // --- LOGIKA DOWNVOTE LENGKAP DIMASUKKAN KEMBALI ---
                        final docRef = firestore.collection('threads').doc(threadId).collection('votes').doc(currentUser.uid);
                        final threadRef = firestore.collection('threads').doc(threadId);
                        if (userVote == 'downvote') {
                          await docRef.delete();
                          await threadRef.update({'downvotes': FieldValue.increment(-1)});
                        } else {
                          await docRef.set({'voteType': 'downvote'});
                          await threadRef.update({
                            'downvotes': FieldValue.increment(1),
                            if (userVote == 'upvote') 'upvotes': FieldValue.increment(-1),
                          });
                        }
                      },
                    ),
                    _ActionButton(
                      icon: Icons.comment_outlined,
                      label: 'Komentar',
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CommentPage(threadId: threadId))),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onPressed;
  const _ActionButton({required this.icon, required this.label, this.isSelected = false, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? Theme.of(context).primaryColor : Colors.grey[600];
    return Expanded(
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }
}