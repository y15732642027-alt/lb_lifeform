/// V19 · 原始触摸·双指距·真方向
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';
import 'dart:math';
import '../core/theme.dart';

class GalaxyTab extends StatefulWidget {
  const GalaxyTab({super.key});
  @override
  State<GalaxyTab> createState() => _GalaxyTabState();
}

class _GalaxyTabState extends State<GalaxyTab> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  final _stars=<_SD>[],_nebulae=<_BN>[];
  double _px=0,_py=0,_elapsed=0,_scale=1;
  double _sw=375,_sh=667;  // 屏幕尺寸·默认值
  Map<int,Offset> _pointers={};
  double _initDist=0,_initScale=0;
  Offset _focalCenter=Offset.zero;  // 双指中心·防偏移
  final _start=DateTime.now().millisecondsSinceEpoch;

  @override
  void initState() {
    super.initState();
    final r=Random(42);
    for(int i=0;i<300;i++) _stars.add(_SD(r.nextDouble(),r.nextDouble(),0.2+r.nextDouble()*2));
    for(int i=0;i<12;i++) _nebulae.add(_BN(r.nextDouble(),0.3+r.nextDouble()*0.4,40+r.nextDouble()*120,0.002+r.nextDouble()*0.015));
    _ctrl=AnimationController(vsync:this,duration:Duration(seconds:1))
      ..addListener((){
        _elapsed=(DateTime.now().millisecondsSinceEpoch-_start)/1000.0;
        // 回弹20%·不归零
        if(_pointers.length<2){
          _scale += (1.0 - _scale) * 0.008;
        }
        if(_pointers.length<1){
          _px *= 0.998;  // 2‰衰减·永不全归
          _py *= 0.998;
        }
        setState((){});
      })
      ..repeat();
  }
  @override void dispose(){_ctrl.dispose();super.dispose();}

  double _dist(Map<int,Offset> pts){
    if(pts.length<2) return 0;
    final vals=pts.values.toList();
    return (vals[0]-vals[1]).distance;
  }

  void _showGalaxySheet(String name, Color color, int idx) {
    final agents = [
      ['匠作营·执行','巡检司·5域','太史令·记录','司阍·放行','掌机司·运维','赤候·搜集'],
      ['制片使·策划','著书使·编剧','掌镜郎·分镜','织画司·剪辑','审画郎·成品','巡检司·影视域'],
      ['掌文郎·策划','著书使·编剧','校书郎·编辑','刊行司·发布','巡检司·小说域'],
      ['设境郎·策划','铸形使·建模','织动司·引擎','试剑郎·测试','巡检司·游戏域'],
    ][idx];
    final descs = ['系统·审核·维护·进化','策划·编剧·分镜·剪辑·审核','大纲·章节·出版·审核','策划·开发·测试·审核'];
    showModalBottomSheet(
      context: context,
      backgroundColor: Color(0xFF0A0A10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(padding: EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
        SizedBox(height: 16),
        Text(name, style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.bold)),
        SizedBox(height: 8),
        Text(descs[idx], style: TextStyle(color: Colors.white54, fontSize: 14)),
        SizedBox(height: 20),
        for(final a in agents)
          _agentRow(a, a.contains('执行')?'⚡':a.contains('验证')?'🔬':a.contains('审阅')?'👁':a.contains('门禁')?'🛑':a.contains('策划')?'📋':'🔧', color),
        SizedBox(height: 20),
        Row(children: [
          Expanded(child: ElevatedButton(onPressed:(){
            final ctrl = TextEditingController();
            showDialog(context: context, builder: (_) => AlertDialog(
              backgroundColor: Color(0xFF0A0A10),
              title: Text('📋 下发任务到 $name', style: TextStyle(color: color, fontSize: 16)),
              content: TextField(controller: ctrl, style: TextStyle(color: Colors.white), decoration: InputDecoration(hintText: '任务描述...', hintStyle: TextStyle(color: Colors.white24))),
              actions: [
                TextButton(onPressed: ()=>Navigator.pop(context), child: Text('取消')),
                ElevatedButton(onPressed: (){
                  Navigator.pop(context);
                  _sendTask(name, ctrl.text, color);
                }, child: Text('发送'), style: ElevatedButton.styleFrom(backgroundColor: color.withAlpha(80))),
              ],
            ));
          },child:Text('📋 下发任务',style:TextStyle(fontSize:12)),style:ElevatedButton.styleFrom(backgroundColor:color.withAlpha(40),foregroundColor:color))),
          SizedBox(width:8),
          Expanded(child: ElevatedButton(onPressed:(){
            Navigator.pop(context);
            _showLogView(name, color);
          },child:Text('📜 查看日志',style:TextStyle(fontSize:12)),style:ElevatedButton.styleFrom(backgroundColor:Colors.white.withAlpha(8),foregroundColor:Colors.white54))),
        ]),
        SizedBox(height: 24),
      ])),
    );
  }

  void _sendTask(String agent, String task, Color c) async {
    try {
      final r = await http.post(
        Uri.parse('http://192.168.1.4:8899/dispatch'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'agent': agent, 'task': task, 'priority': 'normal'}),
      );
      if (r.statusCode == 200) {
        showSnack('✅ 已下发到 $agent');
      } else {
        showSnack('❌ 下发失败: ${r.statusCode}');
      }
    } catch (e) {
      showSnack('❌ 网络错误: $e');
    }
  }

  void showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg, style: TextStyle(fontSize: 12)), backgroundColor: Color(0xFF1a1a2e)));
  }

  void _openAgentChat(String name, Color c) {
    final ctrl = TextEditingController();
    final msgs = <String>[];
    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (_, setD) => AlertDialog(
      backgroundColor: Color(0xFF0A0A10),
      title: Text('💬 $name', style: TextStyle(color: c, fontSize: 16)),
      content: SizedBox(width: double.maxFinite, height: 300, child: Column(children: [
        Expanded(child: ListView(children: msgs.map((m) => Padding(padding: EdgeInsets.only(bottom: 6), child: Text(m, style: TextStyle(color: Colors.white70, fontSize: 13)))).toList())),
        Row(children: [
          Expanded(child: TextField(controller: ctrl, style: TextStyle(color: Colors.white, fontSize: 13), decoration: InputDecoration(hintText: '输入...', hintStyle: TextStyle(color: Colors.white24), border: OutlineInputBorder(borderSide: BorderSide(color: Colors.white12))))),
          SizedBox(width: 8),
          IconButton(icon: Icon(Icons.send, color: c), onPressed: (){
            if(ctrl.text.trim().isEmpty) return;
            setD((){ msgs.add('🧑 ${ctrl.text}'); msgs.add('🤖 $name: 收到·处理中...'); });
            ctrl.clear();
          }),
        ]),
      ])),
      actions: [TextButton(onPressed: ()=>Navigator.pop(ctx), child: Text('关闭'))],
    )));
  }

  void _showLogView(String name, Color c) {
    showDialog(context: context, builder: (_) => AlertDialog(
      backgroundColor: Color(0xFF0A0A10),
      title: Text('📜 $name · 最近日志', style: TextStyle(color: c, fontSize: 16)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        _logLine('08-07 22:00', '巡检完成·0异常'),
        _logLine('08-07 21:30', '任务队列清空'),
        _logLine('08-07 20:00', '星图V4部署成功'),
      ]),
      actions: [TextButton(onPressed: ()=>Navigator.pop(context), child: Text('关闭'))],
    ));
  }

  Widget _logLine(String time, String msg) => Padding(
    padding: EdgeInsets.only(bottom: 4),
    child: Row(children: [
      Text(time, style: TextStyle(color: Colors.white24, fontSize: 11)),
      SizedBox(width: 8),
      Text(msg, style: TextStyle(color: Colors.white54, fontSize: 13)),
    ]),
  );

  Widget _agentRow(String name, String icon, Color c) => InkWell(
    onTap: (){
      HapticFeedback.selectionClick();
      final ctrl = TextEditingController();
      showDialog(context: context, builder: (_) => AlertDialog(
        backgroundColor: Color(0xFF0A0A10),
        title: Text('📋 下发任务到 $name', style: TextStyle(color: c, fontSize: 16)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: ctrl, style: TextStyle(color: Colors.white), decoration: InputDecoration(hintText: '任务描述...', hintStyle: TextStyle(color: Colors.white24))),
          SizedBox(height: 8),
          Text('或直接对话:', style: TextStyle(color: Colors.white38, fontSize: 11)),
          SizedBox(height: 4),
          InkWell(
            onTap: (){
              Navigator.pop(context);
              _openAgentChat(name, c);
            },
            child: Container(
              width: double.infinity, padding: EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(color: c.withAlpha(20), borderRadius: BorderRadius.circular(8)),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.chat, color: c, size: 16), SizedBox(width: 6),
                Text('💬 和$name对话', style: TextStyle(color: c, fontSize: 13)),
              ]),
            ),
          ),
        ]),
        actions: [
          TextButton(onPressed: ()=>Navigator.pop(context), child: Text('取消')),
          ElevatedButton(onPressed: (){
            Navigator.pop(context);
            _sendTask(name, ctrl.text, c);
          }, child: Text('发送'), style: ElevatedButton.styleFrom(backgroundColor: c.withAlpha(80))),
        ],
      ));
    },
    child: Padding(
    padding: EdgeInsets.symmetric(vertical: 6),
    child: Row(children: [
      Text(icon, style: TextStyle(fontSize: 16)),
      SizedBox(width: 12),
      Text(name, style: TextStyle(color: Colors.white70, fontSize: 15)),
      Spacer(),
      Container(width: 8, height: 8, decoration: BoxDecoration(color: c.withAlpha(100), shape: BoxShape.circle)),
    ]),
  ),
);

  @override
  Widget build(BuildContext ctx){
    _sw=MediaQuery.of(ctx).size.width;
    _sh=MediaQuery.of(ctx).size.height;
    return Listener(
      onPointerDown:(e){
        _pointers[e.pointer]=e.position;
        if(_pointers.length>=2){
          _initDist=_dist(_pointers);
          _initScale=_scale;
          // 双指中心·以此为缩放锚点
          final pts=_pointers.values.toList();
          _focalCenter=Offset((pts[0].dx+pts[1].dx)/2,(pts[0].dy+pts[1].dy)/2);
        }
      },
      onPointerMove:(e){
        if(!_pointers.containsKey(e.pointer)) return;
        _pointers[e.pointer]=e.position;
        if(_pointers.length>=2 && _initDist>0){
          // 实时双指中心+平移
          final pts=_pointers.values.toList();
          final newC=Offset((pts[0].dx+pts[1].dx)/2,(pts[0].dy+pts[1].dy)/2);
          _px += (newC.dx-_focalCenter.dx)/_scale;
          _py += (newC.dy-_focalCenter.dy)/_scale;
          _focalCenter = newC;
          final d=_dist(_pointers);
          final oldS=_scale;
          final target=(_initScale*d/_initDist).clamp(0.7,2.5);
          _scale += (target - _scale) * 0.3;
          _px += (newC.dx-_sw/2)*(1/oldS-1/_scale);
          _py += (newC.dy-_sh/2)*(1/oldS-1/_scale);
        }else if(_pointers.length==1){
          _px+=e.delta.dx/_scale;
          _py+=e.delta.dy/_scale;
          final mr=_sw*1.0;  _px=_px.clamp(-mr,mr); _py=_py.clamp(-mr,mr);
        }
        setState((){});
      },
      onPointerUp:(e){
        // 单击检测——点到星系弹出详情
        if(e.pointer==_pointers.keys.first && _pointers.length==1){
          final tap=Offset((e.position.dx-_sw/2)/_scale-_px,(e.position.dy-_sh/2)/_scale-_py);
          for(int i=0;i<4;i++){
            final a=i*1.5708+_elapsed*_GP19._s[i];
            final ox=cos(a)*_GP19._r[i],oy=sin(a)*_GP19._r[i];
            if((tap.dx-ox)*(tap.dx-ox)+(tap.dy-oy)*(tap.dy-oy) < 35*35){
              _showGalaxySheet(_GP19._n[i],_GP19._c[i],i);
              break;
            }
          }
        }
        _pointers.remove(e.pointer);if(_pointers.length<2){_initDist=0;}
      },
      onPointerCancel:(e){_pointers.remove(e.pointer);},
      child:Scaffold(backgroundColor:Color(0xFF020205),body:
        CustomPaint(painter:_GP19(stars:_stars,nebulae:_nebulae,elapsed:_elapsed,scale:_scale,px:_px,py:_py),size:Size.infinite)),
    );
  }
}

