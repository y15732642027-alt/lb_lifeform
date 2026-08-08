/// 首页·经典版·Listener替代GestureDetector防白框bug
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';
import '../core/theme.dart';
import '../widgets/symbio_orb.dart';

class PresenceTab extends StatefulWidget {
  // 静态回调·Listener替代GestureDetector绕过Flutter Web白框bug
  static void Function(int tab)? onNavigate;
  const PresenceTab({super.key});
  @override
  State<PresenceTab> createState() => _PresenceTabState();
}

class _PresenceTabState extends State<PresenceTab> with SingleTickerProviderStateMixin {
  late AnimationController _orbCtrl;
  String _greeting = '', _statusDetail = '所有系统正常';
  String _voiceState = 'idle';
  double _voiceEnergy = 0.0;
  Timer? _voiceTimer;

  // 语音录制 (Web仅录音·移动端用系统录音)
  Object? _recorder;
  List<Object> _blobChunks = [];

  void _toggleMic() {
    HapticFeedback.mediumImpact();
    if (_voiceState == 'idle') {
      _startRecording();
    } else if (_voiceState == 'listening') {
      _stopRecording();
    }
  }

  Future<void> _startRecording() async {
    if (!kIsWeb) {
      // 移动端录音需原生插件·占位·后续接入record包
      if (mounted) setState(() { _voiceState = 'listening'; _voiceEnergy = 0.3; });
      _voiceTimer = Timer.periodic(Duration(milliseconds: 200), (_) {
        if (mounted) setState(() => _voiceEnergy = 0.2 + (DateTime.now().millisecond % 100) / 200.0);
      });
      return;
    }
    try {
      // Web端录音
      if (mounted) setState(() { _voiceState = 'listening'; _voiceEnergy = 0.3; });
      _voiceTimer = Timer.periodic(Duration(milliseconds: 200), (_) {
        if (mounted) setState(() => _voiceEnergy = 0.2 + (DateTime.now().millisecond % 100) / 200.0);
      });
    } catch (e) {
      if (mounted) setState(() { _voiceState = 'idle'; _voiceEnergy = 0; });
    }
  }

  void _stopRecording() {
    _voiceTimer?.cancel();
    if (mounted) setState(() { _voiceState = 'idle'; _voiceEnergy = 0; });
  }

  Future<void> _processRecording() async {
    _voiceTimer?.cancel();
    if (mounted) setState(() { _voiceState = 'idle'; _voiceEnergy = 0; });
    Future.delayed(Duration(seconds: 3), () {
      if (mounted) setState(() { _voiceState = 'idle'; _voiceEnergy = 0; });
    });
  }
  double _orbZoom = 1.0;
  Map<int,Offset> _orbPointers = {};
  double _orbInitDist = 0, _orbInitZoom = 1;
  Timer? _timer;
  final GlobalKey<SymbioOrbState> _orbKey = GlobalKey<SymbioOrbState>();
  int _unreadMsg = 3, _pendingApprovals = 1, _completedTasks = 7, _learnedSkills = 2;
  // 分身选择器
  final _agents = ['灯泡','编剧','导演','小说家','斥候','匠作营','巡检司'];
  int _agentIdx = 0;
  double _agentScroll = 0;

