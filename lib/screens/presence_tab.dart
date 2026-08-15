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

  String _tempRecordPath() => '\${(()=>getTemporaryDirectory)()}/test2800.m4a';

class _PresenceTabState extends State<PresenceTab> with SingleTickerProviderStateMixin {
  late AnimationController _orbCtrl;
  String _greeting = '', _statusDetail = '所有系统正常';
  String _voiceState = 'idle';
  String _voiceText = '', _voiceReply = '';
  List<String> _recentTasks = [];
  double _voiceEnergy = 0.0;
  Timer? _voiceTimer;

  // 语音录制
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();
  WebSocket? _ws;
  VoiceStream? _vs;
  bool _isRecording = false;
  String? _recordPath;
  StreamSubscription<RecordState>? _recSub;
  StreamSubscription<Uint8List>? _pcmSub;

  void _toggleMic() {
    HapticFeedback.mediumImpact();
    // 对话中·灯泡在说/在思考·点麦=打断·马上听新的
    if (_conversationMode && (_voiceState == 'speaking' || _voiceState == 'processing')) {
      _interruptAndListen();
      return;
    }
    if (_isRecording) {
      _stopStreaming();
    } else {
      _startStreaming();
    }
  }

  Future<void> _interruptAndListen() async {
    try { await _player.stop(); } catch (_) {}
    _audioQueue.clear();
    _audioPlaying = false;
    _vs?.sendInterrupt();
    if (mounted) setState(() { _voiceReply = ''; _voiceState = 'listening'; });
  }

  // ===== 流式语音: 按住说话·VAD自动断句·同一个灯泡 =====
  bool _conversationMode = false; // 连续对话开关·点一次进·再点出
  final List<List<int>> _audioQueue = []; // 逐句音频队列·顺序播放
  bool _audioPlaying = false;

  Future<void> _startStreaming() async {
    try {
      await _recorder.listInputDevices();
      final hasPerm = await _recorder.hasPermission();
      if (!hasPerm) {
        throw Exception('麦克风权限被拒绝·请在设置中开启');
      }
      // 连流式服务器(外网wss)
      _vs = VoiceStream();
      _vs!.onMessage = _onStreamMsg;
      await _vs!.connect('wss://ws.symbio.xin');
      _conversationMode = true;
      await _resumeStream();
    } catch (e) {
      print('流式启动失败: $e → 退回文件录音');
      _conversationMode = false;
      _startRecording();
    }
  }

  Future<void> _resumeStream() async {
    if (!_conversationMode) return;
    try {
      final stream = await _recorder.startStream(const RecordConfig(
        encoder: AudioEncoder.pcm16bits, sampleRate: 16000, numChannels: 1,
      ));
      _pcmSub = stream.listen((chunk) {
        _vs?.send(chunk);
        _detectTalkWhilePlaying(chunk);
      });
      _isRecording = true;
      if (mounted) setState(() { _voiceState = 'listening'; _voiceEnergy = 0.5; });
    } catch (e) {
      print('收音恢复失败: $e');
    }
  }

  int _strongCount = 0;
  double _echoBaseline = -1; // -1=未采样·播放初期实测回声水平
  double _baseAccum = 0;
  int _baseSamples = 0;
  /// 自然打断·基线法: 播放头0.5秒采回声基线·之后能量>基线2.5倍且>8000才算人声
  /// 音量自适应·噪音进基线自动被滤
  void _detectTalkWhilePlaying(List<int> chunk) {
    if (!_audioPlaying) {
      _strongCount = 0;
      _echoBaseline = -1;
      _baseAccum = 0;
      _baseSamples = 0;
      return;
    }
    if (chunk.length < 200) return;
    double energy = 0;
    final n = chunk.length ~/ 2 < 100 ? chunk.length ~/ 2 : 100;
    for (int i = 0; i < n; i++) {
      final v = (chunk[i * 2] | (chunk[i * 2 + 1] << 8)) - 32768;
      energy += v.abs();
    }
    energy /= n;
    // 基线采样期: 播放前0.5秒(10块)·只测回声不判定
    if (_echoBaseline < 0) {
      _baseAccum += energy;
      _baseSamples++;
      if (_baseSamples >= 10) {
        _echoBaseline = _baseAccum / _baseSamples;
        print('回声基线: ${_echoBaseline.round()}');
      }
      return;
    }
    if (energy > _echoBaseline * 2.5 && energy > 8000) {
      _strongCount++;
      if (_strongCount >= 6) {
        _strongCount = 0;
        print('自然打断: 人声检测(基线${_echoBaseline.round()}·当前${energy.round()})');
        _interruptAndListen();
      }
    } else {
      _strongCount = 0;
    }
  }

