import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../collections/transaction.dart';

class ApiService {
  static const bool _isMock = true; // flip to false when backend is ready
  static const String _baseUrl = 'https://your-api-placeholder.com/api';

  static Map<String, dynamic> _toJson(Transaction tx) => {
        'id': tx.id,
        'amount': tx.amount,
        'category': tx.category,
        'timestamp': tx.timestamp.toIso8601String(),
        'hourOfDay': tx.hourOfDay,
        'dayOfWeek': tx.dayOfWeek,
      };

  static Future<void> syncTransaction(Transaction tx) async {
    try {
      if (_isMock) {
        await Future.delayed(const Duration(milliseconds: 300));
        debugPrint('[ApiService][MOCK] syncTransaction: ${jsonEncode(_toJson(tx))}');
      } else {
        final res = await http.post(
          Uri.parse('$_baseUrl/transactions'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(_toJson(tx)),
        );
        debugPrint('[ApiService] syncTransaction → ${res.statusCode}');
      }
    } catch (e) {
      debugPrint('[ApiService] syncTransaction error: $e');
    }
  }

  static Future<void> updateTransaction(Transaction tx) async {
    try {
      if (_isMock) {
        await Future.delayed(const Duration(milliseconds: 300));
        debugPrint('[ApiService][MOCK] updateTransaction: ${jsonEncode(_toJson(tx))}');
      } else {
        final res = await http.put(
          Uri.parse('$_baseUrl/transactions/${tx.id}'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(_toJson(tx)),
        );
        debugPrint('[ApiService] updateTransaction → ${res.statusCode}');
      }
    } catch (e) {
      debugPrint('[ApiService] updateTransaction error: $e');
    }
  }

  static Future<void> deleteTransaction(int id) async {
    try {
      if (_isMock) {
        await Future.delayed(const Duration(milliseconds: 300));
        debugPrint('[ApiService][MOCK] deleteTransaction id: $id');
      } else {
        final res = await http.delete(Uri.parse('$_baseUrl/transactions/$id'));
        debugPrint('[ApiService] deleteTransaction → ${res.statusCode}');
      }
    } catch (e) {
      debugPrint('[ApiService] deleteTransaction error: $e');
    }
  }
}
