import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/config.dart';
import '../core/theme.dart';
import '../core/utils.dart';
import '../models/models.dart';
import '../services/repos.dart';
import '../state/hub.dart';
import '../widgets/ui.dart';

/// Module 5 – Investment & Profit. Highly confidential: the menu entry and
/// this route exist only for authorized users (Session.canInvest), and
/// Firestore rules reject every read for anyone else.
class InvestmentScreen extends StatelessWidget {
  const InvestmentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final hub = context.watch<DataHub>();
    final scheme = Theme.of(context).colorScheme;
    final totalInvested =
        hub.investments.fold<double>(0, (p, i) => p + i.totalPerPerson);
    final totalProfit = hub.totalProfit;
    final totalExpenses = hub.totalExpenses;
    final roi = totalInvested <= 0 ? 0.0 : (totalProfit / totalInvested * 100);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Investment & Profit'),
        actions: [
          IconButton(
            tooltip: 'Record profit distribution',
            icon: const Icon(Icons.add_card_outlined),
            onPressed: () => _addProfit(context),
          ),
          IconButton(
            tooltip: 'Add expense',
            icon: const Icon(Icons.remove_circle_outline),
            onPressed: () => _addExpense(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.warning.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.warning.withValues(alpha: 0.35)),
            ),
            child: Row(
              children: [
                const Icon(Icons.lock_outline, size: 18, color: AppTheme.warning),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Confidential module — visible only to users explicitly authorized by the admin. All views are audit-logged.',
                    style: TextStyle(fontSize: 11.5, color: scheme.onSurface),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            childAspectRatio: 1.55,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            children: [
              StatCard(
                  label: 'Total Investment',
                  value: '${AppConfig.currencySymbol} ${Fmt.money(totalInvested)}',
                  icon: Icons.pie_chart_outline,
                  color: AppTheme.brandBlue),
              StatCard(
                  label: 'Total Profit Distributed',
                  value: '${AppConfig.currencySymbol} ${Fmt.money(totalProfit)}',
                  icon: Icons.trending_up,
                  color: AppTheme.success),
              StatCard(
                  label: 'Total Expenses / Handover',
                  value: '${AppConfig.currencySymbol} ${Fmt.money(totalExpenses)}',
                  icon: Icons.money_off_csred_outlined,
                  color: AppTheme.danger),
              StatCard(
                  label: 'Portfolio ROI',
                  value: '${roi.toStringAsFixed(2)}%',
                  icon: Icons.percent,
                  color: AppTheme.warning),
            ],
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: 'Investment Records (per person)',
            padding: const EdgeInsets.fromLTRB(8, 14, 8, 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowHeight: 34,
                dataRowMinHeight: 36,
                dataRowMaxHeight: 42,
                columnSpacing: 18,
                headingTextStyle: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: scheme.onSurface),
                dataTextStyle: const TextStyle(fontSize: 11.5),
                columns: const [
                  DataColumn(label: Text('ID')),
                  DataColumn(label: Text('Name')),
                  DataColumn(label: Text('Base'), numeric: true),
                  DataColumn(label: Text('Addl.'), numeric: true),
                  DataColumn(label: Text('Per Person'), numeric: true),
                  DataColumn(label: Text('Profit Share'), numeric: true),
                ],
                rows: [
                  for (final i in hub.investments)
                    DataRow(cells: [
                      DataCell(Text('${i.memberCode}')),
                      DataCell(ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 130),
                          child: Text(i.memberName,
                              overflow: TextOverflow.ellipsis))),
                      DataCell(Text(Fmt.money(i.baseAmount))),
                      DataCell(Text(Fmt.money(i.additionalCapital))),
                      DataCell(Text(Fmt.money(i.totalPerPerson))),
                      DataCell(Text(Fmt.money(i.profitShare))),
                    ]),
                  DataRow(cells: [
                    const DataCell(Text('')),
                    DataCell(Text('Total',
                        style: TextStyle(
                            fontWeight: FontWeight.w800, color: scheme.primary))),
                    DataCell(Text(
                        Fmt.money(hub.investments.fold<double>(0, (p, i) => p + i.baseAmount)))),
                    DataCell(Text(Fmt.money(hub.investments
                        .fold<double>(0, (p, i) => p + i.additionalCapital)))),
                    DataCell(Text(Fmt.money(totalInvested))),
                    DataCell(Text(Fmt.money(
                        hub.investments.fold<double>(0, (p, i) => p + i.profitShare)))),
                  ]),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: 'Profit Distribution History',
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
            child: hub.profitEvents.isEmpty
                ? const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: EmptyState(
                        icon: Icons.trending_up,
                        title: 'No profit recorded yet'))
                : Column(
                    children: [
                      for (final p in hub.profitEvents)
                        ExpansionTile(
                          tilePadding: EdgeInsets.zero,
                          title: Text('${Fmt.period(p.period)} — ${p.title}',
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w700)),
                          subtitle: Text(
                              'Total ${AppConfig.currencySymbol} ${Fmt.money(p.totalProfit)}',
                              style: TextStyle(
                                  fontSize: 11, color: scheme.onSurfaceVariant)),
                          children: [
                            for (final d in p.distribution)
                              ListTile(
                                dense: true,
                                title: Text('${d['memberName']}',
                                    style: const TextStyle(fontSize: 12.5)),
                                trailing: Text(
                                    '${AppConfig.currencySymbol} ${Fmt.money((d['amount'] as num?)?.toDouble() ?? 0)}',
                                    style: const TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700)),
                              ),
                          ],
                        ),
                      const SizedBox(height: 8),
                    ],
                  ),
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: 'Expenses & Cash Handover',
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
            child: hub.expenses.isEmpty
                ? const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: EmptyState(
                        icon: Icons.money_off_csred_outlined,
                        title: 'No expenses recorded'))
                : Column(
                    children: [
                      for (final e in hub.expenses)
                        ListTile(
                          dense: true,
                          title: Text(e.title,
                              style: const TextStyle(
                                  fontSize: 12.5, fontWeight: FontWeight.w600)),
                          subtitle: Text(e.category,
                              style: TextStyle(
                                  fontSize: 10.5, color: scheme.onSurfaceVariant)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                  '${AppConfig.currencySymbol} ${Fmt.money(e.amount)}',
                                  style: const TextStyle(
                                      fontSize: 12.5, fontWeight: FontWeight.w700)),
                              IconButton(
                                iconSize: 18,
                                icon: const Icon(Icons.delete_outline,
                                    color: AppTheme.danger),
                                onPressed: () async {
                                  final ok = await confirmDialog(context,
                                      'Delete expense?', e.title,
                                      okLabel: 'Delete', danger: true);
                                  if (ok) await Repos.deleteExpense(e);
                                },
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

  Future<void> _addProfit(BuildContext context) async {
    final hub = context.read<DataHub>();
    final title = TextEditingController();
    final total = TextEditingController();
    final period = ValueNotifier<String>(Fmt.currentPeriod());
    final shares = <String, TextEditingController>{
      for (final i in hub.investments) i.memberId: TextEditingController(),
    };
    await showModalSheet(
      context,
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Record Profit Distribution',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            ValueListenableBuilder<String>(
              valueListenable: period,
              builder: (ctx, p, _) => OutlinedButton.icon(
                onPressed: () async {
                  final now = DateTime.now();
                  final d = await showDatePicker(
                      context: ctx,
                      initialDate: DateTime(now.year, now.month),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(now.year + 1, 12));
                  if (d != null) {
                    period.value =
                        '${d.year}-${d.month.toString().padLeft(2, '0')}';
                  }
                },
                icon: const Icon(Icons.calendar_month_outlined, size: 18),
                label: Text('Period: ${Fmt.period(p)}'),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
                controller: title,
                decoration: const InputDecoration(labelText: 'Title (e.g. Q3 land profit)')),
            const SizedBox(height: 10),
            TextField(
                controller: total,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Total profit amount')),
            const SizedBox(height: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final i in hub.investments)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: TextField(
                        controller: shares[i.memberId],
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                            isDense: true,
                            labelText: '${i.memberName} share'),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () async {
                final t = double.tryParse(total.text.trim());
                if (t == null) {
                  snack(context, 'Enter total profit.', error: true);
                  return;
                }
                Navigator.pop(context);
                await Repos.addProfitEvent(ProfitEvent(
                  id: '',
                  period: period.value,
                  title: title.text.trim(),
                  totalProfit: t,
                  distribution: [
                    for (final i in hub.investments)
                      {
                        'memberId': i.memberId,
                        'memberName': i.memberName,
                        'amount': double.tryParse(
                                shares[i.memberId]?.text.trim() ?? '') ??
                            0,
                      },
                  ],
                ));
                if (context.mounted) snack(context, 'Profit event recorded.');
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addExpense(BuildContext context) async {
    final title = TextEditingController();
    final amount = TextEditingController();
    String category = 'general';
    await showModalSheet(
      context,
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Add Expense / Handover',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            TextField(
                controller: title,
                decoration: const InputDecoration(
                    labelText: 'Title (e.g. Cash Handover for Land)')),
            const SizedBox(height: 10),
            TextField(
                controller: amount,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Amount')),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: category,
              decoration: const InputDecoration(labelText: 'Category'),
              items: const [
                DropdownMenuItem(value: 'land', child: Text('Land / asset')),
                DropdownMenuItem(
                    value: 'operational', child: Text('Operational')),
                DropdownMenuItem(value: 'general', child: Text('General')),
              ],
              onChanged: (v) => category = v!,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () async {
                final a = double.tryParse(amount.text.trim());
                if (a == null || title.text.trim().isEmpty) {
                  snack(context, 'Title and amount required.', error: true);
                  return;
                }
                Navigator.pop(context);
                await Repos.addExpense(Expense(
                    id: '', title: title.text.trim(), amount: a, category: category));
                if (context.mounted) snack(context, 'Expense added.');
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
