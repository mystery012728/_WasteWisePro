import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SplashScreen extends StatefulWidget {
  final Widget? child;

  const SplashScreen({
    super.key,
    this.child,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotateAnimation;
  late Animation<Offset> _slideAnimation;
  bool _showSecondaryElements = false;

  @override
  void initState() {
    super.initState();

    // Initialize animations
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.2, 0.7, curve: Curves.elasticOut),
      ),
    );

    _rotateAnimation = Tween<double>(begin: 0.0, end: 2 * 3.14159).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.7, curve: Curves.easeInOutCubic),
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.3, 0.8, curve: Curves.easeOutCubic),
      ),
    );

    // Start the animation sequence
    _animationController.forward();

    // Show secondary elements after delay
    Future.delayed(const Duration(milliseconds: 800), () {
      setState(() => _showSecondaryElements = true);
    });

    // Navigate to next screen after animation
    Future.delayed(const Duration(milliseconds: 3500), () {
      if (mounted && widget.child != null) {
        Navigator.pushAndRemoveUntil(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                widget.child!,
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 800),
          ),
          (route) => false,
        );
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Get screen size for responsive calculations
    final Size screenSize = MediaQuery.of(context).size;
    final double screenWidth = screenSize.width;
    final double screenHeight = screenSize.height;

    // Get device pixel ratio for DPI-aware sizing
    final double pixelRatio = MediaQuery.of(context).devicePixelRatio;

    // Calculate responsive sizes
    final double logoSize = screenWidth * 0.25; // 25% of screen width
    final double welcomeFontSize = screenWidth * 0.06; // 6% of screen width
    final double appNameFontSize = screenWidth * 0.1; // 10% of screen width
    final double progressBarWidth = screenWidth * 0.4; // 40% of screen width

    // Ensure minimum and maximum sizes for better control
    final double finalLogoSize = logoSize.clamp(80.0, 150.0);
    final double finalWelcomeFontSize = welcomeFontSize.clamp(18.0, 28.0);
    final double finalAppNameFontSize = appNameFontSize.clamp(32.0, 56.0);

    // Calculate spacing based on screen height
    final double verticalSpacing = screenHeight * 0.03; // 3% of screen height
    final double mainSpacing = screenHeight * 0.05; // 5% of screen height

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Animated background pattern
          Positioned.fill(
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 1000),
              opacity: _showSecondaryElements ? 0.1 : 0.0,
              child: CustomPaint(
                painter: BackgroundPatternPainter(
                  patternSpacing: (screenWidth / 15).clamp(20.0, 40.0),
                ),
              ),
            ),
          ),

          // Main content
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Animated logo
                AnimatedBuilder(
                  animation: _animationController,
                  builder: (context, child) {
                    return Transform.rotate(
                      angle: _rotateAnimation.value,
                      child: ScaleTransition(
                        scale: _scaleAnimation,
                        child: Container(
                          width: finalLogoSize,
                          height: finalLogoSize,
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.green.withOpacity(0.2),
                                blurRadius: finalLogoSize * 0.15,
                                spreadRadius: finalLogoSize * 0.04,
                              ),
                            ],
                          ),
                          child: Center(
                            child: Image.asset(
                              'icon/img.png', // Replace with your actual image path
                              width: finalLogoSize * 0.5,
                              height: finalLogoSize * 0.5,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),

                SizedBox(height: mainSpacing),

                // Welcome text with slide animation
                SlideTransition(
                  position: _slideAnimation,
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Text(
                      'Welcome to',
                      style: GoogleFonts.poppins(
                        fontSize: finalWelcomeFontSize,
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ),

                SizedBox(height: verticalSpacing),

                // App name with custom styling
                SlideTransition(
                  position: _slideAnimation,
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Text(
                      'WasteWisePro',
                      style: GoogleFonts.poppins(
                        fontSize: finalAppNameFontSize,
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                ),

                SizedBox(height: mainSpacing),

                // Loading indicator
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 500),
                  opacity: _showSecondaryElements ? 1.0 : 0.0,
                  child: SizedBox(
                    width: progressBarWidth,
                    height: 4.0 *
                        pixelRatio /
                        2, // Adjust height based on pixel ratio
                    child: LinearProgressIndicator(
                      backgroundColor: Colors.green.shade100,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.green.shade500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Custom painter for background pattern
class BackgroundPatternPainter extends CustomPainter {
  final double patternSpacing;

  BackgroundPatternPainter({this.patternSpacing = 30.0});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.green.shade100
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    for (double i = 0; i < size.width; i += patternSpacing) {
      for (double j = 0; j < size.height; j += patternSpacing) {
        final path = Path()
          ..moveTo(i, j)
          ..lineTo(i + patternSpacing / 2, j + patternSpacing / 2)
          ..lineTo(i, j + patternSpacing)
          ..lineTo(i - patternSpacing / 2, j + patternSpacing / 2)
          ..close();
        canvas.drawPath(path, paint);
      }
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
