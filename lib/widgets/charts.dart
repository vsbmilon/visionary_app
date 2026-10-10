library;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../core/utils.dart';

/// Chart widgets (fl_chart) — lightweight, offline, no JS.
class MonthlyBarChart extends StatelessWidget {
  final Map<String, double> data; // period -> total
  final double height;
  const MonthlyBarChart({super.key, required this.data, this.height = 190});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final entries = data.entries.toList();
    final maxY = (entries.fold<double>(0, (p, e) => e.value > p ? e.value : p)) * 1.2;
    return SizedBox(
      height: height,
      child: BarChart(
        BarChartData(
          maxY: maxY <= 0 ? 1000 : maxY,
          alignment: BarChartAlignment.spaceAround,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) =>
                FlLine(color: scheme.outlineVariant.withValues(alpha: 0.5), strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (v, _) => Text(
                  v >= 1000 ? '${(v / 1000).toStringAsFixed(0)}k' : v.toStringAsFixed(0),
                  style: TextStyle(fontSize: 9, color: scheme.onSurfaceVariant),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 26,
                getTitlesWidget: (v, _) {
                  final i = v.toInt();
                  if (i < 0 || i >= entries.length) return const SizedBox();
                  final label = Fmt.period(entries[i].key);
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(label.split(' ')[0],
                        style: TextStyle(fontSize: 9, color: scheme.onSurfaceVariant)),
                  );
                },
              ),
            ),
          ),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (g, _, rod, __) {
                final e = entries[g.x];
                return BarTooltipItem(
                  '${Fmt.period(e.key)}\n',
                  TextStyle(color: scheme.onInverseSurface, fontWeight: FontWeight.w700),
                  children: [
                    TextSpan(
                      text: Fmt.money(e.value),
                      style: TextStyle(color: scheme.onInverseSurface, fontSize: 11),
                    ),
                  ],
                );
              },
            ),
          ),
          barGroups: [
            for (var i = 0; i < entries.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: entries[i].value,
                    width: 14,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
                    gradient: const LinearGradient(
                      colors: [AppTheme.brandAccent, AppTheme.brandBlue],
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class SplitPieChart extends StatelessWidget {
  final List<(String, double, Color)> slices; // label, value, color
  const SplitPieChart({super.key, required this.slices});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final total = slices.fold<double>(0, (p, s) => p + s.$2);
    return Row(
      children: [
        SizedBox(
          height: 130,
          width: 130,
          child: PieChart(
            PieChartData(
              centerSpaceRadius: 34,
              sectionsSpace: 2,
              sections: [
                for (final s in slices)
                  PieChartSectionData(
                    value: s.$2 <= 0 ? 0.0001 : s.$2,
                    color: s.$3,
                    radius: 26,
                    title: '',
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final s in slices)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Container(
                          width: 10,
                          height: 10,
                          decoration:
                              BoxDecoration(color: s.$3, shape: BoxShape.circle)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(s.$1,
                            style: TextStyle(
                                fontSize: 12, color: scheme.onSurface)),
                      ),
                      Text(
                          total <= 0
                              ? '0%'
                              : '${(s.$2 / total * 100).toStringAsFixed(0)}%',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: scheme.onSurface)),
                    ],
                  ),
                ),
              const SizedBox(height: 2),
              Text('Total: ${Fmt.money(total)}',
                  style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurfaceVariant)),
            ],
          ),
        ),
      ],
    );
  }
}

class TrendLineChart extends StatelessWidget {
  final List<(String, double)> points; // oldest -> newest
  final double height;
  const TrendLineChart({super.key, required this.points, this.height = 170});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final maxY = (points.fold<double>(0, (p, e) => e.$2 > p ? e.$2 : p)) * 1.25;
    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          maxY: maxY <= 0 ? 5000 : maxY,
          minY: 0,
          gridData: FlGridData(
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) =>
                FlLine(color: scheme.outlineVariant.withValues(alpha: 0.5), strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (v, _) => Text(
                  v >= 1000 ? '${(v / 1000).toStringAsFixed(0)}k' : v.toStringAsFixed(0),
                  style: TextStyle(fontSize: 9, color: scheme.onSurfaceVariant),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                interval: 3,
                getTitlesWidget: (v, _) {
                  final i = v.toInt();
                  if (i < 0 || i >= points.length) return const SizedBox();
                  return Text(Fmt.period(points[i].$1).split(' ')[0],
                      style: TextStyle(fontSize: 9, color: scheme.onSurfaceVariant));
                },
              ),
            ),
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (spots) => spots
                  .map((s) => LineTooltipItem(
                        '${Fmt.period(points[s.x.toInt()].$1)}\n${Fmt.money(points[s.x.toInt()].$2)}',
                        TextStyle(
                            color: scheme.onInverseSurface,
                            fontWeight: FontWeight.w700,
                            fontSize: 11),
                      ))
                  .toList(),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              isCurved: true,
              curveSmoothness: 0.25,
              barWidth: 3,
              color: AppTheme.brandBlue,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [
                    AppTheme.brandBlue.withValues(alpha: 0.28),
                    AppTheme.brandBlue.withValues(alpha: 0.02),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              spots: [
                for (var i = 0; i < points.length; i++) FlSpot(i.toDouble(), points[i].$2),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
