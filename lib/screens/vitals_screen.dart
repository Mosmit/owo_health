import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../utils/constants.dart';
import '../widgets/custom_widgets.dart';

class VitalsScreen extends StatefulWidget {
  const VitalsScreen({super.key});

  @override
  State<VitalsScreen> createState() => _VitalsScreenState();
}

class _VitalsScreenState extends State<VitalsScreen> {
  final User? user = FirebaseAuth.instance.currentUser;
  final _sysController = TextEditingController();
  final _diaController = TextEditingController();
  final _bpmController = TextEditingController();
  final _weightController = TextEditingController();
  bool _isSaving = false;

  Future<void> _saveVitals() async {
    setState(() => _isSaving = true);
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('vitals')
          .add({
            'sys': int.tryParse(_sysController.text),
            'dia': int.tryParse(_diaController.text),
            'bpm': int.tryParse(_bpmController.text),
            'weight': double.tryParse(_weightController.text),
            'timestamp': FieldValue.serverTimestamp(),
          });
      _sysController.clear();
      _diaController.clear();
      _bpmController.clear();
      _weightController.clear();
      if (mounted) FocusScope.of(context).unfocus();
    } catch (e) {
      debugPrint(e.toString());
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        // --- Input Card ---
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Log Vitals", style: AppTextStyles.h3),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: CustomTextField(
                        controller: _sysController,
                        label: "Sys (mmHg)",
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: CustomTextField(
                        controller: _diaController,
                        label: "Dia (mmHg)",
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: CustomTextField(
                        controller: _bpmController,
                        label: "Heart Rate",
                        keyboardType: TextInputType.number,
                        prefixIcon: Icons.favorite,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: CustomTextField(
                        controller: _weightController,
                        label: "Weight (kg)",
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                SizedBox(
                  width: double.infinity,
                  child: CustomButton(
                    text: "Save Record",
                    onPressed: _saveVitals,
                    isLoading: _isSaving,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

        // --- Chart Section (Heart Rate) ---
        Text("Heart Rate History", style: AppTextStyles.h3),
        const SizedBox(height: AppSpacing.sm),
        Container(
          height: 250,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(user!.uid)
                .collection('vitals')
                .orderBy('timestamp', descending: true)
                .limit(7)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData)
                return const Center(child: CircularProgressIndicator());
              final docs = snapshot.data!.docs;
              if (docs.isEmpty) return const Center(child: Text("No data yet"));

              // Prepare spots
              List<FlSpot> spots = [];
              for (int i = 0; i < docs.length; i++) {
                final data = docs[i].data() as Map<String, dynamic>;
                final bpm = data['bpm'];
                if (bpm != null) {
                  spots.add(
                    FlSpot((docs.length - 1 - i).toDouble(), bpm.toDouble()),
                  );
                }
              }

              return LineChart(
                LineChartData(
                  gridData: const FlGridData(show: true),
                  titlesData: const FlTitlesData(show: false),
                  borderData: FlBorderData(
                    show: true,
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: AppColors.primary,
                      barWidth: 3,
                      dotData: const FlDotData(show: true),
                      belowBarData: BarAreaData(
                        show: true,
                        color: AppColors.primary.withOpacity(0.1),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),

        const SizedBox(height: AppSpacing.lg),
        // --- Recent List ---
        Text("Recent Logs", style: AppTextStyles.h3),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(user!.uid)
              .collection('vitals')
              .orderBy('timestamp', descending: true)
              .limit(10)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const SizedBox();
            return Column(
              children: snapshot.data!.docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final date = (data['timestamp'] as Timestamp?)?.toDate();
                return Card(
                  margin: const EdgeInsets.only(top: 8),
                  child: ListTile(
                    dense: true,
                    title: Text(
                      date != null
                          ? DateFormat('MMM d, yyyy').format(date)
                          : "",
                    ),
                    subtitle: Text(
                      "BP: ${data['sys'] ?? '-'}/${data['dia'] ?? '-'}  |  HR: ${data['bpm'] ?? '-'}  |  Wt: ${data['weight'] ?? '-'}",
                      style: const TextStyle(color: AppColors.textPrimary),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20),
                      onPressed: () => doc.reference.delete(),
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
}
