// lib/screens/symptom_checker_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../utils/constants.dart';
import '../widgets/custom_widgets.dart';

class SymptomCheckerScreen extends StatefulWidget {
  const SymptomCheckerScreen({super.key});

  @override
  State<SymptomCheckerScreen> createState() => _SymptomCheckerScreenState();
}

class _SymptomCheckerScreenState extends State<SymptomCheckerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _ageController = TextEditingController();
  final _symptomController = TextEditingController();

  String? _selectedGender;
  final List<String> _selectedSymptoms = [];
  bool _loading = false;
  Map<String, dynamic>? _result;

  final User? _currentUser = FirebaseAuth.instance.currentUser;

  @override
  void dispose() {
    _ageController.dispose();
    _symptomController.dispose();
    super.dispose();
  }

  Future<void> _checkSymptoms() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedGender == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select your gender")),
      );
      return;
    }

    if (_currentUser == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("You must be logged in.")));
      return;
    }

    setState(() {
      _loading = true;
      _result = null;
    });

    // Combine selected chips and manual input
    final allSymptoms = [
      ..._selectedSymptoms,
      if (_symptomController.text.isNotEmpty) _symptomController.text,
    ].join(', ');

    final String prompt =
        """
    Analyze the following patient data and provide a response STRICTLY in JSON format. 
    The JSON object must include three keys: 
    1. "causes": (a brief string)
    2. "urgency": (a single string: "low", "moderate", or "emergency")
    3. "recommendations": (a brief string of next steps)
    Keep the language patient-friendly.

    Patient Data:
    - Age: ${_ageController.text}
    - Gender: $_selectedGender
    - Symptoms: $allSymptoms
    """;

    try {
      final functions = FirebaseFunctions.instance;
      final callable = functions.httpsCallable('getAiResponse');
      final response = await callable.call<Map<String, dynamic>>({
        'prompt': prompt,
      });

      final aiJsonString = response.data['text'] as String;
      final aiJsonMap = jsonDecode(aiJsonString) as Map<String, dynamic>;

      // Save to Firestore
      final dataToSave = {
        'age': _ageController.text,
        'gender': _selectedGender,
        'symptoms': allSymptoms,
        'timestamp': FieldValue.serverTimestamp(),
        'causes': aiJsonMap['causes'],
        'urgency': aiJsonMap['urgency'],
        'recommendations': aiJsonMap['recommendations'],
      };

      await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser!.uid)
          .collection('symptom_checks')
          .add(dataToSave);

      setState(() {
        _result = aiJsonMap;
      });

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Analysis complete and saved'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } on FirebaseFunctionsException catch (e) {
      setState(() {
        _result = {'error': true, 'message': 'Error calling AI: ${e.message}'};
      });
    } catch (e) {
      setState(() {
        _result = {
          'error': true,
          'message': 'An error occurred: ${e.toString()}',
        };
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  void _resetForm() {
    setState(() {
      _ageController.clear();
      _selectedGender = null;
      _symptomController.clear();
      _selectedSymptoms.clear();
      _result = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Card
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(AppBorderRadius.lg),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.health_and_safety_rounded,
                      size: 48,
                      color: Colors.white,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Symptom Checker',
                      style: AppTextStyles.h2.copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Get AI-powered health insights',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Input Card
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppBorderRadius.lg),
                  boxShadow: AppShadows.medium,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Age Input
                    Text(
                      'Age',
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextFormField(
                      controller: _ageController,
                      keyboardType: TextInputType.number,
                      enabled: !_loading,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your age';
                        }
                        final age = int.tryParse(value);
                        if (age == null || age < 0 || age > 120) {
                          return 'Please enter a valid age (0-120)';
                        }
                        return null;
                      },
                      decoration: InputDecoration(
                        hintText: 'Enter your age',
                        prefixIcon: const Icon(Icons.cake_outlined),
                        filled: true,
                        fillColor: AppColors.background,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            AppBorderRadius.md,
                          ),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            AppBorderRadius.md,
                          ),
                          borderSide: const BorderSide(
                            color: AppColors.primary,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // Gender Selection
                    Text(
                      'Gender',
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.sm,
                      children: [
                        _buildGenderChip('Male', Icons.male),
                        _buildGenderChip('Female', Icons.female),
                        _buildGenderChip('Other', Icons.transgender),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // Common Symptoms
                    Text(
                      'Common Symptoms (tap to select)',
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: CommonSymptoms.symptoms.map((symptom) {
                        return _buildSymptomChip(symptom);
                      }).toList(),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // Additional Symptoms
                    Text(
                      'Additional Symptoms',
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextFormField(
                      controller: _symptomController,
                      maxLines: 3,
                      enabled: !_loading,
                      decoration: InputDecoration(
                        hintText: 'Describe any other symptoms...',
                        prefixIcon: const Padding(
                          padding: EdgeInsets.only(bottom: 48),
                          child: Icon(Icons.notes_outlined),
                        ),
                        filled: true,
                        fillColor: AppColors.background,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            AppBorderRadius.md,
                          ),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            AppBorderRadius.md,
                          ),
                          borderSide: const BorderSide(
                            color: AppColors.primary,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: CustomButton(
                            text: 'Reset',
                            onPressed: _loading ? null : _resetForm,
                            outlined: true,
                            icon: Icons.refresh,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          flex: 2,
                          child: CustomButton(
                            text: 'Analyze',
                            onPressed: _loading ? null : _checkSymptoms,
                            isLoading: _loading,
                            icon: Icons.search,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Results
              if (_result != null) ...[
                const SizedBox(height: AppSpacing.lg),
                _buildResultsCard(),
              ],

              const SizedBox(height: AppSpacing.lg),

              // Disclaimer
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppBorderRadius.md),
                  border: Border.all(color: AppColors.error.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: AppColors.error,
                      size: 24,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'This is an AI assistant and not a substitute for professional medical advice. Please consult a doctor.',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGenderChip(String gender, IconData icon) {
    final isSelected = _selectedGender == gender;

    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: AppSpacing.xs),
          Text(gender),
        ],
      ),
      selected: isSelected,
      onSelected: _loading
          ? null
          : (selected) {
              setState(() {
                _selectedGender = selected ? gender : null;
              });
            },
      backgroundColor: AppColors.background,
      selectedColor: AppColors.primary.withOpacity(0.2),
      checkmarkColor: AppColors.primary,
      side: BorderSide(
        color: isSelected ? AppColors.primary : Colors.transparent,
        width: 2,
      ),
    );
  }

  Widget _buildSymptomChip(String symptom) {
    final isSelected = _selectedSymptoms.contains(symptom);

    return FilterChip(
      label: Text(symptom),
      selected: isSelected,
      onSelected: _loading
          ? null
          : (selected) {
              setState(() {
                if (selected) {
                  _selectedSymptoms.add(symptom);
                } else {
                  _selectedSymptoms.remove(symptom);
                }
              });
            },
      backgroundColor: AppColors.background,
      selectedColor: AppColors.primary.withOpacity(0.2),
      checkmarkColor: AppColors.primary,
      side: BorderSide(
        color: isSelected ? AppColors.primary : Colors.transparent,
        width: 2,
      ),
    );
  }

  Widget _buildResultsCard() {
    if (_result!['error'] == true) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.error.withOpacity(0.1),
          borderRadius: BorderRadius.circular(AppBorderRadius.lg),
          border: Border.all(color: AppColors.error),
        ),
        child: Column(
          children: [
            const Icon(Icons.error_outline, color: AppColors.error, size: 48),
            const SizedBox(height: AppSpacing.sm),
            Text(
              _result!['message'],
              style: AppTextStyles.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final urgency = _result!['urgency'] ?? 'low';
    final causes = _result!['causes'] ?? '';
    final recommendations = _result!['recommendations'] ?? '';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppBorderRadius.lg),
        boxShadow: AppShadows.large,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Analysis Results', style: AppTextStyles.h3),
              UrgencyBadge(urgency: urgency),
            ],
          ),
          const Divider(height: AppSpacing.lg),

          _buildResultSection(
            icon: Icons.coronavirus_outlined,
            title: 'Possible Causes',
            content: causes,
          ),
          const SizedBox(height: AppSpacing.md),

          _buildResultSection(
            icon: Icons.medical_services_outlined,
            title: 'Recommendations',
            content: recommendations,
          ),
        ],
      ),
    );
  }

  Widget _buildResultSection({
    required IconData icon,
    required String title,
    required String content,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: AppColors.primary, size: 20),
            const SizedBox(width: AppSpacing.sm),
            Text(
              title,
              style: AppTextStyles.bodyMedium.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(AppBorderRadius.md),
          ),
          child: Text(content, style: AppTextStyles.bodyMedium),
        ),
      ],
    );
  }
}
