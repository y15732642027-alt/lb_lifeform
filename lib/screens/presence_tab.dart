/// 首页·经典版·Listener替代GestureDetector防白框bug
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../core/theme.dart';
import '../core/voice_stream.dart';
import '../widgets/symbio_orb.dart';

class PresenceTab extends StatefulWidget {
  // 静态回调·Listener替代GestureDetector绕过Flutter Web白框bug
  static void Function(int tab, int subTab)? onNavigate;
  static void jump(int tab, [int subTab = 0]) => onNavigate?.call(tab, subTab);
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

  // 语音录制
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();
  WebSocket? _ws;
  bool _isRecording = false;
  String? _recordPath;
  StreamSubscription<RecordState>? _recSub;

  void _toggleMic() {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('MIC_TAP·状态:$_voiceState'), duration: Duration(seconds:2)));
    HapticFeedback.mediumImpact();
    if (_voiceState == 'idle') {
      _startWebRTC();
    } else {
      _stopWebRTC();
    }
  }

  Future<void> _startRecording() async {
    try {
      // 激活iOS AudioSession
      await _recorder.listInputDevices();
      // 检查录音权限
      final hasPerm = await _recorder.hasPermission();
      if (!hasPerm) {
        throw Exception('麦克风权限被拒绝·请在设置中开启');
      }
      final dir = await getApplicationDocumentsDirectory();
      _recordPath = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.wav';
      // aacLc iOS兼容·采样率16k·单声道
      await _recorder.start(const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 44100,
        numChannels: 1,
        
      ), path: _recordPath!);
      _isRecording = true;
      if (mounted) setState(() { _voiceState = 'listening'; _voiceEnergy = 0.3; });
      _voiceTimer = Timer.periodic(Duration(milliseconds: 200), (_) {
        if (mounted) setState(() => _voiceEnergy = 0.2 + (DateTime.now().millisecond % 100) / 200.0);
      });
    } catch (e) {
      final errMsg = e.toString();
      if (mounted) {
        setState(() { _voiceState = 'idle'; _voiceEnergy = 0; });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('录音: $errMsg', maxLines:3), duration: Duration(seconds:4)));
      }
    }
  }

  Future<void> _stopRecording() async {
    _voiceTimer?.cancel();
    if (_isRecording) {
      _isRecording = false;
      await _recorder.stop();
      if (mounted) setState(() { _voiceState = 'processing'; _voiceEnergy = 0.6; });
      await _processRecording();
      if (mounted) setState(() { _voiceState = 'idle'; _voiceEnergy = 0; });
    }
  }

  Future<void> _processRecording() async {
    _voiceTimer?.cancel();
    if (_recordPath == null) return;

    try {
      // 上传录音到语音API
      final uri = Uri.parse('http://symbio.xin/voice');
      final request = http.MultipartRequest('POST', uri);
      request.files.add(await http.MultipartFile.fromPath('file', _recordPath!));
      final response = await request.send().timeout(Duration(seconds: 30));
      final body = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        final data = jsonDecode(body);
        final text = data['text'] ?? '';
        final reply = data['reply'] ?? '';
        final audioB64 = data['audio'] ?? '';

        print('语音: text=$text reply=$reply');

        // 播放回复音频
        if (audioB64.isNotEmpty) {
          final mp3Bytes = base64Decode(audioB64);
          final dir = await getApplicationDocumentsDirectory();
          final mp3Path = '${dir.path}/reply_${DateTime.now().millisecondsSinceEpoch}.mp3';
          final mp3File = File(mp3Path);
          await mp3File.writeAsBytes(mp3Bytes);
          print('[AUDIO] 播放 '+mp3Path+' 长度='+mp3Bytes.length.toString()); await _player.play(DeviceFileSource(mp3Path));
        }
      }
    } catch (e) {
      print('语音处理失败: $e');
    }

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

  @override void dispose(){ _orbCtrl.dispose(); _timer?.cancel(); _voiceTimer?.cancel(); _recSub?.cancel(); _recorder.dispose(); _player.dispose(); _ws?.close(); super.dispose(); }

  void _fetchCounts() async {
    try {
      final r = await http.get(Uri.parse('http://symbio.xin:8899/dispatched')).timeout(Duration(seconds:3));
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
      final r = await http.get(Uri.parse('http://symbio.xin:8848/health')).timeout(Duration(seconds: 3));
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
        child: Center(child: SymbioOrb(key: _orbKey, size: orbSize, status: 'online', voiceState: _voiceState)),
      )),
      SizedBox(height: 10),
      // 麦克风·最简单
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        IconButton(
          icon: Icon(_voiceState == 'listening' ? Icons.mic : Icons.mic_none, size: 28),
          color: _voiceState != 'idle' ? HermesTheme.gold : Colors.white54,
          onPressed: _toggleMic,
        ),
        SizedBox(width: 12),
        _agentDial(),
      ]),
      SizedBox(height: 5),
      Text(_greeting, style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w300)),
      Text(_statusDetail, style: TextStyle(color: HermesTheme.gold, fontSize: 12)),
      SizedBox(height: 8),
      // 四列统计·Listener替代GestureDetector防白框bug
      Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Row(children: [
        _sc('$_completedTasks','已完成',Color(0xFF5CB8A0), onTap: ()=> _completedTasks > 0 ? PresenceTab.jump(2,1) : null),
        _sc('$_learnedSkills','待处理',HermesTheme.gold),
        _sc('$_unreadMsg','消息',Color(0xFF60A5FA), onTap: ()=> _unreadMsg > 0 ? PresenceTab.jump(2) : null),
      ])),
      SizedBox(height: 12),
      // 聊天入口
      Listener(
        onPointerDown: (_) { HapticFeedback.mediumImpact(); PresenceTab.jump(2,3); },
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

        VoiceStream? _voice;

        Future<void> _startWebRTC() async {
        if (mounted) setState(() { _voiceState = 'connecting'; _voiceEnergy = 0.5; });
        try {
        _voice = VoiceStream();
        _voice!.onMessage = (type, data) {
          if (type == 'stt') {
            if (mounted) setState(() { _voiceEnergy = 0.8; });
          } else if (type == 'tts') {
            if (mounted) setState(() { _voiceState = 'responding'; _voiceEnergy = 1.0; });
            Future.delayed(Duration(seconds: 2), () {
              if (mounted) setState(() { _voiceState = 'connected'; _voiceEnergy = 0.5; });
            });
          }
        };
        await _voice!.connect('wss://ws.symbio.xin');
        if (mounted) setState(() { _voiceState = 'connected'; _voiceEnergy = 0.5; });
        } catch (e) {
        if (mounted) {
          setState(() { _voiceState = 'idle'; _voiceEnergy = 0; });
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('WebRTC: $e'), duration: Duration(seconds:3)));
        }
        }
        }

        Future<void> _stopWebRTC() async {
        await _voice?.disconnect();
        _voice = null;
        if (mounted) setState(() { _voiceState = 'idle'; _voiceEnergy = 0; });
        }
        }
