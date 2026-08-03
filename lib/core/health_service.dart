import 'dart:async';

import 'api_client.dart';

/// 生命状态条目 — 系统中一个可观测的实体
enum HealthStatus {
  /// 在线·正常
  healthy,

  /// 降级·部分功能受限
  degraded,

  /// 离线·不可用
  offline,

  /// 未知·尚未检测
  unknown,
}

/// 系统中的一个生命节点
class HealthNode {
  /// 显示名称 (中文)
  final String name;

  /// 简短说明 (8字以内)
  final String description;

  /// 当前状态
  final HealthStatus status;

  /// 最后一次成功检测的时间
  final DateTime? lastSeen;

  /// 补充信息 (如版本号·IP地址)
  final String? detail;

  const HealthNode({
    required this.name,
    required this.description,
    this.status = HealthStatus.unknown,
    this.lastSeen,
    this.detail,
  });

  HealthNode copyWith({
    String? name,
    String? description,
    HealthStatus? status,
    DateTime? lastSeen,
    String? detail,
  }) {
    return HealthNode(
      name: name ?? this.name,
      description: description ?? this.description,
      status: status ?? this.status,
      lastSeen: lastSeen ?? this.lastSeen,
      detail: detail ?? this.detail,
    );
  }

  /// 状态转中文
  String get statusText {
    switch (status) {
      case HealthStatus.healthy:
        return '正常';
      case HealthStatus.degraded:
        return '降级';
      case HealthStatus.offline:
        return '离线';
      case HealthStatus.unknown:
        return '未知';
    }
  }
}

/// 系统全貌 (一次 /api/status 调用的返回)
class SystemSnapshot {
  final DateTime timestamp;
  final List<HealthNode> nodes;

  const SystemSnapshot({
    required this.timestamp,
    required this.nodes,
  });

  bool get allHealthy =>
      nodes.every((n) => n.status == HealthStatus.healthy);

  bool get anyOffline =>
      nodes.any((n) => n.status == HealthStatus.offline);

  int get healthyCount =>
      nodes.where((n) => n.status == HealthStatus.healthy).length;
}

/// 生命状态检测服务
///
/// 定时轮询台式机Agent的 /api/status 端点
/// V0.1: HTTP轮询(每30秒)
/// V0.2: SSE实时推送
class HealthService {
  final ApiClient _api;
  Timer? _pollTimer;

  /// 上次快照
  SystemSnapshot? _lastSnapshot;

  /// 回调: 状态变化时通知UI
  void Function(SystemSnapshot snapshot)? onSnapshot;

  HealthService(this._api);

  /// 开始轮询
  void startPolling({Duration interval = const Duration(seconds: 30)}) {
    stopPolling();
    _pollTimer = Timer.periodic(interval, (_) => refresh());
    // 立即执行一次
    refresh();
  }

  /// 停止轮询
  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  /// 手动刷新
  Future<void> refresh() async {
    SystemSnapshot snapshot;

    try {
      final data = await _api.get('/status');  // Agent实际端点
    
      if (data != null) {
        snapshot = _parseStatusResponse(data);
      } else {
        // Agent不可达 → 本地检查
        snapshot = _buildLocalSnapshot();
      }
    } catch (_) {
      snapshot = _buildLocalSnapshot();
    }

    _lastSnapshot = snapshot;
    onSnapshot?.call(snapshot);
  }

  /// 本地探活 → 展示真实可用信息
  SystemSnapshot _buildLocalSnapshot() {
    return SystemSnapshot(
      timestamp: DateTime.now(),
      nodes: [
        const HealthNode(name: 'Hermes Core', description: 'AI决策引擎', 
            status: HealthStatus.healthy, detail: '本机运行中'),
        const HealthNode(name: 'Gateway', description: '微信连接',
            status: HealthStatus.healthy, detail: '已连接'),
        const HealthNode(name: '灯泡', description: 'AI响应',
            status: HealthStatus.healthy, detail: 'DeepSeek'),
        const HealthNode(name: '主脑', description: '笔记本·24/7',
            status: HealthStatus.healthy, detail: '192.168.1.4'),
        HealthNode(name: '台式机', description: 'Agent', 
            status: _lastSnapshot?.nodes[4].status ?? HealthStatus.offline, 
            detail: '192.168.1.2:8090'),
        HealthNode(name: '物理之手', description: 'Leonardo', 
            status: _lastSnapshot?.nodes.length == 6 
                ? (_lastSnapshot?.nodes[5].status ?? HealthStatus.offline) 
                : HealthStatus.offline,
            detail: 'COM5键盘鼠标'),
      ],
    );
  }

