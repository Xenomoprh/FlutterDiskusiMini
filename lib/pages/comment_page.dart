import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CommentPage extends StatefulWidget {
  final String threadId;

  const CommentPage({Key? key, required this.threadId}) : super(key: key);

  @override
  State<CommentPage> createState() => _CommentPageState();
}

class _CommentPageState extends State<CommentPage> {
  final TextEditingController _commentController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> _addComment() async {
    final user = _auth.currentUser;
    if (user == null) return;

    String content = _commentController.text.trim();
    if (content.isEmpty) return;

    FocusScope.of(context).unfocus();
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    final threadRef = _firestore.collection('threads').doc(widget.threadId);
    final newCommentRef = threadRef.collection('comments').doc();

    try {
      WriteBatch batch = _firestore.batch();

      batch.set(newCommentRef, {
        'content': content,
        'createdBy': user.uid,
        'timestamp': FieldValue.serverTimestamp(),
      });

      batch.update(threadRef, {
        'commentCount': FieldValue.increment(1),
      });

      await batch.commit();
      _commentController.clear();
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text("Gagal mengirim komentar: $e")),
      );
    }
  }

  Future<void> _showDeleteConfirmationDialog(String commentId) async {
    final navigator = Navigator.of(context);
    return showDialog<void>(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: const Text('Hapus Komentar'),
          content: const Text('Apakah Anda yakin ingin menghapus komentar ini?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Batal'),
              onPressed: () => navigator.pop(),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Hapus'),
              onPressed: () {
                navigator.pop();
                _deleteComment(commentId);
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteComment(String commentId) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    final threadRef = _firestore.collection('threads').doc(widget.threadId);
    final commentRef = threadRef.collection('comments').doc(commentId);

    try {
      WriteBatch batch = _firestore.batch();
      batch.delete(commentRef);
      batch.update(threadRef, {
        'commentCount': FieldValue.increment(-1),
      });

      await batch.commit();

      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('Komentar berhasil dihapus.')),
      );
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Gagal menghapus komentar: $e')),
      );
    }
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final date = timestamp.toDate();
    final now = DateTime.now();
    if (now.difference(date).inDays == 0) {
      return DateFormat.Hm().format(date);
    } else {
      return DateFormat('d MMM').format(date);
    }
  }

  Widget _buildCommentBubble({
    required String? avatarUrl,
    required String displayName,
    required String content,
    required String time,
    required bool isOwner,
    required VoidCallback? onDelete,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 20,
          backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
              ? NetworkImage(avatarUrl)
              : null,
          child: (avatarUrl == null || avatarUrl.isEmpty)
              ? Text(displayName.isNotEmpty ? displayName[0] : '?')
              : null,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      displayName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      time,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                    const Spacer(),
                    if (isOwner && onDelete != null)
                      GestureDetector(
                        onTap: onDelete,
                        child: const Icon(Icons.delete, size: 18, color: Colors.red),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(content, style: const TextStyle(fontSize: 15)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final commentsRef = _firestore
        .collection('threads')
        .doc(widget.threadId)
        .collection('comments')
        .orderBy('timestamp', descending: false);

    final currentUserUid = _auth.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Komentar'),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      backgroundColor: Colors.grey[50],
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

                if (docs.isEmpty) {
                  return const Center(
                    child: Text(
                      'Belum ada komentar. Jadilah yang pertama!',
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final commentId = docs[index].id;
                    final createdByUid = data['createdBy'] as String?;
                    final bool isOwner = currentUserUid == createdByUid;
                    final content = data['content'] ?? '';
                    final timestamp = data['timestamp'] as Timestamp?;
                    final time = _formatTimestamp(timestamp);

                    return FutureBuilder<DocumentSnapshot>(
                      future: _firestore.collection('users').doc(createdByUid).get(),
                      builder: (context, userSnapshot) {
                        String displayName = 'Anonim';
                        String? avatarUrl;
                        if (userSnapshot.hasData && userSnapshot.data!.exists) {
                          final userData = userSnapshot.data!.data() as Map<String, dynamic>;
                          displayName = userData['displayName'] as String? ?? 'Anonim';
                          avatarUrl = userData['photoUrl'] as String?;
                        }
                        return _buildCommentBubble(
                          avatarUrl: avatarUrl,
                          displayName: displayName,
                          content: content,
                          time: time,
                          isOwner: isOwner,
                          onDelete: isOwner
                              ? () => _showDeleteConfirmationDialog(commentId)
                              : null,
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
          _buildCommentInput(context),
        ],
      ),
    );
  }

  Widget _buildCommentInput(BuildContext context) {
    final user = _auth.currentUser;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(
        children: [
          FutureBuilder<DocumentSnapshot>(
            future: _firestore.collection('users').doc(user?.uid).get(),
            builder: (context, snapshot) {
              String? avatarUrl;
              String displayName = '';
              if (snapshot.hasData && snapshot.data!.exists) {
                final userData = snapshot.data!.data() as Map<String, dynamic>;
                avatarUrl = userData['photoUrl'] as String?;
                displayName = userData['displayName'] as String? ?? '';
              }
              return CircleAvatar(
                radius: 18,
                backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                    ? NetworkImage(avatarUrl)
                    : null,
                child: (avatarUrl == null || avatarUrl.isEmpty)
                    ? Text(displayName.isNotEmpty ? displayName[0] : '?')
                    : null,
              );
            },
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(24),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _commentController,
                decoration: const InputDecoration(
                  hintText: 'Tulis komentar...',
                  border: InputBorder.none,
                ),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _addComment(),
                minLines: 1,
                maxLines: 3,
              ),
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            radius: 22,
            backgroundColor: Theme.of(context).primaryColor,
            child: IconButton(
              icon: const Icon(Icons.send, color: Colors.white),
              onPressed: _addComment,
              splashRadius: 22,
            ),
          ),
        ],
      ),
    );
  }
}