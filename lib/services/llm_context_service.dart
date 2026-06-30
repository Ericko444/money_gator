import 'package:intl/intl.dart';
import 'package:isar/isar.dart';

import '../collections/transaction.dart';
import '../main.dart';

class LlmContextService {
  static final _dateFormat = DateFormat('yyyy-MM-dd');

  /// Returns a structured text block of the last 30 days of transactions,
  /// capped at 200 entries (most recent first), for injection into LLM prompts.
  Future<String> buildContext() async {
    final now = DateTime.now();
    final thirtyDaysAgo = now.subtract(const Duration(days: 30));

    final all = await isar.transactions
        .filter()
        .timestampBetween(thirtyDaysAgo, now)
        .findAll();
    all.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    final transactions = all.length > 200 ? all.sublist(0, 200) : all;

    if (transactions.isEmpty) {
      return 'No transactions recorded in the last 30 days.';
    }

    final total = transactions.fold(0.0, (sum, tx) => sum + tx.amount);
    final oldest = transactions.last.timestamp;
    final newest = transactions.first.timestamp;

    final buffer = StringBuffer();
    buffer.writeln(
      'Transactions: ${transactions.length} | '
      'Total: Rs ${total.toStringAsFixed(2)} | '
      'Range: ${_dateFormat.format(oldest)}–${_dateFormat.format(newest)}',
    );
    buffer.writeln('---');

    for (final tx in transactions) {
      buffer.writeln(
        '${_dateFormat.format(tx.timestamp)} | ${tx.category} | Rs ${tx.amount.toStringAsFixed(2)}',
      );
    }

    return buffer.toString();
  }
}
