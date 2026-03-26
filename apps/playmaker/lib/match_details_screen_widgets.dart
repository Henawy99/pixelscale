import 'package:flutter/material.dart';
import 'package:playmakerappstart/models/user_model.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:country_picker/country_picker.dart';
import 'package:playmakerappstart/player_details_screen.dart';
import 'package:playmakerappstart/services/supabase_service.dart';


class PlayerLoadingTile extends StatelessWidget {
  const PlayerLoadingTile({super.key});

  @override
  Widget build(BuildContext context) {
    return const ListTile(
      leading: CircleAvatar(
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      title: LinearProgressIndicator(),
    );
  }
}


class PlayerErrorTile extends StatelessWidget {
  const PlayerErrorTile({super.key});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.error.withOpacity(0.1),
        child: Icon(
          Icons.error_outline,
          color: Theme.of(context).colorScheme.error,
        ),
      ),
      title: const Text('Unable to load player'),
    );
  }
}

class GuestPlayerTile extends StatelessWidget {
  final String hostName;
  final int guestNumber;

  const GuestPlayerTile({
    super.key,
    required this.hostName,
    required this.guestNumber,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brandColor = const Color(0xFF00BF63);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 2),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Colors.grey.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: null,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: brandColor.withOpacity(0.1),
                child: Icon(
                  Icons.person_outline,
                  size: 24,
                  color: brandColor,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Guest $guestNumber',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Added by $hostName',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MatchInfoItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final Widget? trailing;
  final String? imageUrl;

  const MatchInfoItem({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    this.trailing,
    this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        if (imageUrl != null && imageUrl!.isNotEmpty)
          CircleAvatar(
            radius: 20,
            backgroundColor: theme.colorScheme.primaryContainer,
            backgroundImage: NetworkImage(imageUrl!),
          )
        else
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 18,
              color: iconColor,
            ),
          ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}



class ModernMatchPlayerTile extends StatelessWidget {
  final PlayerProfile playerProfile;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool isHost;
  final String currentUserId;

  const ModernMatchPlayerTile({
    super.key,
    required this.playerProfile,
    this.trailing,
    this.onTap,
    this.isHost = false,
    required this.currentUserId,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brandColor = const Color(0xFF00BF63);
    final firestoreService = SupabaseService();
    final country = Country.tryParse(playerProfile.nationality);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 2),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isHost ? brandColor.withOpacity(0.2) : Colors.grey.withOpacity(0.1),
          width: isHost ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap ?? () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => FutureBuilder<PlayerProfile?>(
                future: firestoreService.getUserProfileById(currentUserId),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Scaffold(
                      body: Center(child: CircularProgressIndicator()),
                    );
                  }
                  return PlayerDetailsScreen(
                    player: playerProfile,
                    currentUserProfile: snapshot.data ?? playerProfile,
                  );
                },
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Hero(
                tag: 'player-avatar-${playerProfile.id}',
                child: CircleAvatar(
                  radius: 24,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  backgroundImage: playerProfile.profilePicture.isNotEmpty
                      ? CachedNetworkImageProvider(playerProfile.profilePicture)
                      : null,
                  child: playerProfile.profilePicture.isEmpty
                      ? Icon(
                          Icons.person_outline,
                          color: brandColor,
                        )
                      : null,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            playerProfile.name,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: isHost ? brandColor : theme.colorScheme.onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (country != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            country.flagEmoji,
                            style: const TextStyle(fontSize: 16),
                          ),
                        ],
                        if (isHost) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: brandColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Host',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: brandColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (playerProfile.personalLevel.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              playerProfile.personalLevel,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        if (playerProfile.playerId != null && playerProfile.playerId!.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Text(
                            'ID: ${playerProfile.playerId}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              trailing ?? const SizedBox.shrink(),
            ],
          ),
        ),
      ),
    );
  }
}


class JoinRequestTile extends StatelessWidget {
  final PlayerProfile playerProfile;
  final int guestCount;
  final VoidCallback? onAccept;
  final VoidCallback? onDecline;
  final Function(PlayerProfile)? onTapTile;

  const JoinRequestTile({
    super.key,
    required this.playerProfile,
    required this.guestCount,
    this.onAccept,
    this.onDecline,
    this.onTapTile,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
      ),
      child: ListTile(
        onTap: onTapTile != null ? () => onTapTile!(playerProfile) : null,
        leading: CircleAvatar(
          backgroundImage: playerProfile.profilePicture.isNotEmpty
              ? NetworkImage(playerProfile.profilePicture)
              : null,
          child: playerProfile.profilePicture.isEmpty
              ? const Icon(Icons.person_outline)
              : null,
        ),
        title: Text(
          playerProfile.name,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              playerProfile.personalLevel,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            if (guestCount > 0)
              Text(
                '+$guestCount guest${guestCount > 1 ? 's' : ''}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: onAccept,
              icon: const Icon(Icons.check_circle),
              color: const Color(0xFF00BF63),
              iconSize: 28,
            ),
            IconButton(
              onPressed: onDecline,
              icon: const Icon(Icons.cancel),
              color: Colors.red,
              iconSize: 28,
            ),
          ],
        ),
      ),
    );
  }
}