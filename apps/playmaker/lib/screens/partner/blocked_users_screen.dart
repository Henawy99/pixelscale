import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:playmakerappstart/models/footballfield_model.dart';
import 'package:playmakerappstart/services/partner_service.dart';
import 'package:cached_network_image/cached_network_image.dart';

class BlockedUsersScreen extends StatefulWidget {
  final FootballField field;

  const BlockedUsersScreen({Key? key, required this.field}) : super(key: key);

  @override
  State<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends State<BlockedUsersScreen> {
  final PartnerService _partnerService = PartnerService();
  List<Map<String, dynamic>> _blockedUsers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBlockedUsers();
  }

  Future<void> _loadBlockedUsers() async {
    setState(() => _isLoading = true);
    try {
      final users = await _partnerService.getBlockedUsers(widget.field.id);
      if (mounted) {
        setState(() {
          _blockedUsers = users;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading blocked users: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _unblockUser(String userId, String userName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.check_circle, color: Colors.green.shade700),
            ),
            const SizedBox(width: 12),
            const Text('Unblock User'),
          ],
        ),
        content: Text(
          'Are you sure you want to unblock "$userName"? They will be able to book at your field again.',
          style: GoogleFonts.inter(fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade600,
              foregroundColor: Colors.white,
            ),
            child: const Text('Unblock'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      try {
        final success = await _partnerService.unblockUser(
          fieldId: widget.field.id,
          userId: userId,
        );

        if (mounted) {
          Navigator.pop(context); // Close loading

          if (success) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('$userName has been unblocked.'),
                backgroundColor: Colors.green,
              ),
            );
            await _loadBlockedUsers(); // Reload list
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Failed to unblock user.'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          Navigator.pop(context); // Close loading
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'Blocked Users',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadBlockedUsers,
              child: _blockedUsers.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _blockedUsers.length,
                      itemBuilder: (context, index) {
                        final user = _blockedUsers[index];
                        return _buildUserCard(user);
                      },
                    ),
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check_circle_outline,
              size: 64,
              color: Colors.green.shade400,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No Blocked Users',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Text(
              'You haven\'t blocked any users yet. Users you block from bookings will appear here.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user) {
    final userId = user['id'] as String? ?? '';
    final userName = user['name'] as String? ?? 'Unknown User';
    final phoneNumber = user['phone_number'] as String? ?? '';
    final photoUrl = user['photo_url'] as String?;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 28,
              backgroundColor: Colors.red.shade100,
              backgroundImage: photoUrl != null && photoUrl.isNotEmpty
                  ? CachedNetworkImageProvider(photoUrl)
                  : null,
              child: photoUrl == null || photoUrl.isEmpty
                  ? Icon(Icons.person, color: Colors.red.shade700, size: 28)
                  : null,
            ),
            const SizedBox(width: 16),
            
            // User info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    userName,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (phoneNumber.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.phone, size: 14, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Text(
                          phoneNumber,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.block, size: 12, color: Colors.red.shade700),
                        const SizedBox(width: 4),
                        Text(
                          'Blocked',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.red.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            // Unblock button
            ElevatedButton(
              onPressed: () => _unblockUser(userId, userName),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Unblock',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}



