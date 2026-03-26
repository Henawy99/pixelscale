import 'package:flutter/material.dart';
// Coming Soon - will re-enable when squads feature is ready
// ignore: unused_import
import 'package:playmakerappstart/create_sqauds_screen.dart';
import 'package:playmakerappstart/friends_screen.dart';
// ignore: unused_import
import 'package:playmakerappstart/join_squad_screen.dart';
import 'package:playmakerappstart/models/user_model.dart';
// ignore: unused_import
import 'package:playmakerappstart/mysquads_screen.dart';
import 'package:playmakerappstart/custom_container.dart';
import 'package:playmakerappstart/services/supabase_service.dart';
import 'package:playmakerappstart/custom_dialoag.dart';
import 'package:playmakerappstart/login_screen/login_screen.dart';
import 'package:playmakerappstart/localization/app_localizations.dart'; // Added for localization

class SquadsScreen extends StatefulWidget {
  final PlayerProfile playerProfile;

  const SquadsScreen({
    super.key,
    required this.playerProfile,
  });

  @override
  State<SquadsScreen> createState() => _SquadsScreenState();
}

class _SquadsScreenState extends State<SquadsScreen> {
  late PlayerProfile _playerProfile;

  @override
  void initState() {
    super.initState();
    _playerProfile = widget.playerProfile;
  }

  Future<void> _refreshData() async {
    try {
      final updatedProfile = await SupabaseService().getUserModel(_playerProfile.id);
      if (updatedProfile != null && mounted) {
        setState(() {
          _playerProfile = updatedProfile;
        });
      }
    } catch (e) {
      print('Error refreshing profile: $e');
    }
  }

  void _showCreateProfileDialog() {
    CustomDialog.show(
      context: context,
      title: context.loc.createAccountDialogTitle,
      message: context.loc.createAccountDialogMessage,
      confirmText: context.loc.signUpButton,
      cancelText: context.loc.cancel,
      icon: Icons.account_circle_outlined,
      onConfirm: () {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const LoginWithPasswordScreen(),
          ),
        );
      },
    );
  }

  void _showComingSoonDialog() {
    CustomDialog.show(
      context: context,
      title: 'Coming Soon',
      message: 'This feature is coming soon! Stay tuned for updates.',
      confirmText: 'OK',
      icon: Icons.rocket_launch_outlined,
      onConfirm: () {},
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.loc.squadsTabTitle,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        automaticallyImplyLeading: false,
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Friends - Active
                    _ActionCard(
                      title: context.loc.friendsCardTitle,
                      subtitle: context.loc.connectWithPlayersSubtitle,
                      assetImage: 'assets/images/football_team.png',
                      statNumber: _playerProfile.friends.length,
                      statLabel: context.loc.friendsStatLabel,
                      onTap: () {
                        if (_playerProfile.isGuest) {
                          _showCreateProfileDialog();
                        } else {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => FriendsScreen(
                                playerProfile: _playerProfile,
                              ),
                            ),
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 5),
                    // My Squads - Coming Soon
                    _ActionCard(
                      title: context.loc.mySquadsCardTitle,
                      subtitle: context.loc.mySquadsCardSubtitle,
                      assetImage: 'assets/images/my_squads_photo.png',
                      statNumber: _playerProfile.teamsJoined.length,
                      statLabel: context.loc.teamsStatLabel,
                      isLocked: true,
                      onTap: () => _showComingSoonDialog(),
                    ),
                    const SizedBox(height: 5),
                    // Join Squads - Coming Soon
                    _ActionCard(
                      title: context.loc.joinSquadsCardTitle,
                      subtitle: context.loc.joinSquadsCardSubtitle,
                      assetImage: 'assets/images/contract.png',
                      isLocked: true,
                      onTap: () => _showComingSoonDialog(),
                    ),
                    const SizedBox(height: 5),
                    // Create Squad - Coming Soon
                    _ActionCard(
                      title: context.loc.createSquadCardTitle,
                      subtitle: context.loc.createSquadCardSubtitle,
                      assetImage: 'assets/images/friends_photo.png',
                      isLocked: true,
                      onTap: () => _showComingSoonDialog(),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String assetImage;
  final int? statNumber;
  final String? statLabel;
  final VoidCallback onTap;
  final bool isLocked;

  const _ActionCard({
    required this.title,
    required this.subtitle,
    required this.assetImage,
    this.statNumber,
    this.statLabel,
    required this.onTap,
    this.isLocked = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool isRtl = Directionality.of(context) == TextDirection.rtl;

    Widget textContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Flexible(
                  child: Text(
                    title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isLocked ? Colors.grey : const Color(0xFF00BF63),
                    ),
                    textAlign: TextAlign.start,
                  ),
                ),
                if (isLocked) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Coming Soon',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: Colors.orange.shade800,
                        fontWeight: FontWeight.w600,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(isLocked ? 0.5 : 0.7),
              ),
              textAlign: TextAlign.start,
            ),
          ],
        ),
        if (statNumber != null && statLabel != null && !isLocked)
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Text(
                statNumber.toString(),
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF00BF63),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                statLabel!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
            ],
          ),
      ],
    );

    Widget imageContent = SizedBox(
      width: 180, // Adjusted width to give more space for text
      child: Opacity(
        opacity: isLocked ? 0.4 : 1.0,
        child: Image.asset(
          assetImage,
          fit: BoxFit.cover,
        ),
      ),
    );

    return CustomContainer(
      clipImage: false, // Keep this false if CustomContainer handles clipping
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          splashColor: isLocked ? Colors.grey.withOpacity(0.1) : const Color(0xFF00BF63).withOpacity(0.1),
          highlightColor: isLocked ? Colors.grey.withOpacity(0.05) : const Color(0xFF00BF63).withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: 120,
            child: Stack(
              children: [
                Positioned(
                  top: 0,
                  bottom: 0,
                  right: isRtl ? null : -20,
                  left: isRtl ? -20 : null,
                  child: imageContent,
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3, // Give more space to text
                        child: textContent,
                      ),
                      const Spacer(flex: 2), // Adjust spacer if image width changed
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

class MainScreenContainer extends StatefulWidget {
  final double height;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final bool clipImage;
  final VoidCallback? onTap; // Add this line

  const MainScreenContainer({
    Key? key,
    required this.child,
    this.height = 130,
    this.padding = const EdgeInsets.all(16.0),
    this.color = Colors.white,
    this.clipImage = false,
    this.onTap, // Add this line
  }) : super(key: key);

  @override
  _MainScreenContainerState createState() => _MainScreenContainerState();
}

class _MainScreenContainerState extends State<MainScreenContainer> {
  Color _borderColor = Colors.transparent;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        setState(() {
          _borderColor = Colors.green;
        });
      },
      onTapUp: (_) {
        setState(() {
          _borderColor = Colors.transparent;
        });
        if (widget.onTap != null) {
          widget.onTap!();
        }
      },
      onTapCancel: () {
        setState(() {
          _borderColor = Colors.transparent;
        });
      },
      child: Container(
        height: widget.height,
        decoration: BoxDecoration(
          color: widget.color,
          borderRadius: BorderRadius.circular(8.0),
          border: Border.all(color: _borderColor, width: 3.0),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.8),
              offset: const Offset(1.1, 1.1),
              blurRadius: 10.0,
            ),
          ],
        ),
        child: widget.clipImage
            ? ClipRRect(
                borderRadius: BorderRadius.circular(8.0),
                child: widget.child,
              )
            : Padding(
                padding: widget.padding,
                child: widget.child,
              ),
      ),
    );
  }
}
