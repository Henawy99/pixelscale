import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:playmakerappstart/models/footballfield_model.dart';
import 'package:playmakerappstart/services/partner_service.dart';
import 'package:cached_network_image/cached_network_image.dart';

class PartnerDashboardScreen extends StatefulWidget {
  final FootballField field;

  const PartnerDashboardScreen({Key? key, required this.field}) : super(key: key);

  @override
  State<PartnerDashboardScreen> createState() => _PartnerDashboardScreenState();
}

class _PartnerDashboardScreenState extends State<PartnerDashboardScreen> {
  final PartnerService _partnerService = PartnerService();
  Map<String, dynamic>? _stats;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);
    try {
      final stats = await _partnerService.getBookingStats(widget.field.id);
      if (mounted) {
        setState(() {
          _stats = stats;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading stats: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: GoogleFonts.inter(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadStats,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Field Info Card
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (widget.field.photos.isNotEmpty)
                          ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(16),
                            ),
                            child: CachedNetworkImage(
                              imageUrl: widget.field.photos.first,
                              height: 200,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                height: 200,
                                color: Colors.grey.shade300,
                                child: const Center(child: CircularProgressIndicator()),
                              ),
                              errorWidget: (context, url, error) => Container(
                                height: 200,
                                color: Colors.grey.shade300,
                                child: const Icon(Icons.error, size: 40),
                              ),
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.field.footballFieldName,
                                style: GoogleFonts.inter(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(Icons.location_on, 
                                    size: 18, 
                                    color: Colors.grey.shade600),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${widget.field.locationName} • ${widget.field.streetName}',
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      widget.field.fieldSize,
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.blue.shade700,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      widget.field.priceRange,
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.green.shade700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Today's Stats
                  Text(
                    'Today\'s Overview',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),

                  _buildStatCard(
                    title: 'Bookings Today',
                    value: _stats?['todayBookings']?.toString() ?? '0',
                    icon: Icons.event_available,
                    color: Colors.blue,
                  ),
                  const SizedBox(height: 12),
                  _buildStatCard(
                    title: 'Revenue Today',
                    value: 'EGP ${(_stats?['todayRevenue'] ?? 0).toStringAsFixed(0)}',
                    icon: Icons.attach_money,
                    color: Colors.green,
                  ),

                  const SizedBox(height: 24),

                  // Overall Stats
                  Text(
                    'Overall Statistics',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          title: 'This Week',
                          value: _stats?['weekBookings']?.toString() ?? '0',
                          icon: Icons.calendar_view_week,
                          color: Colors.orange,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          title: 'This Month',
                          value: _stats?['monthBookings']?.toString() ?? '0',
                          icon: Icons.calendar_month,
                          color: Colors.purple,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  _buildStatCard(
                    title: 'Total Revenue',
                    value: 'EGP ${(_stats?['totalRevenue'] ?? 0).toStringAsFixed(0)}',
                    icon: Icons.payments,
                    color: Colors.teal,
                  ),
                ],
              ),
            ),
    );
  }
}
