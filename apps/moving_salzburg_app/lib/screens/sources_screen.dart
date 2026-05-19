import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../theme/app_theme.dart';
import '../services/data_service.dart';

class SourcesScreen extends StatelessWidget {
  const SourcesScreen({super.key});

  static const _colors = [AppTheme.blue, AppTheme.accent, AppTheme.green, AppTheme.gold, AppTheme.orange, AppTheme.red];

  @override
  Widget build(BuildContext context) {
    final data = DataService.getAnalytics();
    final refEntries = data.referrers.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final devEntries = data.devices.entries.toList();
    final countryEntries = data.countries.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final refTotal = refEntries.fold<int>(0, (s, e) => s + e.value);

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(title: const Text('Besucherquellen'), backgroundColor: AppTheme.bg),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Referrers Pie Chart
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: AppTheme.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.border)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Traffic-Quellen', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                const SizedBox(height: 20),
                SizedBox(
                  height: 200,
                  child: PieChart(PieChartData(
                    sectionsSpace: 2, centerSpaceRadius: 45,
                    sections: refEntries.asMap().entries.map((e) {
                      final pct = (e.value.value / refTotal * 100).toStringAsFixed(0);
                      return PieChartSectionData(
                        value: e.value.value.toDouble(),
                        color: _colors[e.key % _colors.length],
                        radius: 50, title: '$pct%',
                        titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
                      );
                    }).toList(),
                  )),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 16, runSpacing: 8,
                  children: refEntries.asMap().entries.map((e) => Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 10, height: 10, decoration: BoxDecoration(color: _colors[e.key % _colors.length], borderRadius: BorderRadius.circular(3))),
                      const SizedBox(width: 6),
                      Text('${e.value.key} (${e.value.value})', style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                    ],
                  )).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Top Referrers List
          const Text('Top Quellen', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
          const SizedBox(height: 12),
          ...refEntries.map((e) => _sourceRow(e.key, e.value, refTotal)),
          const SizedBox(height: 24),

          // Devices
          const Text('Geräte', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
          const SizedBox(height: 12),
          Row(
            children: devEntries.asMap().entries.map((e) {
              final total = devEntries.fold<int>(0, (s, x) => s + x.value);
              final pct = (e.value.value / total * 100).toStringAsFixed(0);
              final icons = [Icons.phone_android, Icons.computer, Icons.tablet_android];
              return Expanded(
                child: Container(
                  margin: EdgeInsets.only(right: e.key < devEntries.length - 1 ? 10 : 0),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: AppTheme.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppTheme.border)),
                  child: Column(
                    children: [
                      Icon(icons[e.key % icons.length], color: _colors[e.key], size: 24),
                      const SizedBox(height: 10),
                      Text('$pct%', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
                      const SizedBox(height: 4),
                      Text(e.value.key, style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),

          // Countries
          const Text('Länder', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
          const SizedBox(height: 12),
          ...countryEntries.map((e) {
            final total = countryEntries.fold<int>(0, (s, x) => s + x.value);
            return _sourceRow(e.key, e.value, total);
          }),
        ],
      ),
    );
  }

  Widget _sourceRow(String label, int count, int total) {
    final pct = count / total;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppTheme.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.border)),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white)),
              Text('$count (${(pct * 100).toStringAsFixed(1)}%)', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.blueLight)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: pct, minHeight: 5, backgroundColor: AppTheme.bg2, valueColor: const AlwaysStoppedAnimation(AppTheme.blueLight)),
          ),
        ],
      ),
    );
  }
}
