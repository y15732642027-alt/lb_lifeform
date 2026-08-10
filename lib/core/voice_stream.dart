import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// 纯WebSocket实时语音·不用flutter_webrtc
class VoiceStream {
  WebSocket? _ws;
  Function(String type, dynamic data)? onMessage;

  Future<void> connect(String wsUrl) async {
    _ws = await WebSocket.connect(wsUrl);
    
    // 接收消息
    _ws!.listen((data) {
      if (data is String) {
        final msg = jsonDecode(data);
        if (msg['type'] == 'stt' || msg['type'] == 'tts') {
          onMessage?.call(msg['type'], msg['text']);
        }
      } else if (data is List<int>) {
        onMessage?.call('audio', data);
      }
    }, onError: (e) {
      onMessage?.call('error', e.toString());
    });
  }

  void send(List<int> pcmBytes) {
    _ws?.add(pcmBytes);
  }

  Future<void> disconnect() async {
    await _ws?.close();
  }
}
