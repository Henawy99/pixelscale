import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../widgets/widgets.dart';
import '../services/data_service.dart';
import '../models/models.dart';

class BookingsScreen extends StatefulWidget {
  const BookingsScreen({super.key});
  @override
  State<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends State<BookingsScreen> {
  String _filter = 'all';

  @override
  Widget build(BuildContext context) {
    final allBookings = DataService.getBookings();
    final bookings = _filter == 'all' ? allBookings : allBookings.where((b) => b.status == _filter).toList();

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(title: const Text('Anfragen'), backgroundColor: AppTheme.bg),
      body: Column(
        children: [
          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                _chip('Alle', 'all', allBookings.length),
                _chip('Neu', 'new', allBookings.where((b) => b.status == 'new').length),
                _chip('Kontaktiert', 'contacted', allBookings.where((b) => b.status == 'contacted').length),
                _chip('Bestätigt', 'confirmed', allBookings.where((b) => b.status == 'confirmed').length),
                _chip('Abgeschlossen', 'completed', allBookings.where((b) => b.status == 'completed').length),
              ],
            ),
          ),
          Expanded(
            child: bookings.isEmpty
              ? const Center(child: Text('Keine Anfragen', style: TextStyle(color: AppTheme.textMuted)))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: bookings.length,
                  itemBuilder: (ctx, i) => _bookingCard(bookings[i]),
                ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, String value, int count) {
    final active = _filter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text('$label ($count)'),
        selected: active,
        onSelected: (_) => setState(() => _filter = value),
        backgroundColor: AppTheme.card,
        selectedColor: AppTheme.blue.withOpacity(0.2),
        side: BorderSide(color: active ? AppTheme.blueLight : AppTheme.border),
        labelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: active ? AppTheme.blueLight : AppTheme.textMuted),
        checkmarkColor: AppTheme.blueLight,
      ),
    );
  }

  Widget _bookingCard(Booking b) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: AppTheme.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.border)),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showDetail(b),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 22, backgroundColor: AppTheme.blue.withOpacity(0.15),
                      child: Text(b.name[0], style: const TextStyle(color: AppTheme.blueLight, fontWeight: FontWeight.w700, fontSize: 16)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(b.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
                          Text(DateFormat('dd.MM.yyyy HH:mm').format(b.createdAt), style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                        ],
                      ),
                    ),
                    StatusBadge(status: b.status),
                  ],
                ),
                const SizedBox(height: 14),
                _infoRow(Icons.location_on, '${b.fromAddress} → ${b.toAddress}'),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _miniTag(Icons.home, b.rooms),
                    const SizedBox(width: 8),
                    _miniTag(Icons.route, '${b.distanceKm} km'),
                    const Spacer(),
                    Text(b.priceRange, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.blueLight)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppTheme.textMuted),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 12, color: AppTheme.textMuted), maxLines: 1, overflow: TextOverflow.ellipsis)),
      ],
    );
  }

  Widget _miniTag(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: AppTheme.bg2, borderRadius: BorderRadius.circular(6)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppTheme.textMuted),
          const SizedBox(width: 4),
          Text(text, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
        ],
      ),
    );
  }

  void _showDetail(Booking b) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.85, maxChildSize: 0.95, minChildSize: 0.5,
        expand: false,
        builder: (_, sc) => ListView(
          controller: sc,
          padding: const EdgeInsets.all(24),
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.border, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            Row(
              children: [
                CircleAvatar(radius: 28, backgroundColor: AppTheme.blue.withOpacity(0.15),
                  child: Text(b.name[0], style: const TextStyle(color: AppTheme.blueLight, fontWeight: FontWeight.w700, fontSize: 20))),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(b.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
                    Text(b.email, style: const TextStyle(fontSize: 13, color: AppTheme.textMuted)),
                  ]),
                ),
                StatusBadge(status: b.status),
              ],
            ),
            const SizedBox(height: 20),
            // Action buttons
            Row(
              children: [
                Expanded(child: _actionBtn(Icons.phone, 'Anrufen', () => _launch('tel:${b.phone}'))),
                const SizedBox(width: 10),
                Expanded(child: _actionBtn(Icons.email, 'E-Mail', () => _launch('mailto:${b.email}'))),
              ],
            ),
            const SizedBox(height: 20),
            // Price
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: AppTheme.gradient, borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Geschätzter Preis', style: TextStyle(color: Colors.white70, fontSize: 13)),
                  Text(b.priceRange, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text('Details', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
            const SizedBox(height: 12),
            _detailRow('Von', b.fromAddress),
            _detailRow('Nach', b.toAddress),
            _detailRow('Entfernung', '${b.distanceKm} km'),
            _detailRow('Zimmer', b.rooms),
            _detailRow('Etage', b.floor),
            _detailRow('Aufzug', b.hasElevator ? 'Ja' : 'Nein'),
            _detailRow('Schwere Gegenstände', b.heavyItems),
            _detailRow('Extras', b.extras),
            _detailRow('Termin', b.schedule),
            _detailRow('Uhrzeit', b.timePreference),
            if (b.message.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text('Nachricht', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: AppTheme.bg, borderRadius: BorderRadius.circular(12)),
                child: Text(b.message, style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary, height: 1.5)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 140, child: Text(label, style: const TextStyle(fontSize: 13, color: AppTheme.textMuted))),
          Expanded(child: Text(value.isEmpty ? '–' : value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.white))),
        ],
      ),
    );
  }

  Widget _actionBtn(IconData icon, String label, VoidCallback onTap) {
    return Material(
      color: AppTheme.bg2,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap, borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: AppTheme.blueLight, size: 18),
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.blueLight)),
            ],
          ),
        ),
      ),
    );
  }

  void _launch(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }
}
