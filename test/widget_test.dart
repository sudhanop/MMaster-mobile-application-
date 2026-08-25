import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:balance_book/models/profile.dart';
import 'package:balance_book/models/ledger_tx.dart';
import 'package:balance_book/main.dart';

void main() {
  setUp(() async {
    Hive.init('./test_widget_db');
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(ProfileAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(LedgerTxAdapter());
    }
    await Hive.openBox<Profile>('profiles');
    await Hive.openBox<LedgerTx>('transactions');
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
  });

  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();
    expect(find.byType(MyApp), findsOneWidget);
    expect(find.text('MMaster'), findsOneWidget);
  });
}
