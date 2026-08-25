import 'package:hive/hive.dart';

@HiveType(typeId: 1)
class LedgerTx extends HiveObject {
  @HiveField(0)
  int id;

  @HiveField(1)
  int profileId;

  @HiveField(2)
  double amount;

  @HiveField(3)
  String reason;

  @HiveField(4)
  DateTime date;

  @HiveField(5)
  bool isIncome;

  @HiveField(6)
  double newBalance;

  @HiveField(7)
  String account; // 'bank' or 'purse'

  LedgerTx({
    required this.id,
    required this.profileId,
    required this.amount,
    required this.reason,
    required this.date,
    required this.isIncome,
    required this.newBalance,
    this.account = 'bank',
  });
}

class LedgerTxAdapter extends TypeAdapter<LedgerTx> {
  @override
  final int typeId = 1;

  @override
  LedgerTx read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (int i = 0; i < numOfFields; i++) {
      fields[reader.readByte()] = reader.read();
    }

    DateTime parsedDate;
    final rawDate = fields[4];
    if (rawDate is DateTime) {
      parsedDate = rawDate;
    } else if (rawDate is int) {
      parsedDate = DateTime.fromMillisecondsSinceEpoch(rawDate);
    } else if (rawDate is String) {
      parsedDate = DateTime.tryParse(rawDate) ?? DateTime.now();
    } else {
      parsedDate = DateTime.now();
    }

    final accountRaw = fields[7]?.toString().toLowerCase().trim();
    final account = (accountRaw == 'purse' || accountRaw == 'cash') ? 'purse' : 'bank';

    return LedgerTx(
      id: (fields[0] as num?)?.toInt() ?? 0,
      profileId: (fields[1] as num?)?.toInt() ?? 0,
      amount: (fields[2] as num?)?.toDouble() ?? 0.0,
      reason: fields[3]?.toString() ?? '',
      date: parsedDate,
      isIncome: fields[5] == true,
      newBalance: (fields[6] as num?)?.toDouble() ?? 0.0,
      account: account,
    );
  }

  @override
  void write(BinaryWriter writer, LedgerTx obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.profileId)
      ..writeByte(2)
      ..write(obj.amount)
      ..writeByte(3)
      ..write(obj.reason)
      ..writeByte(4)
      ..write(obj.date)
      ..writeByte(5)
      ..write(obj.isIncome)
      ..writeByte(6)
      ..write(obj.newBalance)
      ..writeByte(7)
      ..write(obj.account);
  }
}
