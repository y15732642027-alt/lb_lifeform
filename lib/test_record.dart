import 'dart:async';
import 'package:flutter/material.dart';
import 'package:record/record.dart';

/// 2300·纯录音测试·不连网
class RecordTest extends StatefulWidget {
  const RecordTest({super.key});
  State<RecordTest> createState() => _RecordTestState();
}

class _RecordTestState extends State<RecordTest> {
  final _rec = AudioRecorder();
  double _vu = 0.0;
  String _msg = '按我录音';
  bool _isOn = false;
  StreamSubscription<RecordState>? _sub;

  void _tap() async {
    if (_isOn) {
      _sub?.cancel();
      await _rec.stop();
      setState(() { _isOn = false; _vu = 0; _msg = '已停止'; });
    } else {
      try {
        final has = await _rec.hasPermission();
        if (!has) {
          setState(() => _msg = '❌无权限·去设置→隐私→麦克风→开');
          return;
        }
        final stream = await _rec.startStream(const RecordConfig(
          encoder: AudioEncoder.pcm16bits, sampleRate: 16000, numChannels: 1,
        ));
        _sub = stream.listen((state) {
          if (state.decibels != null) {
            setState(() => _vu = (state.decibels! + 60).clamp(0, 60) / 60);
          }
        });
        setState(() { _isOn = true; _msg = '说话→光球动'; });
      } catch (e) {
        setState(() => _msg = '❌: $e');
      }
    }
  }

  Widget build(BuildContext c) => Scaffold(
    backgroundColor: const Color(0xFF050505),
    body: SafeArea(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      GestureDetector(
        onTap: _tap,
        child: AnimatedContainer(duration: Duration(milliseconds: 200),
          width: 180 + _vu * 60, height: 180 + _vu * 60,
          decoration: BoxDecoration(shape: BoxShape.circle,
            color: _isOn ? Colors.blue.withValues(alpha: 0.4 + _vu * 0.6) : Colors.amber.withValues(alpha: 0.3),
            boxShadow: [BoxShadow(color: (_isOn ? Colors.blue : Colors.amber).withValues(alpha: 0.5 + _vu), blurRadius: 40 + _vu * 80)]),
          child: Center(child: _isOn ? Icon(Icons.mic, color: Colors.white, size: 50) : Icon(Icons.mic_none, color: Colors.white54, size: 50)))),
      const SizedBox(height: 30),
      Text(_msg, style: TextStyle(color: Colors.white70, fontSize: 16)),
    ])));
}
