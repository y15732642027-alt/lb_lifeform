import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/theme.dart';

class MessagesTab extends StatefulWidget {
  const MessagesTab({super.key});
  @override
  State<MessagesTab> createState() => MessagesTabState();
}

class MessagesTabState extends State<MessagesTab> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String,dynamic>> _tasks = [], _approvals = [], _notifs = [];
  final List<Map<String,String>> _conversations = [];
  final _chatCtrl = TextEditingController();
  String _chatReply = '';
  final Set<String> _removed = {};
  int? _expanded;
  Timer? _timer;
  bool _loading = true;
  bool _busy = false;
  final String _base = 'http://192.168.1.2:8848';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _fetch();
    _timer = Timer.periodic(Duration(seconds: 5), (_) => _fetch());
  }

  @override
  void dispose() { _timer?.cancel(); _tabController.dispose(); _chatCtrl.dispose(); super.dispose(); }

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
      final r = await http.get(Uri.parse('http://192.168.1.4:8899/dispatched')).timeout(Duration(seconds:3));
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

  Future<void> _approve(String id, String action) async {
    try {
      await http.post(Uri.parse('$_base/respond'), headers: {'Content-Type':'application/json'}, body: jsonEncode({'id':id,'action':action}));
    } catch (_) {}
    _removed.add(id);
    setState(() { _approvals.removeWhere((a)=>a['id']==id); });
  }

  void _sendMsg(String text) {
    if(text.trim().isEmpty) return;
    setState((){
      _conversations.add({'role':'me','text':text});
      _conversations.add({'role':'bulb','text':'收到: $text'});
    });
    _chatCtrl.clear();
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
    return Column(children: [
      SizedBox(height:4),
      TabBar(controller:_tabController, indicatorColor:Color(0xFFe94560), labelColor:Color(0xFFe94560), unselectedLabelColor:HermesTheme.textSecondary,
        tabs: [Tab(text:'任务 ${_tasks.length>0?"(${_tasks.length})":""}'), Tab(text:'审批 ${_approvals.length>0?"(${_approvals.length})":""}'), Tab(text:'通知 ${_notifs.length>0?"(${_notifs.length})":""}'), Tab(text:'对话')]),
      Expanded(child: TabBarView(controller:_tabController, children: [
        _buildTaskList(),
        _buildList(_approvals, (a)=>Column(children:[
         ListTile(title:Text('⚠️ ${a['title']??''}',style:TextStyle(color:Color(0xFFef4444))),subtitle:Text(a['agent']??'',style:TextStyle(color:HermesTheme.textSecondary,fontSize:12)),trailing:Row(mainAxisSize:MainAxisSize.min,children:[_btn('同意',()=>_approve(a['id']??'','approved'),Color(0xFF00cc66)),SizedBox(width:4),_btn('拒绝',()=>_approve(a['id']??'','rejected'),Color(0xFFef4444))]),onTap:()=>setState(()=>_expanded=_expanded==a.hashCode?null:a.hashCode)),
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
            IconButton(icon:Icon(Icons.send,color:HermesTheme.gold),onPressed:()=>_sendMsg(_chatCtrl.text)),
          ])),
        ]),
      ]))
    ]);
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
