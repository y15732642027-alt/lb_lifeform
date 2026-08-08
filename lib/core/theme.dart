import 'package:flutter/material.dart';

/// 共生体美学 · 黑金配色
/// Hermes Companion 商业版视觉规范
class HermesTheme {
  // 基础
  static const bg = Color(0xFF050505);          // 纯黑底
  static const surface = Color(0xFF0d0d0d);     // 卡片黑
  static const surfaceLight = Color(0xFF1a1a1a);// 悬浮黑
  
  // 文字
  static const textPrimary = Color(0xFFf0ede5); // 暖白
  static const textSecondary = Color(0xFF8b8578);// 暗金灰
  static const textMuted = Color(0xFF4a4540);   // 深金灰
  
  // 主题色
  static const gold = Color(0xFFd4a853);        // 暖金·主色
  static const goldLight = Color(0xFFf0d080);   // 亮金·高亮
  static const silver = Color(0xFFc0c0c0);      // 银·辅助
  static const ice = Color(0xFF80d0ff);          // 冰蓝·思考态
  
  // 功能色
  static const success = Color(0xFF5cb878);     // 沉绿
  static const warning = Color(0xFFd4a853);     // 复用金
  static const error = Color(0xFF8b3030);       // 暗红
  static const info = Color(0xFF6078a0);        // 灰蓝

  // 兼容旧引用
  static const lampYellow = gold;
  static const statusGreen = Color(0xFF5cb878);
  static const statusYellow = Color(0xFFd4a853);
  static const statusRed = Color(0xFF8b3030);
  static const statusBlue = Color(0xFF6078a0);
  static const border = Color(0xFF2a2a2a);
  
  // 主题
  static ThemeData get darkTheme => ThemeData(
    scaffoldBackgroundColor: bg,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.dark(
      primary: gold, secondary: silver,
      surface: surface, error: error,
    ),
    appBarTheme: AppBarTheme(color: bg, elevation: 0),
    cardTheme: CardThemeData(color: surface, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
    iconTheme: IconThemeData(color: textSecondary),
    textTheme: TextTheme(
      headlineLarge: TextStyle(color: textPrimary, fontSize: 28, fontWeight: FontWeight.w300, letterSpacing: -0.5),
      headlineMedium: TextStyle(color: textPrimary, fontSize: 22, fontWeight: FontWeight.w300),
      titleLarge: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.w400),
      titleMedium: TextStyle(color: textSecondary, fontSize: 14, fontWeight: FontWeight.w400),
      bodyLarge: TextStyle(color: textPrimary, fontSize: 16),
      bodyMedium: TextStyle(color: textSecondary, fontSize: 14),
      bodySmall: TextStyle(color: textMuted, fontSize: 12),
    ),
  );
}
