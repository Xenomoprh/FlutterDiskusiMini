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
      'createdBy': user.uid,
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
                if (snapshot.hasError) return const Text('Error');
                if (!snapshot.hasData) return const CircularProgressIndicator();

                final docs = snapshot.data!.docs;

                if (docs.isEmpty) return const Text('Belum ada komentar.');

                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    return ListTile(
                      title: Text(data['content'] ?? ''),
                      subtitle: Text('Oleh: ${data['createdBy'] ?? 'Anonim'}'),
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
