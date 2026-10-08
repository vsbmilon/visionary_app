import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/config.dart';
import '../core/theme.dart';
import '../core/utils.dart';
import '../models/models.dart';
import '../state/hub.dart';
import '../state/session.dart';
import '../widgets/charts.dart';
import '../widgets/ui.dart';

/// Module 2 – Member summary (search + sort + totals).
class MembersScreen extends StatefulWidget {
  const MembersScreen({super.key});

  @override
  State<MembersScreen> createState() => _MembersScreenState();
}

enum _Sort { deposit, name, code }

class _MembersScreenState extends State<MembersScreen> {
  String _q = '';
  _Sort _sort = _Sort.deposit;

  @override
  Widget build(BuildContext context) {
    final hub = context.watch<DataHub>();
    final scheme = Theme.of(context).colorScheme;

    var list = hub.members.where((m) => m.active).toList();
    if (_q.isNotEmpty) {
      list = list
          .where((m) =>
              m.name.toLowerCase().contains(_q.toLowerCase()) ||
              '${m.code}'.contains(_q))
          .toList();
    }
    list.sort((a, b) => switch (_sort) {
          _Sort.deposit =>
              hub.depositTotal(memberId: b.id).compareTo(hub.depositTotal(memberId: a.id)),
          _Sort.name => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          _Sort.code => a.code.compareTo(b.code),
        });

    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    onChanged: (v) => setState(() => _q = v),
                    decoration: InputDecoration(
                      isDense: true,
                      prefixIcon: const Icon(Icons.search, size: 20),
                      hintText: 'Search member by name or ID…',
                      suffixIcon: _q.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.close, size: 18),
                              onPressed: () => setState(() => _q = '')),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                PopupMenuButton<_Sort>(
                  tooltip: 'Sort',
                  initialValue: _sort,
                  onSelected: (v) => setState(() => _sort = v),
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                        value: _Sort.deposit, child: Text('Highest deposit')),
                    PopupMenuItem(value: _Sort.name, child: Text('Name A–Z')),
                    PopupMenuItem(value: _Sort.code, child: Text('Member ID')),
                  ],
                  child: Container(
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.sort_rounded, size: 20),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: list.isEmpty
                ? EmptyState(
                    icon: Icons.group_outlined,
                    title: 'No members found',
                    message: _q.isEmpty
                        ? 'Import data from Google Sheets or add members in Data Entry.'
                        : 'Nothing matches “$_q”.')
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (ctx, i) {
                      final m = list[i];
                      final total = hub.depositTotal(memberId: m.id);
                      return Card(
                        child: ListTile(
                          onTap: () => Navigator.push(
                              ctx,
                              MaterialPageRoute(
                                  builder: (_) => MemberDetailScreen(member: m))),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 6),
                          leading: CircleAvatar(
                            radius: 21,
                            backgroundColor:
                                AppTheme.brandBlue.withValues(alpha: 0.12),
                            child: Text('${m.code}',
                                style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.brandBlue,
                                    fontSize: 13)),
                          ),
                          title: Text(m.name,
                              style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w700)),
                          subtitle: Text(
                              'Joined ${Fmt.date(m.joinedAt?.toDate())}',
                              style: TextStyle(
                                  fontSize: 11, color: scheme.onSurfaceVariant)),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                  '${AppConfig.currencySymbol} ${Fmt.money(total)}',
                                  style: const TextStyle(
                                      fontSize: 14, fontWeight: FontWeight.w800)),
                              Text('total deposit',
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: scheme.onSurfaceVariant)),
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
}

/// Module 3 – Member details: profile, monthly history, payment status,
/// total contribution and deposit trend chart.
class MemberDetailScreen extends StatelessWidget {
  final Member member;
  const MemberDetailScreen({super.key, required this.member});

  @override
  Widget build(BuildContext context) {
    final hub = context.watch<DataHub>();
    final session = context.watch<Session>();
    final scheme = Theme.of(context).colorScheme;
    final myDeposits = hub.depositsOf(member.id);
    final total = hub.depositTotal(memberId: member.id);
    final accounts = session.visibleAccounts(hub.accounts);

    // trend: monthly totals oldest -> newest
    final periods = Fmt.lastPeriods(12);
    final points = <(String, double)>[
      for (final p in periods)
        (
          p,
          myDeposits
              .where((d) => d.period == p)
              .fold<double>(0, (s, d) => s + d.amount)
        ),
    ];

    return Scaffold(
      appBar: AppBar(title: Text('Member ${member.code}')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 27,
                    backgroundColor: AppTheme.brandBlue.withValues(alpha: 0.12),
                    child: Text('${member.code}',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.brandBlue)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(member.name,
                            style: const TextStyle(
                                fontSize: 16.5, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 3),
                        Text(
                            'Joined ${Fmt.date(member.joinedAt?.toDate())}${member.phone.isNotEmpty ? ' • ${member.phone}' : ''}',
                            style: TextStyle(
                                fontSize: 11.5, color: scheme.onSurfaceVariant)),
                        const SizedBox(height: 8),
                        Wrap(spacing: 6, children: [
                          for (final a in accounts)
                            StatusChip(
                              text:
                                  '${a.name}: ${Fmt.money(hub.depositTotal(memberId: member.id, accountId: a.id))}',
                              color: AppTheme.brandBlue,
                            ),
                        ]),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: StatCard(
                  label: 'Total Contribution',
                  value: '${AppConfig.currencySymbol} ${Fmt.money(total)}',
                  icon: Icons.savings_rounded,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatCard(
                  label: 'Entries',
                  value: '${myDeposits.length}',
                  icon: Icons.receipt_long_outlined,
                  color: AppTheme.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: 'Deposit Trend (12 months)',
            child: TrendLineChart(points: points),
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: 'Monthly Deposit History & Payment Status',
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
            child: myDeposits.isEmpty
                ? const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: EmptyState(
                        icon: Icons.inbox_outlined, title: 'No deposits yet'))
                : Column(
                    children: [
                      for (final d in myDeposits)
                        ListTile(
                          dense: true,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 2),
                          leading: Icon(Icons.calendar_month_outlined,
                              size: 18, color: scheme.onSurfaceVariant),
                          title: Text(Fmt.period(d.period),
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w600)),
                          subtitle: Text(d.accountName,
                              style: TextStyle(
                                  fontSize: 11, color: scheme.onSurfaceVariant)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              StatusChip(
                                text: hub.statusFor(
                                    d.amount,
                                    accounts
                                        .firstWhere((a) => a.id == d.accountId,
                                            orElse: () => Account(
                                                id: '', name: ''))
                                        .expectedMonthly),
                                color: statusColor(hub.statusFor(
                                    d.amount,
                                    accounts
                                        .firstWhere((a) => a.id == d.accountId,
                                            orElse: () => Account(
                                                id: '', name: ''))
                                        .expectedMonthly)),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 72,
                                child: Text(
                                    '${AppConfig.currencySymbol} ${Fmt.money(d.amount)}',
                                    textAlign: TextAlign.end,
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800)),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 8),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
