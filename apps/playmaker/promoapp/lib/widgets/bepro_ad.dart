import 'package:flutter/material.dart';

class BeproAd extends StatefulWidget {
  const BeproAd({super.key});

  @override
  State<BeproAd> createState() => _BeproAdState();
}

class _BeproAdState extends State<BeproAd> with SingleTickerProviderStateMixin {
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
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.white,
        child: Center(
          child: Image.asset(
            'assets/images/beprologo.png',
            width: 400,
            height: 400,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => Container(
              width: 300,
              height: 150,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Center(
                child: Text(
                  'BePro',
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