  Future<void> _stopStreaming() async {
    _conversationMode = false;
    _isRecording = false;
    try { await _pcmSub?.cancel(); } catch (_) {}
    try { await _recorder.stop(); } catch (_) {}
    try { await _vs?.disconnect(); } catch (_) {}
    _vs = null;
    if (mounted) setState(() { _voiceState = 'idle'; });
  }

  void _onStreamMsg(String type, dynamic data) {
    if (type == 'stt') {
      if (mounted) setState(() { _voiceText = data.toString(); _voiceReply = ''; _voiceState = 'processing'; });
    } else if (type == 'tts_delta') {
      // 流式增量·回复逐块长出来(GPT式打字感)
      if (mounted) setState(() { _voiceReply += data.toString(); });
    } else if (type == 'tts') {
      // 完整回复兜底
      if (mounted) setState(() { _voiceReply = data.toString(); });
    } else if (type == 'stop') {
      // 服务端检测到插话·立即停播让位
      try { _player.stop(); } catch (_) {}
      _audioQueue.clear();
      _audioPlaying = false;
      if (mounted) setState(() { _voiceState = 'listening'; });
    } else if (type == 'audio') {
      // 逐句音频·进队列顺序播放
      _audioQueue.add(data as List<int>);
      if (!_audioPlaying) {
        _playNextFromQueue();
      }
    }
  }

  Future<void> _playNextFromQueue() async {
    if (_audioQueue.isEmpty) {
      _audioPlaying = false;
      return;
    }
    _audioPlaying = true;
    final bytes = _audioQueue.removeAt(0);
    if (mounted) setState(() { _voiceState = 'speaking'; });
    try {
      final dir = await getApplicationDocumentsDirectory();
      final p = '${dir.path}/reply_${DateTime.now().millisecondsSinceEpoch}.wav';
      await File(p).writeAsBytes(bytes);
      _vs?.sendPlaying();
      await _player.stop();
      await _player.play(DeviceFileSource(p));
      // 播完回调: 通知服务器·播下一段
      _player.onPlayerComplete.listen((_) {
        _vs?.sendPlayed();
        _playNextFromQueue();
      });
    } catch (e) {
      print('音频播放失败: $e');
      _vs?.sendPlayed();
      _playNextFromQueue();
    }
  }

