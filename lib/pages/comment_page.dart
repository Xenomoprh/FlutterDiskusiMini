import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class CommentPage extends StatefulWidget {
  final String threadId;

  const CommentPage({Key? key, required this.threadId}) : super(key: key);

  @override
  State<CommentPage> createState() => _CommentPageState();
}

class _CommentPageState extends State<CommentPage> {
  final TextEditingController _commentController = TextEditingController();

  Future<void> _addComment() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    String content = _commentController.text.trim();
    if (content.isEmpty) return;

    await FirebaseFirestore.instance
        .collection('threads')
        .doc(widget.threadId)
        .collection('comments')
        .add({
      'content': content,
      'createdBy': user.uid, // UID pengguna yang membuat komentar
      'timestamp': FieldValue.serverTimestamp(),
    });

    _commentController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final commentsRef = FirebaseFirestore.instance
        .collection('threads')
        .doc(widget.threadId)
        .collection('comments')
        .orderBy('timestamp', descending: true);

    return Scaffold(
      appBar: AppBar(title: const Text('Komentar')),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: commentsRef.snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) return const Center(child: Text('Error memuat komentar.'));
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data!.docs;

                if (docs.isEmpty) return const Center(child: Text('Belum ada komentar.'));

                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final commentContent = data['content'] ?? '';
                    final commentCreatorUid = data['createdBy']; // UID pembuat komentar

                    return ListTile(
                      title: Text(commentContent),
                      subtitle: FutureBuilder<DocumentSnapshot>(
                        future: FirebaseFirestore.instance.collection('users').doc(commentCreatorUid).get(),
                        builder: (context, userSnapshot) {
                          if (userSnapshot.connectionState == ConnectionState.waiting) {
                            return const Text('Memuat info pengguna...');
                          }
                          if (userSnapshot.hasError || !userSnapshot.hasData || !userSnapshot.data!.exists) {
                            return const Text('Oleh: Pengguna Tidak Dikenal');
                          }
                          final userData = userSnapshot.data!.data() as Map<String, dynamic>;
                          final displayName = userData['displayName'];
                          final finalDisplayName = (displayName == null || displayName.isEmpty) ? 'Anonim' : displayName;
                          return Text('Oleh: $finalDisplayName');
                        },
                      ),
                      // Anda bisa menambahkan timestamp komentar jika ada
                      // trailing: Text(data['timestamp'] != null ? (data['timestamp'] as Timestamp).toDate().toString() : ''),
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    decoration: const InputDecoration(
                      hintText: 'Tulis komentar...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _addComment,
                  child: const Text('Kirim'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}