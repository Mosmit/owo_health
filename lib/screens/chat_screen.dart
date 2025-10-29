import 'dart:async'; // Make sure this is imported for Future.delayed if you use fakes

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  bool _isLoading = false;

  // Get current user and functions instance
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  // Reference for READING messages (ordered query)
  late final Query _messagesQuery;

  // Reference for ADDING messages (collection reference)
  late final CollectionReference _messagesCollectionRef;

  @override
  void initState() {
    super.initState();
    if (_currentUser != null) {
      // Initialize BOTH references
      _messagesCollectionRef = FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser!.uid)
          .collection('messages');

      _messagesQuery = _messagesCollectionRef.orderBy(
        'timestamp',
        descending: true,
      ); // <-- Newest first
    }
    // Handle the case where _currentUser might be null if needed,
    // though AuthGate should prevent this screen loading if null.
    // else { print("Error: currentUser is null in ChatScreen initState"); }
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    // Ensure _currentUser is not null before proceeding
    if (text.isEmpty || _currentUser == null) return;

    setState(() {
      _isLoading = true;
    });

    _controller.clear();

    try {
      // 1. Save the user's message to Firestore using the CollectionReference
      final userMessage = {
        'text': text,
        'sender': 'user',
        'timestamp': FieldValue.serverTimestamp(),
      };
      // Use the CollectionReference for adding
      await _messagesCollectionRef.add(userMessage);

      // --- UNCOMMENT THIS BLOCK TO CALL THE REAL FUNCTION ---
      // 2. Call the Cloud Function
      final callable = _functions.httpsCallable(
        'getChatResponse',
      ); // <-- Correct name
      // Send data with 'text' key, expect String response
      final response = await callable.call<String>({
        'text': text, // <-- Correct key and value
      });

      // 3. Save the AI's response to Firestore using the CollectionReference
      final aiText = response.data; // Function returns the string directly
      final aiMessage = {
        'text':
            aiText ??
            "Sorry, I couldn't process that.", // Handle null just in case
        'sender': 'ai',
        'timestamp': FieldValue.serverTimestamp(),
      };
      // Use the CollectionReference for adding
      await _messagesCollectionRef.add(aiMessage);
      // --- END REAL FUNCTION CALL BLOCK ---

      /* --- FAKE RESPONSE BLOCK (Use if emulators/backend aren't ready) ---
      // 1. Simulate network delay
      await Future.delayed(const Duration(seconds: 1));
      String aiReply = "Fake AI reply: $text";

      // 2. Save fake AI reply
      final aiMessage = {
        'text': aiReply,
        'sender': 'ai',
        'timestamp': FieldValue.serverTimestamp(),
      };
      await _messagesCollectionRef.add(aiMessage);
      --- END FAKE RESPONSE BLOCK --- */
    } catch (e) {
      // If there's an error, save an error message using the CollectionReference
      await _messagesCollectionRef.add({
        'text': 'Error: Could not get a response. $e', // Show error details
        'sender': 'ai',
        'timestamp': FieldValue.serverTimestamp(),
      });
      // Optionally show a snackbar too
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error getting AI response: ${e.toString()}')),
        );
      }
    } finally {
      // Ensure widget is still mounted before calling setState
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show error or loading if currentUser is null (shouldn't happen with AuthGate)
    if (_currentUser == null) {
      return Scaffold(
        // Add Scaffold for consistent UI
        appBar: AppBar(title: const Text("Chat Error")),
        body: const Center(child: Text("Error: No user logged in.")),
      );
    }

    // Main Chat UI - Wrap in Scaffold if this is a full screen
    return Scaffold(
      appBar: AppBar(
        title: const Text('OwoHealth AI Chat'),
        // Add back button automatically if pushed onto nav stack
      ),
      body: Column(
        children: [
          // 1. The Message List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              // Use the Query for the stream
              stream: _messagesQuery.snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('Start chatting below!'));
                }

                final docs = snapshot.data!.docs;
                return ListView.builder(
                  reverse: true, // <-- Show newest messages at the bottom
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    // Access data safely
                    final data =
                        docs[index].data() as Map<String, dynamic>? ?? {};
                    final text = data['text'] as String? ?? '';
                    final sender = data['sender'] as String? ?? '';
                    final isUser = sender == 'user';

                    return Align(
                      alignment: isUser
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(
                          vertical: 4,
                          horizontal: 8,
                        ),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isUser ? Colors.teal[100] : Colors.grey[300],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(text),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          const Divider(height: 1),

          // 2. The Text Input
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: "Enter your question...",
                      border: OutlineInputBorder(), // Add border for clarity
                    ),
                    enabled: !_isLoading, // Disable when loading
                    onSubmitted: (_) =>
                        _isLoading ? null : _sendMessage(), // Send on enter
                  ),
                ),
                const SizedBox(width: 8), // Add spacing
                IconButton(
                  icon: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send, color: Colors.teal),
                  onPressed: _isLoading ? null : _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
