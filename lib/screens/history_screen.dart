import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  bool _showLineChart = true; // Toggle for the chart type

  // Helper function to get the color for each urgency level
  Color _getUrgencyColor(String urgency) {
    switch (urgency.toLowerCase()) {
      case "emergency":
        return Colors.red;
      case "moderate":
        return Colors.orange;
      case "low":
      default:
        return Colors.green;
    }
  }

  // Helper function for chart bottom axis titles
  Widget _bottomTitleWidgets(
    double value,
    TitleMeta meta,
    List<String> sortedDays,
  ) {
    const style = TextStyle(fontSize: 10);
    int index = value.toInt();
    if (index >= 0 && index < sortedDays.length) {
      return Padding(
        padding: const EdgeInsets.only(top: 8.0),
        child: Text(sortedDays[index], style: style),
      );
    }
    return const Text("", style: style);
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUser == null) {
      return const Center(child: Text("Error: No user logged in."));
    }

    return StreamBuilder<QuerySnapshot>(
      // 1. Stream from the user-specific, private collection
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser!.uid)
          .collection('symptom_checks')
          .orderBy('timestamp', descending: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text(
              "No symptom history recorded yet.",
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          );
        }

        final docs = snapshot.data!.docs;

        // --- 2. Process Data for Charts ---
        int mildCount = 0;
        int moderateCount = 0;
        int emergencyCount = 0;

        // Group counts by day for the line/bar charts
        Map<String, Map<String, int>> dailyCounts = {};

        for (var doc in docs) {
          final data = doc.data() as Map<String, dynamic>;

          // 2a. Read the clean urgency data (no parsing needed!)
          final urgency = data['urgency']?.toLowerCase() ?? 'low';

          // Count for Pie Chart
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

          // 2b. Group for Line/Bar Chart
          final timestamp =
              (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
          final day = DateFormat('MM/dd').format(timestamp);

          dailyCounts.putIfAbsent(
            day,
            () => {"low": 0, "moderate": 0, "emergency": 0},
          );
          dailyCounts[day]![urgency] = (dailyCounts[day]![urgency] ?? 0) + 1;
        }

        // --- 3. Prepare Data for FL_Chart ---
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
                BarChartRodData(toY: low, color: Colors.green, width: 5),
                BarChartRodData(toY: moderate, color: Colors.orange, width: 5),
                BarChartRodData(toY: emergency, color: Colors.red, width: 5),
              ],
            ),
          );
        }

        // --- 4. Build the UI ---
        return SingleChildScrollView(
          child: Column(
            children: [
              // --- Pie Chart Summary ---
              SizedBox(
                height: 200,
                child: PieChart(
                  PieChartData(
                    sections: [
                      PieChartSectionData(
                        value: mildCount.toDouble(),
                        title: "Low\n$mildCount",
                        color: Colors.green,
                        radius: 60,
                      ),
                      PieChartSectionData(
                        value: moderateCount.toDouble(),
                        title: "Moderate\n$moderateCount",
                        color: Colors.orange,
                        radius: 60,
                      ),
                      PieChartSectionData(
                        value: emergencyCount.toDouble(),
                        title: "Emergency\n$emergencyCount",
                        color: Colors.red,
                        radius: 60,
                      ),
                    ],
                    centerSpaceRadius: 40,
                  ),
                ),
              ),
              const Divider(),

              // --- Chart Toggle ---
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Line"),
                  Switch(
                    value: _showLineChart,
                    onChanged: (value) {
                      setState(() {
                        _showLineChart = value;
                      });
                    },
                  ),
                  const Text("Bar"),
                ],
              ),

              // --- Line/Bar Chart ---
              SizedBox(
                height: 250,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: _showLineChart
                      ? LineChart(
                          LineChartData(
                            lineBarsData: [
                              LineChartBarData(
                                spots: mildSpots,
                                color: Colors.green,
                                isCurved: true,
                              ),
                              LineChartBarData(
                                spots: moderateSpots,
                                color: Colors.orange,
                                isCurved: true,
                              ),
                              LineChartBarData(
                                spots: emergencySpots,
                                color: Colors.red,
                                isCurved: true,
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
              ),
              const Divider(),

              // --- History List ---
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  // Show newest first
                  final doc = docs[docs.length - 1 - index];
                  final data = doc.data() as Map<String, dynamic>;
                  final urgency = data['urgency'] ?? 'low';

                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: _getUrgencyColor(urgency),
                        child: const Icon(
                          Icons.warning_amber,
                          color: Colors.white,
                        ),
                      ),
                      title: Text(data['symptoms'] ?? 'No symptoms listed'),
                      subtitle: Text("Urgency: $urgency"),
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
}
