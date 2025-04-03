import 'dart:ui';
import 'package:flutter/material.dart';

class ScreenUtil {
  static final ScreenUtil _instance = ScreenUtil._();
  static ScreenUtil get instance => _instance;

  // Design size (baseline for calculations)
  late double _designWidth;
  late double _designHeight;

  // Screen information
  late double _screenWidth;
  late double _screenHeight;
  late double _pixelRatio;
  late double _statusBarHeight;
  late double _bottomBarHeight;
  late double _textScaleFactor;

  // Orientation
  late Orientation _orientation;

  // Singleton constructor
  ScreenUtil._();

  // Initialize with design size (usually your Figma/design specs)
  void init(BuildContext context,
      {double designWidth = 375, double designHeight = 812}) {
    _designWidth = designWidth;
    _designHeight = designHeight;

    MediaQueryData mediaQuery = MediaQuery.of(context);
    _pixelRatio = mediaQuery.devicePixelRatio;
    _screenWidth = mediaQuery.size.width;
    _screenHeight = mediaQuery.size.height;
    _statusBarHeight = mediaQuery.padding.top;
    _bottomBarHeight = mediaQuery.padding.bottom;
    _textScaleFactor = mediaQuery.textScaleFactor;
    _orientation = mediaQuery.orientation;
  }

  // Check if initialized
  bool get isInitialized => _designWidth != null && _designHeight != null;

  // Get screen width
  double get screenWidth => _screenWidth;

  // Get screen height
  double get screenHeight => _screenHeight;

  // Get pixel ratio
  double get pixelRatio => _pixelRatio;

  // Get status bar height
  double get statusBarHeight => _statusBarHeight;

  // Get bottom bar height
  double get bottomBarHeight => _bottomBarHeight;

  // Get orientation
  Orientation get orientation => _orientation;

  // Scale width based on design width
  double setWidth(double width) {
    return width * _screenWidth / _designWidth;
  }

  // Scale height based on design height
  double setHeight(double height) {
    return height * _screenHeight / _designHeight;
  }

  // Set responsive font size
  double setSp(double fontSize) {
    // Scale font size based on ratio of design width and actual width
    // with additional adjustment for pixel ratio and text scale factor
    double scaledSize = fontSize * _screenWidth / _designWidth;

    // Apply constraints to prevent text from becoming too small or too large
    return scaledSize.clamp(fontSize * 0.8, fontSize * 1.2);
  }

  // Set responsive radius
  double setRadius(double radius) {
    return radius * _screenWidth / _designWidth;
  }

  // Get responsive size (for both width and height)
  double get scale => _screenWidth / _designWidth;

  // Get adaptive size based on orientation
  double adaptive(double size) {
    return _orientation == Orientation.portrait
        ? setWidth(size)
        : setHeight(size);
  }

  // Get proportionally scaled size based on screen width
  double wp(double percentage) {
    return _screenWidth * percentage / 100;
  }

  // Get proportionally scaled size based on screen height
  double hp(double percentage) {
    return _screenHeight * percentage / 100;
  }

  // Calculate if current device is a tablet
  bool get isTablet => _screenWidth >= 600;

  // Calculate if current device is a phone
  bool get isPhone => _screenWidth < 600;

  // Prevent text overflow by fitting text to available width
  String fitText(String text, TextStyle style, double maxWidth) {
    final TextPainter textPainter = TextPainter(
      text: TextSpan(text: text, style: style),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout(minWidth: 0, maxWidth: double.infinity);

    if (textPainter.width <= maxWidth) {
      return text;
    }

    // If text overflows, reduce it with ellipsis
    int endIndex = text.length;
    final String ellipsis = '...';

    do {
      endIndex--;
      final String truncatedText = text.substring(0, endIndex) + ellipsis;
      textPainter.text = TextSpan(text: truncatedText, style: style);
      textPainter.layout(minWidth: 0, maxWidth: double.infinity);
    } while (textPainter.width > maxWidth && endIndex > 0);

    return text.substring(0, endIndex) + ellipsis;
  }

  // Get safe block horizontal (accounting for notches and cutouts)
  double get safeBlockHorizontal => _screenWidth / 100;

  // Get safe block vertical (accounting for status bar and bottom bar)
  double get safeBlockVertical =>
      (_screenHeight - _statusBarHeight - _bottomBarHeight) / 100;
}

// Extension methods for easier usage
extension SizeExtension on num {
  // Get scaled width
  double get w => ScreenUtil.instance.setWidth(this.toDouble());

  // Get scaled height
  double get h => ScreenUtil.instance.setHeight(this.toDouble());

  // Get scaled font size
  double get sp => ScreenUtil.instance.setSp(this.toDouble());

  // Get scaled radius
  double get r => ScreenUtil.instance.setRadius(this.toDouble());

  // Get percentage of screen width
  double get wp => ScreenUtil.instance.wp(this.toDouble());

  // Get percentage of screen height
  double get hp => ScreenUtil.instance.hp(this.toDouble());
}

// Widget to initialize ScreenUtil
class ScreenUtilInit extends StatelessWidget {
  final Widget Function(BuildContext context, Widget? child) builder;
  final Widget? child;
  final double designWidth;
  final double designHeight;

  const ScreenUtilInit({
    Key? key,
    required this.builder,
    this.child,
    this.designWidth = 375,
    this.designHeight = 812,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    ScreenUtil.instance.init(
      context,
      designWidth: designWidth,
      designHeight: designHeight,
    );
    return builder(context, child);
  }
}
