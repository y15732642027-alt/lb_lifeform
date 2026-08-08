import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import '../core/theme.dart';

class VoiceTab extends StatefulWidget {
  const VoiceTab({super.key});
  @override
  State<VoiceTab> createState() => _VoiceTabState();
}

class _VoiceTabState extends State<VoiceTab> {
  final List<Map<String,String>> _messages = [];
  final _ctrl = TextEditingController();
  final String _rat = 'http://192.168.1.2:8848';
  Timer? _poll;
  String _lastReply = "";
  bool _waiting = false;

  @override
  void initState() {
    super.initState();
    _poll = Timer.periodic(Duration(seconds: 2), (_) => _checkReply());
  }

  @override
  void dispose() { _ctrl.dispose(); _poll?.cancel(); super.dispose(); }

  void _checkReply() async {
    try {
      final r = await http.get(Uri.parse('$_rat/chat_reply')).timeout(Duration(seconds:3));
      if (r.statusCode == 200) {
        final d = jsonDecode(r.body);
        final reply = d['reply'] ?? '';
        if (reply.isNotEmpty && reply != _lastReply) {
          _lastReply = reply;
          setState(() {
            _messages.add({'role':'灯','text':reply});
            _waiting = false;
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _send(String text) async {
    if (text.isEmpty || _waiting) return;
    setState(() {
      _messages.add({'role':'你','text':text});
      _waiting = true;
    });
    _ctrl.clear();
    try {
      final r = await http.post(Uri.parse('$_rat/chat'),
        headers: {'Content-Type':'application/json'},
        body: jsonEncode({'text':text}),
      ).timeout(Duration(seconds:20));
      if (r.statusCode == 200) {
        final d = jsonDecode(r.body);
        setState(() {
          _messages.add({'role':'灯','text':d['reply']??'(无回复)'});
          _waiting = false;
        });
      }
    } catch (_) {
      setState(() => _waiting = false);
    }
  }

  @override
  Widget build(BuildContext ctx) {
    return Column(children: [
      Container(padding:EdgeInsets.all(8),color:Color(0xFF003322),
        child:Row(children:[Icon(Icons.mic,color:Colors.green,size:16),SizedBox(width:8),
          Text(_waiting?'⏳ 等待灯泡回复...':'🎤 实时对话·同一条线',style:TextStyle(color:HermesTheme.textSecondary,fontSize:13))])),
      Expanded(child: ListView.builder(itemCount:_messages.length, itemBuilder:(_,i){
        final m = _messages[i]; final isMe = m['role']=='你';
        return Align(alignment:isMe?Alignment.centerRight:Alignment.centerLeft,
          child: Container(margin:EdgeInsets.all(6),padding:EdgeInsets.all(12),
            decoration:BoxDecoration(color:isMe?Color(0xFF1a3a5c):Color(0xFF1a1a3e),borderRadius:BorderRadius.circular(12)),
            child:Text(m['text']!,style:TextStyle(color:HermesTheme.textPrimary,fontSize:15))));
      })),
      Container(padding:EdgeInsets.all(8),color:Color(0xFF0d0d1a),
        child:Row(children:[
          Expanded(child:TextField(controller:_ctrl,enabled:!_waiting,
            style:TextStyle(color:HermesTheme.textPrimary),
            decoration:InputDecoration(hintText:'说话·灯泡秒回',hintStyle:TextStyle(color:HermesTheme.textSecondary),border:InputBorder.none),
            onSubmitted:_send)),
          IconButton(icon:Icon(Icons.send,color:_waiting?Colors.grey:Color(0xFF22d3ee)),onPressed:_waiting?null:()=>_send(_ctrl.text)),
        ]))
    ]);
  }
}
