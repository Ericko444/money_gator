import 'dart:convert';
import 'dart:io';

import 'package:isar/isar.dart';

import '../collections/transaction.dart';
import '../main.dart'; // To access the global 'isar' variable

class BackupService {
  static const _backupDirPath = '/storage/emulated/0/Documents/MoneyGate/backups';

  static Future<File> exportToFile() async {
    final transactions = await isar.transactions.where().sortByTimestampDesc().findAll();

    final json = {
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'transactions': transactions
          .map((t) => {
                'amount': t.amount,
                'category': t.category,
                'timestamp': t.timestamp.toIso8601String(),
                'hourOfDay': t.hourOfDay,
                'dayOfWeek': t.dayOfWeek,
              })
          .toList(),
    };

    final dir = Directory(_backupDirPath);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final timestamp = DateTime.now().toIso8601String().replaceAll(RegExp(r'[:.]'), '-');
    final file = File('${dir.path}/money_gator_backup_$timestamp.json');
    await file.writeAsString(jsonEncode(json));
    return file;
  }

  /// Wipes all existing transactions and replaces them with the file's contents.
  /// Throws a [FormatException] if the file isn't a valid backup, in which case
  /// no changes are made to the database.
  static Future<int> importFromFile(File file) async {
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map<String, dynamic> || decoded['transactions'] is! List) {
      throw const FormatException('File is not a valid money_gator backup');
    }

    final items = (decoded['transactions'] as List).map((m) {
      final entry = m as Map<String, dynamic>;
      return Transaction()
        ..amount = (entry['amount'] as num).toDouble()
        ..category = entry['category'] as String
        ..timestamp = DateTime.parse(entry['timestamp'] as String)
        ..hourOfDay = entry['hourOfDay'] as int
        ..dayOfWeek = entry['dayOfWeek'] as int;
    }).toList();

    await isar.writeTxn(() async {
      await isar.transactions.clear();
      await isar.transactions.putAll(items);
    });

    return items.length;
  }
}
