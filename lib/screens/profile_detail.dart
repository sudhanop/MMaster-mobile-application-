import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import '../models/profile.dart';
import '../models/ledger_tx.dart';

class ProfileDetailScreen extends StatefulWidget {
  final int profileId;
  const ProfileDetailScreen({Key? key, required this.profileId}) : super(key: key);

  @override
  State<ProfileDetailScreen> createState() => _ProfileDetailScreenState();
}

class _ProfileDetailScreenState extends State<ProfileDetailScreen> {
  late Box<Profile> profilesBox;
  late Box<LedgerTx> txBox;
  String _selectedFilter = 'all'; // 'all', 'bank', 'purse', 'income', 'expense'
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    profilesBox = Hive.box<Profile>('profiles');
    txBox = Hive.box<LedgerTx>('transactions');
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  /// Recalculates the running balance for every transaction belonging
  /// to this profile, then updates the profile's total balance.
  Future<void> _recalculateProfileBalance() async {
    final txs = txBox.values
        .where((tx) => tx.profileId == widget.profileId)
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

    final profile = profilesBox.get(widget.profileId);
    if (profile != null) {
      profile.balance = runningBalance;
      await profilesBox.put(widget.profileId, profile);
    }
  }

  Future<void> _showTransactionDialog({
    LedgerTx? transaction,
    required bool isIncome,
    String? defaultAccount,
  }) async {
    final amtCtrl = TextEditingController(
      text: transaction != null ? transaction.amount.toString() : '',
    );
    final reasonCtrl = TextEditingController(text: transaction?.reason ?? '');
    DateTime selected = transaction?.date ?? DateTime.now();
    String selectedAccount = transaction?.account ?? defaultAccount ?? 'bank';

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setStateDialog) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(
                isIncome ? Icons.add_circle_outline : Icons.remove_circle_outline,
                color: isIncome ? Colors.green : Colors.red,
              ),
              const SizedBox(width: 8),
              Text(
                transaction == null
                    ? (isIncome ? 'Add Money' : 'Spend Money')
                    : 'Edit ${isIncome ? 'Income' : 'Expense'}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Account selector (Bank vs Purse)
                const Text(
                  'Account / Storage:',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        avatar: const Icon(Icons.account_balance_rounded, size: 16),
                        label: const Text('🏦 Bank'),
                        selected: selectedAccount == 'bank',
                        selectedColor: Colors.blue.shade100,
                        onSelected: (val) {
                          if (val) setStateDialog(() => selectedAccount = 'bank');
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ChoiceChip(
                        avatar: const Icon(Icons.wallet_rounded, size: 16),
                        label: const Text('👛 Purse'),
                        selected: selectedAccount == 'purse',
                        selectedColor: Colors.amber.shade200,
                        onSelected: (val) {
                          if (val) setStateDialog(() => selectedAccount = 'purse');
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: amtCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Amount',
                    prefixText: '₹ ',
                    prefixStyle: const TextStyle(fontWeight: FontWeight.bold),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: reasonCtrl,
                  decoration: InputDecoration(
                    labelText: 'Reason / Note',
                    hintText: isIncome ? 'e.g. Salary, Freelance, Gift' : 'e.g. Groceries, Dinner, Bills',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 14),
                InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () async {
                    final d = await showDatePicker(
                      context: ctx,
                      initialDate: selected,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (d != null) {
                      selected = DateTime(
                        d.year,
                        d.month,
                        d.day,
                        selected.hour,
                        selected.minute,
                      );
                      setStateDialog(() {});
                    }
                  },
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Date',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      suffixIcon: const Icon(Icons.calendar_today_outlined),
                    ),
                    child: Text(DateFormat.yMMMd().format(selected)),
                  ),
                ),
              ],
            ),
          ),
          actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isIncome ? Colors.green[700] : Colors.red[700],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                final amt = double.tryParse(amtCtrl.text.trim()) ?? 0.0;
                final reason = reasonCtrl.text.trim();
                if (amt <= 0 || reason.isEmpty) return;

                if (transaction == null) {
                  final id = DateTime.now().microsecondsSinceEpoch;
                  final tx = LedgerTx(
                    id: id,
                    profileId: widget.profileId,
                    amount: amt,
                    reason: reason,
                    date: selected,
                    isIncome: isIncome,
                    newBalance: 0,
                    account: selectedAccount,
                  );
                  await txBox.put(id, tx);
                } else {
                  transaction.amount = amt;
                  transaction.reason = reason;
                  transaction.date = selected;
                  transaction.isIncome = isIncome;
                  transaction.account = selectedAccount;
                  await txBox.put(transaction.id, transaction);
                }

