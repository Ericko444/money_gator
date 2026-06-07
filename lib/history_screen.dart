import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import 'package:intl/intl.dart';
import 'main.dart'; // Access global 'isar'
import 'collections/transaction.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  String formatCurrency(double amount) {
    return NumberFormat.currency(symbol: 'Rs ', decimalDigits: 0).format(amount);
  }

  String formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final dateToCheck = DateTime(date.year, date.month, date.day);

    if (dateToCheck == today) return "Today";
    if (dateToCheck == yesterday) return "Yesterday";
    return DateFormat('EEE, d MMM').format(date);
  }

  // NEW: Dialog to Edit or Delete
  void _showEditDialog(BuildContext context, Transaction tx) {
    final TextEditingController amountController = TextEditingController(text: tx.amount.toStringAsFixed(0));
    String selectedCategory = tx.category;
    final List<String> categories = ["Food", "Transport", "Shopping", "Bills"];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: Colors.grey[900],
              title: const Text("Edit Entry", style: TextStyle(color: Colors.white)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Amount Field
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white, fontSize: 24),
                    decoration: const InputDecoration(
                      labelText: "Amount (Rs)",
                      labelStyle: TextStyle(color: Colors.grey),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
                      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.blueAccent)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Category Dropdown
                  DropdownButton<String>(
                    value: selectedCategory,
                    dropdownColor: Colors.grey[800],
                    isExpanded: true,
                    style: const TextStyle(color: Colors.white),
                    items: categories.map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                    onChanged: (newValue) {
                      setState(() {
                        selectedCategory = newValue!;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                // DELETE BUTTON
                TextButton(
                  onPressed: () async {
                    await isar.writeTxn(() async {
                      await isar.transactions.delete(tx.id);
                    });
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: const Text("Delete", style: TextStyle(color: Colors.red)),
                ),
                // SAVE BUTTON
                ElevatedButton(
                  onPressed: () async {
                    if (amountController.text.isEmpty) return;
                    final newAmount = double.tryParse(amountController.text) ?? tx.amount;

                    await isar.writeTxn(() async {
                      tx.amount = newAmount;
                      tx.category = selectedCategory;
                      await isar.transactions.put(tx);
                    });

                    if (context.mounted) Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                  child: const Text("Save", style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Spending History", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        elevation: 0,
      ),
      body: StreamBuilder<List<Transaction>>(
        stream: isar.transactions.where().sortByTimestampDesc().watch(fireImmediately: true),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final transactions = snapshot.data!;

          if (transactions.isEmpty) {
            return const Center(child: Text("No spending yet.", style: TextStyle(color: Colors.grey)));
          }

          return ListView.builder(
            itemCount: transactions.length,
            itemBuilder: (context, index) {
              final tx = transactions[index];
              final isNewDay = index == 0 ||
                  formatDate(transactions[index].timestamp) != formatDate(transactions[index - 1].timestamp);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isNewDay)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                      child: Text(
                        formatDate(tx.timestamp),
                        style: TextStyle(color: Colors.blueAccent.shade100, fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ),

                  // Wrap List Tile in InkWell for Tap
                  ListTile(
                    onTap: () => _showEditDialog(context, tx), // <--- TAP TO EDIT
                    leading: CircleAvatar(
                      backgroundColor: Colors.grey[900],
                      child: Icon(_getIconForCategory(tx.category), color: Colors.white, size: 20),
                    ),
                    title: Text(tx.category, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
                    subtitle: Text(DateFormat('HH:mm').format(tx.timestamp), style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                    trailing: Text(formatCurrency(tx.amount), style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  IconData _getIconForCategory(String category) {
    switch (category) {
      case 'Food': return Icons.fastfood;
      case 'Transport': return Icons.directions_bus;
      case 'Shopping': return Icons.shopping_bag;
      case 'Bills': return Icons.receipt;
      default: return Icons.attach_money;
    }
  }
}