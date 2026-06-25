import 'package:isar/isar.dart';
import '../collections/transaction.dart';
import '../main.dart'; // To access the global 'isar' variable

class DashboardStats {
  final double totalMonth;
  final double totalToday;
  final double totalWeek;
  final Map<String, double> categoryBreakdown;
  final Map<String, double> weekCategoryBreakdown;
  final List<DailyTrend> weeklyTrend;

  DashboardStats({
    required this.totalMonth,
    required this.totalToday,
    required this.totalWeek,
    required this.categoryBreakdown,
    required this.weekCategoryBreakdown,
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
    // ISO week starts on Monday (weekday 1)
    final startOfWeek = DateTime(now.year, now.month, now.day - (now.weekday - 1));

    // 2. Get Totals
    final totalMonth = await isar.transactions
        .filter()
        .timestampBetween(startOfMonth, endOfToday)
        .amountProperty()
        .sum();

    final totalToday = await isar.transactions
        .filter()
        .timestampBetween(startOfToday, endOfToday)
        .amountProperty()
        .sum();

    final totalWeek = await isar.transactions
        .filter()
        .timestampBetween(startOfWeek, endOfToday)
        .amountProperty()
        .sum();

    // 3. Get Category Breakdown (month)
    final monthTx = await isar.transactions
        .filter()
        .timestampBetween(startOfMonth, endOfToday)
        .findAll();

    final Map<String, double> categories = {};
    for (var tx in monthTx) {
      categories[tx.category] = (categories[tx.category] ?? 0) + tx.amount;
    }

    // 4. Get Category Breakdown (current ISO week)
    final weekTx = await isar.transactions
        .filter()
        .timestampBetween(startOfWeek, endOfToday)
        .findAll();

    final Map<String, double> weekCategories = {};
    for (var tx in weekTx) {
      weekCategories[tx.category] = (weekCategories[tx.category] ?? 0) + tx.amount;
    }

    // 5. Get Weekly Trend (Last 7 Days)
    List<DailyTrend> weeklyData = [];

    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final dayStart = DateTime(date.year, date.month, date.day);
      final dayEnd = DateTime(date.year, date.month, date.day, 23, 59, 59);

      final daySum = await isar.transactions
          .filter()
          .timestampBetween(dayStart, dayEnd)
          .amountProperty()
          .sum();

      weeklyData.add(DailyTrend(_getWeekdayLabel(date.weekday), daySum));
    }

    return DashboardStats(
      totalMonth: totalMonth,
      totalToday: totalToday,
      totalWeek: totalWeek,
      categoryBreakdown: categories,
      weekCategoryBreakdown: weekCategories,
      weeklyTrend: weeklyData,
    );
  }

  String _getWeekdayLabel(int weekday) {
    const days = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
    return days[weekday - 1];
  }
}