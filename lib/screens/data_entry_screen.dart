import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/config.dart';
import '../core/theme.dart';
import '../core/utils.dart';
import '../models/models.dart';
import '../services/repos.dart';
import '../services/sheets_sync.dart';
import '../state/hub.dart';
import '../widgets/ui.dart';

/// Module 4 – Admin data entry (Admin & Super Admin only; route is also
/// protected by Firestore rules, not just the UI).
class DataEntryScreen extends StatelessWidget {
  const DataEntryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Data Entry'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Deposits'),
              Tab(text: 'Members'),
              Tab(text: 'Sheets Sync'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [_DepositsTab(), _MembersTab(), _SyncTab()],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------- deposits tab
class _DepositsTab extends StatefulWidget {
  const _DepositsTab();

  @override
  State<_DepositsTab> createState() => _DepositsTabState();
}

class _DepositsTabState extends State<_DepositsTab> {
  String? _accountFilter;
  String? _periodFilter;

  @override
  Widget build(BuildContext context) {
    final hub = context.watch<DataHub>();
    final scheme = Theme.of(context).colorScheme;
    var list = hub.deposits;
    if (_accountFilter != null) {
      list = list.where((d) => d.accountId == _accountFilter).toList();
    }
    if (_periodFilter != null) {
      list = list.where((d) => d.period == _periodFilter).toList();
    }
    list = [...list]..sort((a, b) => b.period.compareTo(a.period));

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editDeposit(context, null),
        icon: const Icon(Icons.add),
        label: const Text('Deposit'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String?>(
                    initialValue: _accountFilter,
                    decoration:
                        const InputDecoration(isDense: true, prefixIcon: Icon(Icons.account_balance_outlined, size: 20)),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('All accounts')),
                      for (final a in hub.accounts)
                        DropdownMenuItem(value: a.id, child: Text(a.name)),
                    ],
                    onChanged: (v) => setState(() => _accountFilter = v),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final p = await _pickPeriod(context, _periodFilter);
                      setState(() => _periodFilter = p);
                    },
                    icon: const Icon(Icons.calendar_month_outlined, size: 18),
                    label: Text(
                        _periodFilter == null
                            ? 'All months'
                            : Fmt.period(_periodFilter!),
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12.5)),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: list.isEmpty
                ? const EmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: 'No deposit entries',
                    message: 'Tap “Deposit” to add one, or use Sheets Sync.')
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (ctx, i) {
                      final d = list[i];
                      return Card(
                        child: ListTile(
                          onTap: () => _editDeposit(context, d),
                          title: Text(
                              '${d.memberName} (${d.memberCode})',
                              style: const TextStyle(
                                  fontSize: 13.5, fontWeight: FontWeight.w700)),
                          subtitle: Text(
                              '${d.accountName} • ${Fmt.period(d.period)} • by ${d.source}',
                              style: TextStyle(
                                  fontSize: 11, color: scheme.onSurfaceVariant)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                  '${AppConfig.currencySymbol} ${Fmt.money(d.amount)}',
                                  style: const TextStyle(
                                      fontSize: 13.5, fontWeight: FontWeight.w800)),
                              IconButton(
                                tooltip: 'Delete',
                                icon: const Icon(Icons.delete_outline,
                                    size: 20, color: AppTheme.danger),
                                onPressed: () async {
                                  final ok = await confirmDialog(
                                      context,
                                      'Delete deposit?',
                                      '${d.memberName} • ${Fmt.period(d.period)} • ${Fmt.money(d.amount)}\nThis will be recorded in the audit log.',
                                      okLabel: 'Delete',
                                      danger: true);
                                  if (ok) {
                                    await Repos.deleteDeposit(d);
                                    if (ctx.mounted) {
                                      snack(ctx, 'Deposit deleted.');
                                    }
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _editDeposit(BuildContext context, Deposit? existing) async {
    final hub = context.read<DataHub>();
    if (hub.members.isEmpty || hub.accounts.isEmpty) {
      snack(context, 'Import members & accounts from Google Sheets first.',
          error: true);
      return;
    }
    final member = ValueNotifier<Member>(
        existing != null
            ? hub.memberById(existing.memberId) ?? hub.members.first
            : hub.members.first);
    final account = ValueNotifier<Account>(
        existing != null
            ? hub.accounts.firstWhere((a) => a.id == existing.accountId,
                orElse: () => hub.accounts.first)
            : hub.accounts.first);
    final period = ValueNotifier<String>(existing?.period ?? Fmt.currentPeriod());
    final amount = TextEditingController(text: existing?.amount.toStringAsFixed(0) ?? '');
    final note = TextEditingController(text: existing?.note ?? '');

    await showModalSheet(
      context,
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(existing == null ? 'Add Deposit' : 'Edit Deposit',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 14),
            ValueListenableBuilder<Member>(
              valueListenable: member,
              builder: (ctx, m, _) => DropdownButtonFormField<Member>(
                initialValue: m,
                decoration: const InputDecoration(labelText: 'Member'),
                items: [
                  for (final mem in hub.members)
                    DropdownMenuItem(
                        value: mem, child: Text('${mem.code} – ${mem.name}')),
                ],
                onChanged: (v) => member.value = v!,
              ),
            ),
            const SizedBox(height: 10),
            ValueListenableBuilder<Account>(
              valueListenable: account,
              builder: (ctx, a, _) => DropdownButtonFormField<Account>(
                initialValue: a,
                decoration: const InputDecoration(labelText: 'Account'),
                items: [
                  for (final acc in hub.accounts)
                    DropdownMenuItem(value: acc, child: Text(acc.name)),
                ],
                onChanged: (v) => account.value = v!,
              ),
            ),
            const SizedBox(height: 10),
            ValueListenableBuilder<String>(
              valueListenable: period,
              builder: (ctx, p, _) => OutlinedButton.icon(
                onPressed: () async {
                  final np = await _pickPeriod(ctx, p);
                  if (np != null) period.value = np;
                },
                icon: const Icon(Icons.calendar_month_outlined, size: 18),
                label: Text('Month: ${Fmt.period(p)}'),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: amount,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: 'Amount', prefixText: '${AppConfig.currencySymbol} '),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: note,
              decoration: const InputDecoration(labelText: 'Note (optional)'),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: () async {
                final value = double.tryParse(amount.text.trim());
                if (value == null || value <= 0) {
                  snack(context, 'Enter a valid amount.', error: true);
                  return;
                }
                final d = Deposit(
                  id: existing?.id ?? '',
                  memberId: member.value.id,
                  memberCode: member.value.code,
                  memberName: member.value.name,
                  accountId: account.value.id,
                  accountName: account.value.name,
                  period: period.value,
                  amount: value,
                  note: note.text.trim(),
                  source: existing?.source ?? 'app',
                );
                Navigator.pop(context);
                await Repos.saveDeposit(d, isNew: existing == null);
                if (context.mounted) {
                  snack(context,
                      existing == null ? 'Deposit added.' : 'Deposit updated.');
                }
              },
              child: Text(existing == null ? 'Add Deposit' : 'Save Changes'),
            ),
          ],
        ),
      ),
    );
  }
}

Future<String?> _pickPeriod(BuildContext context, String? current) async {
  final now = DateTime.now();
  final initial = current != null
      ? DateTime(
          int.parse(current.split('-').first), int.parse(current.split('-')[1]))
      : DateTime(now.year, now.month);
  final picked = await showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: DateTime(2020),
    lastDate: DateTime(now.year + 2, 12),
    initialDatePickerMode: DatePickerMode.day,
  );
  if (picked == null) return null;
  return '${picked.year}-${picked.month.toString().padLeft(2, '0')}';
}

// ------------------------------------------------------------- members tab
class _MembersTab extends StatelessWidget {
  const _MembersTab();

  @override
  Widget build(BuildContext context) {
    final hub = context.watch<DataHub>();
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editMember(context, null),
        icon: const Icon(Icons.person_add_alt),
        label: const Text('Member'),
      ),
      body: hub.members.isEmpty
          ? const EmptyState(
              icon: Icons.group_add_outlined,
              title: 'No members',
              message: 'Add members here or bulk import from Google Sheets.')
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
              itemCount: hub.members.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (ctx, i) {
                final m = hub.members[i];
                return Card(
                  child: ListTile(
                    onTap: () => _editMember(ctx, m),
                    leading: CircleAvatar(
                        child: Text('${m.code}')),
                    title: Text(m.name,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(m.active ? 'Active' : 'Removed',
                        style: TextStyle(
                            fontSize: 11,
                            color: m.active
                                ? AppTheme.success
                                : AppTheme.danger)),
                    trailing: IconButton(
                      tooltip: m.active ? 'Remove member' : 'Restore',
                      icon: Icon(
                          m.active
                              ? Icons.person_remove_outlined
                              : Icons.person_add_outlined,
                          color: m.active ? AppTheme.danger : AppTheme.success),
                      onPressed: () async {
                        if (m.active) {
                          final ok = await confirmDialog(
                              ctx,
                              'Remove member?',
                              '${m.name} will be marked inactive (history is kept).',
                              okLabel: 'Remove',
                              danger: true);
                          if (ok) {
                            await Repos.saveMember(
                                Member(
                                    id: m.id,
                                    code: m.code,
                                    name: m.name,
                                    phone: m.phone,
                                    joinedAt: m.joinedAt,
                                    active: false),
                                isNew: false);
                          }
                        } else {
                          await Repos.saveMember(
                              Member(
                                  id: m.id,
                                  code: m.code,
                                  name: m.name,
                                  phone: m.phone,
                                  joinedAt: m.joinedAt,
                                  active: true),
                              isNew: false);
                        }
                      },
                    ),
                  ),
                );
              },
            ),
    );
  }

  Future<void> _editMember(BuildContext context, Member? existing) async {
    final code = TextEditingController(text: existing?.code.toString() ?? '');
    final name = TextEditingController(text: existing?.name ?? '');
    final phone = TextEditingController(text: existing?.phone ?? '');
    await showModalSheet(
      context,
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(existing == null ? 'Add Member' : 'Update Member',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 14),
            TextField(
                controller: code,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Member ID (e.g. 115)')),
            const SizedBox(height: 10),
            TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Full name')),
            const SizedBox(height: 10),
            TextField(
                controller: phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Phone (optional)')),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: () async {
                final c = int.tryParse(code.text.trim());
                if (c == null || name.text.trim().isEmpty) {
                  snack(context, 'ID and name are required.', error: true);
                  return;
                }
                Navigator.pop(context);
                await Repos.saveMember(
                    Member(
                        id: existing?.id ?? 'm_$c',
                        code: c,
                        name: name.text.trim(),
                        phone: phone.text.trim(),
                        joinedAt: existing?.joinedAt,
                        active: existing?.active ?? true),
                    isNew: existing == null);
                if (context.mounted) {
                  snack(context,
                      existing == null ? 'Member added.' : 'Member updated.');
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- sync tab
class _SyncTab extends StatefulWidget {
  const _SyncTab();

  @override
  State<_SyncTab> createState() => _SyncTabState();
}

class _SyncTabState extends State<_SyncTab> {
  bool _busy = false;
  String _lastResult = '';

  Future<void> _run(Future<String> Function() fn) async {
    setState(() {
      _busy = true;
      _lastResult = '';
    });
    try {
      final msg = await fn();
      setState(() => _lastResult = msg);
    } catch (e) {
      setState(() => _lastResult = 'Failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hub = context.watch<DataHub>();
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SectionCard(
          title: 'Bulk import from Google Sheets',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Pulls members, accounts, the monthly deposit grids (1st & 2nd Account tabs) and the Investment tab into the app. Re-running is safe: existing rows are updated, not duplicated.',
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _busy || !SheetsSync.configured
                    ? null
                    : () => _run(SheetsSync.importAll),
                icon: const Icon(Icons.cloud_download_outlined),
                label: Text(_busy ? 'Working…' : 'Import now'),
              ),
              if (!SheetsSync.configured)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Not configured: deploy apps_script/Code.gs as a Web App and paste the URL into lib/core/config.dart.',
                    style: TextStyle(fontSize: 11, color: AppTheme.warning),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: 'Push app data back to Google Sheets',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Writes every app deposit into the matching member row / month column of the sheet, so the spreadsheet stays the source of truth for printing.',
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _busy || !SheetsSync.configured
                    ? null
                    : () => _run(() => SheetsSync.exportToSheets(hub.deposits)),
                icon: const Icon(Icons.cloud_upload_outlined),
                label: Text(_busy ? 'Working…' : 'Export ${hub.deposits.length} rows'),
              ),
            ],
          ),
        ),
        if (_lastResult.isNotEmpty) ...[
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Icon(
                      _lastResult.startsWith('Failed')
                          ? Icons.error_outline
                          : Icons.check_circle_outline,
                      color: _lastResult.startsWith('Failed')
                          ? AppTheme.danger
                          : AppTheme.success),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Text(_lastResult,
                          style: const TextStyle(fontSize: 12.5))),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
