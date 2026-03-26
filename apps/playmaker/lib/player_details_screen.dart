import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:country_picker/country_picker.dart';
import 'package:playmakerappstart/l10n/app_localizations.dart';
import './models/squad.dart';
import 'package:playmakerappstart/models/user_model.dart';
import 'package:playmakerappstart/services/supabase_service.dart';
import 'package:playmakerappstart/services/notification_service.dart';
import 'package:playmakerappstart/squad_details_screen.dart';

class PlayerDetailsScreen extends StatefulWidget {
  final PlayerProfile player;
  final PlayerProfile currentUserProfile;
  final bool forceShowAsFriend;

  const PlayerDetailsScreen({
    Key? key, 
    required this.player,
    required this.currentUserProfile,
    this.forceShowAsFriend = false,
  }) : super(key: key);

  @override
  State<PlayerDetailsScreen> createState() => _PlayerDetailsScreenState();
}

class _PlayerDetailsScreenState extends State<PlayerDetailsScreen> with SingleTickerProviderStateMixin {
  final _supabaseService = SupabaseService();
  bool _isLoading = false;
  late PlayerProfile _playerProfile;
  final _brandColor = const Color(0xFF00BF63);
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late bool _isFriend;
  late bool _requestSent;

  @override
  void initState() {
    super.initState();
    _playerProfile = widget.player;
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();
    _updateFriendStatus();
  }

