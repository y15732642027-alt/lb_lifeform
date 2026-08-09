import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:record/record.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/theme.dart';

class MessagesTab extends StatefulWidget {
  static void switchTo(int tab) {
    MessagesTabState.instance?._tabController?.animateTo(tab);
  }
  const MessagesTab({super.key});
  @override
  State<MessagesTab> createState() => MessagesTabState();
}

class MessagesTabState extends State<MessagesTab> with SingleTickerProviderStateMixin {
  static MessagesTabState? instance;
  late TabController _tabController;
  List<Map<String,dynamic>> _tasks = [], _approvals = [], _notifs = [];
  final List<Map<String,String>> _conversations = [];
  final _chatCtrl = TextEditingController();
  String _chatReply = '';
  final AudioRecorder _chatRecorder = AudioRecorder();
  bool _isChatRecording = false;
  String? _chatRecordPath;
  final Set<String> _removed = {};
  int? _expanded;
  Timer? _timer;
  bool _loading = true;
  bool _busy = false;
  final String _base = 'http://symbio.xin:8848';

  @override
  void initState() {
    super.initState();
    instance = this;
    _tabController = TabController(length: 4, vsync: this);
    _fetch();
    _timer = Timer.periodic(Duration(seconds: 5), (_) => _fetch());
  }

  @override
  void dispose() { _timer?.cancel(); _tabController.dispose(); _chatCtrl.dispose(); _chatRecorder.dispose(); super.dispose(); }

  Future<void> _fetch() async {
    if (_busy) return;
    _busy = true;
    // Tasks from white mouse
    _tasks = [];
    try {
      final r = await http.get(Uri.parse('$_base/tasks')).timeout(Duration(seconds:5));
      if (r.statusCode==200) {
        final d = jsonDecode(r.body);
        _tasks = (d['tasks']??[]).map<Map<String,dynamic>>((t)=>Map<String,dynamic>.from(t)).toList();
      }
    } catch (_) {}
    // Dispatched tasks from local
    try {
      final r = await http.get(Uri.parse('http://symbio.xin:8899/dispatched')).timeout(Duration(seconds:3));
      if (r.statusCode==200) {
        final d = jsonDecode(r.body);
        if (d is List) {
          _tasks.addAll(d.map<Map<String,dynamic>>((t)=>Map<String,dynamic>.from(t)));
        }
      }
    } catch (_) {}
    // Approvals
    try {
      final r = await http.get(Uri.parse('$_base/approvals')).timeout(Duration(seconds:3));
      if (r.statusCode==200) {
        final d = jsonDecode(r.body);
        _approvals = (d['approvals']??[]).where((a)=>a['status']=='pending').map<Map<String,dynamic>>((a)=>Map<String,dynamic>.from(a)).toList();
      }
    } catch (_) {}
    // Notifications
    try {
      final r = await http.get(Uri.parse('$_base/notifications')).timeout(Duration(seconds:3));
      if (r.statusCode==200) {
        final d = jsonDecode(r.body);
        _notifs = (d is List ? d : []).map<Map<String,dynamic>>((n)=>Map<String,dynamic>.from(n)).toList();
      }
    } catch (_) {}
    setState(() { _loading = false; _busy = false; });
  }

