// lib/screens/history_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../utils/constants.dart';
import '../widgets/custom_widgets.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  bool _showLineChart = true;
  String _selectedFilter = 'All';

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

  Widget _bottomTitleWidgets(
    double value,
    TitleMeta meta,
    List<String> sortedDays,
  ) {
    const style = TextStyle(fontSize: 10, color: AppColors.textSecondary);
    int index = value.toInt();
    if (index >= 0 && index < sortedDays.length) {
      return Padding(
        padding: const EdgeInsets.only(top: 8.0),
        child: Text(sortedDays[index], style: style),
      );
    }
    return const Text("", style: style);
  }

  Future<void> _deleteEntry(String docId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Entry'),
        content: const Text('Are you sure you want to delete this entry?'),
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
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && _currentUser != null) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(_currentUser!.uid)
            .collection('symptom_checks')
            .doc(docId)
            .delete();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Entry deleted'),
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
      return const EmptyState(
        icon: Icons.error_outline,
        title: 'Not Logged In',
        message: 'Please log in to view your history',
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser!.uid)
          .collection('symptom_checks')
          .orderBy('timestamp', descending: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const EmptyState(
            icon: Icons.history_outlined,
            title: 'No History Yet',
            message: 'Your symptom check history will appear here',
          );
        }

        final docs = snapshot.data!.docs;

        // Process Data
        int mildCount = 0;
        int moderateCount = 0;
        int emergencyCount = 0;
        Map<String, Map<String, int>> dailyCounts = {};

        for (var doc in docs) {
          final data = doc.data() as Map<String, dynamic>;
          final urgency = data['urgency']?.toLowerCase() ?? 'low';

          switch (urgency) {
            case "emergency":
              emergencyCount++;
              break;
            case "moderate":
              moderateCount++;
              break;
            case "low":
            default:
              mildCount++;
          }

          final timestamp =
              (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
          final day = DateFormat('MM/dd').format(timestamp);

          dailyCounts.putIfAbsent(
            day,
            () => {"low": 0, "moderate": 0, "emergency": 0},
          );
          dailyCounts[day]![urgency] = (dailyCounts[day]![urgency] ?? 0) + 1;
        }

        // Prepare chart data
        final sortedDays = dailyCounts.keys.toList()
          ..sort(
            (a, b) => DateFormat(
              "MM/dd",
            ).parse(a).compareTo(DateFormat("MM/dd").parse(b)),
          );

        List<FlSpot> mildSpots = [];
        List<FlSpot> moderateSpots = [];
        List<FlSpot> emergencySpots = [];
        List<BarChartGroupData> barGroups = [];

        for (int i = 0; i < sortedDays.length; i++) {
          String day = sortedDays[i];
          double low = dailyCounts[day]!["low"]!.toDouble();
          double moderate = dailyCounts[day]!["moderate"]!.toDouble();
          double emergency = dailyCounts[day]!["emergency"]!.toDouble();

          mildSpots.add(FlSpot(i.toDouble(), low));
          moderateSpots.add(FlSpot(i.toDouble(), moderate));
          emergencySpots.add(FlSpot(i.toDouble(), emergency));

          barGroups.add(
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: low,
                  color: AppColors.urgencyLow,
                  width: 12,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(4),
                  ),
                ),
                BarChartRodData(
                  toY: moderate,
                  color: AppColors.urgencyModerate,
                  width: 12,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(4),
                  ),
                ),
                BarChartRodData(
                  toY: emergency,
                  color: AppColors.urgencyEmergency,
                  width: 12,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(4),
                  ),
                ),
              ],
            ),
          );
        }

        final totalChecks = docs.length;

        return SingleChildScrollView(
          child: Column(
            children: [
              // Summary Stats
              Container(
                margin: const EdgeInsets.all(AppSpacing.md),
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(AppBorderRadius.lg),
                  boxShadow: AppShadows.medium,
                ),
                child: Column(
                  children: [
                    Text(
                      'Total Checks',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '$totalChecks',
                      style: AppTextStyles.h1.copyWith(
                        color: Colors.white,
                        fontSize: 48,
                      ),
                    ),
                  ],
                ),
              ),

              // Urgency Distribution
              Container(
                margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppBorderRadius.lg),
                  boxShadow: AppShadows.small,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Urgency Distribution', style: AppTextStyles.h3),
                    const SizedBox(height: AppSpacing.lg),
                    SizedBox(
                      height: 200,
                      child: PieChart(
                        PieChartData(
                          sections: [
                            PieChartSectionData(
                              value: mildCount.toDouble(),
                              title: "$mildCount",
                              color: AppColors.urgencyLow,
                              radius: 80,
                              titleStyle: AppTextStyles.bodyMedium.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            PieChartSectionData(
                              value: moderateCount.toDouble(),
                              title: "$moderateCount",
                              color: AppColors.urgencyModerate,
                              radius: 80,
                              titleStyle: AppTextStyles.bodyMedium.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            PieChartSectionData(
                              value: emergencyCount.toDouble(),
                              title: "$emergencyCount",
                              color: AppColors.urgencyEmergency,
                              radius: 80,
                              titleStyle: AppTextStyles.bodyMedium.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                          sectionsSpace: 2,
                          centerSpaceRadius: 50,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildLegendItem(
                          'Low',
                          AppColors.urgencyLow,
                          mildCount,
                        ),
                        _buildLegendItem(
                          'Moderate',
                          AppColors.urgencyModerate,
                          moderateCount,
                        ),
                        _buildLegendItem(
                          'Emergency',
                          AppColors.urgencyEmergency,
                          emergencyCount,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.md),

              // Trend Chart
              Container(
                margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppBorderRadius.lg),
                  boxShadow: AppShadows.small,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Trend Over Time', style: AppTextStyles.h3),
                        Container(
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(
                              AppBorderRadius.full,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildChartToggle('Line', true),
                              _buildChartToggle('Bar', false),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    SizedBox(
                      height: 250,
                      child: _showLineChart
                          ? LineChart(
                              LineChartData(
                                gridData: const FlGridData(show: true),
                                lineBarsData: [
                                  LineChartBarData(
                                    spots: mildSpots,
                                    color: AppColors.urgencyLow,
                                    isCurved: true,
                                    dotData: const FlDotData(show: true),
                                    belowBarData: BarAreaData(
                                      show: true,
                                      color: AppColors.urgencyLow.withOpacity(
                                        0.2,
                                      ),
                                    ),
                                  ),
                                  LineChartBarData(
                                    spots: moderateSpots,
                                    color: AppColors.urgencyModerate,
                                    isCurved: true,
                                    dotData: const FlDotData(show: true),
                                    belowBarData: BarAreaData(
                                      show: true,
                                      color: AppColors.urgencyModerate
                                          .withOpacity(0.2),
                                    ),
                                  ),
                                  LineChartBarData(
                                    spots: emergencySpots,
                                    color: AppColors.urgencyEmergency,
                                    isCurved: true,
                                    dotData: const FlDotData(show: true),
                                    belowBarData: BarAreaData(
                                      show: true,
                                      color: AppColors.urgencyEmergency
                                          .withOpacity(0.2),
                                    ),
                                  ),
                                ],
                                titlesData: FlTitlesData(
                                  bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      getTitlesWidget: (val, meta) =>
                                          _bottomTitleWidgets(
                                            val,
                                            meta,
                                            sortedDays,
                                          ),
                                    ),
                                  ),
                                  leftTitles: AxisTitles(
                                    sideTitles: SideTitles(showTitles: true),
                                  ),
                                  topTitles: AxisTitles(
                                    sideTitles: SideTitles(showTitles: false),
                                  ),
                                  rightTitles: AxisTitles(
                                    sideTitles: SideTitles(showTitles: false),
                                  ),
                                ),
                              ),
                            )
                          : BarChart(
                              BarChartData(
                                barGroups: barGroups,
                                gridData: const FlGridData(show: true),
                                titlesData: FlTitlesData(
                                  bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      getTitlesWidget: (val, meta) =>
                                          _bottomTitleWidgets(
                                            val,
                                            meta,
                                            sortedDays,
                                          ),
                                    ),
                                  ),
                                  leftTitles: AxisTitles(
                                    sideTitles: SideTitles(showTitles: true),
                                  ),
                                  topTitles: AxisTitles(
                                    sideTitles: SideTitles(showTitles: false),
                                  ),
                                  rightTitles: AxisTitles(
                                    sideTitles: SideTitles(showTitles: false),
                                  ),
                                ),
                              ),
                            ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.md),

              // History List Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Recent Checks', style: AppTextStyles.h3),
                    TextButton.icon(
                      onPressed: () {
                        // Could add filter functionality
                      },
                      icon: const Icon(Icons.filter_list, size: 18),
                      label: const Text('Filter'),
                    ),
                  ],
                ),
              ),

              // History List
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.all(AppSpacing.md),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final doc = docs[docs.length - 1 - index];
                  final data = doc.data() as Map<String, dynamic>;
                  final urgency = data['urgency'] ?? 'low';
                  final symptoms = data['symptoms'] ?? 'No symptoms listed';
                  final timestamp = (data['timestamp'] as Timestamp?)?.toDate();
                  final dateStr = timestamp != null
                      ? DateFormat('MMM dd, yyyy • h:mm a').format(timestamp)
                      : 'Unknown date';

                  return Dismissible(
                    key: Key(doc.id),
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
                    onDismissed: (direction) => _deleteEntry(doc.id),
                    child: Container(
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
                            borderRadius: BorderRadius.circular(
                              AppBorderRadius.sm,
                            ),
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
                          maxLines: 2,
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
                        trailing: const Icon(
                          Icons.chevron_right,
                          color: AppColors.textHint,
                        ),
                        onTap: () {
                          // Could open detail view
                          showModalBottomSheet(
                            context: context,
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(AppBorderRadius.lg),
                              ),
                            ),
                            builder: (context) => _buildDetailSheet(data),
                          );
                        },
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLegendItem(String label, Color color, int count) {
    return Column(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          label,
          style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600),
        ),
        Text('$count', style: AppTextStyles.bodySmall),
      ],
    );
  }

  Widget _buildChartToggle(String label, bool isLine) {
    final isSelected = _showLineChart == isLine;

    return GestureDetector(
      onTap: () {
        setState(() {
          _showLineChart = isLine;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(AppBorderRadius.full),
        ),
        child: Text(
          label,
          style: AppTextStyles.bodySmall.copyWith(
            color: isSelected ? Colors.white : AppColors.textSecondary,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildDetailSheet(Map<String, dynamic> data) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Check Details', style: AppTextStyles.h3),
              UrgencyBadge(urgency: data['urgency'] ?? 'low'),
            ],
          ),
          const Divider(height: AppSpacing.lg),

          _buildDetailRow('Age', data['age'] ?? 'N/A'),
          _buildDetailRow('Gender', data['gender'] ?? 'N/A'),
          _buildDetailRow('Symptoms', data['symptoms'] ?? 'N/A'),

          if (data['causes'] != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              'Possible Causes',
              style: AppTextStyles.bodyMedium.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(AppBorderRadius.md),
              ),
              child: Text(data['causes'], style: AppTextStyles.bodyMedium),
            ),
          ],

          if (data['recommendations'] != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              'Recommendations',
              style: AppTextStyles.bodyMedium.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(AppBorderRadius.md),
              ),
              child: Text(
                data['recommendations'],
                style: AppTextStyles.bodyMedium,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTextStyles.bodyMedium.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
