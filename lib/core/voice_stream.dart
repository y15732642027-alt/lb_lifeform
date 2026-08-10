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

  bool get isConnected => _ws != null;

  void send(List<int> pcmBytes) {
    _ws?.add(pcmBytes);
  }

  Future<void> disconnect() async {
    await _ws?.close();
  }
}
