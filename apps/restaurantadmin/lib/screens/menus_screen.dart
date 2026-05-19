import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
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

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

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
          return;
        }
      }
    }

    if (mounted) setState(() { _isLoading = true; _error = null; });

    try {
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
        if (_brandsBox.isNotEmpty) {
           setState(() {
            _brands = _brandsBox.values.toList();
            _isLoading = false;
            _error = 'Failed to fetch latest brands. Displaying cached data.';
          });
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

  // ───────────────────────────────────────
  // Platform Logo Helper
  // ───────────────────────────────────────

  static const Map<String, _PlatformInfo> _platformData = {
    'lieferando': _PlatformInfo(
      name: 'Lieferando',
      logoUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/b/b3/Lieferando_Logo_2020.svg/1200px-Lieferando_Logo_2020.svg.png',
      color: Color(0xFFFF8000),
    ),
    'foodora': _PlatformInfo(
      name: 'Foodora',
      logoUrl: 'https://images.ctfassets.net/23u853certza/2dNnEqRp2b0ibOpFNBPkqo/37e49b0119d9be0fba1de6acba29b105/foodora-icon.png',
      color: Color(0xFFD70F64),
    ),
    'foodora_self': _PlatformInfo(
      name: 'Foodora Self',
      logoUrl: 'https://images.ctfassets.net/23u853certza/2dNnEqRp2b0ibOpFNBPkqo/37e49b0119d9be0fba1de6acba29b105/foodora-icon.png',
      color: Color(0xFFB00D55),
    ),
    'wolt': _PlatformInfo(
      name: 'Wolt',
      logoUrl: 'https://play-lh.googleusercontent.com/FG5DmtfCUZKg_p4ql5WfmWuIAHPkKAiY-IbEHAW77o0TtVV8nDAWXmKmCfqamUjDN2Y',
      color: Color(0xFF009DE0),
    ),
    'google': _PlatformInfo(
      name: 'Google',
      logoUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/768px-Google_%22G%22_logo.svg.png',
      color: Color(0xFF4285F4),
    ),
  };

  // ───────────────────────────────────────
  // UI Components
  // ───────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [Colors.purple[700]!, Colors.purple[400]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withAlpha(60),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(40),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.restaurant_menu, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Restaurant Brands',
                  style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_brands.length} ${_brands.length == 1 ? 'brand' : 'brands'} • Ratings scraped daily',
                  style: TextStyle(color: Colors.white.withAlpha(180), fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingChip(String platformKey, double? rating, int? reviewCount) {
    if (rating == null) return const SizedBox.shrink();

    final info = _platformData[platformKey];
    if (info == null) return const SizedBox.shrink();

    final isLow = rating < 4.0;
    final chipColor = isLow ? Colors.red[50]! : Colors.green[50]!;
    final borderColor = isLow ? Colors.red[300]! : Colors.green[300]!;
    final ratingColor = isLow ? Colors.red[700]! : Colors.green[700]!;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: chipColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Platform logo
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: CachedNetworkImage(
              imageUrl: info.logoUrl,
              width: 18,
              height: 18,
              fit: BoxFit.contain,
              placeholder: (_, __) => Container(
                width: 18, height: 18,
                decoration: BoxDecoration(
                  color: info.color.withAlpha(40),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Center(
                  child: Text(info.name[0], style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: info.color)),
                ),
              ),
              errorWidget: (_, __, ___) => Container(
                width: 18, height: 18,
                decoration: BoxDecoration(
                  color: info.color.withAlpha(40),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Center(
                  child: Text(info.name[0], style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: info.color)),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          // Star icon + rating
          Icon(Icons.star_rounded, size: 14, color: isLow ? Colors.red[400] : Colors.amber[600]),
          const SizedBox(width: 2),
          Text(
            rating.toStringAsFixed(1),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: ratingColor,
            ),
          ),
          // Review count
          if (reviewCount != null) ...[
            const SizedBox(width: 4),
            Text(
              '($reviewCount)',
              style: TextStyle(fontSize: 10, color: Colors.grey[500]),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBrandCard(Brand brand, int index) {
    // Collect all ratings for this brand
    final ratings = <String, ({double? rating, int? reviewCount})>{
      'lieferando': (rating: brand.lieferandoRating, reviewCount: brand.lieferandoReviewCount),
      'foodora': (rating: brand.foodoraRating, reviewCount: brand.foodoraReviewCount),
      'foodora_self': (rating: brand.foodoraSelfRating, reviewCount: brand.foodoraSelfReviewCount),
      'wolt': (rating: brand.woltRating, reviewCount: brand.woltReviewCount),
      'google': (rating: brand.googleRating, reviewCount: brand.googleReviewCount),
    };

    final hasAnyRating = ratings.values.any((r) => r.rating != null);
    final hasLowRating = ratings.values.any((r) => r.rating != null && r.rating! < 4.0);

    // Brand image
    Widget imageWidget;
    if (brand.imageUrl != null && brand.imageUrl!.isNotEmpty && brand.imageUrl!.startsWith('http')) {
      imageWidget = CachedNetworkImage(
        imageUrl: brand.imageUrl!,
        fit: BoxFit.cover,
        placeholder: (_, __) => Container(
          color: Colors.grey[100],
          child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
        errorWidget: (_, __, ___) => Container(
          color: Colors.grey[200],
          child: Icon(Icons.restaurant, size: 40, color: Colors.grey[400]),
        ),
      );
    } else {
      imageWidget = Container(
        color: Colors.grey[100],
        child: Center(
          child: Icon(Icons.restaurant, size: 40, color: Colors.grey[400]),
        ),
      );
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          final delay = (index * 0.08).clamp(0.0, 0.6);
          final end = (delay + 0.4).clamp(0.0, 1.0);
          final progress = Curves.easeOut.transform(
            (((_animationController.value - delay) / (end - delay)).clamp(0.0, 1.0)),
          );
          return Transform.translate(
            offset: Offset(0, 20 * (1 - progress)),
            child: Opacity(opacity: progress, child: child),
          );
        },
        child: GestureDetector(
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
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: hasLowRating
                      ? Colors.red.withAlpha(30)
                      : Colors.black.withAlpha(15),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
              border: hasLowRating
                  ? Border.all(color: Colors.red[200]!, width: 1.5)
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Brand image
                Expanded(
                  flex: 3,
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                        child: SizedBox.expand(child: imageWidget),
                      ),
                      // Settings button
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Material(
                          color: Colors.black.withAlpha(90),
                          borderRadius: BorderRadius.circular(8),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () {
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
                            child: const Padding(
                              padding: EdgeInsets.all(6),
                              child: Icon(Icons.tune_rounded, color: Colors.white, size: 16),
                            ),
                          ),
                        ),
                      ),
                      // Low rating warning badge
                      if (hasLowRating)
                        Positioned(
                          top: 6,
                          left: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.red[600],
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.warning_rounded, color: Colors.white, size: 12),
                                SizedBox(width: 3),
                                Text('Low', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                      // Brand name overlay
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.black.withAlpha(160), Colors.transparent],
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                            ),
                          ),
                          child: Text(
                            brand.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              shadows: [Shadow(offset: Offset(0, 1), blurRadius: 3, color: Colors.black54)],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Ratings section
                if (hasAnyRating)
                  Expanded(
                    flex: 2,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
                      child: SingleChildScrollView(
                        child: Wrap(
                          spacing: 4,
                          runSpacing: 2,
                          children: ratings.entries
                              .where((e) => e.value.rating != null)
                              .map((e) => _buildRatingChip(e.key, e.value.rating, e.value.reviewCount))
                              .toList(),
                        ),
                      ),
                    ),
                  ),

                if (!hasAnyRating)
                  Expanded(
                    flex: 2,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(
                          'No ratings yet\nTap ⚙ to add URLs',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBrandsGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount;
        double childAspectRatio;
        if (constraints.maxWidth > 1200) {
          crossAxisCount = 5;
          childAspectRatio = 0.7;
        } else if (constraints.maxWidth > 900) {
          crossAxisCount = 4;
          childAspectRatio = 0.7;
        } else if (constraints.maxWidth > 600) {
          crossAxisCount = 3;
          childAspectRatio = 0.72;
        } else {
          crossAxisCount = 2;
          childAspectRatio = 0.68;
        }

        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: childAspectRatio,
          ),
          itemCount: _brands.length,
          itemBuilder: (context, index) => _buildBrandCard(_brands[index], index),
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
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.grey[700]),
          ),
          const SizedBox(height: 12),
          Text(
            'No brands found. Pull down to refresh.',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
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
                BoxShadow(color: Colors.black.withAlpha(20), blurRadius: 8, offset: const Offset(0, 4)),
              ],
            ),
            child: const CircularProgressIndicator(),
          ),
          const SizedBox(height: 24),
          Text('Loading brands...', style: TextStyle(fontSize: 16, color: Colors.grey[600])),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: _isLoading
          ? _buildLoadingState()
          : _error != null && _brands.isEmpty
              ? Center(child: Text(_error!, style: TextStyle(color: Colors.red[600])))
              : RefreshIndicator(
                  onRefresh: () => _fetchBrands(forceRefresh: true),
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
    );
  }
}

// Helper class for platform info
class _PlatformInfo {
  final String name;
  final String logoUrl;
  final Color color;

  const _PlatformInfo({
    required this.name,
    required this.logoUrl,
    required this.color,
  });
}