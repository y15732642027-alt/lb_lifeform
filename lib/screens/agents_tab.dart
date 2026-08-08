import 'dart:math';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../core/theme.dart';

/// 神经星图 · 分身页 · Life Core中央·12节点环绕·贝塞尔连线·流光动画
class AgentsTab extends StatefulWidget {
  const AgentsTab({super.key});
  @override
  State<AgentsTab> createState() => _AgentsTabState();
}

class _AgentsTabState extends State<AgentsTab> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  List<Map<String,dynamic>> _agents = [];
  String? _selected;
  bool _loading = true;
  Timer? _timer;
  double _rotation = 0.0;
  
  // 12节点定义
  static const _nodes = [
    {'id':'commander',  'label':'总指挥', 'icon':'🛡', 'role':'策划·分配·决策', 'color':0xFFd4a853},
    {'id':'executor',   'label':'执行者', 'icon':'🔧', 'role':'构建·修复·部署', 'color':0xFF5cb878},
    {'id':'verifier',   'label':'验证者', 'icon':'🔬', 'role':'独立验证·不轻信', 'color':0xFF80d0ff},
    {'id':'reviewer',   'label':'审阅者', 'icon':'👁',  'role':'全链审查·把关', 'color':0xFFc0c0c0},
    {'id':'chronicler', 'label':'史官',   'icon':'📜', 'role':'记录·哲学·归档', 'color':0xFFd4a853},
    {'id':'scout',      'label':'斥候',   'icon':'🔍', 'role':'搜索·论文·调研', 'color':0xFF6078a0},
    {'id':'infra',      'label':'基建',   'icon':'🖥',  'role':'巡检·自恢复', 'color':0xFF5cb878},
    {'id':'gate',       'label':'门禁',   'icon':'🛑', 'role':'身份·硬阻断', 'color':0xFF8b3030},
    {'id':'auditor',    'label':'审计员', 'icon':'📊', 'role':'效率·标签审计', 'color':0xFFc0c0c0},
    {'id':'broker',     'label':'通信代理','icon':'📡', 'role':'Gateway·心跳', 'color':0xFF80d0ff},
    {'id':'creative',   'label':'创作引擎','icon':'🎨', 'role':'ComfyUI·出图', 'color':0xFFd4a853},
    {'id':'voice',      'label':'音频',   'icon':'🎵', 'role':'STT·TTS·语音', 'color':0xFF6078a0},
  ];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: Duration(seconds: 8))..repeat();
    _fetch();
    _timer = Timer.periodic(Duration(seconds: 30), (_) => _fetch());
  }

  @override
  void dispose() { _ctrl.dispose(); _timer?.cancel(); super.dispose(); }

  Future<void> _fetch() async {
    try {
      final r = await http.get(Uri.parse('http://192.168.1.2:8848/a')).timeout(Duration(seconds:3));
      if (r.statusCode==200 && mounted) {
        setState(() { _agents = List<Map<String,dynamic>>.from(jsonDecode(r.body)['agents']); _loading=false; });
        return;
      }
    } catch (_) {}
    setState(() {
      _agents = [
        {'name':'🛡 指挥官','role':'总指挥','online':true,'task':'每天9点·出任务清单'},
        {'name':'🔧 执行者','role':'Builder','online':true,'task':'每分钟检查任务队列'},
        {'name':'🔬 验证者','role':'Verifier','online':true,'task':'每天10点·独立核查'},
        {'name':'👁 审阅者','role':'Reviewer','online':true,'task':'每天11点·全链审查'},
        {'name':'📜 史官','role':'Chronicler','online':true,'task':'每小时·哲学搜集'},
        {'name':'🔍 斥候','role':'Scout','online':true,'task':'每日搜论文'},
        {'name':'🖥 基建','role':'Infra','online':true,'task':'每5分·服务巡检'},
        {'name':'🛑 门禁','role':'Gate','online':true,'task':'每小时·身份检查'},
        {'name':'📊 审计员','role':'Auditor','online':true,'task':'每周一·标签审计'},
        {'name':'📡 通信代理','role':'Broker','online':true,'task':'Gateway·微信心跳'},
        {'name':'🎨 创作引擎','role':'Creative','online':true,'task':'ComfyUI·出图'},
        {'name':'🎵 音频','role':'Voice','online':true,'task':'语音·STT·TTS'},
      ];
      _loading = false;
    });
  }

  bool _isOnline(String id) {
    final map = {
      'commander':'指挥官','executor':'执行者','verifier':'验证者','reviewer':'审阅者',
      'chronicler':'史官','scout':'斥候','infra':'基建','gate':'门禁',
      'auditor':'审计员','broker':'通信代理','creative':'创作引擎','voice':'音频',
    };
    final name = map[id] ?? id;
    final agent = _agents.where((a) => (a['name']??'').contains(name)).firstOrNull;
    return agent?['online'] == true;
  }

  @override
  Widget build(BuildContext context) {
    final online = _agents.where((a)=>a['online']==true).length;
    return Scaffold(
      backgroundColor: HermesTheme.bg,
      body: SafeArea(
        child: Column(children: [
          // Header
          Container(padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('神经星图', style: TextStyle(color: HermesTheme.gold, fontSize: 13, letterSpacing: 3)),
                SizedBox(height: 4),
                Text('$online/${_nodes.length} 在线', style: TextStyle(color: HermesTheme.textSecondary, fontSize: 12)),
              ]),
              Row(children: [
                _miniBtn(Icons.refresh, _fetch),
                SizedBox(width: 8),
                _miniBtn(Icons.info_outline, () => _showStats()),
              ]),
            ])),
          
          // Star Map
          Expanded(child: _loading 
            ? Center(child: CircularProgressIndicator(color: HermesTheme.gold.withAlpha(80)))
            : GestureDetector(
              onPanUpdate: (d) => setState(() => _rotation += d.delta.dx * 0.005),
              onTap: () => setState(() => _selected = null),
              child: AnimatedBuilder(animation: _ctrl, builder: (_, __) {
                return CustomPaint(
                  size: Size.infinite,
                  painter: _StarMapPainter(
                    nodes: _nodes,
                    progress: _ctrl.value,
                    rotation: _rotation,
                    selected: _selected,
                    isOnline: _isOnline,
                  ),
                );
              }),
            ),
          ),

          // Node tap areas - overlay on top of CustomPaint
          if (!_loading) SizedBox(height: 0), // spacer

          // Selected agent detail
          if (_selected != null) _buildDetail(_selected!),
          
          // Bottom legend
          Container(padding: EdgeInsets.all(12), color: HermesTheme.surface,
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              _legendDot(HermesTheme.gold, '活跃'),
              SizedBox(width: 12),
              _legendDot(HermesTheme.ice, '在线'),
              SizedBox(width: 12),
              _legendDot(HermesTheme.textMuted, '休眠'),
            ])),
        ]),
      ),
    );
  }

  Widget _miniBtn(IconData icon, VoidCallback fn) => GestureDetector(
    onTap: fn,
    child: Container(padding: EdgeInsets.all(6),
      decoration: BoxDecoration(color: HermesTheme.surfaceLight, borderRadius: BorderRadius.circular(8)),
      child: Icon(icon, size: 16, color: HermesTheme.textSecondary)));

  Widget _legendDot(Color c, String label) => Row(children: [
    Container(width: 6, height: 6, decoration: BoxDecoration(color: c, shape: BoxShape.circle, boxShadow: [BoxShadow(color: c.withAlpha(80), blurRadius: 4)])),
    SizedBox(width: 4),
    Text(label, style: TextStyle(color: HermesTheme.textSecondary, fontSize: 10)),
  ]);

  void _showStats() {
    final online = _agents.where((a)=>a['online']==true).length;
    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: HermesTheme.surface,
      title: Text('星图统计', style: TextStyle(color: HermesTheme.gold)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        _statRow('总节点', '${_nodes.length}'),
        _statRow('在线', '$online'),
        _statRow('离线', '${_nodes.length - online}'),
        _statRow('连线数', '${_nodes.length}'),
        _statRow('更新间隔', '30秒'),
      ]),
      actions: [TextButton(onPressed: ()=>Navigator.pop(ctx), child: Text('关闭', style: TextStyle(color: HermesTheme.textSecondary)))],
    ));
  }

  Widget _statRow(String k, String v) => Padding(padding: EdgeInsets.only(bottom: 4),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(k, style: TextStyle(color: HermesTheme.textSecondary, fontSize: 13)),
      Text(v, style: TextStyle(color: HermesTheme.gold, fontSize: 13)),
    ]));

  Widget _buildDetail(String id) {
    final node = _nodes.firstWhere((n) => n['id'] == id);
    final online = _isOnline(id);
    final agent = _agents.where((a) {
      final map = {'commander':'指挥官','executor':'执行者','verifier':'验证者','reviewer':'审阅者','chronicler':'史官','scout':'斥候','infra':'基建','gate':'门禁','auditor':'审计员','broker':'通信代理','creative':'创作引擎','voice':'音频'};
      return (a['name']??'').contains(map[id] ?? id);
    }).firstOrNull;
    
    return Container(
      margin: EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: HermesTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Color(node['color'] as int).withAlpha(60)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(node['icon'] as String, style: TextStyle(fontSize: 24)),
          SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(node['label'] as String, style: TextStyle(color: HermesTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
            Text(node['role'] as String, style: TextStyle(color: HermesTheme.textSecondary, fontSize: 12)),
          ]),
          Spacer(),
          Container(width: 8, height: 8, decoration: BoxDecoration(
            color: online ? HermesTheme.gold : HermesTheme.textMuted,
            shape: BoxShape.circle,
            boxShadow: online ? [BoxShadow(color: HermesTheme.gold.withAlpha(100), blurRadius: 6)] : null,
          )),
        ]),
        if (agent != null) ...[
          SizedBox(height: 8),
          Text('当前: ${agent['task'] ?? '—'}', style: TextStyle(color: HermesTheme.textSecondary, fontSize: 12)),
        ],
        SizedBox(height: 10),
        Row(children: [
          _actionBtn('发任务', HermesTheme.ice, () => _dispatchTask(node['label'] as String)),
          SizedBox(width: 8),
          _actionBtn('查看日志', HermesTheme.silver, () {}),
        ]),
      ]),
    );
  }

  Widget _actionBtn(String label, Color c, VoidCallback fn) => GestureDetector(
    onTap: fn,
    child: Container(padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: c.withAlpha(25), borderRadius: BorderRadius.circular(8), border: Border.all(color: c.withAlpha(60))),
      child: Text(label, style: TextStyle(color: c, fontSize: 11))));

  void _dispatchTask(String name) {
    final ctrl = TextEditingController();
    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: HermesTheme.surface,
      title: Text('发任务 → $name', style: TextStyle(color: HermesTheme.gold)),
      content: TextField(
        controller: ctrl, autofocus: true,
        style: TextStyle(color: HermesTheme.textPrimary),
        decoration: InputDecoration(hintText: '输入任务...', hintStyle: TextStyle(color: HermesTheme.textMuted),
          enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: HermesTheme.gold.withAlpha(60))),
          focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: HermesTheme.gold))),
      ),
      actions: [
        TextButton(onPressed: ()=>Navigator.pop(ctx), child: Text('取消', style: TextStyle(color: HermesTheme.textSecondary))),
        ElevatedButton(
          onPressed: () { Navigator.pop(ctx); _doDispatch(name, ctrl.text); },
          style: ElevatedButton.styleFrom(backgroundColor: HermesTheme.gold),
          child: Text('发送', style: TextStyle(color: Colors.black)),
        ),
      ],
    ));
  }

  Future<void> _doDispatch(String name, String task) async {
    if (task.isEmpty) return;
    try {
      await http.post(Uri.parse('http://192.168.1.2:8848/exec'),
        headers: {'X-Auth-Token':'hermes-desktop-agent-v1','Content-Type':'application/json'},
        body: jsonEncode({'command':'python D:/ratlab/dispatch.py "$name" "$task"','timeout':8}));
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('✅ 已发送'), backgroundColor: HermesTheme.gold));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('❌ 发送失败'), backgroundColor: HermesTheme.error));
    }
  }
}

