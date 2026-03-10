import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:shared_preferences/shared_preferences.dart';

class InventoryWebSocketService {
  static const String _wsUrl = 'wss://api.itfixer199.com/ws/movements/';
  
  WebSocketChannel? _channel;
  bool _isConnecting = false;
  int _reconnectAttempts = 0;
  final StreamController<Map<String, dynamic>> _messageController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;

  Future<void> connect() async {
    if (_isConnecting) return;
    _isConnecting = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      
      if (token == null) {
        print('❌ WebSocket error: No access token found');
        _isConnecting = false;
        return;
      }

      final uri = Uri.parse('$_wsUrl?token=$token');
      print('📡 Connecting to WebSocket: $uri');
      
      _channel = WebSocketChannel.connect(uri);

      // Wait for the first message or error to confirm connection
      _channel!.stream.listen(
        (message) {
          _reconnectAttempts = 0;
          _isConnecting = false;
          print('📦 WebSocket Message Received: $message');
          try {
            final Map<String, dynamic> data = jsonDecode(message);
            _messageController.add(data);
          } catch (e) {
            print('❌ WebSocket parse error: $e');
          }
        },
        onError: (error) {
          _isConnecting = false;
          print('❌ WebSocket error: $error');
          _reconnect();
        },
        onDone: () {
          _isConnecting = false;
          print('🔌 WebSocket connection closed');
          _reconnect();
        },
      );
    } catch (e) {
      _isConnecting = false;
      print('❌ WebSocket connection exception: $e');
      _reconnect();
    }
  }

  void _reconnect() {
    if (_reconnectAttempts > 5) {
      print('⚠️ WebSocket: Max reconnect attempts reached. Waiting longer...');
    }
    
    _reconnectAttempts++;
    final delay = Duration(seconds: (2 * _reconnectAttempts).clamp(5, 30));
    
    print('🔄 Attempting to reconnect in ${delay.inSeconds} seconds (Attempt $_reconnectAttempts)...');
    
    Future.delayed(delay, () {
      if (_channel == null || _isConnecting == false) {
        connect();
      }
    });
  }

  void disconnect() {
    _channel?.sink.close();
    _channel = null;
  }

  void dispose() {
    disconnect();
    _messageController.close();
  }
}
