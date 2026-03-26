import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:playmakerappstart/models/booking_model.dart';
import 'package:intl/intl.dart';

class BookingDetailScreen extends StatelessWidget {
  final Booking booking;

  const BookingDetailScreen({Key? key, required this.booking}) : super(key: key);

  String _formatDate(String dateStr) {
    try {
      final parts = dateStr.split('-');
      if (parts.length == 3) {
        final date = DateTime(
          int.parse(parts[0]),
          int.parse(parts[1]),
          int.parse(parts[2]),
        );
        return DateFormat('EEEE, MMM dd, yyyy').format(date);
      }
    } catch (e) {
      // Return original if parsing fails
    }
    return dateStr;
  }

  Color _getStatusColorValue(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text('Booking Details', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.green.shade700),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Header
            _buildHeaderCard(),
            const SizedBox(height: 16),

            // Field & Match Information
            _buildCard(
              title: 'Match Information',
              icon: Icons.sports_soccer,
              children: [
                _buildInfoRow('Football Field', booking.footballFieldName),
                _buildInfoRow('Date', _formatDate(booking.date)),
                _buildInfoRow('Time Slot', booking.timeSlot),
                _buildInfoRow('Match Type', booking.isOpenMatch ? 'Open Match' : 'Private Match'),
                _buildInfoRow('Location', booking.locationName),
              ],
            ),
            const SizedBox(height: 16),

            // Booking Information
            _buildCard(
              title: 'Booking Details',
              icon: Icons.receipt_long,
              children: [
                _buildInfoRow('Booking ID', booking.id),
                _buildInfoRow('Booking Reference', booking.bookingReference),
                _buildInfoRow('Status', booking.status, isStatus: true),
                if (booking.description != null && booking.description!.isNotEmpty)
                  _buildInfoRow('Description', booking.description!),
              ],
            ),
            const SizedBox(height: 16),

            // Organizer Information
            _buildCard(
              title: 'Organizer',
              icon: Icons.person,
              children: [
                _buildInfoRow('Organizer ID', booking.userId),
                _buildInfoRow('Host Name', booking.host.isNotEmpty ? booking.host : 'Not provided'),
                _buildInfoRow('Manager Booking', booking.fieldManagerBooking ? 'Yes' : 'No'),
              ],
            ),
            const SizedBox(height: 16),

            // Players Information
            _buildCard(
              title: 'Players',
              icon: Icons.groups,
              children: [
                _buildInfoRow('Invited Players', booking.invitePlayers.length.toString()),
                if (booking.maxPlayers != null)
                  _buildInfoRow('Max Players', booking.maxPlayers.toString()),
                if (booking.maxPlayers != null)
                  _buildInfoRow('Available Spots', '${booking.maxPlayers! - booking.invitePlayers.length}'),
                const SizedBox(height: 12),
                if (booking.invitePlayers.isNotEmpty) ...[
                  Text(
                    'Invited Player List:',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...booking.invitePlayers.asMap().entries.map((entry) {
                    final index = entry.key;
                    final playerId = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: Colors.green.shade100,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                '${index + 1}',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.green.shade700,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              playerId,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ] else
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'No players invited yet',
                        style: GoogleFonts.inter(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                if (booking.inviteSquads.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Invited Squads (${booking.inviteSquads.length}):',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...booking.inviteSquads.map((squadId) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            Icon(Icons.circle, size: 6, color: Colors.grey.shade600),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                squadId,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )),
                ],
              ],
            ),
            const SizedBox(height: 16),

            // Payment Information
            _buildCard(
              title: 'Payment Details',
              icon: Icons.payments,
              children: [
                _buildInfoRow('Price', '${booking.price} EGP'),
                _buildInfoRow('Payment Type', booking.paymentType),
              ],
            ),
            const SizedBox(height: 16),

            // Camera & Recording
            if (booking.isRecordingEnabled)
              _buildCard(
                title: 'Camera Recording',
                icon: Icons.videocam,
                children: [
                  _buildInfoRow('Recording Status', 'Enabled'),
                  if (booking.cameraUsername != null && booking.cameraUsername!.isNotEmpty)
                    _buildInfoRow('Camera Username', booking.cameraUsername!),
                  if (booking.cameraIpAddress != null && booking.cameraIpAddress!.isNotEmpty)
                    _buildInfoRow('Camera IP', booking.cameraIpAddress!),
                  if (booking.recordingUrl != null && booking.recordingUrl!.isNotEmpty)
                    _buildInfoRow('Recording URL', booking.recordingUrl!),
                ],
              ),
            const SizedBox(height: 16),

            // Recurring Information
            if (booking.isRecurring)
              _buildCard(
                title: 'Recurring Booking',
                icon: Icons.repeat,
                children: [
                  _buildInfoRow('Recurring Type', booking.recurringType ?? 'N/A'),
                  if (booking.recurringOriginalDate != null)
                    _buildInfoRow('First Occurrence', _formatDate(booking.recurringOriginalDate!)),
                  if (booking.recurringEndDate != null)
                    _buildInfoRow('End Date', _formatDate(booking.recurringEndDate!)),
                ],
              ),
            const SizedBox(height: 16),

            // Join Requests
            if (booking.openJoiningRequests.isNotEmpty)
              _buildCard(
                title: 'Join Requests',
                icon: Icons.person_add,
                children: [
                  _buildInfoRow('Pending Requests', booking.openJoiningRequests.length.toString()),
                  const SizedBox(height: 8),
                  ...booking.openJoiningRequests.take(5).map((requestId) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            Icon(Icons.circle, size: 6, color: Colors.grey.shade600),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                requestId,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )),
                  if (booking.openJoiningRequests.length > 5)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        '+ ${booking.openJoiningRequests.length - 5} more requests',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [_getStatusColorValue(booking.status), _getStatusColorValue(booking.status).withOpacity(0.7)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          children: [
            Icon(
              booking.status.toLowerCase() == 'confirmed' ? Icons.check_circle : 
              booking.status.toLowerCase() == 'pending' ? Icons.pending : Icons.cancel,
              size: 60,
              color: Colors.white,
            ),
            const SizedBox(height: 16),
            Text(
              booking.status.toUpperCase(),
              style: GoogleFonts.inter(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              booking.footballFieldName,
              style: GoogleFonts.inter(
                fontSize: 16,
                color: Colors.white.withOpacity(0.9),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 22, color: Colors.green.shade700),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isStatus = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: isStatus
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColorValue(value).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: _getStatusColorValue(value)),
                    ),
                    child: Text(
                      value,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _getStatusColorValue(value),
                      ),
                    ),
                  )
                : Text(
                    value,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Colors.black87,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