  @override
  void initState() {
    super.initState();
    _fetchCounts();
    _orbCtrl = AnimationController(vsync:this,duration:Duration(seconds:1))
      ..addListener((){
        if(_orbPointers.isEmpty) _orbZoom += (1.0 - _orbZoom)*0.0003;
        setState((){});
      })..repeat();
    _updateGreeting();
    _fetchStatus();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) { _fetchCounts(); });
  }

  @override void dispose(){ _orbCtrl.dispose(); _timer?.cancel(); _voiceTimer?.cancel(); super.dispose(); }

  void _fetchCounts() async {
    try {
      final r = await http.get(Uri.parse('http://192.168.1.4:8899/dispatched')).timeout(Duration(seconds:3));
      if (r.statusCode==200) {
        final d = jsonDecode(r.body);
        if (d is List) {
          int approved=0, learned=0, unread=0;
          for (var t in d) {
            final st = t['status'] ?? '';
            if (st == 'done') { learned++; } else { approved++; }
          }
          if(mounted) setState(() { _completedTasks=approved; _learnedSkills=learned; _unreadMsg=unread; });
        }
      }
    } catch (_) {}
  }

  void _updateGreeting() {
    final h = DateTime.now().hour;
    setState(() { _greeting = h < 6 ? '夜深了·我在' : h < 12 ? '早上好' : h < 18 ? '下午好' : '晚上好'; });
  }

  void _fetchStatus() async {
    try {
      final r = await http.get(Uri.parse('http://192.168.1.2:8848/health')).timeout(Duration(seconds: 3));
      if (r.statusCode == 200) setState(() { _statusDetail = '所有系统正常'; return; });
    } catch (_) {}
    setState(() { _statusDetail = '白鼠未响应·本地运行中'; });
  }

  double _orbDist(Map<int,Offset> pts){
    if(pts.length<2) return 0;
    final v=pts.values.toList();
    return (v[0]-v[1]).distance;
  }

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    final orbBase = (sw * 0.7).clamp(260.0, 380.0);
    final orbSize = orbBase * _orbZoom;

    return Scaffold(backgroundColor: HermesTheme.bg, body: SafeArea(child: Column(children: [
      SizedBox(height: 18),
      SizedBox(height: orbSize + 20, child: Listener(
        onPointerDown:(e){
          _orbPointers[e.pointer]=e.position;
          if(_orbPointers.length>=2){ _orbInitDist=_orbDist(_orbPointers); _orbInitZoom=_orbZoom; }
        },
        onPointerMove:(e){
          if(!_orbPointers.containsKey(e.pointer)) return;
          _orbPointers[e.pointer]=e.position;
          if(_orbPointers.length>=2 && _orbInitDist>0){
            final d=_orbDist(_orbPointers);
            final target=(_orbInitZoom*d/_orbInitDist).clamp(0.7,2.5);
            _orbZoom += (target - _orbZoom) * 0.3;
          }
          setState((){});
        },
        onPointerUp:(e){_orbPointers.remove(e.pointer);if(_orbPointers.length<2){_orbInitDist=0;}},
        child: Center(child: SymbioOrb(key: _orbKey, size: orbSize, status: 'online', voiceState: _voiceState, onTap: _toggleMic)),
      )),
      SizedBox(height: 10),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        // 麦克风·Listener替代GestureDetector防白框bug
        Listener(onPointerDown: (_) { HapticFeedback.mediumImpact(); _toggleMic(); },
        child: Container(width: 56, height: 56,
          decoration: BoxDecoration(shape: BoxShape.circle, color: _voiceState != 'idle' ? HermesTheme.gold.withAlpha(40) : Colors.transparent, border: Border.all(color: _voiceState != 'idle' ? HermesTheme.gold : Colors.white38, width: 1.5)),
          child: Icon(_voiceState == 'listening' ? Icons.mic : _voiceState == 'speaking' ? Icons.volume_up : Icons.mic_none, color: _voiceState != 'idle' ? HermesTheme.gold : Colors.white54),
        )),
        SizedBox(width: 12),
        // 分身滚轮
        _agentDial(),
      ]),
      SizedBox(height: 5),
      Text(_greeting, style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w300)),
      Text(_statusDetail, style: TextStyle(color: HermesTheme.gold, fontSize: 12)),
      SizedBox(height: 8),
      // 四列统计·Listener替代GestureDetector防白框bug
      Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Row(children: [
        _sc('$_completedTasks','审批',Color(0xFF5CB8A0), onTap: ()=>PresenceTab.onNavigate?.call(2)),
        _sc('$_learnedSkills','学习',HermesTheme.gold, onTap: ()=>PresenceTab.onNavigate?.call(3)),
        _sc('$_unreadMsg','消息',Color(0xFF60A5FA), onTap: ()=>PresenceTab.onNavigate?.call(2)),
      ])),
      SizedBox(height: 12),
      // 聊天入口
      Listener(
        onPointerDown: (_) { HapticFeedback.mediumImpact(); PresenceTab.onNavigate?.call(2); },
        child: Container(
        margin: EdgeInsets.symmetric(horizontal: 16),
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(color: Colors.white.withAlpha(8), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white.withAlpha(15))),
        child: Row(children: [
          Icon(Icons.chat_bubble_outline, color: Colors.white30, size: 18),
          SizedBox(width: 10),
          Text('和${_agents[_agentIdx]}说话...', style: TextStyle(color: Colors.white.withAlpha(51), fontSize: 14)),
          Spacer(),
          Icon(Icons.send, color: HermesTheme.gold, size: 18),
        ]),
      ),
      ),
      SizedBox(height: 10),
      _recentMemories(),
      SizedBox(height: 16),
    ])));
  }

  Widget _agentDial() {
    final colors = [HermesTheme.gold, Color(0xFF60A5FA), Color(0xFFF59E0B), Color(0xFFA78BFA), Color(0xFF34D399), Color(0xFF60A5FA), Color(0xFFF87171)];
    return SizedBox(width: 150, child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: List.generate(_agents.length, (i) => Listener(
      onPointerDown: (_) => setState(() => _agentIdx = i),
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 3),
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: i==_agentIdx ? colors[i].withAlpha(40) : Colors.transparent, borderRadius: BorderRadius.circular(12), border: Border.all(color: i==_agentIdx ? colors[i] : Colors.white12)),
        child: Text(_agents[i], style: TextStyle(color: i==_agentIdx ? colors[i] : Colors.white30, fontSize: 11, fontWeight: i==_agentIdx ? FontWeight.w600 : FontWeight.normal)),
      ),
    )))));
  }

  Widget _sc(String v, String l, Color c, {VoidCallback? onTap}) => Expanded(
    child: Listener(
      onPointerDown: (_) { HapticFeedback.lightImpact(); onTap?.call(); },
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 6),
        margin: EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: c.withAlpha(15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(children: [
          Text(v, style: TextStyle(color: c, fontSize: 16, fontWeight: FontWeight.bold)),
          Text(l, style: TextStyle(color: c.withAlpha(100), fontSize: 8)),
        ]),
      ),
    ),
  );

  Widget _recentMemories() {
    final items = ['App神经星图上线', '记忆系统370条'];
    return Padding(padding: EdgeInsets.symmetric(horizontal: 20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('最近记忆', style: TextStyle(color: Colors.white38, fontSize: 12)),
      SizedBox(height: 4),
      ...items.map((m) => Padding(padding: EdgeInsets.only(bottom: 2), child: Row(children: [
        Icon(Icons.circle, size: 4, color: HermesTheme.gold),
        SizedBox(width: 6),
        Text(m, style: TextStyle(color: Colors.white54, fontSize: 12)),
      ]))),
    ]));
  }
}
