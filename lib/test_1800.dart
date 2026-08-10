import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'dart:async';

// 1800·录音测试——不依赖任何其他代码
class RecorderTest extends StatefulWidget {
  @override
  _RecorderTestState createState() => _RecorderTestState();
}

class _RecorderTestState extends State<RecorderTest> {
  late FlutterSoundRecorder _rec;
  StreamController<Uint8List>? _ctrl;
  double _energy = 0;
  String _status = '待机';

  @override
  void initState() {
    super.initState();
    _rec = FlutterSoundRecorder();
    _init();
  }

  Future<void> _init() async {
    await _rec.openRecorder();
    setState(() => _status = '录音器就绪');
  }

  void _toggleRecord() async {
    if (_rec.isRecording) {
      await _rec.stopRecorder();
      _ctrl?.close();
      setState(() { _status = '停止'; _energy = 0; });
    } else {
      try {
        _ctrl = StreamController<Uint8List>();
        await _rec.startRecorder(toStream: _ctrl!.sink, codec: Codec.pcm16, sampleRate: 16000, numChannels: 1);
        _ctrl!.stream.listen((data) {
          int sum = 0;
          for (int i=0; i<data.length; i+=2) sum += (data[i] & 0xff) | ((data[i+1]&0xff)<<8);
          double avg = (sum / (data.length~/2)).abs() / 32768.0;
          setState(() => _energy = avg);
        });
        setState(() => _status = '录制中');
      } catch(e) {
        setState(() => _status = '错误: $e');
      }
    }
  }

  @override
  Widget build(BuildContext ctx) {
    return Scaffold(
      backgroundColor: Color(0xFF050505),
      body: SafeArea(child: Column(mainAxisAlignment:MainAxisAlignment.center, children:[
        GestureDetector(
          onTapDown:(_)=>_toggleRecord(),
          onTapUp:(_)=>_toggleRecord(),
          child: Container(
            width: 200, height:200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _rec.isRecording ? Colors.blue.withOpacity(0.3+_energy*0.7) : Colors.amber.withOpacity(0.3),
              boxShadow: [BoxShadow(color:(_rec.isRecording?Colors.blue:Colors.amber).withOpacity(0.5+_energy), blurRadius:40+_energy*60)]
            ),
            child: Center(child: Text(_status, style:TextStyle(color:Colors.white)))
          )
        ),
        SizedBox(height:20),
        Text('按住录音·光球随声动', style:TextStyle(color:Colors.white54))
      ]))
    );
  }
}
