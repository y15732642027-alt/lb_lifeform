import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/theme.dart';

class AgentPanel extends StatefulWidget {
  const AgentPanel({super.key});
  @override
  State<AgentPanel> createState() => _AgentPanelState();
}

class _AgentPanelState extends State<AgentPanel> {
  List<Map<String,dynamic>> _agents = [];
  String? _expanded;
  Timer? _timer;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetch();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _fetch());
  }
  @override
  void dispose() { _timer?.cancel(); super.dispose(); }

  Future<void> _fetch() async {
    try {
      final r = await http.get(Uri.parse('https://symbio.xin/api/agents')).timeout(Duration(seconds: 5));
      if (r.statusCode == 200 && mounted) {
        setState(() { _agents = List<Map<String,dynamic>>.from(jsonDecode(r.body)['agents']); _loading = false; });
      }
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    final online = _agents.where((a)=>a['online']==true).length;
    return Scaffold(
      appBar: AppBar(title: Text('分身链路·$online/${_agents.length}在线'),
        actions: [IconButton(icon: Icon(Icons.refresh,size:20),onPressed:_fetch)]),
      body: _loading ? Center(child: CircularProgressIndicator(color: HermesTheme.textSecondary))
        : SingleChildScrollView(padding: EdgeInsets.all(12), child: Column(children: [
          // 思维导图
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(color: HermesTheme.surface, borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Color(0xFFe94560), width: 1)),
            child: CustomPaint(
              size: Size(double.infinity, 320),
              painter: _MindMapPainter(),
              child: SizedBox(height: 320, child: Stack(children: _buildNodes())),
            ),
          ),
          SizedBox(height: 12),
          // 展开详情
          if (_expanded != null) _buildDetail(_expanded!),
        ])),
    );
  }

  List<Widget> _buildNodes() {
    final positions = [
      Offset(80, 40),   // 总指挥  top center
      Offset(180, 120), // 斥候
      Offset(40, 200),  // 执行者
      Offset(120, 200), // 验证者
      Offset(80, 280),  // 审阅者
      Offset(80, 360),  // 史官
    ];
    final names = ['总指挥','斥候','执行者','验证者','审阅者','史官'];
    return List.generate(6, (i) {
      final a = _agents.where((a)=>a['name'].contains(names[i])).firstOrNull;
      final on = a?['online'] == true;
      return Positioned(
        left: positions[i].dx, top: positions[i].dy,
        child: GestureDetector(
          onTap: () => setState(() => _expanded = _expanded == names[i] ? null : names[i]),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: on ? Color(0xFF0a2a1a) : Color(0xFF1a1a2e),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: on ? Color(0xFF00cc66) : Color(0xFF2a2a4a), width: on ? 2 : 1),
              boxShadow: on ? [BoxShadow(color: Color(0xFF00cc66).withOpacity(0.3), blurRadius: 8)] : null,
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width:6,height:6, decoration: BoxDecoration(color: on?Color(0xFF00cc66):Colors.red, shape: BoxShape.circle)),
              SizedBox(width: 6),
              Text(names[i], style: TextStyle(color: on ? HermesTheme.textPrimary : HermesTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
            ]),
          ),
        ),
      );
    });
  }

  Widget _buildDetail(String name) {
    final a = _agents.where((a)=>a['name'].contains(name)).firstOrNull ?? {};
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(color: HermesTheme.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: Color(0xFF00cc66))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(a['name']??name, style: TextStyle(color: HermesTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
        SizedBox(height: 4),
        Text('角色: ${a['role']??''}', style: TextStyle(color: HermesTheme.textSecondary, fontSize: 12)),
        SizedBox(height: 2),
        Text('任务: ${a['task']??'—'}', style: TextStyle(color: HermesTheme.textSecondary, fontSize: 12)),
        SizedBox(height: 2),
        Text('下次: ${a['next_run']??'持续运行'}', style: TextStyle(color: Color(0xFF888888), fontSize: 11)),
        SizedBox(height: 8),
        Row(children: [
          _btn('发任务', Colors.cyan),
          SizedBox(width: 8),
          _btn('手动触发', Colors.orange),
        ]),
      ]),
    );
  }

  Widget _btn(String text, Color c) => GestureDetector(
    onTap: (){},
    child: Container(padding: EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(color: c.withOpacity(0.2), borderRadius: BorderRadius.circular(6), border: Border.all(color: c)),
      child: Text(text, style: TextStyle(color: c, fontSize: 11, fontWeight: FontWeight.bold))),
  );
}

class _MindMapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Color(0xFF00cc66).withOpacity(0.3)..strokeWidth = 2..style = PaintingStyle.stroke;
    // 连线: 总指挥→各节点
    final from = Offset(120, 56);
    final tos = [Offset(210,136), Offset(80,216), Offset(160,216), Offset(120,296), Offset(120,376)];
    for (var to in tos) {
      canvas.drawLine(from, to, paint);
      // 箭头
      final d = (to - from);
      final len = d.distance;
      if (len > 0) {
        final dir = d / len;
        final arrow = to - dir * 6;
        canvas.drawLine(arrow, arrow + Offset(-dir.dy-dir.dx, dir.dx-dir.dy) * 0.5 * 4, paint);
        canvas.drawLine(arrow, arrow + Offset(dir.dy-dir.dx, -dir.dx-dir.dy) * 0.5 * 4, paint);
      }
    }
    // 水平线: 执行者-验证者
    canvas.drawLine(Offset(80,216), Offset(160,216), paint);
    // 垂直: 验证者-审阅者
    canvas.drawLine(Offset(120,232), Offset(120,296), paint);
    // 垂直: 审阅者-史官
    canvas.drawLine(Offset(120,312), Offset(120,376), paint);
  }
  @override
  bool shouldRepaint(covariant CustomPainter old) => true;
}
