import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Hermes暗黑主题 — 灯泡伴侣唯一视觉语言
///
/// 设计原则:
/// - 深色背景不是纯黑(0xFF0A0E14), 带微蓝色调以缓解眼睛疲劳
/// - 状态色语义: 绿=健康·黄=降级·红=离线·蓝=信息
/// - 不引入花哨渐变·保持工业级冷静
class HermesTheme {
  HermesTheme._();

  // ── 品牌色 ──

  /// 主色调: 灯泡暖黄
  static const Color lampYellow = Color(0xFFFFB300);

  /// 强调色: Hermes蓝
  static const Color hermesBlue = Color(0xFF4FC3F7);

  /// 背景: 深灰蓝
  static const Color background = Color(0xFF0A0E14);

  /// 卡片/面板背景
  static const Color surface = Color(0xFF161B22);

  /// 卡片边框
  static const Color border = Color(0xFF30363D);

  /// 文字主色
  static const Color textPrimary = Color(0xFFE6EDF3);

  /// 文字次要
  static const Color textSecondary = Color(0xFF8B949E);

  // ── 状态色 ──

  /// 健康 / 在线
  static const Color statusGreen = Color(0xFF3FB950);

  /// 降级 / 警告
  static const Color statusYellow = Color(0xFFD29922);

  /// 离线 / 故障
  static const Color statusRed = Color(0xFFF85149);

  /// 信息 / 未知
  static const Color statusBlue = Color(0xFF4FC3F7);

  /// 离线闪烁背景 (用于红色脉冲动画的暗底色)
  static const Color statusRedBg = Color(0x20F85149);

  // ── 主题数据 ──

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: lampYellow,
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.dark(
        primary: lampYellow,
        secondary: hermesBlue,
        surface: surface,
        error: statusRed,
        onPrimary: Colors.black,
        onSecondary: Colors.black,
        onSurface: textPrimary,
        onError: Colors.white,
      ),

      // 卡片
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: border, width: 0.5),
        ),
        margin: EdgeInsets.zero,
      ),

      // AppBar
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.notoSansSc(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: const IconThemeData(color: textSecondary),
      ),

      // 底部导航
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: lampYellow,
        unselectedItemColor: textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),

      // 文字层级
      textTheme: GoogleFonts.notoSansScTextTheme().copyWith(
        displayLarge: GoogleFonts.notoSansSc(
          color: textPrimary,
          fontSize: 32,
          fontWeight: FontWeight.bold,
        ),
        titleLarge: GoogleFonts.notoSansSc(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: GoogleFonts.notoSansSc(
          color: textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        bodyLarge: GoogleFonts.notoSansSc(
          color: textPrimary,
          fontSize: 14,
        ),
        bodyMedium: GoogleFonts.notoSansSc(
          color: textSecondary,
          fontSize: 13,
        ),
        labelSmall: GoogleFonts.notoSansSc(
          color: textSecondary,
          fontSize: 11,
        ),
      ),

      // 分割线
      dividerTheme: const DividerThemeData(
        color: border,
        thickness: 0.5,
        space: 0,
      ),

      // 输入框
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: const BorderSide(color: lampYellow, width: 1.5),
        ),
        hintStyle: GoogleFonts.notoSansSc(
          color: textSecondary,
          fontSize: 14,
        ),
      ),
    );
  }
}
