import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class RequestWebSocketService {
  static const String _wsBaseUrl = 'wss://api.itfixer199.com/ws/requests/';

  WebSocketChannel? _channel;
  bool _isConnecting = false;
  bool _manualDisconnect = false;
  int _reconnectAttempts = 0;
  
  final StreamController<Map<String, dynamic>> _messageController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;

  Future<void> connect({
    String? date,
    String? startDate,
    String? endDate,
    int page = 1,
    int size = 10,
  }) async {
    if (_isConnecting) return;
    _isConnecting = true;
    _manualDisconnect = false;

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');

      
      if (token == null) {
        print('❌ Request WebSocket error: No access token found');
        _isConnecting = false;
        return;
      }

      final queryParams = <String, String>{
        'token': token,
        if (date != null) 'date': date,
        if (startDate != null) 'start_date': startDate,
        if (endDate != null) 'end_date': endDate,
        'page': page.toString(),
        'size': size.toString(),
      };

      final uri = Uri.parse(_wsBaseUrl).replace(queryParameters: queryParams);
      print('📡 Connecting to Request WebSocket: $uri');
      
      _channel = WebSocketChannel.connect(uri);

      _channel!.stream.listen(
        (message) {
          _reconnectAttempts = 0;
          _isConnecting = false;
          print('📦 Request WebSocket Message Received: $message');
          try {
            final Map<String, dynamic> data = jsonDecode(message);
            if (!_messageController.isClosed) {
              _messageController.add(data);
            }
          } catch (e) {
            print('❌ Request WebSocket parse error: $e');
          }
        },
        onError: (error) {
          _isConnecting = false;
          print('❌ Request WebSocket error: $error');
          if (!_manualDisconnect) {
            _reconnect(date: date, startDate: startDate, endDate: endDate, page: page, size: size);
          }
        },
        onDone: () {
          _isConnecting = false;
          print('🔌 Request WebSocket connection closed');
          if (!_manualDisconnect) {
            _reconnect(date: date, startDate: startDate, endDate: endDate, page: page, size: size);
          }
        },
      );
    } catch (e) {
      _isConnecting = false;
      print('❌ Request WebSocket connection exception: $e');
      if (!_manualDisconnect) {
        _reconnect(date: date, startDate: startDate, endDate: endDate, page: page, size: size);
      }
    }
  }

  /// Update filters on-the-fly without reconnecting
  void updateFilters({
    String? startDate,
    String? endDate,
    int? page,
    int? size,
  }) {
    if (_channel == null) return;
    
    final filterMessage = {
      if (startDate != null) 'start_date': startDate,
      if (endDate != null) 'end_date': endDate,
      if (page != null) 'page': page,
      if (size != null) 'size': size,
    };
    
    print('📤 Sending filter update: $filterMessage');
    _channel!.sink.add(jsonEncode(filterMessage));
  }

  void _reconnect({
    String? date,
    String? startDate,
    String? endDate,
    int page = 1,
    int size = 10,
  }) {
    if (_manualDisconnect) return;
    if (_reconnectAttempts > 5) {
      print('⚠️ Request WebSocket: Max reconnect attempts reached.');
    }
    
    _reconnectAttempts++;
    final delay = Duration(seconds: (2 * _reconnectAttempts).clamp(5, 30));
    
    print('🔄 Attempting to reconnect Request WebSocket in ${delay.inSeconds} seconds...');
    
    Future.delayed(delay, () {
      if (!_manualDisconnect && (_channel == null || _isConnecting == false)) {
        connect(
          date: date,
          startDate: startDate,
          endDate: endDate,
          page: page,
          size: size,
        );
      }
    });
  }

  void disconnect() {
    _manualDisconnect = true;
    _channel?.sink.close();
    _channel = null;
  }

  void dispose() {
    disconnect();
    _messageController.close();
  }
}
