import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/config.dart';
import '../core/theme.dart';
import '../core/utils.dart';
import '../state/hub.dart';
import '../state/session.dart';
import '../widgets/charts.dart';
import '../widgets/ui.dart';

/// Module 1 – Dashboard.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final hub = context.watch<DataHub>();
    final session = context.watch<Session>();
    final scheme = Theme.of(context).colorScheme;
    final visibleAccounts = session.visibleAccounts(hub.accounts);
    final monthly = hub.monthlyTotals(12);

    return RefreshIndicator(
      onRefresh: () async => Future.delayed(const Duration(milliseconds: 400)),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          // Organization banner
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.brandBlueDark, AppTheme.brandAccent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.insights_rounded,
                          color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(AppConfig.orgName,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 19,
                                  fontWeight: FontWeight.w800)),
                          Text(
                              'Welcome back, ${session.doc?.name.isNotEmpty == true ? session.doc!.name.split(' ').first : 'member'}',
                              style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.85),
                                  fontSize: 12)),
                        ],
                      ),
                    ),
                    Icon(Icons.verified_user_rounded,
                        color: Colors.white.withValues(alpha: 0.8), size: 20),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _bannerStat('Group Total Balance',
                        '${AppConfig.currencySymbol} ${Fmt.money(hub.groupBalance)}'),
                    _bannerStat('Total Deposits',
                        '${AppConfig.currencySymbol} ${Fmt.money(hub.totalDeposits)}'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            childAspectRatio: 1.55,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            children: [
              StatCard(
                label: 'Active Members',
                value: '${hub.activeMembers}',
                icon: Icons.group_rounded,
                color: AppTheme.success,
                caption: 'of ${hub.members.length}',
              ),
              StatCard(
                label: 'This Month Collection',
                value: '${AppConfig.currencySymbol} ${Fmt.money(hub.thisMonthCollection)}',
                icon: Icons.savings_rounded,
                color: AppTheme.brandAccent,
                caption: Fmt.period(hub.currentPeriod),
              ),
              StatCard(
                label: 'Accounts Tracked',
                value: '${visibleAccounts.length}',
                icon: Icons.account_balance_outlined,
                color: AppTheme.warning,
                caption: visibleAccounts.map((a) => a.name).join(', '),
              ),
              StatCard(
                label: 'Deposit Entries',
                value: '${hub.deposits.length}',
                icon: Icons.receipt_long_outlined,
                color: scheme.primary,
                caption: 'all time',
              ),
            ],
          ),
          const SizedBox(height: 14),
          SectionCard(
            title: 'Monthly Collection Summary',
            trailing: Text('last 12 months',
                style: TextStyle(fontSize: 10.5, color: scheme.onSurfaceVariant)),
            child: MonthlyBarChart(data: monthly),
          ),
          const SizedBox(height: 14),
          SectionCard(
            title: 'Collection by Account',
            child: hub.accounts.isEmpty
                ? const EmptyState(
                    icon: Icons.pie_chart_outline, title: 'No accounts yet')
                : SplitPieChart(slices: [
                    for (var i = 0; i < visibleAccounts.length; i++)
                      (
                        visibleAccounts[i].name,
                        hub.depositTotal(accountId: visibleAccounts[i].id),
                        _palette[i % _palette.length],
                      ),
                  ]),
          ),
          const SizedBox(height: 14),
          SectionCard(
            title: 'Recent Deposits',
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
            child: Column(
              children: [
                for (final d in hub.recentDeposits(6))
                  ListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 2),
                    leading: CircleAvatar(
                      radius: 17,
                      backgroundColor:
                          AppTheme.brandBlue.withValues(alpha: 0.12),
                      child: Text('${d.memberCode}',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.brandBlue)),
                    ),
                    title: Text(d.memberName,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                    subtitle: Text(
                        '${d.accountName} • ${Fmt.period(d.period)}',
                        style: TextStyle(
                            fontSize: 11, color: scheme.onSurfaceVariant)),
                    trailing: Text(
                        '${AppConfig.currencySymbol} ${Fmt.money(d.amount)}',
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w800)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bannerStat(String label, String value) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      fontSize: 10,
                      color: Colors.white.withValues(alpha: 0.85),
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 3),
              Text(value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      );

  static const _palette = [
    AppTheme.brandBlue,
    AppTheme.brandAccent,
    AppTheme.warning,
    AppTheme.success,
    Color(0xFF7E57C2),
  ];
}
