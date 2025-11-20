// lib/screens/dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../utils/constants.dart';
import '../widgets/custom_widgets.dart';
import 'symptom_check_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final userName = user?.displayName?.split(' ').first ?? 'User';
    final greeting = _getGreeting();

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        // Welcome Header
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(AppBorderRadius.lg),
            boxShadow: AppShadows.medium,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$greeting,',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          userName,
                          style: AppTextStyles.h2.copyWith(color: Colors.white),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'How are you feeling today?',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.health_and_safety_rounded,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

        // Quick Actions
        Text('Quick Actions', style: AppTextStyles.h3),
        const SizedBox(height: AppSpacing.md),

        Row(
          children: [
            Expanded(
              child: _QuickActionCard(
                icon: Icons.psychology_outlined,
                title: 'Symptom Check',
                color: AppColors.primary,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SymptomCheckScreen(),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _QuickActionCard(
                icon: Icons.emergency_outlined,
                title: 'Emergency',
                color: AppColors.error,
                onTap: () {
                  _showEmergencyDialog(context);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),

        // Stats Overview
        Text('Today\'s Overview', style: AppTextStyles.h3),
        const SizedBox(height: AppSpacing.md),

        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(user?.uid)
              .collection('moods')
              .where(
                'timestamp',
                isGreaterThan: DateTime.now().subtract(const Duration(days: 1)),
              )
              .snapshots(),
          builder: (context, moodSnapshot) {
            final moodCount = moodSnapshot.hasData
                ? moodSnapshot.data!.docs.length
                : 0;

            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(user?.uid)
                  .collection('vitals')
                  .where(
                    'timestamp',
                    isGreaterThan: DateTime.now().subtract(
                      const Duration(days: 1),
                    ),
                  )
                  .snapshots(),
              builder: (context, vitalsSnapshot) {
                final vitalsCount = vitalsSnapshot.hasData
                    ? vitalsSnapshot.data!.docs.length
                    : 0;

                return Row(
                  children: [
                    Expanded(
                      child: StatCard(
                        title: 'Mood Logs',
                        value: '$moodCount',
                        icon: Icons.sentiment_satisfied_alt,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: StatCard(
                        title: 'Vitals Logged',
                        value: '$vitalsCount',
                        icon: Icons.monitor_heart,
                        color: AppColors.accent,
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
        const SizedBox(height: AppSpacing.lg),

        // Recent Activity
        Text('Recent Activity', style: AppTextStyles.h3),
        const SizedBox(height: AppSpacing.md),

        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(user?.uid)
              .collection('symptom_checks')
              .orderBy('timestamp', descending: true)
              .limit(3)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(AppSpacing.xl),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppBorderRadius.md),
                  border: Border.all(
                    color: AppColors.textHint.withOpacity(0.2),
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.health_and_safety_outlined,
                      size: 48,
                      color: AppColors.textHint,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'No recent symptom checks',
                      style: AppTextStyles.bodyMedium,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Start by checking your symptoms',
                      style: AppTextStyles.bodySmall,
                    ),
                  ],
                ),
              );
            }

            return Column(
              children: snapshot.data!.docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final urgency = data['urgency'] ?? 'low';
                final symptoms = data['symptoms'] ?? 'No symptoms listed';
                final timestamp = (data['timestamp'] as Timestamp?)?.toDate();
                final dateStr = timestamp != null
                    ? DateFormat('MMM dd, h:mm a').format(timestamp)
                    : 'Unknown date';

                return Container(
                  margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppBorderRadius.md),
                    boxShadow: AppShadows.small,
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(AppSpacing.md),
                    leading: Container(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: _getUrgencyColor(urgency).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(AppBorderRadius.sm),
                      ),
                      child: Icon(
                        Icons.medical_services_outlined,
                        color: _getUrgencyColor(urgency),
                      ),
                    ),
                    title: Text(
                      symptoms,
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: AppSpacing.xs),
                        UrgencyBadge(urgency: urgency),
                        const SizedBox(height: AppSpacing.xs),
                        Text(dateStr, style: AppTextStyles.bodySmall),
                      ],
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  Color _getUrgencyColor(String urgency) {
    switch (urgency.toLowerCase()) {
      case "emergency":
        return AppColors.urgencyEmergency;
      case "moderate":
        return AppColors.urgencyModerate;
      case "low":
      default:
        return AppColors.urgencyLow;
    }
  }

  void _showEmergencyDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.emergency, color: AppColors.error),
            const SizedBox(width: AppSpacing.sm),
            const Text('Emergency'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('If you\'re experiencing a medical emergency:'),
            SizedBox(height: AppSpacing.md),
            Text('🚨 Call emergency services immediately'),
            Text('📞 Contact: 911 (US) or your local emergency number'),
          ],
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppBorderRadius.md),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.title,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppBorderRadius.lg),
        boxShadow: AppShadows.small,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppBorderRadius.lg),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 32),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  title,
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
