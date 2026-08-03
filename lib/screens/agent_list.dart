import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../core/theme.dart';

/// ═══════════════════════════════════════════════════════
/// 分身列表 — Hermes分身系统总览
/// ═══════════════════════════════════════════════════════
///
/// 展示12个Agent分身的在线状态。
/// V0.1: 静态列表+HTTP轮询
/// V0.2: 实时状态+点击查看详情
class AgentList extends StatefulWidget {
  const AgentList({super.key});

  @override
  State<AgentList> createState() => _AgentListState();
}

class _AgentListState extends State<AgentList> {
  List<_AgentInfo> _agents = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchAgents();
  }

  Future<void> _fetchAgents() async {
    final api = context.read<ApiClient>();

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final data = await api.get('/api/agents');

      if (data == null) {
        setState(() {
          _error = '无法连接Agent';
          _loading = false;
        });
        return;
      }

      final agentList = data['agents'] as List<dynamic>?;
      if (agentList != null) {
        _agents = agentList
            .map((a) => _AgentInfo(
                  name: a['name'] as String? ?? '?',
                  role: a['role'] as String? ?? '',
                  online: a['status'] == 'online' || a['online'] == true,
                ))
            .toList();
      } else {
        // 降级: 使用硬编码的分身列表
        _agents = _fallbackAgents;
      }

      setState(() => _loading = false);
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
        _agents = _fallbackAgents; // 离线时显示静态列表
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('分身系统'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: _fetchAgents,
          ),
        ],
      ),
      body: _loading ? _buildLoading() : _buildList(),
    );
  }

  Widget _buildLoading() {
    return const Center(
      child: CircularProgressIndicator(
        color: HermesTheme.textSecondary,
        strokeWidth: 2,
      ),
    );
  }

  Widget _buildList() {
    if (_agents.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.people_outline,
              size: 48,
              color: HermesTheme.textSecondary,
            ),
            const SizedBox(height: 16),
            Text(
              _error ?? '暂无可用的分身',
              style: const TextStyle(
                color: HermesTheme.textSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: _fetchAgents,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('重试'),
            ),
          ],
        ),
      );
    }

    // 统计: 按状态排序 — 在线的排前面
    final sorted = List<_AgentInfo>.from(_agents)
      ..sort((a, b) {
        if (a.online && !b.online) return -1;
        if (!a.online && b.online) return 1;
        return a.name.compareTo(b.name);
      });

    final onlineCount = sorted.where((a) => a.online).length;

    return RefreshIndicator(
      color: HermesTheme.lampYellow,
      onRefresh: _fetchAgents,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          // 摘要
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: HermesTheme.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: HermesTheme.border, width: 0.5),
            ),
            child: Row(
              children: [
                Icon(
                  onlineCount == sorted.length
                      ? Icons.check_circle_outline
                      : Icons.info_outline,
                  color: HermesTheme.lampYellow,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  '$onlineCount/${sorted.length} 在线',
                  style: const TextStyle(
                    color: HermesTheme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 分身列表
          ...sorted.map(_buildAgentCard),
        ],
      ),
    );
  }

  Widget _buildAgentCard(_AgentInfo agent) {
    final dotColor =
        agent.online ? HermesTheme.statusGreen : HermesTheme.textSecondary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: HermesTheme.surface,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () {
            // TODO V0.2: 点开分身详情
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: HermesTheme.border, width: 0.5),
            ),
            child: Row(
              children: [
                // 状态点
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      if (agent.online)
                        BoxShadow(
                          color: dotColor.withOpacity(0.4),
                          blurRadius: 4,
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),

                // 名称
                Expanded(
                  child: Text(
                    agent.name,
                    style: TextStyle(
                      color: agent.online
                          ? HermesTheme.textPrimary
                          : HermesTheme.textSecondary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),

                // 角色标签
                if (agent.role.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: HermesTheme.border.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      agent.role,
                      style: const TextStyle(
                        color: HermesTheme.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ),

                const SizedBox(width: 8),

                // 状态文字
                Text(
                  agent.online ? '在线' : '离线',
                  style: TextStyle(
                    color: dotColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 脱机时使用的Fallback分身列表 (12分身)
  static const List<_AgentInfo> _fallbackAgents = [
    _AgentInfo(name: '🛡 指挥官', role: '总指挥', online: false),
    _AgentInfo(name: '🔧 执行者', role: 'Builder', online: false),
    _AgentInfo(name: '🔬 验证者', role: 'Verifier', online: false),
    _AgentInfo(name: '👁 审阅者', role: 'Reviewer', online: false),
    _AgentInfo(name: '🖥 基建', role: 'Infra', online: false),
    _AgentInfo(name: '📜 史官', role: 'Chronicler', online: false),
    _AgentInfo(name: '🔍 斥候', role: 'Scout', online: false),
    _AgentInfo(name: '🛑 门禁', role: 'Gate', online: false),
    _AgentInfo(name: '📊 审计员', role: 'Auditor', online: false),
    _AgentInfo(name: '📡 通信代理', role: 'Broker', online: false),
    _AgentInfo(name: '💰 预算', role: 'Budget', online: false),
    _AgentInfo(name: '🎨 创作引擎', role: 'Creative', online: false),
  ];
}

class _AgentInfo {
  final String name;
  final String role;
  final bool online;

  const _AgentInfo({
    required this.name,
    required this.role,
    this.online = false,
  });
}