  @override
  void didUpdateWidget(covariant PlayerDetailsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.player != oldWidget.player || widget.currentUserProfile != oldWidget.currentUserProfile) {
      _updateFriendStatus();
    }
  }

  void _updateFriendStatus() {
    setState(() {
      _isFriend = widget.forceShowAsFriend || widget.currentUserProfile.friends.contains(widget.player.id);
      _requestSent = widget.currentUserProfile.sentFriendRequests.contains(widget.player.id);
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  bool get _isSelf => widget.player.id == widget.currentUserProfile.id;
  bool get _hasPendingRequest => _playerProfile.openFriendRequests.contains(widget.currentUserProfile.id);

  Future<void> _sendFriendRequest() async {
    setState(() => _isLoading = true);
    try {
      await _supabaseService.sendFriendRequest(
        widget.currentUserProfile.id,
        widget.player.id,
      );
      
      // Send push notification to the recipient
      await NotificationService().sendFriendRequestNotification(
        toUserId: widget.player.id,
        fromUserName: widget.currentUserProfile.name,
        fromUserId: widget.currentUserProfile.id,
      );
      
      // Update local state to show pending request immediately
      setState(() {
        _playerProfile = _playerProfile.copyWith(
          openFriendRequests: [..._playerProfile.openFriendRequests, widget.currentUserProfile.id],
        );
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.person_add, color: Colors.white),
                const SizedBox(width: 12),
                Text(AppLocalizations.of(context)!.playerDetails_friendRequestSent(widget.player.name)),
              ],
            ),
            behavior: SnackBarBehavior.floating,
            backgroundColor: _brandColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.playerDetails_errorSendingFriendRequest(e.toString())),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _unfriend() async {
    final theme = Theme.of(context);
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(28),
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
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const CircleAvatar(
                    radius: 32,
                    backgroundColor: Color(0xFF00BF63),
                    child: Icon(
                      Icons.person_remove_outlined,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    AppLocalizations.of(context)!.playerDetails_removeFriendTitle,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AppLocalizations.of(context)!.playerDetails_removeFriendConfirmation(widget.player.name),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(AppLocalizations.of(context)!.cancel),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: FilledButton(
                          onPressed: () async {
                            Navigator.pop(context);
                            setState(() => _isLoading = true);
                            try {
                              await _supabaseService.deleteFriend(
                                widget.currentUserProfile.id,
                                widget.player.id,
                              );

                              // Update local state to reflect the unfriend action
                              // No need for a separate setState here as _updateFriendStatus will call it.
                              _playerProfile = _playerProfile.copyWith(
                                friends: _playerProfile.friends.where((id) => id != widget.currentUserProfile.id).toList(),
                              );
                              widget.currentUserProfile.friends.remove(widget.player.id);
                              
                              // Explicitly call _updateFriendStatus to refresh _isFriend and _requestSent
                              _updateFriendStatus(); 

                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Row(
                                      children: [
                                        const Icon(Icons.person_remove, color: Colors.white),
                                        const SizedBox(width: 12),
                                        Text(AppLocalizations.of(context)!.playerDetails_friendRemovedSnackbar(widget.player.name)),
                                      ],
                                    ),
                                    backgroundColor: Colors.red,
                                    behavior: SnackBarBehavior.floating,
                                    margin: const EdgeInsets.all(16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                );
                              }
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(AppLocalizations.of(context)!.playerDetails_errorRemovingFriend(e.toString())),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            } finally {
                              setState(() => _isLoading = false);
                            }
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: theme.colorScheme.error,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(AppLocalizations.of(context)!.playerDetails_removeButton),
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
    );
  }

  Widget _buildFriendButton() {
    if (_isSelf) return const SizedBox.shrink();

    final theme = Theme.of(context);

    if (_isFriend) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              spreadRadius: 0,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: _brandColor.withOpacity(0.1),
                  borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                    Icon(
                      Icons.check_circle_outlined,
                      size: 16,
                      color: _brandColor,
                    ),
                    const SizedBox(width: 8),
                      Text(
                      AppLocalizations.of(context)!.playerDetails_friendsButton,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: _brandColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _isLoading ? null : _unfriend,
                borderRadius: const BorderRadius.horizontal(right: Radius.circular(12)),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: const BorderRadius.horizontal(right: Radius.circular(12)),
                  ),
                  child: _isLoading 
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.red,
                        ),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.person_remove,
                            size: 16,
                            color: Colors.red,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            AppLocalizations.of(context)!.playerDetails_removeButton,
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: Colors.red,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
      ),
    );
  }

    if (_hasPendingRequest) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: _brandColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              spreadRadius: 0,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.pending_outlined,
              size: 18,
              color: _brandColor,
            ),
            const SizedBox(width: 8),
            Text(
              AppLocalizations.of(context)!.playerDetails_requestPendingButton,
              style: theme.textTheme.labelLarge?.copyWith(
                color: _brandColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          colors: [
            _brandColor,
            _brandColor.withOpacity(0.8),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: _brandColor.withOpacity(0.3),
            blurRadius: 10,
            spreadRadius: 0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isLoading ? null : _sendFriendRequest,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _isLoading 
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(
                      Icons.person_add,
                      color: Colors.white,
                      size: 20,
                    ),
                const SizedBox(width: 8),
                Text(
                  AppLocalizations.of(context)!.playerDetails_addFriendButton,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Helper to format the joined date
  String _formatJoinedDate(String dateString) {
    if (dateString.isEmpty) return AppLocalizations.of(context)!.playerDetails_notSet; // Handle empty date
    try {
      final DateTime date = DateTime.parse(dateString);
      return DateFormat('dd.MM.yyyy', AppLocalizations.of(context)!.localeName).format(date);
    } catch (e) {
      // If parsing fails, return the original string or a default
      print(AppLocalizations.of(context)!.playerDetails_errorParsingJoinedDate(e.toString()));
      return dateString;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final country = Country.tryParse(widget.player.nationality) ?? Country.worldWide;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: Colors.transparent,
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.white),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Background gradient
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          _brandColor,
                          _brandColor.withOpacity(0.7),
                        ],
                      ),
                    ),
                  ),
                  // Subtle pattern overlay
                  Opacity(
                    opacity: 0.1,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        backgroundBlendMode: BlendMode.softLight,
                      ),
                    ),
                  ),
                  // Profile image and name
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: SafeArea(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          GestureDetector(
                            onTap: () {
                              showDialog(
                                context: context,
                                builder: (context) => Dialog(
                                  backgroundColor: Colors.transparent,
                                  child: Stack(
        children: [
                                      InteractiveViewer(
                                        child: Hero(
                                          tag: 'profile-image-${widget.player.id}',
                                          child: CachedNetworkImage(
                                            imageUrl: widget.player.profilePicture,
                                            fit: BoxFit.contain,
                                            placeholder: (context, url) => Container(
                                              color: Colors.black12,
                                              child: const Center(child: CircularProgressIndicator()),
                                            ),
                                            errorWidget: (context, url, error) => Container(
                                              color: Colors.black12,
                                              child: const Icon(Icons.error),
                                            ),
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        top: 8,
                                        right: 8,
                                        child: Material(
                                          color: Colors.black26,
                                          shape: const CircleBorder(),
                                          child: IconButton(
                                            icon: const Icon(Icons.close, color: Colors.white),
                                            onPressed: () => Navigator.pop(context),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.15),
                                    spreadRadius: 1,
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Hero(
                                tag: 'profile-image-${widget.player.id}',
                                child: CircleAvatar(
                                  radius: 60,
                                  backgroundColor: Colors.white,
                                  backgroundImage: widget.player.profilePicture.isNotEmpty
                                    ? CachedNetworkImageProvider(widget.player.profilePicture) as ImageProvider
                                    : null,
                                  child: widget.player.profilePicture.isEmpty
                                    ? Icon(Icons.person, size: 40, color: _brandColor)
                                    : null,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
          Text(
                            widget.player.name,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          if (widget.player.playerId != null && widget.player.playerId!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  AppLocalizations.of(context)!.playerDetails_playerIDLabel(widget.player.playerId!),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Column(
              children: [
                _buildFriendButton(),
                // Stats Section
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: Container(
                    margin: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          spreadRadius: 0,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildStatItem(
                            context,
                            AppLocalizations.of(context)!.playerDetails_statMatches,
                            widget.player.bookings.length.toString(),
                            Icons.sports_soccer_outlined,
                          ),
                          _buildVerticalDivider(),
                          _buildStatItem(
                            context,
                            AppLocalizations.of(context)!.playerDetails_statFriends,
                            widget.player.friends.length.toString(),
                            Icons.group_outlined,
                          ),
                          _buildVerticalDivider(),
                          _buildStatItem(
                            context,
                            AppLocalizations.of(context)!.playerDetails_statSquads,
                            widget.player.teamsJoined.length.toString(),
                            Icons.shield_outlined,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                
                // Player Info Section
                SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.1),
                    end: Offset.zero,
                  ).animate(_fadeAnimation),
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: _brandColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.person_outline,
                                  color: _brandColor,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
          Text(
                                AppLocalizations.of(context)!.playerDetails_playerInfoSectionTitle,
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: _brandColor,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 10,
                                  spreadRadius: 0,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                _buildInfoRow(
                                  context,
                                  icon: Icons.public_outlined,
                                  label: AppLocalizations.of(context)!.playerDetails_nationalityLabel,
                                  value: '${country.flagEmoji} ${country.name != "World Wide" ? country.name : AppLocalizations.of(context)!.playerDetails_notSet}',
                                ),
                                const Divider(height: 24),
                                _buildInfoRow(
                                  context,
                                  icon: Icons.sports_soccer_outlined,
                                  label: AppLocalizations.of(context)!.playerDetails_positionLabel,
                                  value: widget.player.preferredPosition.isEmpty ? AppLocalizations.of(context)!.playerDetails_notSet : widget.player.preferredPosition,
                                ),
                                const Divider(height: 24),
                                _buildInfoRow(
                                  context,
                                  icon: Icons.calendar_today_outlined,
                                  label: AppLocalizations.of(context)!.playerDetails_ageLabel,
                                  value: widget.player.age.isEmpty ? AppLocalizations.of(context)!.playerDetails_notSet : AppLocalizations.of(context)!.playerDetails_ageValue(widget.player.age),
                                ),
                                const Divider(height: 24),
                                _buildInfoRow(
                                  context,
                                  icon: Icons.trending_up_outlined,
                                  label: AppLocalizations.of(context)!.playerDetails_skillLevelLabel,
                                  value: widget.player.personalLevel.isEmpty ? AppLocalizations.of(context)!.playerDetails_notSet : widget.player.personalLevel,
                                ),
                                if (widget.player.joined.isNotEmpty) ...[
                                  const Divider(height: 24),
                                  _buildInfoRow(
                                    context,
                                    icon: Icons.access_time_outlined,
                                    label: AppLocalizations.of(context)!.playerDetails_memberSinceLabel,
                                    value: _formatJoinedDate(widget.player.joined),
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
                // Bottom spacer
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerticalDivider() {
    return Container(
      height: 40,
      width: 1,
      color: Colors.grey.shade200,
    );
  }

  Widget _buildStatItem(BuildContext context, String label, String value, IconData icon) {
    final theme = Theme.of(context);
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _brandColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: _brandColor,
            size: 24,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: _brandColor,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _brandColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: _brandColor,
            size: 20,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
              if (label == 'Skill Level' && value != 'Not set')
                _buildSkillLevelStars(context, value)
              else
                Text(
                  value,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSkillLevelStars(BuildContext context, String level) {
    int stars;
    Color starColor;

    switch (level) {
      case 'Beginner':
        stars = 1;
        starColor = Colors.green.shade400;
        break;
      case 'Casual':
        stars = 2;
        starColor = Colors.green.shade500;
        break;
      case 'Skilled':
        stars = 3;
        starColor = Colors.blue.shade400;
        break;
      case 'Elite':
        stars = 4;
        starColor = Colors.purple.shade400;
        break;
      case 'Expert':
        stars = 5;
        starColor = Colors.amber.shade600;
        break;
      default:
        stars = 0;
        starColor = Colors.grey.shade400;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          level,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: List.generate(5, (index) {
            return Icon(
              index < stars ? Icons.star : Icons.star_border,
              size: 16,
              color: index < stars ? starColor : Colors.grey.shade300,
            );
          }),
        ),
      ],
    );
  }
}

class FriendsListScreen extends StatelessWidget {
  final PlayerProfile playerProfile;

  const FriendsListScreen({Key? key, required this.playerProfile}) : super(key: key);

  Future<void> _showAddFriendDialog(BuildContext context, PlayerProfile friend) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.playerDetails_addFriendDialogTitle),
        content: Text(AppLocalizations.of(context)!.playerDetails_addFriendDialogContent(friend.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          TextButton(
            onPressed: () {
              SupabaseService().sendFriendRequest(
                playerProfile.id,
                friend.id,
              );
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(AppLocalizations.of(context)!.playerDetails_friendRequestSent(friend.name))),
              );
            },
            child: Text(AppLocalizations.of(context)!.playerDetails_addButton),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.friends),
        elevation: 0,
      ),
      body: StreamBuilder<List<PlayerProfile>>(
        stream: SupabaseService().streamUserFriends(playerProfile.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // Handle errors gracefully - show reconnecting message
          if (snapshot.hasError) {
            print('⚠️ Friends stream error: ${snapshot.error}');
            WidgetsBinding.instance.addPostFrameCallback((_) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Connection issue, reconnecting...'),
                  duration: Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            });
          }

          final friends = snapshot.data ?? [];
          
          return ListView.builder(
            itemCount: friends.length,
            itemBuilder: (context, index) {
              final friend = friends[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundImage: friend.profilePicture.isNotEmpty
                      ? CachedNetworkImageProvider(friend.profilePicture)
                      : null,
                  child: friend.profilePicture.isEmpty
                      ? const Icon(Icons.person)
                      : null,
                ),
                title: Text(friend.name),
                subtitle: Text(friend.playerId ?? 'Not assigned'),
                trailing: ElevatedButton(
                  onPressed: () => _showAddFriendDialog(context, friend),
                  child: Text(AppLocalizations.of(context)!.playerDetails_addFriendButton),
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PlayerDetailsScreen(
                        currentUserProfile: playerProfile,
                        player: friend,
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class SquadsListScreen extends StatelessWidget {
  final PlayerProfile playerProfile;

  const SquadsListScreen({Key? key, required this.playerProfile}) : super(key: key);

  Future<void> _showJoinSquadDialog(BuildContext context, Squad squad) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.playerDetails_joinSquadDialogTitle),
        content: Text(AppLocalizations.of(context)!.playerDetails_joinSquadDialogContent(squad.squadName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          TextButton(
            onPressed: () {
              // Add the logic to request joining the squad
              // You might need to add a new method in SupabaseService for this
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(AppLocalizations.of(context)!.playerDetails_requestSentToJoinSquadSnackbar(squad.squadName))),
              );
            },
            child: Text(AppLocalizations.of(context)!.playerDetails_requestToJoinButton),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.squads),
        elevation: 0,
      ),
      body: FutureBuilder<List<Squad>>(
        future: SupabaseService().fetchSquads(playerProfile.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Error: ${snapshot.error}'),
            );
          }

          final squads = snapshot.data ?? [];

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 0.8,
            ),
            itemCount: squads.length,
            itemBuilder: (context, index) {
              final squad = squads[index];
              final isSquadCaptain = squad.captain == playerProfile.id;

              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      spreadRadius: 0,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      flex: 3,
                      child: InkWell(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => SquadDetailsScreen(
                              userId: playerProfile.id,
                              squad: squad,
                              // isCaptain: squad.captain == playerProfile.id, // Removed
                              isVisitor: !squad.squadMembers.contains(playerProfile.id),
                            ),
                          ),
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                            image: DecorationImage(
                              image: CachedNetworkImageProvider(
                                squad.squadLogo ?? squad.profilePicture,
                              ),
                          fit: BoxFit.cover,
                            ),
                          ),
                          child: squad.squadLogo == null && squad.profilePicture.isEmpty
                            ? Center(
                                child: Icon(
                                  Icons.sports_soccer,
                                  size: 40,
                                  color: const Color(0xFF00BF63),
                                ),
                              )
                            : null,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                              squad.squadName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (isSquadCaptain)
                                  Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF00BF63).withOpacity(0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.star,
                                      size: 14,
                                      color: const Color(0xFF00BF63),
                                    ),
                                  ),
                              ],
                            ),
                            const Spacer(),
                            if (!isSquadCaptain) // Only show join button if not the captain
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: () => _showJoinSquadDialog(context, squad),
                                  style: ElevatedButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    backgroundColor: const Color(0xFF00BF63),
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: Text(AppLocalizations.of(context)!.joinMatchButton), // Re-use existing key
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