/// 神经星图绘制器 · Bezier连线·流光粒子·中央Life Core
class _StarMapPainter extends CustomPainter {
  final List<Map<String,dynamic>> nodes;
  final double progress;
  final double rotation;
  final String? selected;
  final bool Function(String id) isOnline;

  _StarMapPainter({required this.nodes, required this.progress, required this.rotation, required this.selected, required this.isOnline});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2 - 20;
    final ringR = min(size.width, size.height) * 0.38;
    final coreR = ringR * 0.22;
    
    // ── 背景星场 ──
    _drawStarfield(canvas, size);
    
    // ── 外层波纹环 ──
    final waveAlpha = (20 + 10 * sin(progress * pi * 2)).toInt();
    canvas.drawCircle(Offset(cx, cy), ringR * 1.05,
      Paint()..style = PaintingStyle.stroke..strokeWidth = 0.5
        ..color = Color(0xFFd4a853).withAlpha(waveAlpha));
    
    // ── Bezier连线从核心到每个节点 ──
    for (int i = 0; i < nodes.length; i++) {
      final angle = i * pi * 2 / nodes.length + rotation;
      final nx = cx + cos(angle) * ringR;
      final ny = cy + sin(angle) * ringR;
      final online = isOnline(nodes[i]['id'] as String);
      final sel = selected == nodes[i]['id'];
      
      // Bezier控制点 - 向外弯曲
      final midAngle = angle;
      final midDist = ringR * 0.45;
      final cpx = cx + cos(midAngle) * midDist;
      final cpy = cy + sin(midAngle) * midDist;
      
      final path = Path()..moveTo(cx, cy);
      path.quadraticBezierTo(cpx, cpy, nx, ny);
      
      // 连线绘制
      final lineColor = online 
        ? (sel ? Color(0xFFd4a853) : Color(0xFFd4a853).withAlpha(40))
        : Color(0xFF4a4540).withAlpha(20);
      canvas.drawPath(path, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = sel ? 1.5 : 0.8
        ..color = lineColor
        ..maskFilter = sel ? MaskFilter.blur(BlurStyle.normal, 3) : null);
      
      // 流光粒子沿Bezier移动
      if (online) {
        final t = (progress * 2 + i * 0.083) % 1.0; // 每节点不同相位
        // Bezier公式: B(t) = (1-t)²P0 + 2(1-t)tP1 + t²P2
        final bx = (1-t)*(1-t)*cx + 2*(1-t)*t*cpx + t*t*nx;
        final by = (1-t)*(1-t)*cy + 2*(1-t)*t*cpy + t*t*ny;
        final glowColor = (nodes[i]['color'] as int?) ?? 0xFFd4a853;
        canvas.drawCircle(Offset(bx, by), 2.5, Paint()..color = Color(glowColor).withAlpha(180)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 4));
        // Trailing glow
        final t2 = ((t - 0.03) % 1.0).clamp(0.0, 1.0);
        final bx2 = (1-t2)*(1-t2)*cx + 2*(1-t2)*t2*cpx + t2*t2*nx;
        final by2 = (1-t2)*(1-t2)*cy + 2*(1-t2)*t2*cpy + t2*t2*ny;
        canvas.drawCircle(Offset(bx2, by2), 1.5, Paint()..color = Color(glowColor).withAlpha(60)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 2));
      }
    }
    
    // ── 外层粒子轨道环 ──
    final orbitCount = 36;
    for (int i = 0; i < orbitCount; i++) {
      final a = i * pi * 2 / orbitCount + progress * 0.5;
      final wobble = sin(progress * 4 + a) * 0.03;
      final dist = ringR * (1.02 + wobble);
      final px = cx + cos(a) * dist;
      final py = cy + sin(a) * dist;
      final alpha = (25 + 15 * sin(progress * 3 + i * 0.5)).toInt();
      canvas.drawCircle(Offset(px, py), 0.8, Paint()..color = Color(0xFFd4a853).withAlpha(alpha));
    }
    
    // ── 节点 ──
    for (int i = 0; i < nodes.length; i++) {
      final angle = i * pi * 2 / nodes.length + rotation;
      final nx = cx + cos(angle) * ringR;
      final ny = cy + sin(angle) * ringR;
      final online = isOnline(nodes[i]['id'] as String);
      final sel = selected == nodes[i]['id'];
      final nodeColor = Color(nodes[i]['color'] as int);
      
      // Glow aura
      if (online) {
        canvas.drawCircle(Offset(nx, ny), sel ? 18 : 13, Paint()
          ..color = nodeColor.withAlpha(sel ? 40 : 15)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, sel ? 10 : 6));
      }
      
      // Outer ring
      canvas.drawCircle(Offset(nx, ny), sel ? 14 : 10, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = sel ? 2.5 : 1.5
        ..color = online 
          ? (sel ? nodeColor : nodeColor.withAlpha(150))
          : Color(0xFF4a4540));
      
      // Inner fill
      canvas.drawCircle(Offset(nx, ny), sel ? 10 : 7, Paint()
        ..color = online 
          ? nodeColor.withAlpha(sel ? 60 : 30)
          : Color(0xFF2a2520));
      
      // Center dot
      canvas.drawCircle(Offset(nx, ny), sel ? 3.5 : 2.5, Paint()
        ..color = online ? nodeColor : Color(0xFF4a4540));
      
      // Label
      if (sel) {
        _drawText(canvas, nodes[i]['label'] as String, nx, ny - 20, HermesTheme.gold, 11, true);
      }
      
      // Online pulse ring
      if (online && !sel) {
        final pulse = (0.5 + 0.5 * sin(progress * 3 + i)).toInt();
        canvas.drawCircle(Offset(nx, ny), 15.0, Paint()
          ..style = PaintingStyle.stroke..strokeWidth = 0.5
          ..color = nodeColor.withAlpha(40 + pulse * 20));
      }
    }
    
    // ── Central Life Core ──
    // Outermost glow
    canvas.drawCircle(Offset(cx, cy), coreR * 2.8,
      Paint()..shader = RadialGradient(colors: [
        Color(0xFFd4a853).withAlpha(12), Color(0xFFd4a853).withAlpha(4), Color(0xFFd4a853).withAlpha(0)
      ]).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: coreR * 2.8)));
    
    // Mid glow
    canvas.drawCircle(Offset(cx, cy), coreR * 1.6,
      Paint()..shader = RadialGradient(colors: [
        Color(0xFFd4a853).withAlpha(30), Color(0xFFd4a853).withAlpha(8), Color(0xFFd4a853).withAlpha(0)
      ]).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: coreR * 1.6)));
    
    // Pulsing ring
    final pulse2 = (0.7 + 0.3 * sin(progress * pi * 2)).toInt();
    canvas.drawCircle(Offset(cx, cy), coreR * 1.15, Paint()
      ..style = PaintingStyle.stroke..strokeWidth = 1.0
      ..color = Color(0xFFd4a853).withAlpha(40 + pulse2 * 30));
    
    // Core fill
    canvas.drawCircle(Offset(cx, cy), coreR, Paint()
      ..shader = RadialGradient(colors: [
        Colors.white.withAlpha(200), Color(0xFFe8c860).withAlpha(140), Color(0xFFd4a853).withAlpha(30)
      ]).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: coreR)));
    
    // Core inner bright spot
    canvas.drawCircle(Offset(cx, cy), coreR * 0.35, Paint()
      ..color = Colors.white.withAlpha(180)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 2));
    
    // "Life Core" label
    _drawText(canvas, 'Life Core', cx, cy + coreR + 18, HermesTheme.gold.withAlpha(120), 9, false);
  }

  void _drawStarfield(Canvas canvas, Size size) {
    final rng = Random(42);
    for (int i = 0; i < 80; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      final a = (40 + rng.nextInt(60)).toInt();
      final s = 0.3 + rng.nextDouble() * 0.8;
      canvas.drawCircle(Offset(x, y), s, Paint()..color = Color(0xFFd4a853).withAlpha(a));
    }
  }

  void _drawText(Canvas canvas, String text, double x, double y, Color color, double fontSize, bool bold) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: TextStyle(color: color, fontSize: fontSize, fontWeight: bold ? FontWeight.w600 : FontWeight.w300)),
      textDirection: TextDirection.ltr)..layout();
    tp.paint(canvas, Offset(x - tp.width / 2, y - tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => true;
}
