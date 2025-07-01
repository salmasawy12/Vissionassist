import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:test1/vChatscreen.dart';

class VolunteerRecentChatsScreen extends StatefulWidget {
  @override
  _VolunteerRecentChatsScreenState createState() =>
      _VolunteerRecentChatsScreenState();
}

class _VolunteerRecentChatsScreenState
    extends State<VolunteerRecentChatsScreen> {
  String? volunteerId;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {
        volunteerId = user.uid; // ✅ use UID directly
        print('Volunteer UID: $volunteerId');
      });
    } else {
      print('User not logged in');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (FirebaseAuth.instance.currentUser == null) {
      return Center(child: Text('Not logged in.'));
    }
    if (volunteerId == null) {
      return Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      appBar: AppBar(title: Text('Recent Chats')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('volunteers')
            .doc(volunteerId)
            .collection('chats')
            .snapshots(),
        builder: (context, chatSnapshot) {
          if (!chatSnapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }

          final chatDocs = chatSnapshot.data!.docs;

          if (chatDocs.isEmpty) {
            return Center(child: Text('No chats yet.'));
          }

          return ListView.builder(
            itemCount: chatDocs.length,
            itemBuilder: (context, index) {
              final chatId = chatDocs[index].id;

              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('volunteers')
                    .doc(volunteerId)
                    .collection('chats')
                    .doc(chatId)
                    .collection('messages')
                    .orderBy('timestamp', descending: true)
                    .limit(1)
                    .snapshots(),
                builder: (context, messageSnapshot) {
                  if (!messageSnapshot.hasData) {
                    return ListTile(
                        title: Text(chatId), subtitle: Text("Loading..."));
                  }

                  final messageDocs = messageSnapshot.data!.docs;

                  if (messageDocs.isEmpty) {
                    return ListTile(
                      title: Text(chatId),
                      subtitle: Text("No messages yet"),
                    );
                  }

                  final messageData =
                      messageDocs.first.data() as Map<String, dynamic>;
                  final lastMessage = messageData['content'] ?? '';
                  final timestamp =
                      (messageData['timestamp'] as Timestamp).toDate();

                  return StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('Users')
                        .doc(chatId)
                        .snapshots(),
                    builder: (context, userSnapshot) {
                      String displayName = "Blind User"; // Default

                      if (userSnapshot.hasData &&
                          userSnapshot.data != null &&
                          userSnapshot.data!.exists) {
                        final data =
                            userSnapshot.data!.data() as Map<String, dynamic>;
                        if (data.containsKey('username') &&
                            data['username'] is String) {
                          displayName = data['username'];
                        }
                      }

                      return ListTile(
                        title: Text(displayName),
                        subtitle: Text(
                          lastMessage,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Text(DateFormat('h:mm a').format(timestamp)),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => VolunteerChatScreen(
                                receiverUid: chatId,
                                displayName: displayName,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
