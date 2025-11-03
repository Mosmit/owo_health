// lib/screens/chat_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:intl/intl.dart';
import '../utils/constants.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  bool _isLoading = false;
  bool _showQuickQuestions = true;

  final User? _currentUser = FirebaseAuth.instance.currentUser;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  late final Query _messagesQuery;
  late final CollectionReference _messagesCollectionRef;

  @override
  void initState() {
    super.initState();
    if (_currentUser != null) {
      _messagesCollectionRef = FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser!.uid)
          .collection('messages');

      _messagesQuery = _messagesCollectionRef.orderBy(
        'timestamp',
        descending: true,
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage([String? presetText]) async {
    final text = (presetText ?? _controller.text).trim();
    if (text.isEmpty || _currentUser == null) return;

    setState(() {
      _isLoading = true;
      _showQuickQuestions = false;
    });

    _controller.clear();

    try {
      // Save user message
      final userMessage = {
        'text': text,
        'sender': 'user',
        'timestamp': FieldValue.serverTimestamp(),
      };
      await _messagesCollectionRef.add(userMessage);

      // Call Cloud Function
      final callable = _functions.httpsCallable('getChatResponse');
      final response = await callable.call<String>({'text': text});

      // Save AI response
      final aiMessage = {
        'text': response.data ?? "Sorry, I couldn't process that.",
        'sender': 'ai',
        'timestamp': FieldValue.serverTimestamp(),
      };
      await _messagesCollectionRef.add(aiMessage);
    } catch (e) {
      await _messagesCollectionRef.add({
        'text': 'Error: Could not get a response. Please try again.',
        'sender': 'ai',
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _clearChat() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Chat History'),
        content: const Text('Are you sure you want to delete all messages?'),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppBorderRadius.md),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed == true && _currentUser != null) {
      try {
        final snapshot = await _messagesCollectionRef.get();
        for (var doc in snapshot.docs) {
          await doc.reference.delete();
        }

        if (mounted) {
          setState(() => _showQuickQuestions = true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Chat history cleared'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Chat Error")),
        body: const Center(child: Text("Error: No user logged in.")),
      );
    }

    return Column(
      children: [
        // Message List
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _messagesQuery.snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                );
              }

              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: AppColors.error.withOpacity(0.5),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'Error loading messages',
                        style: AppTextStyles.bodyMedium,
                      ),
                    ],
                  ),
                );
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return _buildEmptyState();
              }

              final docs = snapshot.data!.docs;
              return ListView.builder(
                controller: _scrollController,
                reverse: true,
                padding: const EdgeInsets.all(AppSpacing.md),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final data =
                      docs[index].data() as Map<String, dynamic>? ?? {};
                  final text = data['text'] as String? ?? '';
                  final sender = data['sender'] as String? ?? '';
                  final timestamp = data['timestamp'] as Timestamp?;
                  final isUser = sender == 'user';

                  return _buildMessageBubble(
                    text: text,
                    isUser: isUser,
                    timestamp: timestamp,
                    index: index,
                  );
                },
              );
            },
          ),
        ),

        // Input Area
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  // Clear Chat Button
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: _isLoading ? null : _clearChat,
                    tooltip: 'Clear Chat',
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: AppSpacing.sm),

                  // Text Input
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(
                          AppBorderRadius.full,
                        ),
                      ),
                      child: TextField(
                        controller: _controller,
                        enabled: !_isLoading,
                        maxLines: null,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          hintText: "Ask me anything...",
                          hintStyle: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textHint,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              AppBorderRadius.full,
                            ),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: AppSpacing.sm,
                          ),
                        ),
                        onSubmitted: (_) => _isLoading ? null : _sendMessage(),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),

                  // Send Button
                  Container(
                    decoration: BoxDecoration(
                      gradient: _isLoading ? null : AppColors.primaryGradient,
                      color: _isLoading ? AppColors.textHint : null,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: _isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.send_rounded, color: Colors.white),
                      onPressed: _isLoading ? null : () => _sendMessage(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: AppSpacing.xxl),

          // Welcome Icon
          Container(
            padding: const EdgeInsets.all(AppSpacing.xl),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.chat_bubble_outline,
              size: 64,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          Text(
            'Hello! I\'m your AI Health Assistant',
            style: AppTextStyles.h2,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),

          Text(
            'Ask me anything about health, symptoms, or wellness',
            style: AppTextStyles.bodyMedium,
            textAlign: TextAlign.center,
          ),

          if (_showQuickQuestions) ...[
            const SizedBox(height: AppSpacing.xl),
            Text('Quick Questions', style: AppTextStyles.h3),
            const SizedBox(height: AppSpacing.md),

            ...QuickQuestions.questions.map((question) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                child: InkWell(
                  onTap: () => _sendMessage(question),
                  borderRadius: BorderRadius.circular(AppBorderRadius.md),
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppBorderRadius.md),
                      border: Border.all(
                        color: AppColors.primary.withOpacity(0.2),
                      ),
                      boxShadow: AppShadows.small,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.lightbulb_outline,
                          color: AppColors.primary,
                          size: 20,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            question,
                            style: AppTextStyles.bodyMedium,
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios,
                          size: 16,
                          color: AppColors.textHint,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildMessageBubble({
    required String text,
    required bool isUser,
    Timestamp? timestamp,
    required int index,
  }) {
    final timeStr = timestamp != null
        ? DateFormat('h:mm a').format(timestamp.toDate())
        : '';

    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 300 + (index * 50)),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Align(
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          child: Column(
            crossAxisAlignment: isUser
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  gradient: isUser ? AppColors.primaryGradient : null,
                  color: isUser ? null : AppColors.surface,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(AppBorderRadius.md),
                    topRight: const Radius.circular(AppBorderRadius.md),
                    bottomLeft: Radius.circular(
                      isUser ? AppBorderRadius.md : AppBorderRadius.xs,
                    ),
                    bottomRight: Radius.circular(
                      isUser ? AppBorderRadius.xs : AppBorderRadius.md,
                    ),
                  ),
                  boxShadow: AppShadows.small,
                ),
                child: Text(
                  text,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: isUser ? Colors.white : AppColors.textPrimary,
                  ),
                ),
              ),
              if (timeStr.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xs),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                  ),
                  child: Text(timeStr, style: AppTextStyles.bodySmall),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