    Future<void> _startRecording() async {
    try {
      // 激活iOS AudioSession(关键·没有它录到的是静音)
      await _recorder.listInputDevices();
      // 检查录音权限
      final hasPerm = await _recorder.hasPermission();
      if (!hasPerm) {
        throw Exception('麦克风权限被拒绝·请在设置中开启');
      }
      final dir = await getApplicationDocumentsDirectory();
      _recordPath = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.wav';
      await _recorder.start(const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 16000,
        numChannels: 1,
      ), path: _recordPath!);
      _isRecording = true;
      if (mounted) setState(() { _voiceState = 'listening'; _voiceEnergy = 0.3; });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('✅ 录音启动OK'), duration: Duration(seconds:2)));
    } catch (e) {
      if (mounted) {
        setState(() { _voiceState = 'idle'; _voiceEnergy = 0; });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('录音失败: $e', maxLines: 3), duration: Duration(seconds:5)));
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
      // 双路语音上传: 家里WiFi直连局域网(快)·连不上走外网隧道
      // 文件读成字节·每条路各自建MultipartFile(流不能复用)
      final bytes = await File(_recordPath!).readAsBytes();
      http.StreamedResponse response;
      try {
        final lanReq = http.MultipartRequest('POST', Uri.parse('http://192.168.1.4:8898/voice'));
        lanReq.files.add(http.MultipartFile.fromBytes('file', bytes, filename: 'voice.wav'));
        response = await lanReq.send().timeout(Duration(seconds: 4));
      } catch (_) {
        final wanReq = http.MultipartRequest('POST', Uri.parse('http://symbio.xin/voice'));
        wanReq.files.add(http.MultipartFile.fromBytes('file', bytes, filename: 'voice.wav'));
        response = await wanReq.send().timeout(Duration(seconds: 90));
      }
      final body = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        final data = jsonDecode(body);
        final text = data['text'] ?? '';
        final reply = data['reply'] ?? '';
        final audioB64 = data['audio'] ?? '';

        print('语音: text=$text reply=$reply');

        // 文字必显: 无论音频播放成不成·回复必须看得见
        if (mounted) setState(() { _voiceText = text; _voiceReply = reply; });

        // 播放回复音频
        if (audioB64.isNotEmpty) {
          if (mounted) setState(() { _voiceState = 'speaking'; });
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
      final r = await http.get(Uri.parse('http://symbio.xin/dispatched')).timeout(Duration(seconds:5));
      if (r.statusCode==200) {
        final d = jsonDecode(r.body);
        if (d is List) {
          int approved=0, learned=0, unread=0;
          for (var t in d) {
            final st = t['status'] ?? '';
            if (st == 'done') { learned++; } else { approved++; }
          }
          // 最近任务(最新两条)
          final titles = <String>[];
          for (var t in d.reversed) {
            if (titles.length >= 2) break;
            final task = (t['task'] ?? '').toString();
            final agent = (t['agent'] ?? '').toString();
            if (task.isNotEmpty) titles.add('$agent: $task');
          }
          if(mounted) setState(() { _completedTasks=approved; _learnedSkills=learned; _unreadMsg=unread; _recentTasks=titles; });
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
      final r = await http.get(Uri.parse('http://symbio.xin/health')).timeout(Duration(seconds: 5));
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
        // 黄灯: 真实录音状态指示灯·_isRecording=true才亮
        AnimatedContainer(
          duration: Duration(milliseconds: 200),
          width: 14, height: 14,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _isRecording ? Color(0xFFFFA500) : Colors.white12,
            boxShadow: _isRecording
                ? [BoxShadow(color: Color(0xFFFFA500).withAlpha(180), blurRadius: 12, spreadRadius: 3)]
                : [],
          ),
        ),
        SizedBox(width: 10),
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
      // 语音对话显示: 你说+灯泡回复
      if (_voiceText.isNotEmpty || _voiceReply.isNotEmpty)
        Padding(padding: EdgeInsets.symmetric(horizontal: 24, vertical: 6), child: Column(children: [
          if (_voiceText.isNotEmpty)
            Text('你说: $_voiceText', style: TextStyle(color: Colors.white54, fontSize: 13)),
          if (_voiceReply.isNotEmpty)
            Padding(padding: EdgeInsets.only(top: 4), child: Text('灯泡: $_voiceReply', style: TextStyle(color: HermesTheme.gold, fontSize: 15, fontWeight: FontWeight.w500))),
        ])),
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
    // 实时数据: 从任务队列拉最新两条(不再是写死的字)
    final items = <String>[];
    if (_recentTasks.isNotEmpty) {
      items.addAll(_recentTasks);
    } else {
      items.add('正在拉取任务队列...');
    }
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
