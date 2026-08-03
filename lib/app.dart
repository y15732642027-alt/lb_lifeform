import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/api_client.dart';
import 'core/health_service.dart';
import 'core/theme.dart';
import 'screens/agent_list.dart';
import 'screens/health_dashboard.dart';

/// 灯泡伴侣 — Hermes移动操作系统入口
///
/// Shell层职责:
/// - 底部导航(TabBar)路由
/// - 全局主题注入
/// - 生命周期管理(前后台切换时触发健康检查)
class LampCompanionApp extends StatelessWidget {
  const LampCompanionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '灯泡伴侣',
      debugShowCheckedModeBanner: false,

      // ── Hermes暗黑主题 ──
      theme: HermesTheme.darkTheme,
      darkTheme: HermesTheme.darkTheme,
      themeMode: ThemeMode.dark,

      home: const _AppShell(),
    );
  }
}

/// App壳 — 底部导航+页面容器
class _AppShell extends StatefulWidget {
  const _AppShell();

  @override
  State<_AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<_AppShell>
    with WidgetsBindingObserver {
  int _currentIndex = 0;

  /// 底部Tab对应的页面
  late final List<Widget> _pages;

  /// API客户端引用 (调试用)
  String _connectionStatus = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _pages = const [
      HealthDashboard(),
      AgentList(),
      _PlaceholderPage(
        icon: Icons.chat_bubble_outline,
        title: '对话',
        subtitle: '灯泡聊天 · 即将上线',
      ),
      _PlaceholderPage(
        icon: Icons.settings_outlined,
        title: '系统',
        subtitle: '系统设置 · 即将上线',
      ),
    ];

    // 启动时检测连接
    _checkConnection();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// 从后台切回前台时刷新
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<HealthService>().refresh();
      _checkConnection();
    }
  }

  Future<void> _checkConnection() async {
    final api = context.read<ApiClient>();
    final reachable = await api.ping();
    if (mounted) {
      setState(() {
        _connectionStatus = reachable ? '已连接' : '未连接';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: [
          BottomNavigationBarItem(
            icon: _currentIndex == 0
                ? const Icon(Icons.favorite)
                : const Icon(Icons.favorite_border),
            label: '生命',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.people_outline),
            activeIcon: Icon(Icons.people),
            label: '分身',
          ),
          BottomNavigationBarItem(
            icon: _currentIndex == 2
                ? const Icon(Icons.chat_bubble)
                : const Icon(Icons.chat_bubble_outline),
            label: '对话',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings),
            label: '系统',
          ),
        ],
      ),
    );
  }
}

/// 占位页面 — V0.1尚未实现的模块
class _PlaceholderPage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _PlaceholderPage({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 48,
              color: HermesTheme.textSecondary.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                color: HermesTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: const TextStyle(
                color: HermesTheme.textSecondary,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
