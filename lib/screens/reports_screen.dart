import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/config.dart';
import '../core/theme.dart';
import '../core/utils.dart';
import '../services/reports_service.dart';
import '../state/hub.dart';
import '../widgets/ui.dart';

/// Module 8 – Reports with PDF & Excel export.
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  String _type = 'monthly';
  String _period = Fmt.currentPeriod();
  String? _memberId;
  bool _busy = false;

  ReportData _build(DataHub hub) {
    switch (_type) {
      case 'monthly':
        final rows = <List<String>>[];
        for (final m in hub.members) {
          for (final a in hub.accounts) {
            final v = hub.deposits
                .where((d) =>
                    d.memberId == m.id &&
                    d.accountId == a.id &&
                    d.period == _period)
                .fold<double>(0, (p, d) => p + d.amount);
            if (v > 0) {
              rows.add(['${m.code}', m.name, a.name, Fmt.money(v)]);
            }
          }
        }
        return ReportData(
          title: 'Monthly Deposit Report',
          subtitle: 'Period: ${Fmt.period(_period)}',
          columns: ['ID', 'Member Name', 'Account', 'Amount'],
          rows: rows,
          footer: [
            ['', 'TOTAL', '', Fmt.money(hub.depositTotal(period: _period))],
          ],
        );
      case 'member':
        final m = hub.memberById(_memberId ?? '') ?? hub.members.first;
        final list = hub.depositsOf(m.id);
        return ReportData(
          title: 'Member Deposit Report',
          subtitle: '${m.code} – ${m.name}',
          columns: ['Month', 'Account', 'Amount', 'Status'],
          rows: [
            for (final d in list)
              [
                Fmt.period(d.period),
                d.accountName,
                Fmt.money(d.amount),
                hub.statusFor(d.amount, hub.accounts
                    .firstWhere((a) => a.id == d.accountId,
                        orElse: () => hub.accounts.first)
                    .expectedMonthly),
              ],
          ],
          footer: [
            ['', 'TOTAL', Fmt.money(hub.depositTotal(memberId: m.id)), ''],
          ],
        );
      case 'investment':
        return ReportData(
          title: 'Investment Report',
          subtitle: 'Confidential',
          columns: ['ID', 'Member', 'Base', 'Addl. Capital', 'Per Person', 'Profit Share'],
          rows: [
            for (final i in hub.investments)
              [
                '${i.memberCode}',
                i.memberName,
                Fmt.money(i.baseAmount),
                Fmt.money(i.additionalCapital),
                Fmt.money(i.totalPerPerson),
                Fmt.money(i.profitShare),
              ],
          ],
          footer: [
            [
              '',
              'TOTAL',
              Fmt.money(hub.investments.fold<double>(0, (p, i) => p + i.baseAmount)),
              Fmt.money(hub.investments.fold<double>(0, (p, i) => p + i.additionalCapital)),
              Fmt.money(hub.investments.fold<double>(0, (p, i) => p + i.totalPerPerson)),
              Fmt.money(hub.investments.fold<double>(0, (p, i) => p + i.profitShare)),
            ],
          ],
        );
      case 'profit':
        final rows = <List<String>>[];
        for (final p in hub.profitEvents) {
          for (final d in p.distribution) {
            rows.add([
              Fmt.period(p.period),
              p.title,
              '${d['memberName']}',
              Fmt.money((d['amount'] as num?)?.toDouble() ?? 0),
            ]);
          }
        }
        return ReportData(
          title: 'Profit Report',
          subtitle: 'All profit distributions',
          columns: ['Period', 'Event', 'Member', 'Amount'],
          rows: rows,
          footer: [['', '', 'TOTAL', Fmt.money(hub.totalProfit)]],
        );
      case 'balance':
        return ReportData(
          title: 'Account Balance Report',
          subtitle: 'As of ${Fmt.date(DateTime.now())}',
          columns: ['Account', 'Deposits', 'Expenses', 'Balance'],
          rows: [
            for (final a in hub.accounts)
              [
                a.name,
                Fmt.money(hub.depositTotal(accountId: a.id)),
                Fmt.money(hub.expenses
                    .where((e) => e.category == a.id)
                    .fold<double>(0, (p, e) => p + e.amount)),
                Fmt.money(hub.depositTotal(accountId: a.id) -
                    hub.expenses
                        .where((e) => e.category == a.id)
                        .fold<double>(0, (p, e) => p + e.amount)),
              ],
          ],
          footer: [
            [
              'GROUP TOTAL',
              Fmt.money(hub.totalDeposits),
              Fmt.money(hub.totalExpenses),
              Fmt.money(hub.groupBalance),
            ],
          ],
        );
    }
    return ReportData(title: '', columns: const []);
  }

  @override
  Widget build(BuildContext context) {
    final hub = context.watch<DataHub>();
    final scheme = Theme.of(context).colorScheme;

    if (hub.members.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Reports')),
        body: const EmptyState(
            icon: Icons.description_outlined,
            title: 'No data yet',
            message: 'Import from Google Sheets or add deposits first.'),
      );
    }

    final types = {
      'monthly': ('Monthly Deposit Report', Icons.calendar_month_outlined),
      'member': ('Member Deposit Report', Icons.person_outline),
      'investment': ('Investment Report', Icons.pie_chart_outline),
      'profit': ('Profit Report', Icons.trending_up),
      'balance': ('Account Balance Report', Icons.account_balance_outlined),
    };

    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          for (final e in types.entries)
            Card(
              child: RadioListTile<String>(
                value: e.key,
                groupValue: _type,
                onChanged: (v) => setState(() => _type = v!),
                title: Text(e.value.$1,
                    style: const TextStyle(
                        fontSize: 13.5, fontWeight: FontWeight.w700)),
                secondary: Icon(e.value.$2, color: AppTheme.brandBlue),
              ),
            ),
          const SizedBox(height: 6),
          if (_type == 'monthly')
            OutlinedButton.icon(
              onPressed: () async {
                final now = DateTime.now();
                final d = await showDatePicker(
                    context: context,
                    initialDate: DateTime(now.year, now.month),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(now.year + 1, 12));
                if (d != null) {
                  setState(() => _period =
                      '${d.year}-${d.month.toString().padLeft(2, '0')}');
                }
              },
              icon: const Icon(Icons.calendar_month_outlined, size: 18),
              label: Text('Period: ${Fmt.period(_period)}'),
            ),
          if (_type == 'member')
            DropdownButtonFormField<String>(
              initialValue: _memberId ?? hub.members.first.id,
              decoration: const InputDecoration(labelText: 'Member'),
              items: [
                for (final m in hub.members)
                  DropdownMenuItem(
                      value: m.id, child: Text('${m.code} – ${m.name}')),
              ],
              onChanged: (v) => setState(() => _memberId = v),
            ),
          const SizedBox(height: 14),
          SectionCard(
            title: 'Preview',
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
            child: _preview(_build(hub), scheme),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _busy
                      ? null
                      : () async {
                          setState(() => _busy = true);
                          await ReportsExporter.exportPdf(_build(hub));
                          setState(() => _busy = false);
                        },
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: const Text('PDF'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy
                      ? null
                      : () async {
                          setState(() => _busy = true);
                          await ReportsExporter.exportExcel(_build(hub));
                          setState(() => _busy = false);
                        },
                  icon: const Icon(Icons.table_chart_outlined),
                  label: const Text('Excel'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
                'PDF opens the Android print dialog (save as PDF or print). Excel is shared via the system share sheet.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10.5, color: scheme.onSurfaceVariant)),
          ),
        ],
      ),
    );
  }

  Widget _preview(ReportData r, ColorScheme scheme) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(r.title,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
          if (r.subtitle.isNotEmpty)
            Text(r.subtitle,
                style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
          const SizedBox(height: 8),
          Text('${r.rows.length} rows • ${r.columns.length} columns',
              style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
          const SizedBox(height: 8),
          SizedBox(
            height: 150,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowHeight: 32,
                dataRowMinHeight: 30,
                dataRowMaxHeight: 36,
                columnSpacing: 16,
                headingTextStyle: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: scheme.onSurface),
                dataTextStyle: const TextStyle(fontSize: 10.5),
                columns: [
                  for (final c in r.columns) DataColumn(label: Text(c)),
                ],
                rows: [
                  for (final row in r.rows.take(30))
                    DataRow(cells: [for (final c in row) DataCell(Text(c))]),
                ],
              ),
            ),
          ),
        ],
      );
}
