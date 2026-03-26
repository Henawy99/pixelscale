import 'package:flutter/material.dart';
import 'package:playmakerappstart/login_screen/login_screen.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

class LandingPage extends StatefulWidget {
  const LandingPage({Key? key}) : super(key: key);

  @override
  _LandingPageState createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> with SingleTickerProviderStateMixin {
  final PageController _controller = PageController();
  bool isLastPage = false;
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
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF00BF63),
      body: Stack(
        children: [
          PageView(
            controller: _controller,
            onPageChanged: (index) {
              setState(() {
                isLastPage = index == 2;
              });
              _animationController.reset();
              _animationController.forward();
            },
            children: [
              buildPage(
                image: 'assets/field_booking.png',
                title: "Look for fields in your area",
                subtitle: "Book and play instantly",
                color: const Color(0xFF00BF63),
                illustration: const Icon(Icons.sports_soccer, size: 120, color: Colors.white),
              ),
              buildPage(
                image: 'assets/squad_formation.png',
                title: "Compete and Form Squads",
                subtitle: "Find and compete with other players, form squads and play against each other",
                color: const Color(0xFF00BF63),
                illustration: const Icon(Icons.group, size: 120, color: Colors.white),
              ),
              buildPage(
                image: 'assets/match_replay.png',
                title: "Watch Your Matches",
                subtitle: "Watch yourself play by viewing your recorded matches",
                color: const Color(0xFF00BF63),
                illustration: const Icon(Icons.sports_score, size: 120, color: Colors.white),
              ),
            ],
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: isLastPage
              ? Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Color(0xFF00BF63),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    onPressed: () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (context) => const LoginWithPasswordScreen(),
                        ),
                      );
                    },
                    child: const Text(
                      'Get Started',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                )
              : Container(
                  height: 160,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withOpacity(0.8),
                        Colors.transparent,
                      ],
                    ),
                  ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (!isLastPage)
                          TextButton(
                            onPressed: () => _controller.jumpToPage(2),
                            child: const Text(
                              'Skip',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          )
                        else
                          const SizedBox(width: 80),
                        Center(
                          child: SmoothPageIndicator(
                            controller: _controller,
                            count: 3,
                            effect: const WormEffect(
                              dotHeight: 10,
                              dotWidth: 10,
                              activeDotColor: Colors.white,
                              dotColor: Colors.white54,
                            ),
                            onDotClicked: (index) => _controller.animateToPage(
                              index,
                              duration: const Duration(milliseconds: 500),
                              curve: Curves.easeInOut,
                            ),
                          ),
                        ),
                        if (!isLastPage)
                          TextButton(
                            onPressed: () => _controller.nextPage(
                              duration: const Duration(milliseconds: 500),
                              curve: Curves.easeInOut,
                            ),
                            child: const Text(
                              'Next',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          )
                        else
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00BF63),
                              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                            onPressed: () {
                              Navigator.of(context).pushReplacement(
                                MaterialPageRoute(
                                  builder: (context) => const LoginWithPasswordScreen(),
                                ),
                              );
                            },
                            child: const Text(
                              'Get Started',
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildPage({
    required String image,
    required String title,
    required String subtitle,
    required Color color,
    required Widget illustration,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: color,
      ),
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Placeholder for screenshot/illustration
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              height: 300,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // You would replace this with actual images
                    illustration,
                  ],
                ),
              ),
            ),
            const SizedBox(height: 40),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Column(
                children: [
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 18,
                      height: 1.5,
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