import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart'; // <-- Tambahkan import ini untuk format tanggal
import '../pages/create_thread_page.dart';
import '../pages/comment_page.dart';
import 'login_screen.dart'; // <-- Import LoginScreen untuk navigasi setelah logout

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final threadsCollection = FirebaseFirestore.instance
        .collection('threads')
        .orderBy('timestamp', descending: true);
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      // Jika tidak ada pengguna yang login, arahkan ke LoginScreen
      // Ini sebagai fallback, idealnya halaman ini tidak bisa diakses tanpa login
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const LoginScreen()));
      });
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Forum Diskusi Mini'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                // Arahkan ke LoginScreen setelah logout dan hapus semua route sebelumnya
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                  (Route<dynamic> route) => false,
                );
              }
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: threadsCollection.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
                child: Text('Terjadi kesalahan: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return const Center(
                child: Text('Belum ada thread. Ayo buat yang pertama!'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(8.0), // Padding untuk keseluruhan list
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final threadId = doc.id;
              final createdByUid = data['createdBy'] as String?;
              final timestamp = data['timestamp'] as Timestamp?;

              String formattedDate = 'Tanggal tidak diketahui';
              if (timestamp != null) {
                // Format timestamp
                formattedDate =
                    DateFormat('dd MMM yyyy, HH:mm').format(timestamp.toDate());
              }

              return Card(
                elevation: 3,
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data['title'] ?? 'Tanpa Judul',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 6),
                      if (createdByUid != null)
                        FutureBuilder<DocumentSnapshot>(
                          future: FirebaseFirestore.instance
                              .collection('users')
                              .doc(createdByUid)
                              .get(),
                          builder: (context, userSnapshot) {
                            if (userSnapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Text('Oleh: Memuat...',
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.grey));
                            }
                            if (!userSnapshot.hasData ||
                                !userSnapshot.data!.exists) {
                              return const Text('Oleh: Pengguna Tidak Dikenal',
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.grey));
                            }
                            final userData =
                                userSnapshot.data!.data() as Map<String, dynamic>;
                            final displayName = userData['displayName'] as String?;
                            final finalDisplayName = (displayName == null || displayName.isEmpty)
                                ? 'Anonim'
                                : displayName;
                            return Text('Oleh: $finalDisplayName • $formattedDate',
                                style: const TextStyle(
                                    fontSize: 12, fontStyle: FontStyle.italic, color: Colors.grey));
                          },
                        )
                      else
                        Text('Oleh: Tidak Diketahui • $formattedDate',
                            style: const TextStyle(
                                fontSize: 12, fontStyle: FontStyle.italic, color: Colors.grey)),
                      const SizedBox(height: 10),
                      Text(
                        data['content'] ?? 'Tanpa Konten',
                        style: Theme.of(context).textTheme.bodyMedium,
                        maxLines: 3, // Batasi jumlah baris konten yang ditampilkan
                        overflow: TextOverflow.ellipsis, // Tambahkan elipsis jika konten panjang
                      ),
                      const Divider(height: 20),
                      FutureBuilder<DocumentSnapshot>(
                        future: FirebaseFirestore.instance
                            .collection('threads')
                            .doc(threadId)
                            .collection('votes')
                            .doc(currentUser.uid)
                            .get(),
                        builder: (context, voteSnapshot) {
                          if (voteSnapshot.connectionState == ConnectionState.waiting) {
                            // Tampilkan indikator loading yang lebih kecil saat vote diambil
                            return const Center(child: SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)));
                          }

                          String? userVote;
                          if (voteSnapshot.hasData && voteSnapshot.data!.exists) {
                            final voteData = voteSnapshot.data!.data() as Map<String, dynamic>?; // Tambahkan null check
                            userVote = voteData?['voteType'] as String?;
                          }

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
                                  final voteRef = FirebaseFirestore.instance
                                      .collection('threads')
                                      .doc(threadId)
                                      .collection('votes')
                                      .doc(currentUser.uid);

                                  if (userVote == 'upvote') { // Batalkan upvote
                                    await voteRef.delete();
                                    await FirebaseFirestore.instance
                                        .collection('threads')
                                        .doc(threadId)
                                        .update({'upvotes': FieldValue.increment(-1)});
                                  } else { // Upvote baru atau ganti dari downvote
                                    int upvoteIncrement = 1;
                                    int downvoteIncrement = 0;
                                    if (userVote == 'downvote') {
                                      downvoteIncrement = -1;
                                    }
                                    await voteRef.set({'voteType': 'upvote'});
                                    await FirebaseFirestore.instance
                                        .collection('threads')
                                        .doc(threadId)
                                        .update({
                                          'upvotes': FieldValue.increment(upvoteIncrement),
                                          'downvotes': FieldValue.increment(downvoteIncrement),
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
                                  final voteRef = FirebaseFirestore.instance
                                      .collection('threads')
                                      .doc(threadId)
                                      .collection('votes')
                                      .doc(currentUser.uid);
                                  
                                  if (userVote == 'downvote') { // Batalkan downvote
                                    await voteRef.delete();
                                    await FirebaseFirestore.instance
                                        .collection('threads')
                                        .doc(threadId)
                                        .update({'downvotes': FieldValue.increment(-1)});
                                  } else { // Downvote baru atau ganti dari upvote
                                    int downvoteIncrement = 1;
                                    int upvoteIncrement = 0;
                                    if (userVote == 'upvote') {
                                      upvoteIncrement = -1;
                                    }
                                    await voteRef.set({'voteType': 'downvote'});
                                    await FirebaseFirestore.instance
                                        .collection('threads')
                                        .doc(threadId)
                                        .update({
                                          'downvotes': FieldValue.increment(downvoteIncrement),
                                          'upvotes': FieldValue.increment(upvoteIncrement),
                                        });
                                  }
                                },
                              ),
                              TextButton.icon(
                                icon: const Icon(Icons.comment_outlined, size: 20),
                                label: const Text('Komentar'),
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.grey[700],
                                ),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => CommentPage(threadId: threadId),
                                    ),
                                  );
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreateThreadPage()),
          );
        },
        label: const Text('Buat Thread'),
        icon: const Icon(Icons.add_comment_outlined),
        tooltip: 'Buat Thread Baru',
      ),
    );
  }
}

// Widget helper untuk tombol vote agar lebih rapi
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
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      onPressed: onPressed,
    );
  }
}