  void _showDetail(String type, Map<String,dynamic> item) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Color(0xFF0A0A10),
        title: Text('$type详情', style: TextStyle(color: HermesTheme.gold, fontSize: 16)),
        content: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            for (final e in item.entries)
              if (e.key != 'id')
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: RichText(text: TextSpan(children: [
                    TextSpan(text: '${e.key}: ', style: TextStyle(color: Colors.white54, fontSize: 13)),
                    TextSpan(text: '${e.value}', style: TextStyle(color: Colors.white, fontSize: 13)),
                  ])),
                ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('关闭', style: TextStyle(color: HermesTheme.gold)))
        ],
      ),
    );
  }

  Future<void> _approve(String id, String action) async {
    try {
      await http.post(Uri.parse('$_base/respond'), headers: {'Content-Type':'application/json'}, body: jsonEncode({'id':id,'action':action}));
    } catch (_) {}
    _removed.add(id);
    setState(() { _approvals.removeWhere((a)=>a['id']==id); });
  }

  Future<void> _startChatRecord() async {
    try {
      final hasPerm = await _chatRecorder.hasPermission();
      if (!hasPerm) return;
      final dir = await getApplicationDocumentsDirectory();
      _chatRecordPath = '${dir.path}/chat_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _chatRecorder.start(const RecordConfig(encoder: AudioEncoder.aacLc, sampleRate: 16000, numChannels: 1), path: _chatRecordPath!);
      if (mounted) setState(() => _isChatRecording = true);
    } catch (_) {}
  }

  Future<void> _stopChatRecord() async {
    if (!_isChatRecording) return;
    if (mounted) setState(() => _isChatRecording = false);
    try {
      await _chatRecorder.stop();
      if (_chatRecordPath == null) return;
      // 上传语音·得到文字·发送
      final uri = Uri.parse('http://symbio.xin:8898/voice');
      final request = http.MultipartRequest('POST', uri);
      request.files.add(await http.MultipartFile.fromPath('file', _chatRecordPath!));
      final response = await request.send().timeout(Duration(seconds: 30));
      if (response.statusCode == 200) {
        final data = jsonDecode(await response.stream.bytesToString());
        final text = data['text'] ?? '';
        final reply = data['reply'] ?? '';
        if (text.isNotEmpty) {
          _chatCtrl.text = text;
          _sendMsg(text);
        }
      }
    } catch (_) {}
  }

  
  Future<void> _sendMsg(String text) async {
    if(text.trim().isEmpty) return;
    setState((){
      _conversations.add({'from':'user','text':text,'time':DateTime.now().toIso8601String()});
    });
    _chatCtrl.clear();
    try {
      // 走Agent API(8642)·和微信共享上下文
      final resp = await http.post(
        Uri.parse('http://symbio.xin:8642/v1/chat/completions'),
        headers: {'Content-Type':'application/json', 'Authorization':'Bearer voice-bridge-key-2026'},
        body: jsonEncode({'model':'deepseek-v4-flash','messages':[{'role':'user','content':text}],'max_tokens':200}),
      ).timeout(Duration(seconds:30));
      final data = jsonDecode(resp.body);
      final reply = (data['choices']??[]).isNotEmpty ? (data['choices'][0]['message']['content']??'(空)') : '(无回复)';
      if(mounted) setState((){
        _conversations.add({'from':'bulb','text':reply,'time':DateTime.now().toIso8601String()});
      });
    } catch(e) {
      if(mounted) setState((){
        _conversations.add({'from':'bulb','text':'灯泡暂时无法连接·请稍后重试','time':DateTime.now().toIso8601String()});
      });
    }
  }
  }

  void switchTo(int tab) => _tabController.animateTo(tab);

  Widget _buildTaskList() {
    if (_tasks.isEmpty) return Center(child: Text('暂无任务', style: TextStyle(color: Colors.white38)));
    return ListView.builder(
      itemCount: _tasks.length,
      itemBuilder: (_, i) {
        final t = _tasks[i];
        final st = t['status'] ?? 'assigned';
        final color = st == 'running' ? Color(0xFF60A5FA) : st == 'done' ? Color(0xFF5CB878) : HermesTheme.gold;
        final icon = st == 'running' ? '⏳' : st == 'done' ? '✅' : '📋';
        final prog = st == 'done' ? 1.0 : st == 'running' ? 0.65 : 0.0;
        final elapsed = _timeSince(t['time'] ?? '');
        final eta = st == 'running' ? '约${(elapsed*0.5).round()}分' : st == 'done' ? '已完成' : '等待中';
        return GestureDetector(
          onTap: () => setState(() => _expanded = _expanded == i ? null : i),
          child: Card(
          color: Color(0xFF0D0D12),
          margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Padding(padding: EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text('$icon ', style: TextStyle(fontSize: 16)),
              Expanded(child: Text(t['task']??'任务', style: TextStyle(color: Colors.white70, fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis)),
            ]),
            SizedBox(height: 8),
            Row(children: [
              _tag(t['agent']??'', color),
              SizedBox(width: 6),
              if(t['galaxy']!=null) _tag(t['galaxy'], color.withAlpha(80)),
              SizedBox(width: 6),
              _tag(st == 'running' ? '进行中' : st == 'done' ? '已完成' : '已分配', color),
              Spacer(),
              Text(eta, style: TextStyle(color: Colors.white24, fontSize: 10)),
            ]),
            SizedBox(height: 6),
            ClipRRect(borderRadius: BorderRadius.circular(2), child: LinearProgressIndicator(value: prog, backgroundColor: Colors.white10, color: color, minHeight: 3)),
            SizedBox(height: 4),
            Text(t['time']??'', style: TextStyle(color: Colors.white.withAlpha(20), fontSize: 9)),
          ])),
        ));
      },
    );
  }

  double _timeSince(String t) {
    try {
      final dt = DateTime.tryParse(t) ?? DateTime.now().subtract(Duration(minutes: 1));
      return DateTime.now().difference(dt).inMinutes.toDouble();
    } catch (_) { return 1; }
  }

  Widget _tag(String label, Color c) => Container(
    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(color: c.withAlpha(25), borderRadius: BorderRadius.circular(4)),
    child: Text(label, style: TextStyle(color: c, fontSize: 10)),
  );

  @override
  Widget build(BuildContext ctx) {
    return SafeArea(child: Column(children: [
      SizedBox(height:4),
      TabBar(controller:_tabController, indicatorColor:Color(0xFFe94560), labelColor:Color(0xFFe94560), unselectedLabelColor:HermesTheme.textSecondary,
        tabs: [Tab(text:'任务 ${_tasks.length>0?"(${_tasks.length})":""}'), Tab(text:'审批 ${_approvals.length>0?"(${_approvals.length})":""}'), Tab(text:'通知 ${_notifs.length>0?"(${_notifs.length})":""}'), Tab(text:'对话')], onTap:(_)=>HapticFeedback.lightImpact()),
      Expanded(child: TabBarView(controller:_tabController, children: [
        _buildTaskList(),
        _buildList(_approvals, (a)=>Column(children:[
         ListTile(title:Text('⚠️ ${a['title']??''}',style:TextStyle(color:Color(0xFFef4444))),subtitle:Text(a['agent']??'',style:TextStyle(color:HermesTheme.textSecondary,fontSize:12)),trailing:Row(mainAxisSize:MainAxisSize.min,children:[_btn('同意',(){HapticFeedback.lightImpact();_approve(a['id']??'','approved');},Color(0xFF00cc66)),SizedBox(width:4),_btn('拒绝',(){HapticFeedback.lightImpact();_approve(a['id']??'','rejected');},Color(0xFFef4444))]),onTap:()=>setState(()=>_expanded=_expanded==a.hashCode?null:a.hashCode)),
         if (_expanded==a.hashCode) Container(padding:EdgeInsets.all(12),color:Color(0xFF1a1a3e),child:SelectableText(a['desc']??'暂无详情',style:TextStyle(color:HermesTheme.textSecondary,fontSize:13)))
        ])),
        _buildList(_notifs, (n)=>Column(children:[
         ListTile(title:Text('${n['icon']??'📢'} ${n['title']??''}',style:TextStyle(color:Color(0xFFf59e0b))),subtitle:Text(n['desc']??'',style:TextStyle(color:HermesTheme.textSecondary,fontSize:12)),onTap:()=>setState(()=>_expanded=_expanded==n.hashCode?null:n.hashCode)),
         if (_expanded==n.hashCode) Container(padding:EdgeInsets.all(12),color:Color(0xFF1a1a3e),child:SelectableText(n['detail']??'暂无',style:TextStyle(color:HermesTheme.textSecondary,fontSize:13)))
        ])),
        // 对话tab
        Column(children: [
          Expanded(child: ListView.builder(
            itemCount: _conversations.length,
            itemBuilder: (_,i){
              final m=_conversations[i];
              final isMe=m['role']=='me';
              return Align(alignment:isMe?Alignment.centerRight:Alignment.centerLeft,child:Container(
                margin:EdgeInsets.symmetric(vertical:2,horizontal:12),
                padding:EdgeInsets.all(10),
                decoration:BoxDecoration(color:isMe?HermesTheme.gold.withAlpha(40):Colors.white.withAlpha(10),borderRadius:BorderRadius.circular(12)),
                child:Text(m['text']!,style:TextStyle(color:isMe?HermesTheme.gold:Colors.white70,fontSize:14)),
              ));
            },
          )),
          Container(padding:EdgeInsets.all(8),child:Row(children:[
            Expanded(child:TextField(controller:_chatCtrl,style:TextStyle(color:Colors.white),decoration:InputDecoration(hintText:'输入...',hintStyle:TextStyle(color:Colors.white24),border:InputBorder.none,contentPadding:EdgeInsets.symmetric(horizontal:12,vertical:8)),onSubmitted:_sendMsg)),
            Row(mainAxisSize: MainAxisSize.min, children: [
            GestureDetector(
              onLongPressStart: (_) => _startChatRecord(),
              onLongPressEnd: (_) => _stopChatRecord(),
              onTap: () => HapticFeedback.lightImpact(),
              child: Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: _isChatRecording ? Color(0xFFef4444).withAlpha(40) : HermesTheme.gold.withAlpha(15),
                  shape: BoxShape.circle),
                child: Icon(_isChatRecording ? Icons.mic : Icons.mic_none, color: _isChatRecording ? Color(0xFFef4444) : HermesTheme.gold, size: 22),
              ),
            ),
            SizedBox(width: 6),
            IconButton(icon:Icon(Icons.send,color:HermesTheme.gold),onPressed:(){HapticFeedback.mediumImpact();_sendMsg(_chatCtrl.text);})
          ]),
          ])),
        ]),
      ]))
    ]));
  }

  Widget _buildList(List<Map<String,dynamic>> items, Widget Function(Map<String,dynamic>) builder) {
    if (_loading) return Center(child: CircularProgressIndicator(color: Color(0xFFe94560)));
    if (items.isEmpty) return Center(child: Text('暂无', style: TextStyle(color: HermesTheme.textSecondary)));
    return ListView.builder(itemCount:items.length, itemBuilder:(_,i)=>builder(items[i]));
  }

  Widget _btn(String label, VoidCallback fn, Color color) {
    return GestureDetector(onTap:fn, child: Container(padding:EdgeInsets.symmetric(horizontal:8,vertical:4), decoration:BoxDecoration(color:color.withOpacity(0.15), borderRadius:BorderRadius.circular(4), border:Border.all(color:color.withOpacity(0.4))), child:Text(label,style:TextStyle(color:color,fontSize:12))));
  }
}
