import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_webrtc/flutter_webrtc.dart';

/// Hermes WebRTC实时语音客户端
/// 连接voice_engine_webrtc.py·9877端口
class WebRTCVoiceClient {
  RTCPeerConnection? _pc;
  WebSocket? _ws;
  MediaStream? _localStream;
  Function(String type, dynamic data)? onMessage;

  Future<void> connect(String wsUrl) async {
    _pc = await createPeerConnection({
      'iceServers': [{'urls': 'stun:stun.l.google.com:19302'}]
    });

    // 获取麦克风
    _localStream = await navigator.mediaDevices.getUserMedia({'audio': true});
    _localStream!.getTracks().forEach((track) {
      _pc!.addTrack(track, _localStream!);
    });

    // 接收远程音频轨道
    _pc!.onTrack = (RTCTrackEvent e) {
      // 服务端会通过WebRTC轨道发TTS音频
      // Flutter端播放（需audioplayers）
    };

    // 信令连接
    _ws = await WebSocket.connect(wsUrl);

    // 创建offer
    final offer = await _pc!.createOffer();
    await _pc!.setLocalDescription(offer);
    _ws!.add(jsonEncode({'type': 'offer', 'sdp': offer.sdp}));

    // 信令循环
    // 单一监听器——合并信令+ICE
    _ws!.listen((data) {
      final msg = jsonDecode(data as String);
      if (msg['type'] == 'answer') {
        _pc!.setRemoteDescription(RTCSessionDescription(msg['sdp'], 'answer'));
      } else if (msg['type'] == 'ice') {
        _pc!.addCandidate(RTCIceCandidate(
          msg['candidate']['candidate'],
          msg['candidate']['sdpMid'],
          msg['candidate']['sdpMLineIndex'],
        ));
      } else if (msg['type'] == 'stt' || msg['type'] == 'tts') {
        onMessage?.call(msg['type'], msg['text']);
      }
    }, onError: (e) {
      onMessage?.call('error', e.toString());
    });

    // ICE candidates
    _pc!.onIceCandidate = (RTCIceCandidate candidate) {
      if (candidate.candidate != null) {
        _ws!.add(jsonEncode({
          'type': 'ice',
          'candidate': {
            'candidate': candidate.candidate,
            'sdpMid': candidate.sdpMid,
            'sdpMLineIndex': candidate.sdpMLineIndex,
          }
        }));
      }
    };
  }

  Future<void> disconnect() async {
    await _localStream?.dispose();
    await _pc?.close();
    await _ws?.close();
  }
}
