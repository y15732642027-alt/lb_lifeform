import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

/// Hermes系统API客户端 — 灯泡伴侣唯一通信枢纽
///
/// V0.1: HTTP查询通道。
/// V0.2: 增加WebSocket事件通道。
/// V0.3: 增加任务命令队列通道。
///
/// 不直接连Gateway — 统一走台式机Agent的Companion API(8090端口)
class ApiClient {
  /// 台式机Agent地址 (局域网·二郎家内网)
  /// 笔记本状态API(代理台式机+本地检测)
  static const String _defaultHost = '192.168.1.4';
  static const int _defaultPort = 8899;

  final String host;
  final int port;
  final http.Client _client;

  /// 请求超时: 局域网5秒足够
  final Duration timeout;

  ApiClient({
    this.host = _defaultHost,
    this.port = _defaultPort,
    this.timeout = const Duration(seconds: 5),
    http.Client? client,
  }) : _client = client ?? http.Client();

  Uri get _baseUri => Uri(scheme: 'http', host: host, port: port);

  /// GET 请求
  ///
  /// 返回 null = 网络不可达(离线)
  /// 抛出 ApiException = 服务端错误
  Future<Map<String, dynamic>?> get(String path) async {
    try {
      final response = await _client
          .get(_baseUri.resolve(path))
          .timeout(timeout);

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      throw ApiException(response.statusCode, response.body);
    } on SocketException {
      return null; // 网络不可达
    } on TimeoutException {
      return null; // 超时=不可达
    }
  }

  /// POST 请求 (发消息·发命令)
  Future<Map<String, dynamic>?> post(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    try {
      final response = await _client
          .post(
            _baseUri.resolve(path),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body ?? {}),
          )
          .timeout(timeout);

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      throw ApiException(response.statusCode, response.body);
    } on SocketException {
      return null;
    } on TimeoutException {
      return null;
    }
  }

  /// 快速探活 — 只检查端口是否可达
  Future<bool> ping() async {
    try {
      final response = await _client
          .get(_baseUri.resolve('/api/ping'))
          .timeout(const Duration(seconds: 2));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  void dispose() => _client.close();
}

class ApiException implements Exception {
  final int statusCode;
  final String body;

  ApiException(this.statusCode, this.body);

  @override
  String toString() => 'ApiException($statusCode): $body';
}
