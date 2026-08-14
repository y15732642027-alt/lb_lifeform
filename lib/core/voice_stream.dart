import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// 纯WebSocket实时语音客户端
class VoiceStream {
  WebSocket? _ws;
  void Function(String type, dynamic data)? onMessage;

  Future<void> connect(String wsUrl) async {
    _ws = await WebSocket.connect(wsUrl);
    _ws!.listen((data) {
      if (data is String) {
        final msg = jsonDecode(data);
        final t = msg['type'];
        if (t == 'stt' || t == 'tts' || t == 'tts_delta') {
          onMessage?.call(t, msg['text']);
        } else if (t == 'stop') {
          onMessage?.call('stop', null); // 服务端检测到插话·停播
        }
      } else if (data is List<int>) {
        onMessage?.call('audio', data);
      }
    }, onError: (e) {
      onMessage?.call('error', e.toString());
    });
  }

  /// 打断: 发送打断指令
  void sendInterrupt() {
    _ws?.add('{"type":"interrupt"}');
  }

  /// 灯泡开始播放语音(服务器屏蔽回音)
  void sendPlaying() {
    _ws?.add('{"type":"playing"}');
  }

  /// 播放结束
  void sendPlayed() {
    _ws?.add('{"type":"played"}');
  }

  void send(List<int> pcmBytes) {
    _ws?.add(pcmBytes);
  }

  Future<void> disconnect() async {
    await _ws?.close();
  }
}
