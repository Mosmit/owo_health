// lib/screens/symptom_check_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/constants.dart';
import '../widgets/custom_widgets.dart';

class SymptomCheckScreen extends StatefulWidget {
  const SymptomCheckScreen({super.key});

  @override
  State<SymptomCheckScreen> createState() => _SymptomCheckScreenState();
}

class _SymptomCheckScreenState extends State<SymptomCheckScreen> {
  final _formKey = GlobalKey<FormState>();
  final _symptomsController = TextEditingController();
  final _ageController = TextEditingController();
  String _selectedGender = 'Male';
  String _selectedUrgency = 'Low';
  bool _isSubmitting = false;

  final List<String> _commonSymptoms = [
    'Headache',
    'Fever',
    'Cough',
    'Sore Throat',
    'Fatigue',
    'Nausea',
    'Dizziness',
    'Chest Pain',
    'Shortness of Breath',
    'Abdominal Pain',
    'Body Aches',
    'Chills',
  ];

  final List<String> _selectedSymptoms = [];

  @override
  void dispose() {
    _symptomsController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  Future<void> _submitSymptomCheck() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedSymptoms.isEmpty && _symptomsController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select or enter at least one symptom'),
          backgroundColor: AppColors.warning,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Combine selected symptoms with typed symptoms
      final allSymptoms = [
        ..._selectedSymptoms,
        if (_symptomsController.text.trim().isNotEmpty)
          _symptomsController.text.trim(),
      ].join(', ');

      // Generate simple recommendations based on urgency
      String recommendations = _getRecommendations(_selectedUrgency);
      String causes = _getPossibleCauses(allSymptoms);

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('symptom_checks')
          .add({
            'symptoms': allSymptoms,
            'age': int.tryParse(_ageController.text) ?? 0,
            'gender': _selectedGender,
            'urgency': _selectedUrgency,
            'recommendations': recommendations,
            'causes': causes,
            'timestamp': FieldValue.serverTimestamp(),
          });

      if (mounted) {
        // Show success dialog
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppBorderRadius.lg),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: _getUrgencyColor(_selectedUrgency).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check_circle_outline,
                    size: 64,
                    color: _getUrgencyColor(_selectedUrgency),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Symptom Check Complete',
                  style: AppTextStyles.h3,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Your symptoms have been recorded',
                  style: AppTextStyles.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.lg),
                UrgencyBadge(urgency: _selectedUrgency),
                const SizedBox(height: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(AppBorderRadius.md),
                  ),
                  child: Text(
                    recommendations,
                    style: AppTextStyles.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // Close dialog
                  Navigator.pop(context); // Go back to dashboard
                },
                child: const Text('Done'),
              ),
            ],
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
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  String _getRecommendations(String urgency) {
    switch (urgency.toLowerCase()) {
      case 'emergency':
        return '🚨 Seek immediate medical attention. Call emergency services or go to the nearest emergency room.';
      case 'moderate':
        return '⚠️ Consider scheduling an appointment with your doctor soon. Monitor your symptoms closely.';
      case 'low':
      default:
        return '✓ Rest, stay hydrated, and monitor your symptoms. Consult a doctor if symptoms worsen.';
    }
  }

  String _getPossibleCauses(String symptoms) {
    final lower = symptoms.toLowerCase();
    if (lower.contains('fever') && lower.contains('cough')) {
      return 'Common cold, flu, or respiratory infection';
    } else if (lower.contains('headache')) {
      return 'Tension, dehydration, stress, or migraine';
    } else if (lower.contains('chest pain')) {
      return 'Requires medical evaluation - could be cardiac, respiratory, or muscular';
    } else if (lower.contains('abdominal pain')) {
      return 'Digestive issues, gastritis, or food sensitivity';
    }
    return 'Multiple possible causes - consult healthcare provider for accurate diagnosis';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Symptom Check'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(AppBorderRadius.lg),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.health_and_safety_rounded,
                    size: 48,
                    color: Colors.white,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Tell us what you\'re experiencing',
                    style: AppTextStyles.h3.copyWith(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Select symptoms or describe them below',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: Colors.white.withOpacity(0.9),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Common Symptoms
            Text('Common Symptoms', style: AppTextStyles.h3),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Tap to select (you can choose multiple)',
              style: AppTextStyles.bodySmall,
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: _commonSymptoms.map((symptom) {
                final isSelected = _selectedSymptoms.contains(symptom);
                return FilterChip(
                  label: Text(symptom),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedSymptoms.add(symptom);
                      } else {
                        _selectedSymptoms.remove(symptom);
                      }
                    });
                  },
                  selectedColor: AppColors.primary.withOpacity(0.2),
                  checkmarkColor: AppColors.primary,
                  labelStyle: TextStyle(
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.textPrimary,
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                  side: BorderSide(
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.textHint.withOpacity(0.3),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Other Symptoms
            Text('Other Symptoms', style: AppTextStyles.h3),
            const SizedBox(height: AppSpacing.sm),
            CustomTextField(
              controller: _symptomsController,
              label: 'Describe any other symptoms',
              prefixIcon: Icons.description_outlined,
              maxLines: 3,
            ),
            const SizedBox(height: AppSpacing.lg),

            // Personal Info
            Text('Personal Information', style: AppTextStyles.h3),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: CustomTextField(
                    controller: _ageController,
                    label: 'Age',
                    prefixIcon: Icons.cake_outlined,
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Required';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppBorderRadius.md),
                      border: Border.all(
                        color: AppColors.textHint.withOpacity(0.3),
                      ),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedGender,
                        isExpanded: true,
                        items: ['Male', 'Female', 'Other'].map((gender) {
                          return DropdownMenuItem(
                            value: gender,
                            child: Text(gender),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedGender = value!;
                          });
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            // Urgency Level
            Text('Urgency Level', style: AppTextStyles.h3),
            const SizedBox(height: AppSpacing.md),
            Column(
              children: [
                _UrgencyOption(
                  title: 'Low',
                  description:
                      'Mild symptoms, can wait for regular appointment',
                  color: AppColors.urgencyLow,
                  isSelected: _selectedUrgency == 'Low',
                  onTap: () => setState(() => _selectedUrgency = 'Low'),
                ),
                const SizedBox(height: AppSpacing.sm),
                _UrgencyOption(
                  title: 'Moderate',
                  description: 'Concerning symptoms, should see doctor soon',
                  color: AppColors.urgencyModerate,
                  isSelected: _selectedUrgency == 'Moderate',
                  onTap: () => setState(() => _selectedUrgency = 'Moderate'),
                ),
                const SizedBox(height: AppSpacing.sm),
                _UrgencyOption(
                  title: 'Emergency',
                  description: 'Severe symptoms, need immediate attention',
                  color: AppColors.urgencyEmergency,
                  isSelected: _selectedUrgency == 'Emergency',
                  onTap: () => setState(() => _selectedUrgency = 'Emergency'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),

            // Submit Button
            CustomButton(
              text: 'Submit Symptom Check',
              onPressed: _submitSymptomCheck,
              isLoading: _isSubmitting,
              icon: Icons.check_circle_outline,
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }
}

class _UrgencyOption extends StatelessWidget {
  final String title;
  final String description;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _UrgencyOption({
    required this.title,
    required this.description,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppBorderRadius.md),
        border: Border.all(
          color: isSelected ? color : AppColors.textHint.withOpacity(0.3),
          width: isSelected ? 2 : 1,
        ),
        boxShadow: isSelected ? AppShadows.small : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppBorderRadius.md),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: color, width: 2),
                    color: isSelected ? color : Colors.transparent,
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, size: 16, color: Colors.white)
                      : null,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(description, style: AppTextStyles.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
