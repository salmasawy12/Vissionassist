import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:socket_io_client/socket_io_client.dart' as IO;

class VolunteerChatScreen extends StatefulWidget {
  final String receiverUid; // blind user UID
  final String displayName;

  const VolunteerChatScreen({
    required this.receiverUid,
    required this.displayName,
  });

  @override
  State<VolunteerChatScreen> createState() => _VolunteerChatScreenState();
}

class _VolunteerChatScreenState extends State<VolunteerChatScreen> {
  final List<Map<String, dynamic>> messages = [];
  final TextEditingController messageController = TextEditingController();
  late IO.Socket socket;

  @override
  void initState() {
    super.initState();
    initSocket();
    loadMessages();
  }

  void initSocket() {
    socket = IO.io(
      'http://172.20.10.3:3000', // Replace with your socket server IP
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .build(),
    );
    socket.connect();

    socket.onConnect((_) => print("Connected to socket"));

    socket.on('receive_message', (data) {
      print("Socket: received message: $data");

      final message = {
        'type': 'text',
        'content': data['content'],
        'isUser': false,
        'timestamp': DateTime.now(),
      };

      setState(() => messages.add(message));

      // Store in Firestore
      final volunteer = FirebaseAuth.instance.currentUser;
      if (volunteer != null) {
        FirebaseFirestore.instance
            .collection('volunteers')
            .doc(volunteer.uid)
            .collection('chats')
            .doc(data['senderId'])
            .collection('messages')
            .add({
          ...message,
          'timestamp': Timestamp.now(),
        });

        FirebaseFirestore.instance
            .collection('volunteers')
            .doc(volunteer.uid)
            .collection('chats')
            .doc(data['senderId'])
            .set({
          'lastMessage': data['content'],
          'timestamp': Timestamp.now(),
          'receiverId': data['senderId'],
        }, SetOptions(merge: true));
      }
    });

    socket.onDisconnect((_) => print("Socket disconnected"));
  }

  void loadMessages() async {
    final volunteer = FirebaseAuth.instance.currentUser;
    if (volunteer == null) return;

    final snapshot = await FirebaseFirestore.instance
        .collection('volunteers')
        .doc(volunteer.uid)
        .collection('chats')
        .doc(widget.receiverUid)
        .collection('messages')
        .orderBy('timestamp')
        .get();

    setState(() {
      messages.clear();
      for (var doc in snapshot.docs) {
        final data = doc.data();
        messages.add({
          'type': data['type'],
          'content': data['content'],
          'isUser': data['isUser'],
          'timestamp': (data['timestamp'] as Timestamp).toDate(),
        });
      }
    });
  }

  void sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    final volunteer = FirebaseAuth.instance.currentUser;
    if (volunteer == null) return;

    final senderId = volunteer.uid;
    final receiverId = widget.receiverUid;
    print(
        'DEBUG: sendMessage called with senderId=[32m$senderId[0m, receiverId=[34m$receiverId[0m');
    if (senderId == receiverId) {
      print('WARNING: senderId and receiverId are the same! Message not sent.');
      // Optionally show a dialog or snackbar here
      return;
    }
    final timestamp = Timestamp.now();

    final message = {
      'type': 'text',
      'content': text,
      'isUser': true,
      'timestamp': timestamp,
      'senderId': senderId,
      'receiverId': receiverId,
    };

    setState(() {
      messages.add(message);
      messageController.clear();
    });

    // Emit through socket
    socket.emit('send_message', {
      'senderId': senderId,
      'receiverId': receiverId,
      'content': text,
    });

    // Save in Firestore
    final senderRef =
        FirebaseFirestore.instance.collection('volunteers').doc(senderId);
    final receiverRef =
        FirebaseFirestore.instance.collection('Users').doc(receiverId);

    await senderRef
        .collection('chats')
        .doc(receiverId)
        .collection('messages')
        .add(message);
    await senderRef.collection('chats').doc(receiverId).set({
      'lastMessage': text,
      'timestamp': timestamp,
      'receiverId': receiverId,
    }, SetOptions(merge: true));

    await receiverRef
        .collection('chats')
        .doc(senderId)
        .collection('messages')
        .add({
      ...message,
      'isUser': false,
    });
    await receiverRef.collection('chats').doc(senderId).set({
      'lastMessage': text,
      'timestamp': timestamp,
      'receiverId': senderId,
    }, SetOptions(merge: true));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Chat with ${widget.displayName}')),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.all(12),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final message = messages[index];
                final isUser = message['isUser'] ?? false;
                return Align(
                  alignment:
                      isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: EdgeInsets.symmetric(vertical: 4),
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: isUser ? Colors.blue[200] : Colors.grey[300],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(message['content']),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: messageController,
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20)),
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.send, color: Colors.blue),
                  onPressed: () => sendMessage(messageController.text),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}
