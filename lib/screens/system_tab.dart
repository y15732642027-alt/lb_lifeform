import 'package:flutter/material.dart';
import 'dart:async';
import 'package:http/http.dart' as http;
import '../core/theme.dart';

class SystemTab extends StatefulWidget {
  const SystemTab({super.key});
  @override
  State<SystemTab> createState() => _SystemTabState();
}

class _SystemTabState extends State<SystemTab> {
  Map<String,bool> _status = {'api':false,'white':false,'gateway':true};
  Timer? _timer;

  @override
  void initState() { super.initState(); _check(); _timer = Timer.periodic(Duration(seconds:30), (_)=>_check()); }
  @override
  void dispose() { _timer?.cancel(); super.dispose(); }

  Future<void> _check() async {
    final s = <String,bool>{};
    try { final r = await http.get(Uri.parse('https://symbio.xin/api/ping')).timeout(Duration(seconds:3)); s['api'] = r.statusCode==200; } catch (_) { s['api'] = false; }
    try { final r = await http.get(Uri.parse('http://192.168.1.2:8848/health')).timeout(Duration(seconds:3)); s['white'] = r.statusCode==200; } catch (_) { s['white'] = false; }
    s['gateway'] = true;
    if (mounted) setState(() => _status = s);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('系统')),
    body: ListView(padding: EdgeInsets.all(14), children: [
      _section('连接状态', [
        _row(Icons.cloud_done, '8899 API', '192.168.1.4:8899', _status['api']==true),
        _row(Icons.memory, '白鼠', '192.168.1.2:8848', _status['white']==true),
        _row(Icons.chat, 'Gateway', '微信+飞书', _status['gateway']==true),
      ]),
      SizedBox(height: 16),
      _section('插件模块', [
        _plugin('🎤 语音', '未安装'), _plugin('🎬 影视链', '未安装'), _plugin('📺 电视投屏', '未安装'),
        _plugin('📱 平板互联', '未安装'), _plugin('📷 相机采集', '未安装'), _plugin('🤖 手机机器人', '未安装'),
      ]),
      SizedBox(height: 16),
      _section('偏好', [
        ListTile(title: Text('主题', style: TextStyle(color: HermesTheme.textPrimary)), subtitle: Text('暗黑', style: TextStyle(color: HermesTheme.textSecondary)), trailing: Icon(Icons.chevron_right, color: HermesTheme.textSecondary)),
        ListTile(title: Text('刷新间隔', style: TextStyle(color: HermesTheme.textPrimary)), subtitle: Text('30秒', style: TextStyle(color: HermesTheme.textSecondary)), trailing: Icon(Icons.chevron_right, color: HermesTheme.textSecondary)),
      ]),
      SizedBox(height: 16),
      _section('关于', [
        ListTile(title: Text('灯泡生命体', style: TextStyle(color: HermesTheme.textPrimary, fontWeight: FontWeight.bold)), subtitle: Text('V2.0 · Aug 05 2026', style: TextStyle(color: HermesTheme.textSecondary))),
      ]),
    ]),
  );

  Widget _section(String t, List<Widget> c) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(t, style: TextStyle(color: Color(0xFFe94560), fontSize: 12, fontWeight: FontWeight.bold)),
    SizedBox(height: 6),
    Container(decoration: BoxDecoration(color: Color(0xFF1a1a2e), borderRadius: BorderRadius.circular(10), border: Border.all(color: Color(0xFF2a2a4a))), child: Column(children: c)),
  ]);

  Widget _row(IconData icon, String name, String detail, bool on) => ListTile(
    leading: Icon(icon, color: on ? Color(0xFF00cc66) : Colors.red, size: 20),
    title: Text(name, style: TextStyle(color: HermesTheme.textPrimary, fontSize: 13)),
    subtitle: Text(detail, style: TextStyle(color: HermesTheme.textSecondary, fontSize: 10)),
    trailing: Container(width: 8, height: 8, decoration: BoxDecoration(color: on ? Color(0xFF00cc66) : Colors.red, shape: BoxShape.circle)),
  );

  Widget _plugin(String name, String status) => ListTile(
    leading: Text(name.split(' ')[0], style: TextStyle(fontSize: 16, color: HermesTheme.textSecondary.withOpacity(0.3))),
    title: Text(name.split(' ').skip(1).join(' '), style: TextStyle(color: HermesTheme.textSecondary.withOpacity(0.3), fontSize: 13)),
    trailing: Container(padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: Color(0xFF2a2a4a), borderRadius: BorderRadius.circular(4)), child: Text(status, style: TextStyle(color: HermesTheme.textSecondary, fontSize: 9))),
  );
}