class _SD{double x,y,sz;_SD(this.x,this.y,this.sz);}
class _BN{double x,y,radius,speed;_BN(this.x,this.y,this.radius,this.speed);}

class _GP19 extends CustomPainter{
  final List<_SD> stars;final List<_BN> nebulae;
  final double elapsed,scale,px,py;
  _GP19({required this.stars,required this.nebulae,required this.elapsed,required this.scale,required this.px,required this.py});
  static const _s=[0.12,0.09,0.06,0.04],_r=[100.0,150.0,200.0,250.0];
  // 星系信息·供点击检测
  static const _n=['核心系统','影视星系','小说星系','游戏星系'];
  static const _c=[Color(0xFF6078A0),Color(0xFF5CB8A0),Color(0xFFF0A0C0),Color(0xFFE0C060)];
  @override void paint(Canvas c,Size sz){
    final cx=sz.width/2+px*scale,cy=sz.height/2+py*scale;
    for(final s in stars){final sy=(s.y+elapsed*0.03)%1*sz.height;c.drawCircle(Offset(s.x*sz.width,sy),s.sz,Paint()..color=Colors.white.withAlpha((15+25*sin(elapsed*3+s.x*30)).toInt().clamp(0,55)));}
    for(final n in nebulae){final ny=(n.y+elapsed*n.speed)%1*sz.height;c.drawCircle(Offset(n.x*sz.width,ny),n.radius,Paint()..shader=RadialGradient(colors:[Colors.white.withAlpha(3),Colors.transparent]).createShader(Rect.fromCircle(center:Offset(n.x*sz.width,ny),radius:n.radius)));}
    c.save();c.translate(sz.width/2+px,sz.height/2+py);c.scale(scale);c.translate(-sz.width/2-px,-sz.height/2-py);
    for(int i=1;i<=4;i++) c.drawCircle(Offset(cx,cy),(70+i*35)*scale,Paint()..color=Colors.white.withAlpha(4)..style=PaintingStyle.stroke..strokeWidth=0.3);
    final br=1+0.08*sin(elapsed*1.5);
    c.drawCircle(Offset(cx,cy),40*br*scale,Paint()..shader=RadialGradient(colors:[HermesTheme.gold.withAlpha(90),HermesTheme.gold.withAlpha(15),Colors.transparent]).createShader(Rect.fromCircle(center:Offset(cx,cy),radius:40*br*scale)));
    c.drawCircle(Offset(cx,cy),10*scale,Paint()..color=HermesTheme.gold.withAlpha(160));
    c.drawCircle(Offset(cx,cy),3*scale,Paint()..color=Colors.white.withAlpha(200));
    TextPainter(text:TextSpan(text:'生命核心',style:TextStyle(color:HermesTheme.gold,fontSize:(11*scale).clamp(6,22))),textDirection:TextDirection.ltr)..layout()..paint(c,Offset(cx-22*scale,cy+44*scale));
    for(int i=0;i<4;i++){final a=i*1.5708+elapsed*_s[i];final ox=cx+cos(a)*_r[i]*scale,oy=cy+sin(a)*_r[i]*scale;
      c.drawCircle(Offset(ox,oy),32*scale,Paint()..shader=RadialGradient(colors:[_c[i].withAlpha(70),_c[i].withAlpha(10),Colors.transparent]).createShader(Rect.fromCircle(center:Offset(ox,oy),radius:32*scale)));
      c.drawCircle(Offset(ox,oy),5*scale,Paint()..color=_c[i].withAlpha(180));
      c.drawCircle(Offset(ox,oy),2*scale,Paint()..color=Colors.white.withAlpha(150));
      TextPainter(text:TextSpan(text:_n[i],style:TextStyle(color:_c[i].withAlpha(170),fontSize:(9*scale).clamp(5,14))),textDirection:TextDirection.ltr)..layout()..paint(c,Offset(ox-18*scale,oy+34*scale));
      for(int p=0;p<25;p++){final pa=a+p*0.25+elapsed*0.5;final pr=28*scale+5*scale*sin(elapsed*4+p);c.drawCircle(Offset(ox+cos(pa)*pr,oy+sin(pa)*pr),0.7*scale,Paint()..color=_c[i].withAlpha((20+30*sin(elapsed*4+p)).toInt().clamp(0,55)));}
    }
    c.restore();
  }
  @override bool shouldRepaint(covariant CustomPainter o)=>true;
}
