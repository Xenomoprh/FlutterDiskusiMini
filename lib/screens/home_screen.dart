import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../pages/create_thread_page.dart';
import '../pages/comment_page.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final threads = FirebaseFirestore.instance
        .collection('threads')
        .orderBy('timestamp', descending: true);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Forum Diskusi Mini'),
        actions: [
          Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
                if (context.mounted) {
                  Navigator.pushReplacementNamed(context, '/login');
                }
              },
            ),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: threads.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Terjadi kesalahan'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return const Center(child: Text('Belum ada thread.'));
          }

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final threadId = doc.id;

              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('threads')
                    .doc(threadId)
                    .collection('votes')
                    .doc(FirebaseAuth.instance.currentUser!.uid)
                    .get(),
                builder: (context, voteSnapshot) {
                  if (voteSnapshot.connectionState == ConnectionState.waiting) {
                    return const SizedBox();
                  }

                  String? userVote;
                  if (voteSnapshot.hasData && voteSnapshot.data!.exists) {
                    userVote = voteSnapshot.data!['voteType'];
                  }

                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: ListTile(
                      title: Text(data['title'] ?? 'Tanpa Judul'),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(data['content'] ?? 'Tanpa Konten'),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              IconButton(
                                icon: Icon(Icons.thumb_up,
                                    color: userVote == 'upvote' ? Colors.blue : Colors.grey),
                                onPressed: () async {
                                  final voteRef = FirebaseFirestore.instance
                                      .collection('threads')
                                      .doc(threadId)
                                      .collection('votes')
                                      .doc(FirebaseAuth.instance.currentUser!.uid);

                                  if (userVote == 'upvote') {
                                    await voteRef.delete();
                                    await FirebaseFirestore.instance
                                        .collection('threads')
                                        .doc(threadId)
                                        .update({'upvotes': FieldValue.increment(-1)});
                                  } else if (userVote == 'downvote') {
                                    await voteRef.update({'voteType': 'upvote'});
                                    await FirebaseFirestore.instance
                                        .collection('threads')
                                        .doc(threadId)
                                        .update({
                                      'upvotes': FieldValue.increment(1),
                                      'downvotes': FieldValue.increment(-1),
                                    });
                                  } else {
                                    await voteRef.set({'voteType': 'upvote'});
                                    await FirebaseFirestore.instance
                                        .collection('threads')
                                        .doc(threadId)
                                        .update({'upvotes': FieldValue.increment(1)});
                                  }
                                },
                              ),
                              Text('${data['upvotes'] ?? 0}'),
                              IconButton(
                                icon: Icon(Icons.thumb_down,
                                    color: userVote == 'downvote' ? Colors.red : Colors.grey),
                                onPressed: () async {
                                  final voteRef = FirebaseFirestore.instance
                                      .collection('threads')
                                      .doc(threadId)
                                      .collection('votes')
                                      .doc(FirebaseAuth.instance.currentUser!.uid);

                                  if (userVote == 'downvote') {
                                    await voteRef.delete();
                                    await FirebaseFirestore.instance
                                        .collection('threads')
                                        .doc(threadId)
                                        .update({'downvotes': FieldValue.increment(-1)});
                                  } else if (userVote == 'upvote') {
                                    await voteRef.update({'voteType': 'downvote'});
                                    await FirebaseFirestore.instance
                                        .collection('threads')
                                        .doc(threadId)
                                        .update({
                                      'upvotes': FieldValue.increment(-1),
                                      'downvotes': FieldValue.increment(1),
                                    });
                                  } else {
                                    await voteRef.set({'voteType': 'downvote'});
                                    await FirebaseFirestore.instance
                                        .collection('threads')
                                        .doc(threadId)
                                        .update({'downvotes': FieldValue.increment(1)});
                                  }
                                },
                              ),
                              Text('${data['downvotes'] ?? 0}'),
                              const SizedBox(width: 16),
                              TextButton.icon(
                                icon: const Icon(Icons.comment),
                                label: const Text('Komentar'),
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
                          ),
                        ],
                      ),
                    ),
                  );
                },
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
        icon: const Icon(Icons.add),
      ),
    );
  }
}
