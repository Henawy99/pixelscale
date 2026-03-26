import 'package:flutter/material.dart';
import 'package:playmakerappstart/join_squad_screen.dart';
import './models/squad.dart';
import 'package:playmakerappstart/models/user_model.dart';
import 'package:playmakerappstart/services/supabase_service.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:playmakerappstart/squad_details_screen.dart';
import 'package:playmakerappstart/create_sqauds_screen.dart';
import 'package:cached_network_image/cached_network_image.dart'; // Added import

class MySquadScreen extends StatefulWidget {
  final PlayerProfile playerProfile;

  const MySquadScreen({
    super.key,
    required this.playerProfile,
  });

  @override
  State<MySquadScreen> createState() => _MySquadScreenState();
}

class _MySquadScreenState extends State<MySquadScreen> {
  final _supabaseService = SupabaseService();
  List<Squad> _squads = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchSquads();
  }

  Widget _buildCard({required Widget child, EdgeInsets? padding}) {
    return Container(
      width: double.infinity,
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

  Future<void> _fetchSquads() async {
    setState(() => _isLoading = true);
    try {
      final fetchedSquads = await _supabaseService.fetchSquads(
        widget.playerProfile.id,
      );
      setState(() => _squads = fetchedSquads);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'My Squads',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black87,
      ),
      body: RefreshIndicator(
        onRefresh: _fetchSquads,
        color: const Color(0xFF00BF63),
        child: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF00BF63),
              ),
            )
          : _squads.isEmpty
            ? _EmptyState(playerProfile: widget.playerProfile)
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _squads.length,
                itemBuilder: (context, index) {
                  final squad = _squads[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _SquadCard(
                      squad: squad,
                      isCaptain: squad.captain == widget.playerProfile.id,
                      userId: widget.playerProfile.id,
                    ),
                  );
                },
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CreateSquadsScreen(
              playerProfile: widget.playerProfile,
            ),
          ),
        ),
        backgroundColor: const Color(0xFF00BF63),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Create Squad'),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final PlayerProfile playerProfile;

  const _EmptyState({required this.playerProfile});

  Widget _buildCard({required Widget child, EdgeInsets? padding}) {
    return Container(
      width: double.infinity,
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
        padding: padding ?? const EdgeInsets.all(32),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: _buildCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF00BF63).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.groups_outlined,
                  size: 64,
                  color: const Color(0xFF00BF63),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'No Squads Yet',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Create your own squad or join existing ones to get started with your football journey',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: Colors.grey[600],
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CreateSquadsScreen(
                        playerProfile: playerProfile,
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.add),
                  label: const Text('Create Squad'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF00BF63),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => JoinSquadsScreen(
                        playerProfile: playerProfile,
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.search),
                  label: const Text('Join Squads'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF00BF63),
                    side: const BorderSide(color: Color(0xFF00BF63)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SquadCard extends StatelessWidget {
  final Squad squad;
  final bool isCaptain;
  final String userId;

  const _SquadCard({
    required this.squad,
    required this.isCaptain,
    required this.userId,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
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
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SquadDetailsScreen(
                userId: userId,
                squad: squad,
                isVisitor: !squad.squadMembers.contains(userId),
              ),
            ),
          ),
          borderRadius: BorderRadius.circular(16),
          splashColor: const Color(0xFF00BF63).withOpacity(0.1),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Header Row
                Row(
                  children: [
                    // Squad Logo/Avatar
                    Container(
                      width: 60,
                      height: 60,
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
                                placeholder: (context, url) => Container(
                                  color: const Color(0xFF00BF63).withOpacity(0.1),
                                  child: const Icon(
                                    Icons.shield_outlined,
                                    color: Color(0xFF00BF63),
                                    size: 30,
                                  ),
                                ),
                                errorWidget: (context, url, error) => Container(
                                  color: const Color(0xFF00BF63).withOpacity(0.1),
                                  child: const Icon(
                                    Icons.shield_outlined,
                                    color: Color(0xFF00BF63),
                                    size: 30,
                                  ),
                                ),
                              )
                            : Center(
                                child: Text(
                                  squad.squadName.isNotEmpty 
                                      ? squad.squadName[0].toUpperCase() 
                                      : 'S',
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    color: const Color(0xFF00BF63),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    
                    // Squad Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  squad.squadName,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isCaptain) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.amber.withOpacity(0.3),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        FontAwesomeIcons.crown,
                                        size: 10,
                                        color: Colors.amber,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Captain',
                                        style: theme.textTheme.labelSmall?.copyWith(
                                          color: Colors.amber[700],
                                          fontWeight: FontWeight.w600,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (squad.squadLocation.isNotEmpty)
                            _InfoRow(
                              icon: Icons.location_on,
                              text: squad.squadLocation,
                              iconColor: const Color(0xFF00BF63),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Stats Row
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _StatItem(
                          icon: Icons.group,
                          label: 'Members',
                          value: '${squad.squadMembers.length}',
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 30,
                        color: Colors.grey[300],
                      ),
                      Expanded(
                        child: _StatItem(
                          icon: Icons.sports_soccer,
                          label: 'Matches',
                          value: squad.matchesPlayed,
                        ),
                      ),
                      if (squad.averageAge != null && squad.averageAge! > 0) ...[
                        Container(
                          width: 1,
                          height: 30,
                          color: Colors.grey[300],
                        ),
                        Expanded(
                          child: _StatItem(
                            icon: Icons.cake,
                            label: 'Avg Age',
                            value: squad.averageAge!.toStringAsFixed(1),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color? iconColor;

  const _InfoRow({
    required this.icon,
    required this.text,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: (iconColor ?? const Color(0xFF00BF63)).withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            icon,
            size: 14,
            color: iconColor ?? const Color(0xFF00BF63),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Icon(
          icon,
          color: const Color(0xFF00BF63),
          size: 18,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: Colors.grey[600],
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}
