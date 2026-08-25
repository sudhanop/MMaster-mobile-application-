import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/profile.dart';
import '../models/ledger_tx.dart';
import 'profile_detail.dart';

String _initials(String name) {
  if (name.trim().isEmpty) return '?';
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.length == 1 || parts[1].isEmpty) {
    return parts[0].substring(0, 1).toUpperCase();
  }
  return (parts[0][0] + parts[1][0]).toUpperCase();
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Box<Profile>? profilesBox;
  Box<LedgerTx>? txBox;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initHive();
  }

  Future<void> _initHive() async {
    try {
      if (!Hive.isBoxOpen('profiles')) {
        await Hive.openBox<Profile>('profiles');
      }
      if (!Hive.isBoxOpen('transactions')) {
        await Hive.openBox<LedgerTx>('transactions');
      }
      if (mounted) {
        setState(() {
          profilesBox = Hive.box<Profile>('profiles');
          txBox = Hive.box<LedgerTx>('transactions');
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _showProfileDialog({Profile? profile}) async {
    final nameCtrl = TextEditingController(text: profile?.name ?? '');
    bool isSubmitting = false;

    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(builder: (ctx, setStateDialog) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(profile == null ? 'Add Profile' : 'Edit Profile',
              style: const TextStyle(fontWeight: FontWeight.bold)),
          content: TextField(
            controller: nameCtrl,
            decoration: InputDecoration(
              labelText: 'Profile Name',
              hintText: 'e.g. Personal, Business, Home',
              prefixIcon: const Icon(Icons.person_outline),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
            textCapitalization: TextCapitalization.words,
            autofocus: true,
          ),
          actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogCtx).pop();
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: isSubmitting
                  ? null
                  : () async {
                      final name = nameCtrl.text.trim();
                      if (name.isEmpty) return;
                      setStateDialog(() => isSubmitting = true);

                      // Dismiss dialog immediately
                      Navigator.of(dialogCtx).pop();

                      final box = profilesBox ?? Hive.box<Profile>('profiles');
                      if (profile == null) {
                        final id = DateTime.now().microsecondsSinceEpoch;
                        final newProfile = Profile(id: id, name: name, balance: 0.0);
                        await box.put(id, newProfile);
                      } else {
                        profile.name = name;
                        if (profile.isInBox) {
                          await profile.save();
                        } else {
                          await box.put(profile.id, profile);
                        }
                      }
                    },
              child: Text(profile == null ? 'Create' : 'Save'),
            ),
          ],
        );
      }),
    );
  }

  Future<void> _deleteProfile(Profile profile) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
            SizedBox(width: 8),
            Text('Delete Profile?'),
          ],
        ),
        content: Text(
          'This will permanently remove "${profile.name}" and all associated transaction records.',
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final tBox = txBox ?? Hive.box<LedgerTx>('transactions');
      final txsToDelete = tBox.values.where((tx) => tx.profileId == profile.id).toList();
      for (final tx in txsToDelete) {
        if (tx.isInBox) {
          await tx.delete();
        } else {
          await tBox.delete(tx.id);
        }
      }
      final pBox = profilesBox ?? Hive.box<Profile>('profiles');
      if (profile.isInBox) {
        await profile.delete();
      } else {
        await pBox.delete(profile.id);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || profilesBox == null || txBox == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('MMaster', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final pBox = profilesBox!;
    final tBox = txBox!;

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.account_balance_wallet_rounded, size: 24),
            SizedBox(width: 8),
            Text('MMaster', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1.2)),
          ],
        ),
      ),
      body: ValueListenableBuilder(
        valueListenable: pBox.listenable(),
        builder: (context, Box<Profile> profilesListenableBox, _) {
          return ValueListenableBuilder(
            valueListenable: tBox.listenable(),
            builder: (context, Box<LedgerTx> txListenableBox, _) {
              final profiles = profilesListenableBox.values.toList();
              final allTxs = txListenableBox.values.toList();

              // Calculate overall metrics
              double totalOverallBalance = 0;
              double totalBankBalance = 0;
              double totalPurseBalance = 0;

              for (final tx in allTxs) {
                final signedAmt = tx.isIncome ? tx.amount : -tx.amount;
                totalOverallBalance += signedAmt;
                if (tx.account == 'purse') {
                  totalPurseBalance += signedAmt;
                } else {
                  totalBankBalance += signedAmt;
                }
              }

              if (profiles.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A237E).withOpacity(0.08),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.people_outline_rounded, size: 64, color: Color(0xFF1A237E)),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Welcome to MMaster',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1A237E)),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Manage your personal ledger, cash purse, and bank balances effortlessly.',
                          style: TextStyle(color: Colors.grey[700], fontSize: 14),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () => _showProfileDialog(),
                          icon: const Icon(Icons.add),
                          label: const Text('Create First Profile'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        )
                      ],
                    ),
                  ),
                );
              }

              return ListView(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 90),
                children: [
                  // ── Global Overview Banner ──
                  Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0D1B2A), Color(0xFF1B263B), Color(0xFF1A237E)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF1A237E).withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 5),
                        )
                      ],
                    ),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'TOTAL NET BALANCE',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white12,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${profiles.length} Profile${profiles.length > 1 ? 's' : ''}',
                                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '₹${totalOverallBalance.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            color: totalOverallBalance >= 0 ? const Color(0xFFB9F6CA) : const Color(0xFFFF8A80),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Divider(color: Colors.white24, height: 1),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            // Bank balance chip
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: Colors.white12),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.withOpacity(0.2),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.account_balance_rounded, color: Colors.lightBlueAccent, size: 18),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text('Bank', style: TextStyle(color: Colors.white70, fontSize: 11)),
                                          Text(
                                            '₹${totalBankBalance.toStringAsFixed(2)}',
                                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    )
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Purse balance chip
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: Colors.white12),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.amber.withOpacity(0.2),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.wallet_rounded, color: Colors.amberAccent, size: 18),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text('Purse (Cash)', style: TextStyle(color: Colors.white70, fontSize: 11)),
                                          Text(
                                            '₹${totalPurseBalance.toStringAsFixed(2)}',
                                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    )
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      'Profiles',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // ── Profiles List ──
                  ...profiles.map((profile) {
                    final profileTxs = allTxs.where((t) => t.profileId == profile.id).toList();
                    double profileBank = 0;
                    double profilePurse = 0;
                    for (final t in profileTxs) {
                      final val = t.isIncome ? t.amount : -t.amount;
                      if (t.account == 'purse') {
                        profilePurse += val;
                      } else {
                        profileBank += val;
                      }
                    }

                    final isPositive = profile.balance >= 0;

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      elevation: 1.5,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ProfileDetailScreen(profileId: profile.id),
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(14.0),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 24,
                                    backgroundColor: const Color(0xFF1A237E).withOpacity(0.12),
                                    child: Text(
                                      _initials(profile.name),
                                      style: const TextStyle(
                                        color: Color(0xFF1A237E),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          profile.name,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${profileTxs.length} transaction${profileTxs.length == 1 ? '' : 's'}',
                                          style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '₹${profile.balance.toStringAsFixed(2)}',
                                        style: TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.w800,
                                          color: isPositive ? Colors.green[700] : Colors.red[700],
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text('Balance', style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                                    ],
                                  ),
                                  PopupMenuButton<String>(
                                    icon: const Icon(Icons.more_vert, color: Colors.grey),
                                    onSelected: (value) {
                                      if (value == 'edit') {
                                        _showProfileDialog(profile: profile);
                                      } else if (value == 'delete') {
                                        _deleteProfile(profile);
                                      }
                                    },
                                    itemBuilder: (context) => const [
                                      PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit_outlined, size: 18), SizedBox(width: 8), Text('Edit')])),
                                      PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline, color: Colors.red, size: 18), SizedBox(width: 8), Text('Delete', style: TextStyle(color: Colors.red))])),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              const Divider(height: 1),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.account_balance_rounded, size: 13, color: Colors.blue),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Bank: ₹${profileBank.toStringAsFixed(2)}',
                                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.blue),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.wallet_rounded, size: 13, color: Colors.amber[800]),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Purse: ₹${profilePurse.toStringAsFixed(2)}',
                                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.amber[900]),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              )
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ],
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showProfileDialog(),
        icon: const Icon(Icons.person_add_rounded),
        label: const Text('Add Profile', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }
}
