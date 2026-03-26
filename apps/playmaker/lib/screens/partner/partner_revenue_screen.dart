import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:playmakerappstart/l10n/app_localizations.dart';
import 'package:playmakerappstart/localization/app_localizations.dart';
import 'package:playmakerappstart/localization/locale_provider.dart';
import 'package:playmakerappstart/models/footballfield_model.dart';
import 'package:playmakerappstart/services/partner_service.dart';
import 'package:provider/provider.dart';

class PartnerRevenueScreen extends StatefulWidget {
  final FootballField field;

  const PartnerRevenueScreen({Key? key, required this.field}) : super(key: key);

  @override
  State<PartnerRevenueScreen> createState() => _PartnerRevenueScreenState();
}

class _PartnerRevenueScreenState extends State<PartnerRevenueScreen> {
  final PartnerService _partnerService = PartnerService();
  Map<String, dynamic>? _stats;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  void _showLanguageSettings() {
    final l10n = AppLocalizations.of(context)!;
    
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.settings, color: Colors.blue.shade600),
                const SizedBox(width: 12),
                Text(
                  l10n.partner_revenue_settings,
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              l10n.partner_revenue_language,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 16),
            _LanguageOption(
              label: 'English',
              icon: '🇺🇸',
              isSelected: LocalizationManager.currentLocale.languageCode == 'en',
              onTap: () async {
                await LocalizationManager.changeLocale(context, LocalizationManager.enLocale);
                Provider.of<LocaleProvider>(context, listen: false).setLocale(LocalizationManager.enLocale);
                if (mounted) Navigator.pop(context);
              },
            ),
            const SizedBox(height: 8),
            _LanguageOption(
              label: 'العربية',
              icon: '🇪🇬',
              isSelected: LocalizationManager.currentLocale.languageCode == 'ar',
              onTap: () async {
                await LocalizationManager.changeLocale(context, LocalizationManager.arLocale);
                Provider.of<LocaleProvider>(context, listen: false).setLocale(LocalizationManager.arLocale);
                if (mounted) Navigator.pop(context);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
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

  Widget _buildRevenueCard({
    required String title,
    required String amount,
    required String subtitle,
    required Color color,
    required IconData icon,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: color.withOpacity(0.3)),
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withOpacity(0.1),
              color.withOpacity(0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              amount,
              style: GoogleFonts.inter(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(
          l10n.partner_revenue_title,
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: _showLanguageSettings,
            tooltip: l10n.partner_revenue_settings,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadStats,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Total Revenue
                  _buildRevenueCard(
                    title: 'Total Revenue',
                    amount: 'EGP ${(_stats?['totalRevenue'] ?? 0).toStringAsFixed(0)}',
                    subtitle: 'All Time',
                    color: Colors.green,
                    icon: Icons.account_balance_wallet,
                  ),

                  const SizedBox(height: 16),

                  // Today's Revenue
                  _buildRevenueCard(
                    title: 'Today\'s Revenue',
                    amount: 'EGP ${(_stats?['todayRevenue'] ?? 0).toStringAsFixed(0)}',
                    subtitle: 'Today',
                    color: Colors.blue,
                    icon: Icons.today,
                  ),

                  const SizedBox(height: 16),

                  // This Week
                  Row(
                    children: [
                      Expanded(
                        child: _buildRevenueCard(
                          title: 'This Week',
                          amount: 'EGP ${(_stats?['weekRevenue'] ?? 0).toStringAsFixed(0)}',
                          subtitle: '7 days',
                          color: Colors.orange,
                          icon: Icons.calendar_view_week,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildRevenueCard(
                          title: 'This Month',
                          amount: 'EGP ${(_stats?['monthRevenue'] ?? 0).toStringAsFixed(0)}',
                          subtitle: '30 days',
                          color: Colors.purple,
                          icon: Icons.calendar_month,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Stats Summary
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.grey.shade200),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Booking Statistics',
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 20),
                          _buildStatRow(
                            'Total Bookings',
                            _stats?['totalBookings']?.toString() ?? '0',
                            Icons.event,
                            Colors.blue,
                          ),
                          const Divider(height: 24),
                          _buildStatRow(
                            'Today\'s Bookings',
                            _stats?['todayBookings']?.toString() ?? '0',
                            Icons.today,
                            Colors.green,
                          ),
                          const Divider(height: 24),
                          _buildStatRow(
                            'This Week',
                            _stats?['weekBookings']?.toString() ?? '0',
                            Icons.calendar_view_week,
                            Colors.orange,
                          ),
                          const Divider(height: 24),
                          _buildStatRow(
                            'This Month',
                            _stats?['monthBookings']?.toString() ?? '0',
                            Icons.calendar_month,
                            Colors.purple,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Average Revenue per Booking
                  if ((_stats?['totalBookings'] ?? 0) > 0)
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey.shade200),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.teal.shade50,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.analytics,
                                color: Colors.teal.shade700,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Average per Booking',
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  Text(
                                    'EGP ${((_stats?['totalRevenue'] ?? 0) / (_stats?['totalBookings'] ?? 1)).toStringAsFixed(0)}',
                                    style: GoogleFonts.inter(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.teal.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildStatRow(String label, String value, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.grey.shade700,
            ),
          ),
        ),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }
}

class _LanguageOption extends StatelessWidget {
  final String label;
  final String icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _LanguageOption({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.shade50 : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.blue.shade600 : Colors.grey.shade200,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Text(icon, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? Colors.blue.shade700 : Colors.black87,
                ),
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: Colors.blue.shade600, size: 20),
          ],
        ),
      ),
    );
  }
}

