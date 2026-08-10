import 'dart:async';
import 'dart:convert';
import 'dart:io';
class VoiceStream {
  WebSocket? _ws;
  void Function(String type, dynamic data)? onMessage;
  bool get isConnected => _ws != null;
  Future<void> connect(String url) async {
    _ws = await WebSocket.connect(url);
    _ws!.listen((d) {
      if (d is String) { final m = jsonDecode(d); onMessage?.call(m['type']??'text', m['text']??d); }
    }, onError: (e) => onMessage?.call('error','$e'), onDone: () => onMessage?.call('done',''));
  }
  void send(List<int> pcm) { _ws?.add(pcm); }
  Future<void> disconnect() async { await _ws?.close(); }
}
