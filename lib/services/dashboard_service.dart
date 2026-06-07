import 'package:isar/isar.dart';
import '../collections/transaction.dart';
import '../main.dart'; // To access the global 'isar' variable

class DashboardStats {
  final double totalMonth;
  final double totalToday;
  final Map<String, double> categoryBreakdown;
  final List<DailyTrend> weeklyTrend;

  DashboardStats({
    required this.totalMonth,
    required this.totalToday,
    required this.categoryBreakdown,
    required this.weeklyTrend,
  });
}

class DailyTrend {
  final String dayName; // "Mon", "Tue"
  final double amount;

  DailyTrend(this.dayName, this.amount);
}

class DashboardService {

  Future<DashboardStats> getStats() async {
    final now = DateTime.now();

    // 1. Calculate Time Ranges
    final startOfMonth = DateTime(now.year, now.month, 1);
    final startOfToday = DateTime(now.year, now.month, now.day);
    final endOfToday = DateTime(now.year, now.month, now.day, 23, 59, 59);

    // 2. Get Totals (Fast Aggregation)
    // Sum for MONTH
    final totalMonth = await isar.transactions
        .filter()
        .timestampBetween(startOfMonth, endOfToday)
        .amountProperty()
        .sum();

    // Sum for TODAY
    final totalToday = await isar.transactions
        .filter()
        .timestampBetween(startOfToday, endOfToday)
        .amountProperty()
        .sum();

    // 3. Get Category Breakdown (For Pie Chart)
    // We fetch all transactions for this month to group them manually
    // (Isar doesn't have 'groupBy' yet, but it's fast enough for this)
    final monthTx = await isar.transactions
        .filter()
        .timestampBetween(startOfMonth, endOfToday)
        .findAll();

    final Map<String, double> categories = {};
    for (var tx in monthTx) {
      categories[tx.category] = (categories[tx.category] ?? 0) + tx.amount;
    }

    // 4. Get Weekly Trend (Last 7 Days)
    List<DailyTrend> weeklyData = [];

    // Loop backwards 6 days + today
    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final dayStart = DateTime(date.year, date.month, date.day);
      final dayEnd = DateTime(date.year, date.month, date.day, 23, 59, 59);

      final daySum = await isar.transactions
          .filter()
          .timestampBetween(dayStart, dayEnd)
          .amountProperty()
          .sum();

      // Format Day Name (e.g., "Mon")
      // Simple switch to avoid 'intl' dependency overhead here if you want,
      // but since we have intl, let's just use weekday index
      String dayLabel = _getWeekdayLabel(date.weekday);

      weeklyData.add(DailyTrend(dayLabel, daySum));
    }

    return DashboardStats(
      totalMonth: totalMonth,
      totalToday: totalToday,
      categoryBreakdown: categories,
      weeklyTrend: weeklyData,
    );
  }

  String _getWeekdayLabel(int weekday) {
    const days = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
    return days[weekday - 1];
  }
}