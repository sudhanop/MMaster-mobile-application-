import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:hive/hive.dart';
import 'package:balance_book/models/profile.dart';
import 'package:balance_book/models/ledger_tx.dart';

void main() {
  setUp(() async {
    Hive.init('./test_hive_db');
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(ProfileAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(LedgerTxAdapter());
    }
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
  });

  group('Profile Model', () {
    test('creates a profile with correct fields', () {
      final profile = Profile(id: 1, name: 'Test User', balance: 100.0);
      expect(profile.id, 1);
      expect(profile.name, 'Test User');
      expect(profile.balance, 100.0);
    });

    test('stores and retrieves profile from Hive box', () async {
      final box = await Hive.openBox<Profile>('test_profiles');
      final profile = Profile(id: 42, name: 'Alice', balance: 500.0);
      await box.put(42, profile);

      final retrieved = box.get(42);
      expect(retrieved, isNotNull);
      expect(retrieved!.id, 42);
      expect(retrieved.name, 'Alice');
      expect(retrieved.balance, 500.0);
      await box.close();
    });
  });

  group('LedgerTx Model & Accounts (Bank vs Purse)', () {
    test('creates transaction with default bank account', () {
      final tx = LedgerTx(
        id: 1,
        profileId: 42,
        amount: 100.0,
        reason: 'Groceries',
        date: DateTime(2026, 8, 25),
        isIncome: false,
        newBalance: 400.0,
      );
      expect(tx.account, 'bank');
    });

    test('creates transaction with explicit purse account', () {
      final tx = LedgerTx(
        id: 2,
        profileId: 42,
        amount: 50.0,
        reason: 'Street Food',
        date: DateTime(2026, 8, 25),
        isIncome: false,
        newBalance: 350.0,
        account: 'purse',
      );
      expect(tx.account, 'purse');
    });

    test('persists and retrieves account field in Hive', () async {
      final box = await Hive.openBox<LedgerTx>('test_tx_accounts');
      final tx1 = LedgerTx(
        id: 101,
        profileId: 1,
        amount: 200.0,
        reason: 'Salary',
        date: DateTime(2026, 8, 25),
        isIncome: true,
        newBalance: 200.0,
        account: 'bank',
      );
      final tx2 = LedgerTx(
        id: 102,
        profileId: 1,
        amount: 50.0,
        reason: 'Cash Tip',
        date: DateTime(2026, 8, 25),
        isIncome: true,
        newBalance: 250.0,
        account: 'purse',
      );
      await box.put(101, tx1);
      await box.put(102, tx2);

      final retrieved1 = box.get(101);
      final retrieved2 = box.get(102);
      expect(retrieved1?.account, 'bank');
      expect(retrieved2?.account, 'purse');
      await box.close();
    });
  });

  group('Purse and Bank Balance Calculations', () {
    test('calculates Bank vs Purse balances correctly', () async {
      final profileBox = await Hive.openBox<Profile>('test_calc_p');
      final txBox = await Hive.openBox<LedgerTx>('test_calc_t');

      final profile = Profile(id: 1, name: 'Alice', balance: 0.0);
      await profileBox.put(1, profile);

      // Bank income: +5000
      await txBox.put(1, LedgerTx(
        id: 1, profileId: 1, amount: 5000.0, reason: 'Salary',
        date: DateTime(2026, 8, 20, 10, 0), isIncome: true, newBalance: 0, account: 'bank',
      ));
      // Purse income: +1000
      await txBox.put(2, LedgerTx(
        id: 2, profileId: 1, amount: 1000.0, reason: 'Cash Gift',
        date: DateTime(2026, 8, 20, 11, 0), isIncome: true, newBalance: 0, account: 'purse',
      ));
      // Bank expense: -1500
      await txBox.put(3, LedgerTx(
        id: 3, profileId: 1, amount: 1500.0, reason: 'Online Shopping',
        date: DateTime(2026, 8, 20, 12, 0), isIncome: false, newBalance: 0, account: 'bank',
      ));
      // Purse expense: -300
      await txBox.put(4, LedgerTx(
        id: 4, profileId: 1, amount: 300.0, reason: 'Auto fare',
        date: DateTime(2026, 8, 20, 13, 0), isIncome: false, newBalance: 0, account: 'purse',
      ));

      final txs = txBox.values.where((t) => t.profileId == 1).toList();

      double bank = 0;
      double purse = 0;
      double total = 0;

      for (final t in txs) {
        final val = t.isIncome ? t.amount : -t.amount;
        total += val;
        if (t.account == 'purse') {
          purse += val;
        } else {
          bank += val;
        }
      }

      expect(bank, 3500.0); // 5000 - 1500
      expect(purse, 700.0); // 1000 - 300
      expect(total, 4200.0); // 3500 + 700
      expect(total, bank + purse);

      await profileBox.close();
      await txBox.close();
    });

    test('simulates ATM transfer from Bank to Purse', () async {
      final txBox = await Hive.openBox<LedgerTx>('test_transfer_t');

      // 1. Initial bank income +2000
      await txBox.put(1, LedgerTx(
        id: 1, profileId: 1, amount: 2000.0, reason: 'Salary',
        date: DateTime(2026, 8, 20, 10, 0), isIncome: true, newBalance: 0, account: 'bank',
      ));

      // 2. Transfer 500 from Bank to Purse (Withdrawal)
      await txBox.put(2, LedgerTx(
        id: 2, profileId: 1, amount: 500.0, reason: 'ATM Withdrawal (Out: Bank)',
        date: DateTime(2026, 8, 20, 11, 0), isIncome: false, newBalance: 0, account: 'bank',
      ));
      await txBox.put(3, LedgerTx(
        id: 3, profileId: 1, amount: 500.0, reason: 'ATM Withdrawal (In: Purse)',
        date: DateTime(2026, 8, 20, 11, 0, 1), isIncome: true, newBalance: 0, account: 'purse',
      ));

      final txs = txBox.values.where((t) => t.profileId == 1).toList();

      double bank = 0;
      double purse = 0;
      double total = 0;

      for (final t in txs) {
        final val = t.isIncome ? t.amount : -t.amount;
        total += val;
        if (t.account == 'purse') {
          purse += val;
        } else {
          bank += val;
        }
      }

      expect(bank, 1500.0); // 2000 - 500
      expect(purse, 500.0); // +500
      expect(total, 2000.0); // Total net wealth unchanged by transfer!

      await txBox.close();
    });
  });
}
