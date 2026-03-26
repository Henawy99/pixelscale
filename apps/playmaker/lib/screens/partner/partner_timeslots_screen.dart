import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:playmakerappstart/models/footballfield_model.dart';
import 'package:playmakerappstart/services/partner_service.dart';

class PartnerTimeslotsScreen extends StatefulWidget {
  final FootballField field;

  const PartnerTimeslotsScreen({Key? key, required this.field}) : super(key: key);

  @override
  State<PartnerTimeslotsScreen> createState() => _PartnerTimeslotsScreenState();
}

class _PartnerTimeslotsScreenState extends State<PartnerTimeslotsScreen> {
  final PartnerService _partnerService = PartnerService();
  late FootballField _field;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _field = widget.field;
  }

  Future<void> _toggleTimeslot(String day, int index, bool currentAvailability) async {
    setState(() => _isLoading = true);

    final success = await _partnerService.updateTimeslotAvailability(
      fieldId: _field.id,
      day: day,
      slotIndex: index,
      available: !currentAvailability,
    );

    if (success) {
      // Update local state
      setState(() {
        _field.availableTimeSlots[day]![index]['available'] = !currentAvailability;
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              currentAvailability
                  ? 'Timeslot closed successfully'
                  : 'Timeslot opened successfully',
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update timeslot'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Info Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue.shade700),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Toggle timeslots to open or close them for booking',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: Colors.blue.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Timeslots by Day
              ..._field.availableTimeSlots.entries.map((entry) {
                final day = entry.key;
                final slots = entry.value;

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey.shade200),
                  ),
                  child: Theme(
                    data: Theme.of(context).copyWith(
                      dividerColor: Colors.transparent,
                    ),
                    child: ExpansionTile(
                      title: Text(
                        day,
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      subtitle: Text(
                        '${slots.length} timeslots',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      children: slots.isEmpty
                          ? [
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Text(
                                  'No timeslots for this day',
                                  style: GoogleFonts.inter(
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ),
                            ]
                          : slots.asMap().entries.map((slotEntry) {
                              final index = slotEntry.key;
                              final slot = slotEntry.value;
                              final isAvailable = slot['available'] as bool;

                              return Container(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: isAvailable
                                      ? Colors.green.shade50
                                      : Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isAvailable
                                        ? Colors.green.shade200
                                        : Colors.red.shade200,
                                  ),
                                ),
                                child: ListTile(
                                  leading: Icon(
                                    isAvailable
                                        ? Icons.check_circle
                                        : Icons.cancel,
                                    color: isAvailable
                                        ? Colors.green.shade700
                                        : Colors.red.shade700,
                                  ),
                                  title: Text(
                                    slot['time'].toString(),
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  subtitle: Text(
                                    '${slot['price']} EGP • ${isAvailable ? "Open" : "Closed"}',
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                  trailing: Switch(
                                    value: isAvailable,
                                    onChanged: _isLoading
                                        ? null
                                        : (value) =>
                                            _toggleTimeslot(day, index, isAvailable),
                                    activeColor: Colors.green.shade700,
                                  ),
                                ),
                              );
                            }).toList(),
                    ),
                  ),
                );
              }).toList(),
            ],
          ),

          // Loading Overlay
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }
}

