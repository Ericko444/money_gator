import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'services/dashboard_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<DashboardStats> _statsFuture;
  int _touchedIndex = -1;
  int _touchedWeekIndex = -1;

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  void _refreshData() {
    setState(() {
      _statsFuture = DashboardService().getStats();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("The Reality", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.black,
        actions: [
          IconButton(icon: const Icon(Icons.refresh, color: Colors.white), onPressed: _refreshData)
        ],
      ),
      body: FutureBuilder<DashboardStats>(
        future: _statsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}", style: const TextStyle(color: Colors.red)));
          if (!snapshot.hasData) return const Center(child: Text("No Data", style: TextStyle(color: Colors.white)));

          final stats = snapshot.data!;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Row 1: This Month + This Week
                Row(
                  children: [
                    Expanded(child: _buildStatCard("This Month", stats.totalMonth, Colors.blueAccent)),
                    const SizedBox(width: 16),
                    Expanded(child: _buildStatCard("This Week", stats.totalWeek, Colors.purpleAccent)),
                  ],
                ),

                const SizedBox(height: 16),

                // Row 2: Today (full width)
                _buildStatCard("Today", stats.totalToday, _getTodayColor(stats.totalToday)),

                const SizedBox(height: 40),

                // Monthly pie chart
                const Text("Where it went", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                SizedBox(
                  height: 250,
                  child: stats.categoryBreakdown.isEmpty
                      ? _buildEmptyState("No spending this month yet.")
                      : _buildPieChart(stats.categoryBreakdown, _touchedIndex, (i) => setState(() => _touchedIndex = i)),
                ),

                const SizedBox(height: 40),

                // Weekly category pie chart
                const Text("This Week by Category", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                SizedBox(
                  height: 250,
                  child: stats.weekCategoryBreakdown.isEmpty
                      ? _buildEmptyState("No spending this week yet.")
                      : _buildPieChart(stats.weekCategoryBreakdown, _touchedWeekIndex, (i) => setState(() => _touchedWeekIndex = i)),
                ),

                const SizedBox(height: 40),

                // 7-day bar chart
                const Text("Last 7 Days", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                SizedBox(
                  height: 250,
                  child: _buildBarChart(stats.weeklyTrend),
                ),

                const SizedBox(height: 50),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPieChart(Map<String, double> data, int touchedIndex, void Function(int) onTouch) {
    final List<PieChartSectionData> sections = [];
    int index = 0;

    data.forEach((category, amount) {
      final isTouched = index == touchedIndex;
      final fontSize = isTouched ? 20.0 : 14.0;
      final radius = isTouched ? 110.0 : 100.0;

      sections.add(PieChartSectionData(
        color: _getCategoryColor(category),
        value: amount,
        title: '${(amount / 1000).toStringAsFixed(1)}k',
        radius: radius,
        titleStyle: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold, color: Colors.white),
        badgeWidget: isTouched ? _buildBadge(category) : null,
        badgePositionPercentageOffset: .98,
      ));
      index++;
    });

    return PieChart(
      PieChartData(
        pieTouchData: PieTouchData(
          touchCallback: (FlTouchEvent event, pieTouchResponse) {
            if (!event.isInterestedForInteractions || pieTouchResponse == null || pieTouchResponse.touchedSection == null) {
              onTouch(-1);
              return;
            }
            onTouch(pieTouchResponse.touchedSection!.touchedSectionIndex);
          },
        ),
        sectionsSpace: 2,
        centerSpaceRadius: 40,
        sections: sections,
      ),
    );
  }

  Widget _buildBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4)),
      child: Text(text, style: const TextStyle(fontSize: 10, color: Colors.black, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildBarChart(List<DailyTrend> trends) {
    return BarChart(
      BarChartData(
        gridData: const FlGridData(show: false),
        titlesData: FlTitlesData(
          show: true,
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (double value, TitleMeta meta) {
                if (value.toInt() >= 0 && value.toInt() < trends.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(trends[value.toInt()].dayName, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  );
                }
                return const Text('');
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        barGroups: trends.asMap().entries.map((entry) {
          final data = entry.value;
          return BarChartGroupData(
            x: entry.key,
            barRods: [
              BarChartRodData(
                toY: data.amount,
                color: data.amount > 1500 ? Colors.redAccent : Colors.blueAccent,
                width: 16,
                borderRadius: BorderRadius.circular(4),
                backDrawRodData: BackgroundBarChartRodData(show: true, toY: 3000, color: Colors.grey[900]),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'Food': return Colors.orangeAccent;
      case 'Transport': return Colors.blueAccent;
      case 'Shopping': return Colors.purpleAccent;
      case 'Bills': return Colors.redAccent;
      default: return Colors.grey;
    }
  }

  Color _getTodayColor(double amount) {
    if (amount > 1500) return Colors.redAccent;
    if (amount > 1000) return Colors.orangeAccent;
    return Colors.greenAccent;
  }

  Widget _buildEmptyState(String msg) {
    return Center(child: Text(msg, style: TextStyle(color: Colors.grey[600])));
  }

  Widget _buildStatCard(String title, double amount, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: Colors.grey[400], fontSize: 14)),
          const SizedBox(height: 8),
          Text("Rs ${amount.toStringAsFixed(0)}", style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
