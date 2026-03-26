import 'package:flutter/material.dart';
// import 'package:playmakerappstart/player_list_tile.dart'; // Replaced with components/player_tile.dart
import 'package:playmakerappstart/components/player_tile.dart'; // Corrected import
import 'package:provider/provider.dart';
import 'package:playmakerappstart/models/user_model.dart';
import 'package:playmakerappstart/friends_screen_manager.dart';

class InviteFriendsBottomSheet extends StatefulWidget {
  final PlayerProfile playerProfile;
  final List<String> initiallySelectedFriends;

  const InviteFriendsBottomSheet({
    Key? key,
    required this.playerProfile,
    required this.initiallySelectedFriends,
  }) : super(key: key);

  @override
  _InviteFriendsBottomSheetState createState() => _InviteFriendsBottomSheetState();
}

class _InviteFriendsBottomSheetState extends State<InviteFriendsBottomSheet> {
  Set<String> selectedFriends = {};

  @override
  void initState() {
    super.initState();
    selectedFriends = Set.from(widget.initiallySelectedFriends);
  }

  void _toggleFriendSelection(String friendId) {
    setState(() {
      if (selectedFriends.contains(friendId)) {
        selectedFriends.remove(friendId);
      } else {
        selectedFriends.add(friendId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return ChangeNotifierProvider(
      create: (context) => FriendManager()..initialize(widget.playerProfile.id),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withOpacity(0.1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.all(24),
                    sliver: SliverToBoxAdapter(
                      child: Row(
                        children: [
                          const Icon(
                            Icons.group_add_outlined,
                            size: 24,
                            color: Color(0xFF00BF63),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Invite Friends',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
                    sliver: Consumer<FriendManager>(
                      builder: (context, friendManager, child) {
                        if (friendManager.isLoading) {
                          return const SliverFillRemaining(
                            child: Center(child: CircularProgressIndicator()),
                          );
                        } else if (friendManager.friendsProfiles.isEmpty) {
                          return SliverFillRemaining(
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.group_off_outlined,
                                    size: 48,
                                    color: theme.colorScheme.onSurface.withOpacity(0.5),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No friends found',
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        } else {
                          return SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final friend = friendManager.friendsProfiles[index];
                                final bool isAlreadyInSquad = widget.initiallySelectedFriends.contains(friend.id);
                                final bool isSelectedForInvite = selectedFriends.contains(friend.id);

                                return Container(
                                  margin: const EdgeInsets.symmetric(vertical: 2),
                                  child: PlayerTile(
                                    playerProfile: friend,
                                    actionType: isAlreadyInSquad 
                                        ? PlayerTileActionType.statusText 
                                        : PlayerTileActionType.customWidget,
                                    statusText: isAlreadyInSquad ? 'Already in Squad' : null,
                                    customTrailingWidget: isAlreadyInSquad 
                                        ? null 
                                        : Icon(
                                            isSelectedForInvite ? Icons.check_circle : Icons.check_circle_outline,
                                            color: isSelectedForInvite ? const Color(0xFF00BF63) : Colors.grey.shade400,
                                            size: 24,
                                          ),
                                    onTap: isAlreadyInSquad ? null : () => _toggleFriendSelection(friend.id),
                                    isSelected: isSelectedForInvite && !isAlreadyInSquad,
                                    isDisabled: isAlreadyInSquad,
                                    // PlayerTile handles its own disabledTileColor
                                  ),
                                );
                              },
                              childCount: friendManager.friendsProfiles.length,
                            ),
                          );
                        }
                      },
                    ),
                  ),
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      24,
                      24,
                      24,
                      24 + MediaQuery.of(context).viewInsets.bottom,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: FilledButton.icon(
                        onPressed: selectedFriends.isEmpty ? null : () {
                          Navigator.pop(context, selectedFriends.toList());
                        },
                        icon: const Icon(Icons.group_add),
                        label: Text(
                          selectedFriends.isEmpty 
                              ? 'Select Players'
                              : 'Invite Selected (${selectedFriends.length})',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: selectedFriends.isEmpty
                                ? theme.colorScheme.onSurface.withOpacity(0.38)
                                : Colors.white,
                          ),
                        ),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(double.infinity, 56),
                          backgroundColor: const Color(0xFF00BF63),
                          disabledBackgroundColor: theme.colorScheme.onSurface.withOpacity(0.12),
                        ),
                      ),
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
}
