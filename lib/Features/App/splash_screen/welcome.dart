import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import '../User_auth/presentation/Pages/login_page.dart';
import '../User_auth/util/screen_util.dart';

class welcome extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.green,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        scaffoldBackgroundColor: Colors.white,
      ),
      home: ScreenUtilInit(
        designWidth: 375,
        designHeight: 812,
        builder: (context, child) => OnboardingScreen(),
      ),
    );
  }
}

class OnboardingScreen extends StatefulWidget {
  @override
  _OnboardingScreenState createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  List<Map<String, String>> onboardingData = [
    {
      "title": "Turn Waste into Worth",
      "description":
          "Start your journey towards a sustainable future with our innovative recycling solutions.",
      "gif": "images/recycle.gif",
    },
    {
      "title": "Smart Pickup Service",
      "description":
          "Schedule waste collection that adapts to your lifestyle with AI-powered optimization.",
      "gif": "images/map.gif",
    },
    {
      "title": "Eco-Friendly Navigation",
      "description":
          "Find the nearest recycling points with our intelligent mapping system.",
      "gif": "images/navigation.gif",
    },
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _navigateToLogin() {
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => LoginPage(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        transitionDuration: Duration(milliseconds: 800),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background Design
          Positioned.fill(
            child: CustomPaint(
              painter: BackgroundPainter(
                color: Colors.green.shade50,
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // App Name
                Padding(
                  padding: EdgeInsets.only(top: 20.h, left: 20.w),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'WasteWisePro',
                      style: GoogleFonts.poppins(
                        fontSize: 24.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade800,
                      ),
                    ).animate().fadeIn().slideX(),
                  ),
                ),

                // Skip Button
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: EdgeInsets.only(right: 20.w, top: 20.h),
                    child: TextButton(
                      onPressed: _navigateToLogin,
                      child: Text(
                        'Skip',
                        style: GoogleFonts.poppins(
                          color: Colors.green.shade600,
                          fontWeight: FontWeight.w600,
                          fontSize: 14.sp,
                        ),
                      ),
                    ),
                  ).animate().fadeIn().slideX(),
                ),

                // Main Content
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: (value) {
                      setState(() {
                        _currentPage = value;
                      });
                    },
                    itemCount: onboardingData.length,
                    itemBuilder: (context, index) => OnboardingContent(
                      title: onboardingData[index]["title"]!,
                      description: onboardingData[index]["description"]!,
                      gif: onboardingData[index]["gif"]!,
                    ),
                  ),
                ),

                // Page Indicator
                Padding(
                  padding: EdgeInsets.only(bottom: 30.h),
                  child: SmoothPageIndicator(
                    controller: _pageController,
                    count: onboardingData.length,
                    effect: ExpandingDotsEffect(
                      dotHeight: 8.h,
                      dotWidth: 8.w,
                      activeDotColor: Colors.green.shade800,
                      dotColor: Colors.green.shade200,
                    ),
                  ),
                ),

                // Navigation Buttons
                Padding(
                  padding:
                      EdgeInsets.only(bottom: 40.h, left: 20.w, right: 20.w),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (_currentPage > 0)
                        _buildButton(
                          onPressed: () {
                            _pageController.previousPage(
                              duration: Duration(milliseconds: 600),
                              curve: Curves.easeInOutCubic,
                            );
                          },
                          text: "Previous",
                          isOutlined: true,
                        )
                      else
                        SizedBox(width: 100.w),
                      _buildButton(
                        onPressed: () {
                          if (_currentPage == onboardingData.length - 1) {
                            _navigateToLogin();
                          } else {
                            _pageController.nextPage(
                              duration: Duration(milliseconds: 600),
                              curve: Curves.easeInOutCubic,
                            );
                          }
                        },
                        text: _currentPage == onboardingData.length - 1
                            ? "Get Started"
                            : "Next",
                        isOutlined: false,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildButton({
    required VoidCallback onPressed,
    required String text,
    required bool isOutlined,
  }) {
    return Container(
      height: 50.h,
      decoration: BoxDecoration(
        gradient: isOutlined
            ? null
            : LinearGradient(
                colors: [Colors.green.shade400, Colors.green.shade600],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        borderRadius: BorderRadius.circular(25.r),
        boxShadow: isOutlined
            ? []
            : [
                BoxShadow(
                  color: Colors.green.withOpacity(0.3),
                  blurRadius: 8,
                  offset: Offset(0, 4),
                ),
              ],
        border: isOutlined
            ? Border.all(color: Colors.green.shade600, width: 2)
            : null,
      ),
      child: MaterialButton(
        onPressed: onPressed,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(25.r),
        ),
        padding: EdgeInsets.symmetric(horizontal: 32.w),
        child: Text(
          text,
          style: GoogleFonts.poppins(
            color: isOutlined ? Colors.green.shade600 : Colors.white,
            fontSize: 16.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    )
        .animate(onPlay: (controller) => controller.repeat())
        .shimmer(duration: Duration(seconds: 3), color: Colors.white24);
  }
}

class OnboardingContent extends StatelessWidget {
  final String title, description, gif;

  const OnboardingContent({
    Key? key,
    required this.title,
    required this.description,
    required this.gif,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(20.w),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            height: 300.h,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20.r),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20.r),
              child: Image.asset(
                gif,
                fit: BoxFit.cover,
              ),
            ),
          )
              .animate()
              .fadeIn(duration: Duration(milliseconds: 600))
              .scale(delay: 200.ms),
          SizedBox(height: 40.h),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 24.sp,
              fontWeight: FontWeight.bold,
              color: Colors.green.shade800,
            ),
          )
              .animate()
              .fadeIn(duration: Duration(milliseconds: 600))
              .slideY(begin: 0.3, end: 0),
          SizedBox(height: 16.h),
          Text(
            description,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 14.sp,
              color: Colors.grey[600],
              height: 1.4,
            ),
          )
              .animate()
              .fadeIn(duration: Duration(milliseconds: 800))
              .slideY(begin: 0.3, end: 0),
        ],
      ),
    );
  }
}

class BackgroundPainter extends CustomPainter {
  final Color color;

  BackgroundPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width * 0.8, 0)
      ..quadraticBezierTo(
        size.width,
        size.height * 0.2,
        size.width * 0.8,
        size.height * 0.4,
      )
      ..quadraticBezierTo(
        size.width * 0.6,
        size.height * 0.6,
        size.width * 0.8,
        size.height * 0.8,
      )
      ..quadraticBezierTo(
        size.width,
        size.height,
        size.width * 0.8,
        size.height,
      )
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(BackgroundPainter oldDelegate) => false;
}