                await _recalculateProfileBalance();
                if (mounted) {
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      }),
    );
  }

  /// Quick Transfer Dialog: transfer between Bank and Purse
  Future<void> _showTransferDialog() async {
    final amtCtrl = TextEditingController();
    String fromAccount = 'bank';
    String toAccount = 'purse';
    final reasonCtrl = TextEditingController(text: 'ATM Cash Withdrawal');

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setStateDialog) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.swap_horiz_rounded, color: Colors.indigo, size: 28),
              SizedBox(width: 8),
              Text('Transfer Money', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.indigo.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            const Text('From', style: TextStyle(fontSize: 11, color: Colors.grey)),
                            const SizedBox(height: 4),
                            Text(fromAccount == 'bank' ? '🏦 Bank' : '👛 Purse',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.swap_horizontal_circle_rounded, color: Colors.indigo, size: 28),
                        onPressed: () {
                          setStateDialog(() {
                            final temp = fromAccount;
                            fromAccount = toAccount;
                            toAccount = temp;
                            if (fromAccount == 'bank') {
                              reasonCtrl.text = 'ATM Cash Withdrawal';
                            } else {
                              reasonCtrl.text = 'Cash Deposit to Bank';
                            }
                          });
                        },
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            const Text('To', style: TextStyle(fontSize: 11, color: Colors.grey)),
                            const SizedBox(height: 4),
                            Text(toAccount == 'bank' ? '🏦 Bank' : '👛 Purse',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: amtCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Transfer Amount',
                    prefixText: '₹ ',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: reasonCtrl,
                  decoration: InputDecoration(
                    labelText: 'Note / Reason',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  textCapitalization: TextCapitalization.sentences,
                ),
              ],
            ),
          ),
          actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A237E),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                final amt = double.tryParse(amtCtrl.text.trim()) ?? 0.0;
                final reason = reasonCtrl.text.trim();
                if (amt <= 0 || reason.isEmpty) return;

                final now = DateTime.now();
                // 1. Expense from source account
                final id1 = DateTime.now().microsecondsSinceEpoch;
                final txOut = LedgerTx(
                  id: id1,
                  profileId: widget.profileId,
                  amount: amt,
                  reason: '$reason (Out: ${fromAccount == 'bank' ? 'Bank' : 'Purse'})',
                  date: now,
                  isIncome: false,
                  newBalance: 0,
                  account: fromAccount,
                );
                await txBox.put(id1, txOut);

                // 2. Income into destination account
                final id2 = id1 + 1;
                final txIn = LedgerTx(
                  id: id2,
                  profileId: widget.profileId,
                  amount: amt,
                  reason: '$reason (In: ${toAccount == 'bank' ? 'Bank' : 'Purse'})',
                  date: now.add(const Duration(milliseconds: 10)),
                  isIncome: true,
                  newBalance: 0,
                  account: toAccount,
                );
                await txBox.put(id2, txIn);

                await _recalculateProfileBalance();
                if (mounted) {
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Transfer'),
            ),
          ],
        );
      }),
    );
  }

  Future<void> _deleteTransaction(LedgerTx tx) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Transaction?'),
        content: Text('Remove "${tx.reason}" from this profile?'),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await txBox.delete(tx.id);
      await _recalculateProfileBalance();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: profilesBox.listenable(keys: [widget.profileId]),
      builder: (context, Box<Profile> pBox, _) {
        final profile = pBox.get(widget.profileId);

        if (profile == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Profile')),
            body: const Center(child: Text('Profile not found or was deleted.')),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(profile.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            elevation: 0,
            actions: [
              IconButton(
                icon: const Icon(Icons.swap_horiz_rounded),
                tooltip: 'Transfer Bank <-> Purse',
                onPressed: () => _showTransferDialog(),
              ),
            ],
          ),
          body: ValueListenableBuilder(
            valueListenable: txBox.listenable(),
            builder: (context, Box<LedgerTx> tBox, _) {
              final allProfileTxs = tBox.values
                  .where((t) => t.profileId == widget.profileId)
                  .toList();

              // Calculate purse vs bank balances
              double bankBalance = 0;
              double purseBalance = 0;
              for (final t in allProfileTxs) {
                final val = t.isIncome ? t.amount : -t.amount;
                if (t.account == 'purse') {
                  purseBalance += val;
                } else {
                  bankBalance += val;
                }
              }

              // Filter transactions based on selection and search
              List<LedgerTx> filteredTxs = allProfileTxs.where((t) {
                if (_selectedFilter == 'bank' && t.account != 'bank') return false;
                if (_selectedFilter == 'purse' && t.account != 'purse') return false;
                if (_selectedFilter == 'income' && !t.isIncome) return false;
                if (_selectedFilter == 'expense' && t.isIncome) return false;
                if (_searchQuery.isNotEmpty &&
                    !t.reason.toLowerCase().contains(_searchQuery.toLowerCase())) {
                  return false;
                }
                return true;
              }).toList();

              filteredTxs.sort((a, b) {
                final dateCompare = b.date.compareTo(a.date);
                if (dateCompare != 0) return dateCompare;
                return b.id.compareTo(a.id);
              });

              return Column(
                children: [
                  // ── Top Summary Gradient Banner ──
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF0D1B2A), Color(0xFF1B263B), Color(0xFF1A237E)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 28,
                              backgroundColor: Colors.white12,
                              child: Text(
                                profile.name.isNotEmpty ? profile.name[0].toUpperCase() : '?',
                                style: const TextStyle(fontSize: 22, color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    profile.name,
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                                  const SizedBox(height: 2),
                                  const Text('TOTAL BALANCE', style: TextStyle(color: Colors.white70, fontSize: 11, letterSpacing: 1)),
                                  Text(
                                    '₹${profile.balance.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontSize: 26,
                                      fontWeight: FontWeight.w800,
                                      color: profile.balance >= 0 ? const Color(0xFFB9F6CA) : const Color(0xFFFF8A80),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        // ── Bank & Purse Split Cards ──
                        Row(
                          children: [
                            // Bank Card
                            Expanded(
                              child: InkWell(
                                onTap: () {
                                  setState(() {
                                    _selectedFilter = _selectedFilter == 'bank' ? 'all' : 'bank';
                                  });
                                },
                                borderRadius: BorderRadius.circular(14),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: _selectedFilter == 'bank'
                                        ? Colors.blue.withOpacity(0.3)
                                        : Colors.white.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: _selectedFilter == 'bank' ? Colors.lightBlueAccent : Colors.white12,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.account_balance_rounded, color: Colors.lightBlueAccent, size: 20),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text('Bank', style: TextStyle(color: Colors.white70, fontSize: 11)),
                                            Text(
                                              '₹${bankBalance.toStringAsFixed(2)}',
                                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      )
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            // Purse Card
                            Expanded(
                              child: InkWell(
                                onTap: () {
                                  setState(() {
                                    _selectedFilter = _selectedFilter == 'purse' ? 'all' : 'purse';
                                  });
                                },
                                borderRadius: BorderRadius.circular(14),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: _selectedFilter == 'purse'
                                        ? Colors.amber.withOpacity(0.3)
                                        : Colors.white.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: _selectedFilter == 'purse' ? Colors.amberAccent : Colors.white12,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.wallet_rounded, color: Colors.amberAccent, size: 20),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text('Purse (Cash)', style: TextStyle(color: Colors.white70, fontSize: 11)),
                                            Text(
                                              '₹${purseBalance.toStringAsFixed(2)}',
                                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      )
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // ── Search & Filter Row ──
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 40,
                            child: TextField(
                              controller: _searchCtrl,
                              decoration: InputDecoration(
                                hintText: 'Search notes...',
                                hintStyle: const TextStyle(fontSize: 13),
                                prefixIcon: const Icon(Icons.search, size: 18),
                                suffixIcon: _searchQuery.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear, size: 16),
                                        onPressed: () {
                                          _searchCtrl.clear();
                                          setState(() => _searchQuery = '');
                                        },
                                      )
                                    : null,
                                contentPadding: EdgeInsets.zero,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
                              ),
                              onChanged: (val) {
                                setState(() => _searchQuery = val.trim());
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── Filter Chips ──
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    child: Row(
                      children: [
                        ChoiceChip(
                          label: const Text('All'),
                          selected: _selectedFilter == 'all',
                          onSelected: (val) => setState(() => _selectedFilter = 'all'),
                        ),
                        const SizedBox(width: 6),
                        ChoiceChip(
                          label: const Text('🏦 Bank'),
                          selected: _selectedFilter == 'bank',
                          onSelected: (val) => setState(() => _selectedFilter = val ? 'bank' : 'all'),
                        ),
                        const SizedBox(width: 6),
                        ChoiceChip(
                          label: const Text('👛 Purse'),
                          selected: _selectedFilter == 'purse',
                          onSelected: (val) => setState(() => _selectedFilter = val ? 'purse' : 'all'),
                        ),
                        const SizedBox(width: 6),
                        ChoiceChip(
                          label: const Text('📈 Income'),
                          selected: _selectedFilter == 'income',
                          onSelected: (val) => setState(() => _selectedFilter = val ? 'income' : 'all'),
                        ),
                        const SizedBox(width: 6),
                        ChoiceChip(
                          label: const Text('📉 Spend'),
                          selected: _selectedFilter == 'expense',
                          onSelected: (val) => setState(() => _selectedFilter = val ? 'expense' : 'all'),
                        ),
                      ],
                    ),
                  ),

                  // ── Transaction List ──
                  Expanded(
                    child: filteredTxs.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.receipt_long_outlined, size: 54, color: Colors.grey[400]),
                                const SizedBox(height: 10),
                                Text(
                                  allProfileTxs.isEmpty ? 'No transactions yet' : 'No matching records',
                                  style: TextStyle(fontSize: 16, color: Colors.grey[600], fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  allProfileTxs.isEmpty ? 'Tap Add or Spend below to get started.' : 'Try changing your search or filters.',
                                  style: TextStyle(color: Colors.grey[500], fontSize: 13),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(12, 4, 12, 110),
                            itemCount: filteredTxs.length,
                            itemBuilder: (context, index) {
                              final t = filteredTxs[index];
                              final isPurse = t.account == 'purse';

                              return Card(
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                elevation: 1,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                                  leading: CircleAvatar(
                                    backgroundColor: t.isIncome ? Colors.green.shade50 : Colors.red.shade50,
                                    child: Icon(
                                      t.isIncome ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                                      color: t.isIncome ? Colors.green[700] : Colors.red[700],
                                    ),
                                  ),
                                  title: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          t.reason,
                                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                                        ),
                                      ),
                                    ],
                                  ),
                                  subtitle: Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Row(
                                      children: [
                                        // Account Tag
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: isPurse ? Colors.amber.shade50 : Colors.blue.shade50,
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(
                                              color: isPurse ? Colors.amber.shade200 : Colors.blue.shade200,
                                              width: 0.8,
                                            ),
                                          ),
                                          child: Text(
                                            isPurse ? '👛 Purse' : '🏦 Bank',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: isPurse ? Colors.amber[900] : Colors.blue[900],
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          DateFormat.yMMMd().add_jm().format(t.date),
                                          style: TextStyle(fontSize: 11.5, color: Colors.grey[600]),
                                        ),
                                      ],
                                    ),
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            '${t.isIncome ? '+' : '-'}₹${t.amount.toStringAsFixed(2)}',
                                            style: TextStyle(
                                              color: t.isIncome ? Colors.green[800] : Colors.red[800],
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'Bal: ₹${t.newBalance.toStringAsFixed(2)}',
                                            style: const TextStyle(fontSize: 11, color: Colors.black54),
                                          ),
                                        ],
                                      ),
                                      PopupMenuButton<String>(
                                        icon: const Icon(Icons.more_vert, color: Colors.grey, size: 20),
                                        onSelected: (value) {
                                          if (value == 'edit') {
                                            _showTransactionDialog(
                                              transaction: t,
                                              isIncome: t.isIncome,
                                            );
                                          } else if (value == 'delete') {
                                            _deleteTransaction(t);
                                          }
                                        },
                                        itemBuilder: (context) => const [
                                          PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit_outlined, size: 18), SizedBox(width: 8), Text('Edit')])),
                                          PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline, color: Colors.red, size: 18), SizedBox(width: 8), Text('Delete', style: TextStyle(color: Colors.red))])),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              );
            },
          ),
          floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
          floatingActionButton: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FloatingActionButton.extended(
                  heroTag: 'add_money',
                  onPressed: () => _showTransactionDialog(isIncome: true),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add Money', style: TextStyle(fontWeight: FontWeight.bold)),
                  backgroundColor: Colors.green[700],
                  foregroundColor: Colors.white,
                  elevation: 4,
                ),
                const SizedBox(width: 14),
                FloatingActionButton.extended(
                  heroTag: 'spend_money',
                  onPressed: () => _showTransactionDialog(isIncome: false),
                  icon: const Icon(Icons.remove_rounded),
                  label: const Text('Spend Money', style: TextStyle(fontWeight: FontWeight.bold)),
                  backgroundColor: Colors.red[700],
                  foregroundColor: Colors.white,
                  elevation: 4,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
