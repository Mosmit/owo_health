// lib/screens/mood_tracker_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../utils/constants.dart';
import '../widgets/custom_widgets.dart';

class MoodTrackerScreen extends StatefulWidget {
  const MoodTrackerScreen({super.key});

  @override
  State<MoodTrackerScreen> createState() => _MoodTrackerScreenState();
}

class _MoodTrackerScreenState extends State<MoodTrackerScreen>
    with SingleTickerProviderStateMixin {
  final User? user = FirebaseAuth.instance.currentUser;
  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _customMoodController = TextEditingController();
  String? _selectedMood;
  bool _isSaving = false;
  bool _useCustomMood = false;
  late AnimationController _animationController;

  final List<Map<String, dynamic>> _moods = [
    {
      'label': 'Awful',
      'emoji': '😫',
      'color': const Color(0xFFE74C3C),
      'description': 'Terrible day',
    },
    {
      'label': 'Bad',
      'emoji': '😔',
      'color': const Color(0xFFE67E22),
      'description': 'Not feeling well',
    },
    {
      'label': 'Okay',
      'emoji': '😐',
      'color': const Color(0xFFF39C12),
      'description': 'Just getting by',
    },
    {
      'label': 'Good',
      'emoji': '🙂',
      'color': AppColors.primary,
      'description': 'Pretty good',
    },
    {
      'label': 'Great',
      'emoji': '😁',
      'color': const Color(0xFF27AE60),
      'description': 'Wonderful day',
    },
  ];

  // Additional mood options for more specific feelings
  final List<Map<String, dynamic>> _detailedMoods = [
    {'label': 'Anxious', 'emoji': '😰', 'color': const Color(0xFF9B59B6)},
    {'label': 'Stressed', 'emoji': '😤', 'color': const Color(0xFFE74C3C)},
    {'label': 'Excited', 'emoji': '🤩', 'color': const Color(0xFF3498DB)},
    {'label': 'Peaceful', 'emoji': '😌', 'color': const Color(0xFF1ABC9C)},
    {'label': 'Tired', 'emoji': '😴', 'color': const Color(0xFF95A5A6)},
    {'label': 'Energetic', 'emoji': '⚡', 'color': const Color(0xFFF1C40F)},
    {'label': 'Sad', 'emoji': '😢', 'color': const Color(0xFF34495E)},
    {'label': 'Angry', 'emoji': '😠', 'color': const Color(0xFFE74C3C)},
    {'label': 'Content', 'emoji': '😊', 'color': const Color(0xFF2ECC71)},
    {'label': 'Overwhelmed', 'emoji': '😵', 'color': const Color(0xFF8E44AD)},
    {'label': 'Grateful', 'emoji': '🙏', 'color': const Color(0xFF16A085)},
    {'label': 'Hopeful', 'emoji': '🌟', 'color': const Color(0xFFF39C12)},
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _noteController.dispose();
    _customMoodController.dispose();
    super.dispose();
  }

  Future<void> _saveMood() async {
    String moodToSave;

    if (_useCustomMood) {
      if (_customMoodController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Please enter how you\'re feeling'),
            backgroundColor: AppColors.warning,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      moodToSave = _customMoodController.text.trim();
    } else {
      if (_selectedMood == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Please select a mood'),
            backgroundColor: AppColors.warning,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      moodToSave = _selectedMood!;
    }

    setState(() => _isSaving = true);

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('moods')
          .add({
            'mood': moodToSave,
            'note': _noteController.text.trim(),
            'isCustom': _useCustomMood,
            'timestamp': FieldValue.serverTimestamp(),
          });

      _noteController.clear();
      _customMoodController.clear();
      setState(() {
        _selectedMood = null;
        _useCustomMood = false;
      });

      if (mounted) {
        _animationController.forward().then(
          (_) => _animationController.reset(),
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: AppSpacing.sm),
                const Text('Mood logged successfully! 🎉'),
              ],
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppBorderRadius.md),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Used CustomScrollView to prevent overflow issues
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            children: [
              // --- Input Section ---
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.primary.withOpacity(0.05),
                      AppColors.accent.withOpacity(0.05),
                    ],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("How are you feeling?", style: AppTextStyles.h3),
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          decoration: BoxDecoration(
                            gradient: AppColors.primaryGradient,
                            borderRadius: BorderRadius.circular(
                              AppBorderRadius.full,
                            ),
                          ),
                          child: const Icon(
                            Icons.psychology_outlined,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // Toggle between preset and custom
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(
                          AppBorderRadius.full,
                        ),
                        boxShadow: AppShadows.small,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _ToggleButton(
                              text: 'Quick Select',
                              isSelected: !_useCustomMood,
                              onTap: () =>
                                  setState(() => _useCustomMood = false),
                            ),
                          ),
                          Expanded(
                            child: _ToggleButton(
                              text: 'Custom Mood',
                              isSelected: _useCustomMood,
                              onTap: () =>
                                  setState(() => _useCustomMood = true),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // Content based on toggle
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: _useCustomMood
                          ? _buildCustomMoodInput()
                          : _buildQuickSelect(),
                    ),

                    const SizedBox(height: AppSpacing.md),

                    // Note Input
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(AppBorderRadius.md),
                        boxShadow: AppShadows.small,
                      ),
                      child: TextField(
                        controller: _noteController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: "Add a note about your day... (optional)",
                          hintStyle: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textHint,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              AppBorderRadius.md,
                            ),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.all(AppSpacing.md),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // Save Button
                    CustomButton(
                      text: 'Log Mood',
                      onPressed: _saveMood,
                      isLoading: _isSaving,
                      icon: Icons.favorite_rounded,
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
            ],
          ),
        ),

        // --- History List (Sliver) ---
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(user!.uid)
              .collection('moods')
              .orderBy('timestamp', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              );
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(
                  icon: Icons.sentiment_satisfied_alt_outlined,
                  title: 'No Moods Logged Yet',
                  message: 'Start tracking your emotional wellbeing today',
                  action: Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(AppBorderRadius.md),
                    ),
                    child: Text(
                      '💡 Tip: Regular mood tracking helps identify patterns',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.primary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              );
            }

            final docs = snapshot.data!.docs;

            return SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final data = docs[index].data() as Map<String, dynamic>;
                final mood = data['mood'] ?? 'Unknown';
                final isCustom = data['isCustom'] ?? false;
                final note = data['note'] ?? '';
                final date = (data['timestamp'] as Timestamp?)?.toDate();

                // Find mood config
                final moodConfig = _moods.firstWhere(
                  (m) => m['label'] == mood,
                  orElse: () => _detailedMoods.firstWhere(
                    (m) => m['label'] == mood,
                    orElse: () => {
                      'label': mood,
                      'emoji': '💭',
                      'color': AppColors.primary,
                    },
                  ),
                );

                return Padding(
                  padding: const EdgeInsets.only(
                    left: AppSpacing.md,
                    right: AppSpacing.md,
                    top: AppSpacing.sm,
                  ),
                  child: Dismissible(
                    key: Key(docs[index].id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: AppSpacing.lg),
                      decoration: BoxDecoration(
                        color: AppColors.error,
                        borderRadius: BorderRadius.circular(AppBorderRadius.md),
                      ),
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    onDismissed: (direction) {
                      docs[index].reference.delete();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Mood entry deleted'),
                          backgroundColor: AppColors.error,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(AppBorderRadius.md),
                        boxShadow: AppShadows.small,
                        border: Border.all(
                          color: (moodConfig['color'] as Color).withOpacity(
                            0.2,
                          ),
                          width: 2,
                        ),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(AppSpacing.md),
                        leading: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: (moodConfig['color'] as Color).withOpacity(
                              0.1,
                            ),
                            borderRadius: BorderRadius.circular(
                              AppBorderRadius.sm,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              moodConfig['emoji'],
                              style: const TextStyle(fontSize: 28),
                            ),
                          ),
                        ),
                        title: Row(
                          children: [
                            Text(
                              mood,
                              style: AppTextStyles.bodyMedium.copyWith(
                                fontWeight: FontWeight.bold,
                                color: moodConfig['color'],
                              ),
                            ),
                            if (isCustom) ...[
                              const SizedBox(width: AppSpacing.xs),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.xs,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.accent.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(
                                    AppBorderRadius.xs,
                                  ),
                                ),
                                child: Text(
                                  'Custom',
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: AppColors.accent,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (note.isNotEmpty) ...[
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                note,
                                style: AppTextStyles.bodySmall,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              date != null
                                  ? DateFormat('MMM d, h:mm a').format(date)
                                  : 'Unknown date',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textHint,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }, childCount: docs.length),
            );
          },
        ),
        // Add some bottom padding for scrolling
        const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xl)),
      ],
    );
  }

  Widget _buildQuickSelect() {
    return Column(
      key: const ValueKey('quick_select'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'General Mood',
          style: AppTextStyles.bodySmall.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: _moods.map((mood) {
            final isSelected = _selectedMood == mood['label'];
            return GestureDetector(
              onTap: () => setState(() => _selectedMood = mood['label']),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: isSelected
                      ? mood['color'].withOpacity(0.2)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(AppBorderRadius.md),
                  border: isSelected
                      ? Border.all(color: mood['color'], width: 2)
                      : Border.all(color: Colors.transparent, width: 2),
                  boxShadow: isSelected ? AppShadows.small : null,
                ),
                child: Column(
                  children: [
                    Text(mood['emoji'], style: const TextStyle(fontSize: 32)),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      mood['label'],
                      style: AppTextStyles.bodySmall.copyWith(
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'Specific Feelings',
          style: AppTextStyles.bodySmall.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: _detailedMoods.map((mood) {
            final isSelected = _selectedMood == mood['label'];
            return GestureDetector(
              onTap: () => setState(() => _selectedMood = mood['label']),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? mood['color'].withOpacity(0.2)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(AppBorderRadius.full),
                  border: Border.all(
                    color: isSelected
                        ? mood['color']
                        : AppColors.textHint.withOpacity(0.3),
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(mood['emoji'], style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      mood['label'],
                      style: AppTextStyles.bodySmall.copyWith(
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: isSelected
                            ? mood['color']
                            : AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildCustomMoodInput() {
    return Column(
      key: const ValueKey('custom_mood'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Describe Your Feeling',
          style: AppTextStyles.bodySmall.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppBorderRadius.md),
            boxShadow: AppShadows.small,
          ),
          child: TextField(
            controller: _customMoodController,
            decoration: InputDecoration(
              hintText: "e.g., Reflective, Nostalgic, Motivated...",
              hintStyle: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textHint,
              ),
              prefixIcon: const Icon(
                Icons.edit_outlined,
                color: AppColors.primary,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppBorderRadius.md),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.info.withOpacity(0.1),
            borderRadius: BorderRadius.circular(AppBorderRadius.md),
            border: Border.all(color: AppColors.info.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Icon(Icons.lightbulb_outline, color: AppColors.info, size: 20),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Use this when preset moods don\'t capture what you\'re feeling',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.info,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ToggleButton extends StatelessWidget {
  final String text;
  final bool isSelected;
  final VoidCallback onTap;

  const _ToggleButton({
    required this.text,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          gradient: isSelected ? AppColors.primaryGradient : null,
          color: isSelected ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(AppBorderRadius.full),
        ),
        child: Text(
          text,
          style: AppTextStyles.bodySmall.copyWith(
            color: isSelected ? Colors.white : AppColors.textSecondary,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
