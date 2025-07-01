import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:test1/vChatscreen.dart';

/// Recent Chats screen for volunteers.
/// Shows all chats with blind users, last message, and allows opening chat screens.
class VolunteerRecentChatsScreen extends StatefulWidget {
  @override
  VolunteerRecentChatsScreenState createState() =>
      VolunteerRecentChatsScreenState();
}

class VolunteerRecentChatsScreenState
    extends State<VolunteerRecentChatsScreen> {
  String? volunteerId;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      volunteerId = user.uid; // Use UID directly
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Scaffold(body: Center(child: Text('Not logged in.')));
    }
    if (volunteerId == null) {
      return Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final volunteerChatsCollection = FirebaseFirestore.instance
        .collection('volunteers')
        .doc(volunteerId)
        .collection('chats');

    return Scaffold(
      appBar: AppBar(title: Text('Recent Chats')),
      body: StreamBuilder<QuerySnapshot>(
        stream: volunteerChatsCollection.snapshots(),
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
              final chatDoc = chatDocs[index];
              final blindUserUid = chatDoc.id;
              // Get last message for this chat
              return StreamBuilder<QuerySnapshot>(
                stream: volunteerChatsCollection
                    .doc(blindUserUid)
                    .collection('messages')
                    .orderBy('timestamp', descending: true)
                    .limit(1)
                    .snapshots(),
                builder: (context, messageSnapshot) {
                  String lastMessage = "No messages yet";
                  String timestamp = "--:--";
                  if (messageSnapshot.hasData &&
                      messageSnapshot.data!.docs.isNotEmpty) {
                    final messageData = messageSnapshot.data!.docs.first.data()
                        as Map<String, dynamic>;
                    lastMessage = messageData['content'] ?? '';
                    final timestampValue = messageData['timestamp'];
                    timestamp = (timestampValue != null &&
                            timestampValue is Timestamp)
                        ? DateFormat('h:mm a').format(timestampValue.toDate())
                        : "--:--";
                  }
                  // Get blind user's display name
                  return FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance
                        .collection('Users')
                        .doc(blindUserUid)
                        .get(),
                    builder: (context, userSnapshot) {
                      String displayName = "Blind User";
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
                      return Card(
                        margin:
                            EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                        elevation: 5,
                        child: ListTile(
                          contentPadding: EdgeInsets.all(10),
                          leading: CircleAvatar(
                            backgroundColor: Color(0xff1370C2),
                            child: Text(displayName[0].toUpperCase()),
                          ),
                          title: Text(displayName),
                          subtitle: Text(
                            lastMessage,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Text(timestamp),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => VolunteerChatScreen(
                                  receiverUid: blindUserUid,
                                  displayName: displayName,
                                ),
                              ),
                            );
                          },
                        ),
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