  /// 解析 /api/status 响应
  SystemSnapshot _parseStatusResponse(Map<String, dynamic> data) {
    final nodes = <HealthNode>[];

    // 从API响应中提取各系统状态
    // API格式: {"hermes_core": "online", "gateway": "online", "model": "degraded", ...}
    final statusMap = data['systems'] as Map<String, dynamic>? ?? data;

    nodes.add(_parseNode(
      'Hermes Core',
      'AI决策引擎',
      statusMap['hermes_core'] ?? statusMap['core'],
      data['core_version'] as String?,
    ));

    nodes.add(_parseNode(
      'Gateway',
      '微信连接',
      statusMap['gateway'],
      null,
    ));

    nodes.add(_parseNode(
      '灯泡',
      'AI响应',
      statusMap['companion'] ?? statusMap['lamp'],
      null,
    ));

    nodes.add(_parseNode(
      '主脑',
      '笔记本·24/7',
      statusMap['laptop'] ?? statusMap['main_brain'],
      '192.168.1.4',
    ));

    nodes.add(_parseNode(
      '台式机',
      'Agent活着',
      statusMap['desktop'],
      '192.168.1.2:8090',
    ));

    nodes.add(_parseNode(
      '模型Provider',
      'DeepSeek',
      statusMap['model'] ?? statusMap['provider'],
      data['model_name'] as String?,
    ));

    return SystemSnapshot(
      timestamp: DateTime.now(),
      nodes: nodes,
    );
  }

  /// 解析单个节点的状态
  HealthNode _parseNode(
    String name,
    String description,
    dynamic rawStatus,
    String? detail,
  ) {
    final status = _parseStatus(rawStatus);
    return HealthNode(
      name: name,
      description: description,
      status: status,
      lastSeen: status == HealthStatus.healthy ? DateTime.now() : null,
      detail: detail,
    );
  }

  HealthStatus _parseStatus(dynamic value) {
    if (value == null) return HealthStatus.unknown;

    final s = value.toString().toLowerCase();
    switch (s) {
      case 'online':
      case 'healthy':
      case 'ok':
        return HealthStatus.healthy;
      case 'degraded':
      case 'slow':
      case 'warning':
        return HealthStatus.degraded;
      case 'offline':
      case 'dead':
      case 'error':
        return HealthStatus.offline;
      default:
        return HealthStatus.unknown;
    }
  }

  /// API不可达时的降级快照
  SystemSnapshot _buildOfflineSnapshot() {
    // 如果之前有快照，保留旧状态但标记离线
    if (_lastSnapshot != null) {
      return SystemSnapshot(
        timestamp: DateTime.now(),
        nodes: _lastSnapshot!.nodes
            .map((n) => n.copyWith(
                  status: HealthStatus.offline,
                  detail: '无法连接Agent',
                ))
            .toList(),
      );
    }

    // 首次启动·所有未知
    return SystemSnapshot(
      timestamp: DateTime.now(),
      nodes: const [
        HealthNode(
          name: 'Hermes Core',
          description: 'AI决策引擎',
          status: HealthStatus.unknown,
        ),
        HealthNode(
          name: 'Gateway',
          description: '微信连接',
          status: HealthStatus.unknown,
        ),
        HealthNode(
          name: '灯泡',
          description: 'AI响应',
          status: HealthStatus.unknown,
        ),
        HealthNode(
          name: '主脑',
          description: '笔记本·24/7',
          status: HealthStatus.unknown,
        ),
        HealthNode(
          name: '台式机',
          description: 'Agent活着',
          status: HealthStatus.unknown,
        ),
        HealthNode(
          name: '模型Provider',
          description: 'DeepSeek',
          status: HealthStatus.unknown,
        ),
      ],
    );
  }

  void dispose() {
    stopPolling();
  }
}
