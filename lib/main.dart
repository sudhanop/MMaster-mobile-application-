import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'models/profile.dart';
import 'models/ledger_tx.dart';
import 'screens/home.dart';

/// Recalculates all profile balances safely from their transaction history.
Future<void> _recalculateAllBalances() async {
  try {
    if (!Hive.isBoxOpen('profiles') || !Hive.isBoxOpen('transactions')) return;
    final profilesBox = Hive.box<Profile>('profiles');
    final txBox = Hive.box<LedgerTx>('transactions');

    for (final key in profilesBox.keys.toList()) {
      final profile = profilesBox.get(key);
      if (profile == null) continue;

      final txs = txBox.values
          .where((tx) => tx.profileId == profile.id)
          .toList()
        ..sort((a, b) {
          final dateCompare = a.date.compareTo(b.date);
          if (dateCompare != 0) return dateCompare;
          return a.id.compareTo(b.id);
        });

      double runningBalance = 0;
      for (final tx in txs) {
        runningBalance = tx.isIncome
            ? runningBalance + tx.amount
            : runningBalance - tx.amount;
        if (tx.newBalance != runningBalance) {
          tx.newBalance = runningBalance;
          await txBox.put(tx.id, tx);
        }
      }

      if (profile.balance != runningBalance) {
        profile.balance = runningBalance;
        await profilesBox.put(profile.id, profile);
      }
    }
  } catch (e, stack) {
    debugPrint('Safe recalculation warning: $e\n$stack');
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Hive.initFlutter();
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(ProfileAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(LedgerTxAdapter());
    }
    await Hive.openBox<Profile>('profiles');
    await Hive.openBox<LedgerTx>('transactions');

    // Fix any stale balance data from previous versions
    await _recalculateAllBalances();
  } catch (e, stack) {
    debugPrint('App init error: $e\n$stack');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MMaster',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1A237E),
          primary: const Color(0xFF1A237E),
        ),
        scaffoldBackgroundColor: const Color(0xFFF0F4FF),
        cardColor: Colors.white,
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1A237E),
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Color(0xFF1A237E),
          foregroundColor: Colors.white,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1A237E),
            foregroundColor: Colors.white,
          ),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
