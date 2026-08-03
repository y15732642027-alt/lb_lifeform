import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/health_service.dart';
import '../core/theme.dart';

/// ═══════════════════════════════════════════════════════
/// 首页 — 生命状态总览
/// ═══════════════════════════════════════════════════════
///
/// 灯泡伴侣最高优先级页面。不是聊天·是生命状态。
/// 二郎打开App第一眼看到：今天谁病了。
///
/// 设计:
/// - 每个系统节点 = 一张独立状态卡片
/// - 绿色=正常·黄色=降级·红色闪烁=离线
/// - 点击卡片可查看详情(未来)
class HealthDashboard extends StatefulWidget {
  const HealthDashboard({super.key});

  @override
  State<HealthDashboard> createState() => _HealthDashboardState();
}

class _HealthDashboardState extends State<HealthDashboard> {
  late final HealthService _healthService;
  SystemSnapshot? _snapshot;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _healthService = context.read<HealthService>();
    _healthService.onSnapshot = (snapshot) {
      if (mounted) {
        setState(() {
          _snapshot = snapshot;
        });
      }
    };
    _healthService.startPolling();
  }

  @override
  void dispose() {
    _healthService.stopPolling();
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final nodes = _snapshot?.nodes ?? [];

    // 全局状态摘要
    final healthyCount = _snapshot?.healthyCount ?? 0;
    final totalCount = nodes.isNotEmpty ? nodes.length : 6;
    final anyOffline = _snapshot?.anyOffline ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('灯泡生命体'),
        actions: [
          // 手动刷新按钮
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            tooltip: '刷新状态',
            onPressed: () => _healthService.refresh(),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        color: HermesTheme.lampYellow,
        onRefresh: () => _healthService.refresh(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            // ═══ 摘要栏 ═══
            _buildSummaryBar(healthyCount, totalCount, anyOffline),
            const SizedBox(height: 16),

            // ═══ 节点卡片 ═══
            if (nodes.isNotEmpty)
              ...nodes.map((node) => _buildNodeCard(node))
            else
              _buildEmptyState(),
          ],
        ),
      ),
    );
  }

  /// 顶部摘要: "5/6 正常" 或 "⚠ 2个节点离线"
  Widget _buildSummaryBar(int healthy, int total, bool anyOffline) {
    final Color accentColor;
    final IconData icon;
    final String label;

    if (anyOffline) {
      accentColor = HermesTheme.statusRed;
      icon = Icons.warning_amber_rounded;
      label = '$healthy/$total 正常 · 有节点离线';
    } else if (healthy == total) {
      accentColor = HermesTheme.statusGreen;
      icon = Icons.check_circle_outline;
      label = '全部正常 · $healthy/$total';
    } else {
      accentColor = HermesTheme.statusYellow;
      icon = Icons.info_outline;
      label = '$healthy/$total 正常 · 等待检测';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: accentColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: accentColor.withOpacity(0.3),
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: accentColor, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: accentColor,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          // 更新时间
          if (_snapshot != null)
            Text(
              _formatTimestamp(_snapshot!.timestamp),
              style: const TextStyle(
                color: HermesTheme.textSecondary,
                fontSize: 11,
              ),
            ),
        ],
      ),
    );
  }

  /// 单张节点卡片
  Widget _buildNodeCard(HealthNode node) {
    final statusColor = _statusColor(node.status);
    final showPulse = node.status == HealthStatus.offline;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: HermesTheme.surface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            // TODO V0.2: 点击查看详情/日志
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: showPulse
                    ? HermesTheme.statusRed.withOpacity(0.4)
                    : HermesTheme.border,
                width: 0.5,
              ),
            ),
            child: Row(
              children: [
                // ── 状态指示灯 ──
                _StatusDot(
                  color: statusColor,
                  pulsing: showPulse,
                ),
                const SizedBox(width: 14),

                // ── 名称+说明 ──
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        node.name,
                        style: const TextStyle(
                          color: HermesTheme.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Text(
                            node.description,
                            style: const TextStyle(
                              color: HermesTheme.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                          if (node.detail != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: HermesTheme.border.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                node.detail!,
                                style: const TextStyle(
                                  color: HermesTheme.textSecondary,
                                  fontSize: 10,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                // ── 状态文字 ──
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: statusColor.withOpacity(0.3),
                      width: 0.5,
                    ),
                  ),
                  child: Text(
                    node.statusText,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 首次加载·无数据
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 60),
        child: Column(
          children: [
            const SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: HermesTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              '正在连接系统…',
              style: TextStyle(
                color: HermesTheme.textSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '台式机Agent · 192.168.1.2:8090',
              style: TextStyle(
                color: HermesTheme.textSecondary.withOpacity(0.5),
                fontSize: 11,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _statusColor(HealthStatus status) {
    switch (status) {
      case HealthStatus.healthy:
        return HermesTheme.statusGreen;
      case HealthStatus.degraded:
        return HermesTheme.statusYellow;
      case HealthStatus.offline:
        return HermesTheme.statusRed;
      case HealthStatus.unknown:
        return HermesTheme.statusBlue;
    }
  }

  String _formatTimestamp(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}

/// 状态指示灯 — 带脉冲动画(离线时闪烁)
class _StatusDot extends StatefulWidget {
  final Color color;
  final bool pulsing;
  final double size;

  const _StatusDot({
    required this.color,
    this.pulsing = false,
    this.size = 12,
  });

  @override
  State<_StatusDot> createState() => _StatusDotState();
}

class _StatusDotState extends State<_StatusDot>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  Animation<double>? _animation;

  @override
  void initState() {
    super.initState();
    if (widget.pulsing) {
      _controller = AnimationController(
        duration: const Duration(milliseconds: 1500),
        vsync: this,
      )..repeat(reverse: true);

      _animation = Tween<double>(begin: 0.3, end: 1.0).animate(
        CurvedAnimation(parent: _controller!, curve: Curves.easeInOut),
      );
    }
  }

  @override
  void didUpdateWidget(_StatusDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pulsing && _controller == null) {
      _controller = AnimationController(
        duration: const Duration(milliseconds: 1500),
        vsync: this,
      )..repeat(reverse: true);
      _animation = Tween<double>(begin: 0.3, end: 1.0).animate(
        CurvedAnimation(parent: _controller!, curve: Curves.easeInOut),
      );
    } else if (!widget.pulsing && _controller != null) {
      _controller!.stop();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dot = Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        color: widget.color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: widget.color.withOpacity(0.5),
            blurRadius: 6,
            spreadRadius: 1,
          ),
        ],
      ),
    );

    if (widget.pulsing && _animation != null) {
      return AnimatedBuilder(
        animation: _animation!,
        builder: (context, child) {
          return Opacity(opacity: _animation!.value, child: child);
        },
        child: dot,
      );
    }

    return dot;
  }
}
