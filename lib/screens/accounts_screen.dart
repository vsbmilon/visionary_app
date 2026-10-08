import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/config.dart';
import '../core/theme.dart';
import '../core/utils.dart';
import '../models/models.dart';
import '../services/repos.dart';
import '../state/hub.dart';
import '../state/session.dart';
import '../widgets/charts.dart';
import '../widgets/ui.dart';

/// Module 6 – Account management. Admin controls which accounts members
/// can see; hidden accounts simply never reach unauthorized clients
/// (enforced by Firestore rules as well).
class AccountsScreen extends StatefulWidget {
  const AccountsScreen({super.key});

  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> {
  String? _selected;

  @override
  Widget build(BuildContext context) {
    final hub = context.watch<DataHub>();
    final session = context.watch<Session>();
    final scheme = Theme.of(context).colorScheme;
    final visible = session.visibleAccounts(hub.accounts);
    final sel = _selected != null &&
            visible.any((a) => a.id == _selected)
        ? _selected!
        : (visible.isNotEmpty ? visible.first.id : null);
    final selAccount =
        sel == null ? null : visible.firstWhere((a) => a.id == sel);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Accounts'),
        actions: [
          if (session.isAdmin)
            IconButton(
              tooltip: 'Add account',
              icon: const Icon(Icons.add_circle_outline),
              onPressed: () => _addAccount(context, hub.accounts.length),
            ),
        ],
      ),
      body: visible.isEmpty
          ? const EmptyState(
              icon: Icons.account_balance_wallet_outlined,
              title: 'No accounts visible to you',
              message: 'An admin can grant you access from Accounts settings.')
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                SizedBox(
                  height: 108,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: visible.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (ctx, i) {
                      final a = visible[i];
                      final balance = hub.depositTotal(accountId: a.id) -
                          hub.expenses
                              .where((e) => e.category == a.id)
                              .fold<double>(0, (p, e) => p + e.amount);
                      final selected = a.id == sel;
                      return GestureDetector(
                        onTap: () => setState(() => _selected = a.id),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: 190,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            gradient: selected
                                ? const LinearGradient(
                                    colors: [
                                      AppTheme.brandBlueDark,
                                      AppTheme.brandAccent
                                    ])
                                : null,
                            color: selected
                                ? null
                                : scheme.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: selected
                                    ? Colors.transparent
                                    : scheme.outlineVariant),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(a.name,
                                        style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w800,
                                            color: selected
                                                ? Colors.white
                                                : scheme.onSurface)),
                                  ),
                                  if (!a.memberVisible && session.isAdmin)
                                    Icon(Icons.visibility_off,
                                        size: 14,
                                        color: Colors.white
                                            .withValues(alpha: 0.85)),
                                ],
                              ),
                              Text(
                                  '${AppConfig.currencySymbol} ${Fmt.money(balance)}',
                                  style: TextStyle(
                                      fontSize: 19,
                                      fontWeight: FontWeight.w800,
                                      color: selected
                                          ? Colors.white
                                          : scheme.onSurface)),
                              Text('current balance',
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: selected
                                          ? Colors.white
                                              .withValues(alpha: 0.8)
                                          : scheme.onSurfaceVariant)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 14),
                if (selAccount != null) ...[
                  SectionCard(
                    title: '${selAccount.name} — Monthly Transactions',
                    trailing: session.isAdmin
                        ? IconButton(
                            tooltip: 'Account settings',
                            icon: const Icon(Icons.tune, size: 20),
                            onPressed: () =>
                                _accountSettings(context, selAccount),
                          )
                        : null,
                    child: MonthlyBarChart(
                      data: {
                        for (final p in Fmt.lastPeriods(12))
                          p: hub.deposits
                              .where((d) =>
                                  d.accountId == selAccount.id &&
                                  d.period == p)
                              .fold<double>(0, (s, d) => s + d.amount),
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  SectionCard(
                    title: 'Transaction Summary',
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                    child: Column(
                      children: [
                        _sumRow('Total collected',
                            hub.depositTotal(accountId: selAccount.id)),
                        _sumRow(
                            'Entries',
                            hub.deposits
                                .where((d) => d.accountId == selAccount.id)
                                .length
                                .toDouble()),
                        _sumRow(
                            'Expected / member / month',
                            selAccount.expectedMonthly),
                        _sumRow(
                            'Paid this month',
                            hub.depositTotal(
                                accountId: selAccount.id,
                                period: hub.currentPeriod)),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ],
              ],
            ),
    );
  }

  Widget _sumRow(String label, double v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Expanded(
                child: Text(label,
                    style: TextStyle(
                        fontSize: 12.5,
                        color: Theme.of(context).colorScheme.onSurfaceVariant))),
            Text('${AppConfig.currencySymbol} ${Fmt.money(v)}',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          ],
        ),
      );

  Future<void> _accountSettings(BuildContext context, Account a) async {
    final expected =
        TextEditingController(text: a.expectedMonthly.toStringAsFixed(0));
    bool memberVisible = a.memberVisible;
    await showModalSheet(
      context,
      StatefulBuilder(
        builder: (ctx, setSt) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('${a.name} settings',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: memberVisible,
                title: const Text('Visible to members',
                    style: TextStyle(fontSize: 13.5)),
                subtitle: Text(
                    memberVisible
                        ? 'Every member can see this account and its deposits.'
                        : 'Hidden from members (admins & granted viewers only).',
                    style: const TextStyle(fontSize: 11)),
                onChanged: (v) => setSt(() => memberVisible = v),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: expected,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Expected monthly deposit per member'),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  await Repos.saveAccount(Account(
                    id: a.id,
                    name: a.name,
                    order: a.order,
                    memberVisible: memberVisible,
                    expectedMonthly:
                        double.tryParse(expected.text) ?? a.expectedMonthly,
                    extraViewerUids: a.extraViewerUids,
                  ));
                },
                child: const Text('Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _addAccount(BuildContext context, int order) async {
    final name = TextEditingController();
    await showModalSheet(
      context,
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('New Account',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            TextField(
                controller: name,
                decoration:
                    const InputDecoration(labelText: 'Account name (e.g. 3rd Account)')),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () async {
                if (name.text.trim().isEmpty) return;
                Navigator.pop(context);
                final id = 'acct_${order + 1}';
                await Repos.saveAccount(Account(
                    id: id,
                    name: name.text.trim(),
                    order: order + 1,
                    memberVisible: false));
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }
}
