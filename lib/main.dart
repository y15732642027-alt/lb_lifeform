import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'core/api_client.dart';
import 'core/health_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // 锁定竖屏 (V0.1只做手机)
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // 设置状态栏样式 — 白色文字(暗黑主题)
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    ),
  );

  // 初始化核心服务
  final apiClient = ApiClient();
  final healthService = HealthService(apiClient);

  runApp(
    MultiProvider(
      providers: [
        Provider<ApiClient>.value(value: apiClient),
        Provider<HealthService>.value(value: healthService),
      ],
      child: const HermesCompanion(),
    ),
  );
}
