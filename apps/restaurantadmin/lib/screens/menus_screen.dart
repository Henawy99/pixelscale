import 'package:flutter/material.dart';
import 'package:restaurantadmin/widgets/category_card.dart';
import 'package:restaurantadmin/screens/brand_menu_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive/hive.dart';
import 'package:restaurantadmin/models/brand.dart';
import 'package:restaurantadmin/widgets/delivery_links_settings_dialog.dart';

class MenusScreen extends StatefulWidget {
  const MenusScreen({super.key});

  @override
  State<MenusScreen> createState() => _MenusScreenState();
}

class _MenusScreenState extends State<MenusScreen> with TickerProviderStateMixin {
  final SupabaseClient _supabase = Supabase.instance.client;
  List<Brand> _brands = [];
  bool _isLoading = true;
  String? _error;

  late Box<Brand> _brandsBox;
  late Box _appSettingsBox;
  final String _brandsCacheKey = 'all_brands_cache'; // Box name for all brands
  final String _brandsTimestampKey = 'all_brands_timestamp';
  final Duration _cacheDuration = const Duration(hours: 1); // Cache brands for 1 hour

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeOut));
    
    _initHiveAndFetchBrands();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _initHiveAndFetchBrands() async {
    _appSettingsBox = Hive.box('app_settings'); // Opened in main.dart
    _brandsBox = await Hive.openBox<Brand>(_brandsCacheKey);
    await _fetchBrands(forceRefresh: false);
  }

  Future<void> _fetchBrands({bool forceRefresh = false}) async {
    if (!forceRefresh && _brandsBox.isNotEmpty) {
      final int? lastFetchMillis = _appSettingsBox.get(_brandsTimestampKey) as int?;
      if (lastFetchMillis != null) {
        final lastFetchTime = DateTime.fromMillisecondsSinceEpoch(lastFetchMillis);
        if (DateTime.now().difference(lastFetchTime) < _cacheDuration) {
          if (mounted) {
            setState(() {
              _brands = _brandsBox.values.toList();
              _isLoading = false;
              _error = null;
            });
            _animationController.forward();
          }
          print('Loaded brands from Hive cache.');
          return;
        }
      }
    }

    if (mounted) setState(() { _isLoading = true; _error = null; });

    try {
      print('Fetching brands from Supabase for Hive update...');
      final response = await _supabase
          .from('brands')
          .select()
          .order('name', ascending: true);

      final List<Brand> newBrands = (response as List)
          .map((data) => Brand.fromJson(data as Map<String, dynamic>))
          .toList();

      await _brandsBox.clear();
      Map<String, Brand> brandsToCache = { for (var brand in newBrands) brand.id : brand };
      await _brandsBox.putAll(brandsToCache);
      await _appSettingsBox.put(_brandsTimestampKey, DateTime.now().millisecondsSinceEpoch);

      if (mounted) {
        setState(() {
          _brands = newBrands;
          _isLoading = false;
        });
        _animationController.forward();
      }
    } catch (e) {
      print('[MenusScreen] Error fetching brands: $e');
      if (mounted) {
        // Try to load from cache if network fails but cache exists
        if (_brandsBox.isNotEmpty) {
           setState(() {
            _brands = _brandsBox.values.toList();
            _isLoading = false;
            _error = 'Failed to fetch latest brands. Displaying cached data. Error: $e';
          });
          _showWarningSnackBar(_error!);
          _animationController.forward();
        } else {
          setState(() {
            _error = 'Failed to load brands: $e';
            _isLoading = false;
          });
        }
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _showWarningSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.orange[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
                      children: [
            const Icon(Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [Colors.purple[600]!, Colors.purple[400]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
                      ],
                    ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.restaurant_menu,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Restaurant Menus',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_brands.length} ${_brands.length == 1 ? 'brand' : 'brands'} available',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  int _getCrossAxisCount(double screenWidth) {
    if (screenWidth > 1200) return 5;  // Large desktop
    if (screenWidth > 900) return 4;   // Desktop
    if (screenWidth > 600) return 3;   // Tablet
    return 2;                          // Mobile
  }

  double _getChildAspectRatio(double screenWidth) {
    if (screenWidth > 600) return 1.1;  // Web/Tablet - more square
    return 0.9;                         // Mobile - slightly taller
  }

  Widget _buildBrandsGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = _getCrossAxisCount(constraints.maxWidth);
        final childAspectRatio = _getChildAspectRatio(constraints.maxWidth);
        
        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: childAspectRatio,
                          ),
                          itemCount: _brands.length,
                          itemBuilder: (context, index) {
                            final brand = _brands[index];
            return FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.2),
                  end: Offset.zero,
                ).animate(CurvedAnimation(
                  parent: _animationController,
                  curve: Interval(
                    (index * 0.05).clamp(0.0, 1.0),
                    ((index * 0.05) + 0.3).clamp(0.0, 1.0),
                    curve: Curves.easeOut,
                  ),
                )),
                child: CategoryCard(
                  categoryName: brand.name,
                  imageUrl: brand.imageUrl,
                  isNetworkImage: brand.imageUrl != null && brand.imageUrl!.startsWith('http'),
                  ratings: {
                    'Lief': brand.lieferandoRating,
                    'Foodora': brand.foodoraRating,
                    'Wolt': brand.woltRating,
                    'Google': brand.googleRating,
                  },
                  onSettingsTap: () {
                    showDialog(
                      context: context,
                      builder: (context) => DeliveryLinksSettingsDialog(
                        brand: brand,
                        onSave: (updatedBrand) async {
                          await _supabase.from('brands').update(updatedBrand.toJson()).eq('id', updatedBrand.id);
                          await _fetchBrands(forceRefresh: true);
                        },
                      ),
                    );
                  },
                  onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => BrandMenuScreen(
                                      brandId: brand.id,
                                      brandName: brand.name,
                        ),
                      ),
                    );
                  },
                                    ),
                                  ),
                                );
                              },
                            );
                          },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.restaurant_menu, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 24),
          Text(
            'No Restaurant Brands',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'No brands found. Pull down to refresh\nor contact support to add new brands.',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.purple[600]!, Colors.purple[400]!],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.purple.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _fetchBrands(forceRefresh: true),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.refresh, color: Colors.white, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Refresh Brands',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[400]),
            const SizedBox(height: 20),
            Text(
              'Oops! Something went wrong',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _error ?? 'Unknown error occurred',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.red[600]!, Colors.red[400]!],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _fetchBrands(forceRefresh: true),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.refresh, color: Colors.white, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Try Again',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const CircularProgressIndicator(),
          ),
          const SizedBox(height: 24),
          Text(
            'Loading restaurant brands...',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: _isLoading
              ? _buildLoadingState()
              : _error != null && _brands.isEmpty
                  ? _buildErrorState()
                  : RefreshIndicator(
                      onRefresh: () async {
                        await _fetchBrands(forceRefresh: true);
                        if (_error == null) {
                          _showSuccessSnackBar('Brands refreshed successfully!');
                        }
                      },
                      color: Colors.purple,
                      child: _brands.isEmpty
                          ? _buildEmptyState()
                          : Column(
                              children: [
                                _buildHeader(),
                                Expanded(child: _buildBrandsGrid()),
                              ],
                            ),
                    ),
        ),
      ),
    );
  }
}
              