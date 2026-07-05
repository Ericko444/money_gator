import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart'; // Keep this as backup
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';

import 'collections/transaction.dart';
import 'services/api_service.dart';
import 'history_screen.dart';
import 'dashboard_screen.dart';
import 'chat_screen.dart';
import 'settings_screen.dart';

late Isar isar;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. GET STORAGE PERMISSIONS
  await _requestPermission();

  // 2. DEFINE THE IMMORTAL PATH
  // This points to "Internal Storage > Documents > MoneyGate"
  // Data here survives app uninstall.
  String dbPath = "/storage/emulated/0/Documents/MoneyGate";

  // Verify path exists, if not create it
  final dir = Directory(dbPath);
  if (!await dir.exists()) {
    try {
      await dir.create(recursive: true);
    } catch (e) {
      print("Could not create external directory, falling back to internal.");
      final internalDir = await getApplicationDocumentsDirectory();
      dbPath = internalDir.path;
    }
  }

  // 3. OPEN DATABASE
  isar = await Isar.open(
    [TransactionSchema],
    directory: dbPath,
  );

  runApp(const MaterialApp(home: MainApp(), debugShowCheckedModeBanner: false));
}

// Helper to ask for permission aggressively
Future<void> _requestPermission() async {
  if (Platform.isAndroid) {
    final androidInfo = await DeviceInfoPlugin().androidInfo;

    // Android 11+ (API 30+) requires "Manage All Files" permission
    if (androidInfo.version.sdkInt >= 30) {
      var status = await Permission.manageExternalStorage.status;
      if (!status.isGranted) {
        await Permission.manageExternalStorage.request();
      }
    } else {
      // Android 10 and below
      var status = await Permission.storage.status;
      if (!status.isGranted) {
        await Permission.storage.request();
      }
    }
  }
}

// Wrapper to handle Navigation
class MainApp extends StatefulWidget {
  const MainApp({super.key});
  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const GatekeeperScreen(),
    const HistoryScreen(),
    const DashboardScreen(),
    const ChatScreen(),
    const SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    // We wrap in PopScope to prevent accidental closing
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: _pages[_currentIndex],
        bottomNavigationBar: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.grey[900],
          selectedItemColor: Colors.blueAccent,
          unselectedItemColor: Colors.grey,
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.dialpad), label: 'Input'),
            BottomNavigationBarItem(icon: Icon(Icons.history), label: 'History'),
            BottomNavigationBarItem(icon: Icon(Icons.pie_chart), label: 'Reality'),
            BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), label: 'Chat'),
            BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------
// YOUR EXISTING KEYPAD (Refactored slightly for the new structure)
// ---------------------------------------------------------
class GatekeeperScreen extends StatefulWidget {
  const GatekeeperScreen({super.key});

  @override
  State<GatekeeperScreen> createState() => _GatekeeperScreenState();
}

class _GatekeeperScreenState extends State<GatekeeperScreen> {
  static const platform = MethodChannel('com.example.money_gate/app_control');

  String _input = "";
  String _selectedCategory = "Transport";
  final List<String> categories = ["Food", "Transport", "Shopping", "Bills"];

  void _onKeyTap(String value) {
    setState(() {
      if (value == "DEL") {
        if (_input.isNotEmpty) _input = _input.substring(0, _input.length - 1);
      } else {
        _input += value;
      }
    });
  }

  Future<void> _submit() async {
    if (_input.isEmpty) return;

    double amount = double.parse(_input);
    DateTime now = DateTime.now();

    final newTx = Transaction()
      ..amount = amount
      ..category = _selectedCategory
      ..timestamp = now
      ..hourOfDay = now.hour
      ..dayOfWeek = now.weekday;

    await isar.writeTxn(() async {
      await isar.transactions.put(newTx);
    });
    ApiService.syncTransaction(newTx); // fire-and-forget

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('last_paid_timestamp', now.millisecondsSinceEpoch);

    // Clear input after pay
    setState(() {
      _input = "";
    });

    try {
      await platform.invokeMethod('closeApp');
    } catch (e) {
      print(e);
    }
  }

