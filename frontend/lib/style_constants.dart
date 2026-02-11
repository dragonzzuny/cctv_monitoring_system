import 'package:flutter/material.dart';

class AppColors {
  // Premium Dark Theme Palette
  static const Color background = Color(0xFF0F172A);
  static const Color surface = Color(0xFF1E293B);
  static const Color cardBg = Color(0xFF334155);
  
  static const Color primary = Color(0xFF38BDF8); // Sky Blue
  static const Color secondary = Color(0xFF818CF8); // Indigo
  static const Color accent = Color(0xFFF472B6); // Pink
  
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFFBBF24);
  static const Color danger = Color(0xFFEF4444);
  static const Color info = Color(0xFF0EA5E9);
  
  static const Color textMain = Color(0xFFF8FAFC);
  static const Color textDim = Color(0xFF94A3B8);
  
  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF38BDF8), Color(0xFF818CF8)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient glassGradient = LinearGradient(
    colors: [
      Color(0x33FFFFFF),
      Color(0x0AFFFFFF),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class AppStyles {
  static BoxDecoration glassDecoration({
    double borderRadius = 16.0,
    double opacity = 0.1,
    Color? color,
  }) {
    return BoxDecoration(
      color: (color ?? Colors.white).withOpacity(opacity),
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: Colors.white.withOpacity(0.1),
        width: 1.5,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.2),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  static TextStyle heading = const TextStyle(
    color: AppColors.textMain,
    fontSize: 24,
    fontWeight: FontWeight.bold,
    letterSpacing: -0.5,
  );

  static TextStyle body = const TextStyle(
    color: AppColors.textDim,
    fontSize: 14,
  );

  static TextStyle cardTitle = const TextStyle(
    color: AppColors.textMain,
    fontSize: 16,
    fontWeight: FontWeight.w600,
  );
}
