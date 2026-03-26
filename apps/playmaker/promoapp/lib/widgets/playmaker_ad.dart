import 'package:flutter/material.dart';

class PlaymakerAd extends StatefulWidget {
  const PlaymakerAd({super.key});

  @override
  State<PlaymakerAd> createState() => _PlaymakerAdState();
}

class _PlaymakerAdState extends State<PlaymakerAd> with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeIn),
    );
    
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isLandscape = size.width > size.height;
    
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF00D26A),
              Color(0xFF00BF63),
              Color(0xFF00A855),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: isLandscape 
                ? _buildLandscapeLayout(size)
                : _buildPortraitLayout(size),
          ),
        ),
      ),
    );
  }

  Widget _buildLandscapeLayout(Size size) {
    // Horizontal layout for TV/landscape screens
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Logo
        Container(
          width: 140,
          height: 140,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: Image.asset(
              'assets/images/playmaker_logo.png',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                color: const Color(0xFF00BF63),
                child: const Icon(
                  Icons.sports_soccer,
                  size: 70,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
        
        const SizedBox(width: 60),
        
        // Store badges
        Image.asset(
          'assets/images/store_badges.png',
          height: 120,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => _buildFallbackBadges(),
        ),
      ],
    );
  }

  Widget _buildPortraitLayout(Size size) {
    // Vertical layout for portrait screens
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Logo
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Image.asset(
              'assets/images/playmaker_logo.png',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                color: const Color(0xFF00BF63),
                child: const Icon(
                  Icons.sports_soccer,
                  size: 60,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
        
        const SizedBox(height: 40),
        
        // Store badges
        Image.asset(
          'assets/images/store_badges.png',
          height: 80,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => _buildFallbackBadges(),
        ),
      ],
    );
  }

  Widget _buildFallbackBadges() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildFallbackBadge(Icons.apple, 'App Store'),
        const SizedBox(height: 12),
        _buildFallbackBadge(Icons.shop, 'Google Play'),
      ],
    );
  }

  Widget _buildFallbackBadge(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 22),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