  Future<void> _handleCheckIn() async {
    // 1. Just update the timestamp (Reset the 2-hour timer)
    final prefs = await SharedPreferences.getInstance();
    int now = DateTime.now().millisecondsSinceEpoch;
    await prefs.setInt('last_paid_timestamp', now);

    // 2. Clear input
    setState(() {
      _input = "";
    });

    // 3. Unlock immediately
    try {
      await platform.invokeMethod('closeApp');
    } catch (e) {
      print(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get screen height to make dynamic decisions if needed
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenHeight < 700;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea( // Ensures we don't draw behind the notch or home bar
          child: Column(
            children: [
              // ---------------------------------------------
              // 1. DYNAMIC TOP SECTION (Takes available space)
              // ---------------------------------------------
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "TOLL REQUIRED",
                      style: TextStyle(color: Colors.grey[500], fontSize: isSmallScreen ? 14 : 16),
                    ),

                    const SizedBox(height: 10),

                    // FITTED BOX: Prevents overflow if font is too big
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          _input.isEmpty ? "0" : "Rs $_input",
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: isSmallScreen ? 40 : 60, // Smaller font on small screens
                              fontWeight: FontWeight.bold
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ---------------------------------------------
              // 2. CATEGORY SELECTOR (Fixed Height)
              // ---------------------------------------------
              SizedBox(
                height: 50,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: categories.map((cat) {
                      final isSelected = _selectedCategory == cat;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        child: ChoiceChip(
                          label: Text(cat, style: TextStyle(fontSize: isSmallScreen ? 12 : 14)),
                          selected: isSelected,
                          selectedColor: Colors.blueAccent,
                          labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black),
                          backgroundColor: Colors.grey[300],
                          onSelected: (bool selected) {
                            setState(() {
                              _selectedCategory = cat;
                            });
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // ---------------------------------------------
              // 3. KEYPAD AREA (Auto-sized)
              // ---------------------------------------------
              Container(
                color: Colors.grey[900],
                padding: EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: isSmallScreen ? 10 : 20 // Reduce padding on small screens
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min, // Shrink to fit content
                  children: [
                    _buildRow(["1", "2", "3"], isSmallScreen),
                    _buildRow(["4", "5", "6"], isSmallScreen),
                    _buildRow(["7", "8", "9"], isSmallScreen),
                    _buildRow([".", "0", "DEL"], isSmallScreen),

                    SizedBox(height: isSmallScreen ? 10 : 20),

                    // PAY BUTTON
                    SizedBox(
                      width: double.infinity,
                      height: isSmallScreen ? 45 : 55,
                      child: ElevatedButton(
                        onPressed: _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(
                            "LOG & UNLOCK",
                            style: TextStyle(fontSize: isSmallScreen ? 16 : 18, color: Colors.white, fontWeight: FontWeight.bold)
                        ),
                      ),
                    ),

                    SizedBox(height: isSmallScreen ? 8 : 12),

                    // CHECK-IN BUTTON
                    SizedBox(
                      width: double.infinity,
                      height: isSmallScreen ? 35 : 45,
                      child: TextButton.icon(
                        onPressed: _handleCheckIn,
                        icon: Icon(Icons.check_circle_outline, color: Colors.greenAccent, size: isSmallScreen ? 18 : 24),
                        label: Text(
                            "NO SPEND",
                            style: TextStyle(fontSize: isSmallScreen ? 14 : 16, color: Colors.greenAccent, fontWeight: FontWeight.w600)
                        ),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          backgroundColor: Colors.transparent,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  // UPDATED HELPER FOR RESPONSIVE KEYS
  Widget _buildRow(List<String> keys, bool isSmallScreen) {
    // Dynamic size for buttons
    final btnSize = isSmallScreen ? 60.0 : 75.0;
    final fontSize = isSmallScreen ? 22.0 : 28.0;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 4 : 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: keys.map((key) {
          return InkWell(
            onTap: () => _onKeyTap(key),
            borderRadius: BorderRadius.circular(40),
            child: Container(
              width: btnSize,
              height: btnSize,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.grey[800],
              ),
              child: Text(key, style: TextStyle(fontSize: fontSize, color: Colors.white)),
            ),
          );
        }).toList(),
      ),
    );
  }

}