import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../widgets/widgets.dart';
import '../services/data_service.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final data = DataService.getAnalytics();
    final bookings = DataService.getBookings();
    final newBookings = bookings.where((b) => b.status == 'new').length;

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 100, floating: true, pinned: true,
            backgroundColor: AppTheme.bg,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
              title: Row(
                children: [
                  Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(gradient: AppTheme.gradient, borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.local_shipping, color: Colors.white, size: 16),
                  ),
                  const SizedBox(width: 10),
                  const Text('Dashboard', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(delegate: SliverChildListDelegate([
              // Stats Grid
              GridView.count(
                crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 1.3,
                children: [
                  StatCard(icon: Icons.visibility, label: 'Heute', value: '${data.todayViews}', subtitle: '+12% vs gestern'),
                  StatCard(icon: Icons.calendar_today, label: 'Diese Woche', value: '${data.weekViews}', subtitle: '+8% vs letzte Woche'),
                  StatCard(icon: Icons.trending_up, label: 'Monat', value: '${data.monthViews}', subtitle: '+23% Wachstum', iconColor: AppTheme.green),
                  StatCard(icon: Icons.email_outlined, label: 'Neue Anfragen', value: '$newBookings', subtitle: 'Unbearbeitet', iconColor: AppTheme.gold, valueColor: AppTheme.gold),
                ],
              ),
              const SizedBox(height: 24),

              // Visitor Chart
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: AppTheme.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.border)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Besucher (30 Tage)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                        Text('${data.totalViews} gesamt', style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                      ],
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 180,
                      child: LineChart(
                        LineChartData(
                          gridData: FlGridData(show: true, drawVerticalLine: false,
                            getDrawingHorizontalLine: (v) => FlLine(color: AppTheme.border, strokeWidth: 1)),
                          titlesData: FlTitlesData(
                            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 30,
                              getTitlesWidget: (val, meta) {
                                final i = val.toInt();
                                if (i % 7 != 0 || i >= data.dailyViews.length) return const SizedBox.shrink();
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(DateFormat('dd.MM').format(data.dailyViews[i].date),
                                    style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
                                );
                              },
                            )),
                          ),
                          borderData: FlBorderData(show: false),
                          lineBarsData: [
                            LineChartBarData(
                              spots: data.dailyViews.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.views.toDouble())).toList(),
                              isCurved: true, color: AppTheme.blueLight,
                              barWidth: 2.5, isStrokeCapRound: true,
                              dotData: const FlDotData(show: false),
                              belowBarData: BarAreaData(show: true,
                                gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
                                  colors: [AppTheme.blue.withOpacity(0.3), AppTheme.blue.withOpacity(0)])),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Quick Stats Row
              Row(
                children: [
                  _quickStat('Bounce Rate', '${data.bounceRate}%', Icons.trending_down, AppTheme.orange),
                  const SizedBox(width: 12),
                  _quickStat('Ø Dauer', '${(data.avgSessionDuration / 60).toStringAsFixed(1)} min', Icons.timer, AppTheme.green),
                ],
              ),
              const SizedBox(height: 24),

              // Recent Bookings
              const Text('Letzte Anfragen', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
              const SizedBox(height: 12),
              ...bookings.take(3).map((b) => _bookingTile(b)),
            ])),
          ),
        ],
      ),
    );
  }

  Widget _quickStat(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppTheme.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppTheme.border)),
        child: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
                Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _bookingTile(b) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppTheme.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppTheme.border)),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20, backgroundColor: AppTheme.blue.withOpacity(0.15),
            child: Text(b.name[0], style: const TextStyle(color: AppTheme.blueLight, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(b.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
                const SizedBox(height: 2),
                Text(b.priceRange, style: const TextStyle(fontSize: 12, color: AppTheme.blueLight, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          StatusBadge(status: b.status),
        ],
      ),
    );
  }
}
