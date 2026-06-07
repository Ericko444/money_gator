import 'package:isar/isar.dart';

part 'transaction.g.dart'; // This line will show an error until we generate code

@collection
class Transaction {
  Id id = Isar.autoIncrement;

  late double amount;
  late String category;

  @Index()
  late DateTime timestamp;

  // Fields for the future "AI" predictor
  late int hourOfDay;  // 0-23
  late int dayOfWeek;  // 1-7 (Mon-Sun)
}