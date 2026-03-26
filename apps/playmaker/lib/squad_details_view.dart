import 'package:flutter/material.dart';
import 'package:playmakerappstart/models/squads_model.dart/squads_model.dart';
import 'package:cached_network_image/cached_network_image.dart';

class SquadDetailsView extends StatelessWidget {
  final Squad squad;

  const SquadDetailsView({Key? key, required this.squad}) : super(key: key);

  Widget _buildCard({required Widget child, EdgeInsets? padding}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: padding ?? const EdgeInsets.all(20),
        child: child,
      ),
    );
  }

  Widget _buildSectionTitle(String title, {IconData? icon, Widget? trailing}) {
    return Row(
      children: [
        if (icon != null) ...[
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF00BF63).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: const Color(0xFF00BF63), size: 20),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ),
        if (trailing != null) trailing,
      ],
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF00BF63).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: const Color(0xFF00BF63),
                size: 20,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: CustomScrollView(
        slivers: [
          // App Bar with Hero Image
          SliverAppBar(
            expandedHeight: 200,
            floating: false,
            pinned: true,
            backgroundColor: Colors.white,
            foregroundColor: Colors.black87,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  squad.squadLogo != null && squad.squadLogo!.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: squad.squadLogo!,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  const Color(0xFF00BF63).withOpacity(0.8),
                                  const Color(0xFF00BF63).withOpacity(0.6),
                                ],
                              ),
                            ),
                            child: const Center(
                              child: CircularProgressIndicator(
                                color: Colors.white,
                              ),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  const Color(0xFF00BF63).withOpacity(0.8),
                                  const Color(0xFF00BF63).withOpacity(0.6),
                                ],
                              ),
                            ),
                            child: const Icon(
                              Icons.shield_outlined,
                              size: 60,
                              color: Colors.white,
                            ),
                          ),
                        )
                      : Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                const Color(0xFF00BF63).withOpacity(0.8),
                                const Color(0xFF00BF63).withOpacity(0.6),
                              ],
                            ),
                          ),
                          child: Center(
                            child: Text(
                              squad.squadName.isNotEmpty 
                                  ? squad.squadName[0].toUpperCase() 
                                  : 'S',
                              style: const TextStyle(
                                fontSize: 60,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const [0.3, 1.0],
                        colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
                      ),
                    ),
                  ),
                ],
              ),
              title: Text(
                squad.squadName,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  shadows: [
                    Shadow(
                      blurRadius: 2.0,
                      color: Colors.black54,
                      offset: Offset(1.0, 1.0),
                    ),
                  ],
                ),
              ),
              centerTitle: true,
              titlePadding: const EdgeInsets.only(bottom: 16),
            ),
          ),
          
          // Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Squad Info Card
                  _buildCard(
                    child: Column(
                      children: [
                        Row(
                          children: [
                            // Squad Logo
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: const Color(0xFF00BF63).withOpacity(0.1),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0xFF00BF63).withOpacity(0.2),
                                  width: 2,
                                ),
                              ),
                              child: ClipOval(
                                child: squad.squadLogo != null && squad.squadLogo!.isNotEmpty
                                    ? CachedNetworkImage(
                                        imageUrl: squad.squadLogo!,
                                        fit: BoxFit.cover,
                                        placeholder: (context, url) => const Icon(
                                          Icons.shield_outlined,
                                          color: Color(0xFF00BF63),
                                          size: 40,
                                        ),
                                        errorWidget: (context, url, error) => const Icon(
                                          Icons.shield_outlined,
                                          color: Color(0xFF00BF63),
                                          size: 40,
                                        ),
                                      )
                                    : Center(
                                        child: Text(
                                          squad.squadName.isNotEmpty 
                                              ? squad.squadName[0].toUpperCase() 
                                              : 'S',
                                          style: const TextStyle(
                                            fontSize: 32,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF00BF63),
                                          ),
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(width: 20),
                            
                            // Squad Details
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    squad.squadName,
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  if (squad.squadLocation.isNotEmpty) ...[
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF00BF63).withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: const Icon(
                                            Icons.location_on,
                                            size: 16,
                                            color: Color(0xFF00BF63),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            squad.squadLocation,
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey[600],
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                  ],
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF00BF63).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Icon(
                                          Icons.person,
                                          size: 16,
                                          color: Color(0xFF00BF63),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Captain: ${squad.captain}',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[600],
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Stats Row
                  Row(
                    children: [
                      _buildStatItem(
                        icon: Icons.group,
                        label: 'Members',
                        value: '${squad.squadMembers.length}',
                      ),
                      const SizedBox(width: 12),
                      _buildStatItem(
                        icon: Icons.sports_soccer,
                        label: 'Matches',
                        value: squad.matchesPlayed,
                      ),
                      const SizedBox(width: 12),
                      _buildStatItem(
                        icon: Icons.location_on,
                        label: 'Location',
                        value: squad.squadLocation.isNotEmpty 
                            ? squad.squadLocation.substring(0, squad.squadLocation.length > 8 ? 8 : squad.squadLocation.length)
                            : 'N/A',
                      ),
                    ],
                  ),

                  // Squad Members
                  _buildCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionTitle(
                          'Squad Members',
                          icon: Icons.group,
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00BF63).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              '${squad.squadMembers.length}',
                              style: const TextStyle(
                                color: Color(0xFF00BF63),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // Members List
                        squad.squadMembers.isEmpty
                            ? Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: Colors.grey[50],
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.grey[200]!),
                                ),
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.group_off,
                                      size: 48,
                                      color: Colors.grey[400],
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'No members yet',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'This squad is just getting started',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[500],
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: squad.squadMembers.length,
                                separatorBuilder: (context, index) => Divider(
                                  height: 1,
                                  color: Colors.grey[200],
                                ),
                                itemBuilder: (context, index) {
                                  final member = squad.squadMembers[index];
                                  final isCaptain = member == squad.captain;
                                  
                                  return Container(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 20,
                                          backgroundColor: const Color(0xFF00BF63).withOpacity(0.1),
                                          child: Text(
                                            member.isNotEmpty ? member[0].toUpperCase() : 'M',
                                            style: const TextStyle(
                                              color: Color(0xFF00BF63),
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Text(
                                                    member,
                                                    style: const TextStyle(
                                                      fontSize: 16,
                                                      fontWeight: FontWeight.w600,
                                                      color: Colors.black87,
                                                    ),
                                                  ),
                                                  if (isCaptain) ...[
                                                    const SizedBox(width: 8),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 2,
                                                      ),
                                                      decoration: BoxDecoration(
                                                        color: Colors.amber.withOpacity(0.1),
                                                        borderRadius: BorderRadius.circular(8),
                                                        border: Border.all(
                                                          color: Colors.amber.withOpacity(0.3),
                                                        ),
                                                      ),
                                                      child: Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          const Icon(
                                                            Icons.star,
                                                            size: 12,
                                                            color: Colors.amber,
                                                          ),
                                                          const SizedBox(width: 4),
                                                          Text(
                                                            'Captain',
                                                            style: TextStyle(
                                                              fontSize: 10,
                                                              fontWeight: FontWeight.bold,
                                                              color: Colors.amber[700],
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                'Squad Member',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
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
    );
  }
}
