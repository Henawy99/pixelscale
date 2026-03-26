import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:playmakerappstart/models/user_model.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';

class UserDetailScreen extends StatelessWidget {
  final PlayerProfile user;

  const UserDetailScreen({Key? key, required this.user}) : super(key: key);

  String _formatDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return 'N/A';
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('MMM dd, yyyy • hh:mm a').format(date);
    } catch (e) {
      return dateString;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text('User Details', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.green.shade700),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Header Card
            _buildHeaderCard(),
            const SizedBox(height: 16),

            // Personal Information
            _buildCard(
              title: 'Personal Information',
              icon: Icons.person,
              children: [
                _buildInfoRow('Full Name', user.name.isNotEmpty ? user.name : 'Not provided'),
                _buildInfoRow('Player ID', user.playerId != null ? user.playerId! : 'Not assigned'),
                _buildInfoRow('Phone Number', user.phoneNumber.isNotEmpty ? user.phoneNumber : 'Not provided'),
                _buildInfoRow('Age', user.age.isNotEmpty ? user.age : 'Not provided'),
                _buildInfoRow('Nationality', user.nationality.isNotEmpty ? user.nationality : 'Not provided'),
                _buildInfoRow('Favourite Club', user.favouriteClub.isNotEmpty ? user.favouriteClub : 'Not provided'),
              ],
            ),
            const SizedBox(height: 16),

            // Account Information
            _buildCard(
              title: 'Account Information',
              icon: Icons.account_circle,
              children: [
                _buildInfoRow('User ID', user.id),
                _buildInfoRow('Email', user.email),
                _buildInfoRow('Account Created', _formatDate(user.joined)),
                _buildInfoRow('Email Verified', user.verifiedEmail ? 'Yes' : 'No', isStatus: true, statusValue: user.verifiedEmail),
                _buildInfoRow('Rank', user.rank.isNotEmpty ? user.rank : 'Unranked'),
                _buildInfoRow('Guest Account', user.isGuest ? 'Yes' : 'No'),
              ],
            ),
            const SizedBox(height: 16),

            // Football Profile
            _buildCard(
              title: 'Football Profile',
              icon: Icons.sports_soccer,
              children: [
                _buildInfoRow('Preferred Position', user.preferredPosition.isNotEmpty ? user.preferredPosition : 'Not set'),
                _buildInfoRow('Skill Level', user.personalLevel.isNotEmpty ? user.personalLevel : 'Not set'),
              ],
            ),
            const SizedBox(height: 16),

            // Statistics
            _buildCard(
              title: 'User Statistics',
              icon: Icons.bar_chart,
              children: [
                _buildInfoRow('Total Bookings', user.numberOfGames.toString()),
                _buildInfoRow('Total Friends', user.numberOfFriends.toString()),
                _buildInfoRow('Squads Joined', user.numberOfSquads.toString()),
                _buildInfoRow('Pending Friend Requests', user.openFriendRequests.length.toString()),
                _buildInfoRow('Sent Friend Requests', user.sentFriendRequests.length.toString()),
              ],
            ),
            const SizedBox(height: 16),

            // Friends List
            if (user.friends.isNotEmpty)
              _buildCard(
                title: 'Friends',
                icon: Icons.people,
                children: [
                  _buildInfoRow('Friends Count', user.friends.length.toString()),
                  const SizedBox(height: 8),
                  ...user.friends.take(10).map((friendId) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            Icon(Icons.circle, size: 6, color: Colors.grey.shade600),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                friendId,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )),
                  if (user.friends.length > 10)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        '+ ${user.friends.length - 10} more friends',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                ],
              ),
            const SizedBox(height: 16),

            // Squads Information
            if (user.teamsJoined.isNotEmpty)
              _buildCard(
                title: 'Squads',
                icon: Icons.groups,
                children: [
                  _buildInfoRow('Member of Squads', user.teamsJoined.length.toString()),
                  const SizedBox(height: 8),
                  ...user.teamsJoined.map((squadId) => Padding(
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
              ),
            const SizedBox(height: 16),

            // Recent Bookings
            if (user.bookings.isNotEmpty)
              _buildCard(
                title: 'Recent Bookings',
                icon: Icons.event,
                children: [
                  _buildInfoRow('Total Bookings', user.bookings.length.toString()),
                  const SizedBox(height: 8),
                  ...user.bookings.take(5).map((bookingId) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            Icon(Icons.circle, size: 6, color: Colors.grey.shade600),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                bookingId,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )),
                  if (user.bookings.length > 5)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        '+ ${user.bookings.length - 5} more bookings',
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
            colors: [Colors.green.shade600, Colors.green.shade800],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          children: [
            // Profile Picture
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 4),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: CircleAvatar(
                radius: 50,
                backgroundColor: Colors.white,
                backgroundImage: user.profilePicture.isNotEmpty
                    ? CachedNetworkImageProvider(user.profilePicture)
                    : null,
                child: user.profilePicture.isEmpty
                    ? Icon(Icons.person, size: 50, color: Colors.green.shade700)
                    : null,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              user.name.isNotEmpty ? user.name : 'User',
              style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                user.email,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: Colors.white,
                ),
              ),
            ),
            if (user.playerId != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'ID: ${user.playerId}',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade700,
                  ),
                ),
              ),
            ],
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

  Widget _buildInfoRow(String label, String value, {bool isStatus = false, bool statusValue = false}) {
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
                      color: statusValue ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: statusValue ? Colors.green : Colors.orange),
                    ),
                    child: Text(
                      value,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: statusValue ? Colors.green : Colors.orange,
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
