import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:playmakerappstart/models/user_model.dart';
import 'package:playmakerappstart/services/supabase_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:playmakerappstart/screens/admin/user_detail_screen.dart';
import 'package:playmakerappstart/screens/admin/fake_user_generator_dialog.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:playmakerappstart/config/supabase_config.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({Key? key}) : super(key: key);

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

enum UserFilterType { real, fake, all }

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  final TextEditingController _searchController = TextEditingController();

  List<PlayerProfile> _users = [];
  List<PlayerProfile> _filteredUsers = [];
  int _totalUsers = 0;
  int _newUsersToday = 0;
  int _newUsersThisWeek = 0;
  int _newUsersThisMonth = 0;
  int _visitorsToday = 0;
  bool _isLoading = true;
  UserFilterType _filterType = UserFilterType.real;

  @override
  void initState() {
    super.initState();
    _fetchUsers();
    _searchController.addListener(_filterUsers);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchUsers() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      // Fetch all users
      final users = await _supabaseService.getAllUsers(limit: 1000);

      // Sort by newest first (joined date descending)
      users.sort((a, b) {
        try {
          final dateA = DateTime.parse(a.joined);
          final dateB = DateTime.parse(b.joined);
          return dateB.compareTo(dateA);
        } catch (e) {
          return 0;
        }
      });

      // Get statistics
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final startOfWeek = today.subtract(Duration(days: today.weekday - 1));
      final startOfMonth = DateTime(now.year, now.month, 1);

      final newToday = await _supabaseService.getNewUsersCount(
        startDate: today,
        endDate: today.add(const Duration(days: 1)),
      );
      final newWeek = await _supabaseService.getNewUsersCount(
        startDate: startOfWeek,
      );
      final newMonth = await _supabaseService.getNewUsersCount(
        startDate: startOfMonth,
      );
      final visitorsToday = await _supabaseService.getTodayVisitorCount();

      if (mounted) {
        setState(() {
          _users = users;
          _totalUsers = users.length;
          _newUsersToday = newToday;
          _newUsersThisWeek = newWeek;
          _newUsersThisMonth = newMonth;
          _visitorsToday = visitorsToday;
          _isLoading = false;
        });
        _filterUsers();
      }
    } catch (e) {
      print('Error fetching users: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        _showError('Failed to load users');
      }
    }
  }

  void _filterUsers() {
    final query = _searchController.text.toLowerCase();
    
    setState(() {
      _filteredUsers = _users.where((user) {
        // 1. Check genuine/fake filter
        final isFake = user.email.startsWith('fake_') || user.email == 'demo@playmaker.com';
        
        if (_filterType == UserFilterType.real && isFake) return false;
        if (_filterType == UserFilterType.fake && !isFake) return false;
        
        // 2. Check search query
        if (query.isEmpty) return true;
        
        return user.name.toLowerCase().contains(query) ||
            user.email.toLowerCase().contains(query) ||
            (user.playerId?.toLowerCase().contains(query) ?? false);
      }).toList();
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  bool _isFakeUser(PlayerProfile user) {
    return user.email.startsWith('fake_') || user.email == 'demo@playmaker.com';
  }

  Future<void> _deleteFakeUser(PlayerProfile user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Fake User'),
        content: Text('Are you sure you want to delete "${user.name}"?\nThis will remove the auth account and profile.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final adminClient = SupabaseClient(
        SupabaseConfig.supabaseUrl,
        SupabaseConfig.supabaseServiceRoleKey,
      );

      // Delete profile first
      await adminClient.from('player_profiles').delete().eq('id', user.id);

      // Delete auth user
      await adminClient.auth.admin.deleteUser(user.id);

      adminClient.dispose();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Deleted "${user.name}"'), backgroundColor: Colors.green),
        );
        _fetchUsers();
      }
    } catch (e) {
      print('Error deleting fake user: $e');
      if (mounted) {
        _showError('Failed to delete user: $e');
      }
    }
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required bool isWideScreen,
  }) {
    if (isWideScreen) {
      // Compact horizontal layout for web
      return Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: Colors.grey.shade200),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    value,
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    } else {
      // Original vertical layout for mobile
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(height: 8),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: GoogleFonts.inter(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isWideScreen = size.width > 900;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => const FakeUserGeneratorDialog(),
          );
        },
        icon: const Icon(Icons.auto_awesome),
        label: const Text('Generate Fake User'),
        backgroundColor: const Color(0xFF00BF63),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchUsers,
              child: ListView(
                padding: EdgeInsets.all(isWideScreen ? 24 : 16),
                children: [
                  // Statistics Cards - Responsive Layout
                  if (isWideScreen)
                    // Web: Horizontal row of compact stats
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            title: 'Total Users',
                            value: _totalUsers.toString(),
                            icon: Icons.people,
                            color: Colors.blue,
                            isWideScreen: true,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            title: 'New Today',
                            value: _newUsersToday.toString(),
                            icon: Icons.today,
                            color: Colors.green,
                            isWideScreen: true,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            title: 'This Week',
                            value: _newUsersThisWeek.toString(),
                            icon: Icons.calendar_view_week,
                            color: Colors.orange,
                            isWideScreen: true,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            title: 'This Month',
                            value: _newUsersThisMonth.toString(),
                            icon: Icons.calendar_month,
                            color: Colors.purple,
                            isWideScreen: true,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            title: 'Visitors Today',
                            value: _visitorsToday.toString(),
                            icon: Icons.visibility,
                            color: Colors.indigo,
                            isWideScreen: true,
                          ),
                        ),
                      ],
                    )
                  else
                    // Mobile: Grid layout
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.5,
                      children: [
                        _buildStatCard(
                          title: 'Total Users',
                          value: _totalUsers.toString(),
                          icon: Icons.people,
                          color: Colors.blue,
                          isWideScreen: false,
                        ),
                        _buildStatCard(
                          title: 'New Today',
                          value: _newUsersToday.toString(),
                          icon: Icons.today,
                          color: Colors.green,
                          isWideScreen: false,
                        ),
                        _buildStatCard(
                          title: 'This Week',
                          value: _newUsersThisWeek.toString(),
                          icon: Icons.calendar_view_week,
                          color: Colors.orange,
                          isWideScreen: false,
                        ),
                        _buildStatCard(
                          title: 'This Month',
                          value: _newUsersThisMonth.toString(),
                          icon: Icons.calendar_month,
                          color: Colors.purple,
                          isWideScreen: false,
                        ),
                        _buildStatCard(
                          title: 'Visitors Today',
                          value: _visitorsToday.toString(),
                          icon: Icons.visibility,
                          color: Colors.indigo,
                          isWideScreen: false,
                        ),
                      ],
                    ),

                  SizedBox(height: isWideScreen ? 24 : 20),

                  // Search Bar and Filter
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          constraints: BoxConstraints(maxWidth: isWideScreen ? 500 : double.infinity),
                          child: TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              hintText: 'Search users...',
                              prefixIcon: const Icon(Icons.search),
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<UserFilterType>(
                            value: _filterType,
                            onChanged: (UserFilterType? newValue) {
                              if (newValue != null) {
                                setState(() {
                                  _filterType = newValue;
                                });
                                _filterUsers();
                              }
                            },
                            items: const [
                              DropdownMenuItem(
                                value: UserFilterType.real,
                                child: Text('Real Users'),
                              ),
                              DropdownMenuItem(
                                value: UserFilterType.fake,
                                child: Text('Fake Users'),
                              ),
                              DropdownMenuItem(
                                value: UserFilterType.all,
                                child: Text('All Users'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Users List Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${_filteredUsers.length} Users',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh),
                        onPressed: _fetchUsers,
                        tooltip: 'Refresh',
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Users List
                  if (_filteredUsers.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                          'No users found',
                          style: GoogleFonts.inter(
                            color: Colors.grey,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    )
                  else if (isWideScreen)
                    // Web: Table-like layout
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        children: [
                          // Header
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                            ),
                            child: Row(
                              children: [
                                const SizedBox(width: 56), // Avatar space
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    'Name',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    'Email',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 1,
                                  child: Text(
                                    'Joined',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 80), // Status space
                              ],
                            ),
                          ),
                          // User Rows
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _filteredUsers.length,
                            separatorBuilder: (context, index) => Divider(
                              height: 1,
                              color: Colors.grey.shade200,
                            ),
                            itemBuilder: (context, index) {
                              final user = _filteredUsers[index];
                              return InkWell(
                                onTap: () async {
                                  try {
                                    PlayerProfile? userProfile;
                                    if (user.playerId != null && user.playerId!.isNotEmpty) {
                                      userProfile = await _supabaseService.getPlayerProfile(user.playerId!);
                                    }
                                    userProfile ??= user;
                                    if (mounted) {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => UserDetailScreen(user: userProfile!),
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    if (mounted) {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => UserDetailScreen(user: user),
                                        ),
                                      );
                                    }
                                  }
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 20,
                                        backgroundImage: user.profilePicture.isNotEmpty
                                            ? CachedNetworkImageProvider(user.profilePicture)
                                            : null,
                                        child: user.profilePicture.isEmpty
                                            ? Text(user.name.isNotEmpty ? user.name[0].toUpperCase() : '?')
                                            : null,
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          user.name,
                                          style: GoogleFonts.inter(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          user.email,
                                          style: GoogleFonts.inter(
                                            fontSize: 14,
                                            color: Colors.grey.shade700,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Expanded(
                                        flex: 1,
                                        child: Text(
                                          _formatDate(user.joined),
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ),
                                      SizedBox(
                                        width: _isFakeUser(user) ? 120 : 80,
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.end,
                                          children: [
                                            if (_isFakeUser(user))
                                              IconButton(
                                                icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                                                onPressed: () => _deleteFakeUser(user),
                                                tooltip: 'Delete fake user',
                                                padding: EdgeInsets.zero,
                                                constraints: const BoxConstraints(),
                                              ),
                                            if (_isFakeUser(user)) const SizedBox(width: 8),
                                            Icon(
                                              user.verifiedEmail ? Icons.verified : Icons.pending,
                                              color: user.verifiedEmail ? Colors.green : Colors.orange,
                                              size: 18,
                                            ),
                                            const SizedBox(width: 8),
                                            Icon(
                                              Icons.chevron_right,
                                              color: Colors.grey.shade400,
                                              size: 20,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    )
                  else
                    // Mobile: Card layout
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _filteredUsers.length,
                      itemBuilder: (context, index) {
                        final user = _filteredUsers[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            onTap: () async {
                              try {
                                PlayerProfile? userProfile;
                                if (user.playerId != null && user.playerId!.isNotEmpty) {
                                  userProfile = await _supabaseService.getPlayerProfile(user.playerId!);
                                }
                                userProfile ??= user;
                                if (mounted) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => UserDetailScreen(user: userProfile!),
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (mounted) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => UserDetailScreen(user: user),
                                    ),
                                  );
                                }
                              }
                            },
                            leading: CircleAvatar(
                              backgroundImage: user.profilePicture.isNotEmpty
                                  ? CachedNetworkImageProvider(user.profilePicture)
                                  : null,
                              child: user.profilePicture.isEmpty
                                  ? Text(user.name.isNotEmpty ? user.name[0].toUpperCase() : '?')
                                  : null,
                            ),
                            title: Text(
                              user.name,
                              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(user.email),
                                if (user.playerId != null)
                                  Text(
                                    'ID: ${user.playerId}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_isFakeUser(user))
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                    onPressed: () => _deleteFakeUser(user),
                                    tooltip: 'Delete fake user',
                                  ),
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Icon(
                                      user.verifiedEmail ? Icons.verified : Icons.pending,
                                      color: user.verifiedEmail ? Colors.green : Colors.orange,
                                      size: 20,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _formatDate(user.joined),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
    );
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays == 0) {
        return 'Today';
      } else if (difference.inDays == 1) {
        return 'Yesterday';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}d ago';
      } else {
        return DateFormat('MMM d').format(date);
      }
    } catch (e) {
      return dateStr;
    }
  }
}

